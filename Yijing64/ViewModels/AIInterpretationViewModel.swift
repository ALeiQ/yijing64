import Foundation
import YijingCore

/// 对话展示模型：承载思考内容与流式标记（思考不写入持久化 transcript）。
struct AITurn: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id: UUID
    var role: Role
    var content: String
    var reasoning: String
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        reasoning: String = "",
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.isStreaming = isStreaming
    }
}

@MainActor
final class AIInterpretationViewModel: ObservableObject {
    @Published var question = ""
    /// 本次会话已展示的对话气泡（含进行中的流式占位）。
    @Published private(set) var turns: [AITurn] = []
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?
    /// 本次会话累计的 AI token 用量（含开始前的历史记录累计）。
    @Published private(set) var sessionUsage: TokenUsage?

    private let client: LLMClient
    private let store: CastHistoryStore
    private let usageStore: TokenUsageStore
    private let record: CastRecord
    /// 已成功保存的对话轮次（仅成功轮次入队，避免悬空提问）。
    private var committed: [DialogueTurn]

    var hasAPIKey: Bool { !client.config.apiKey.isEmpty }

    var canSend: Bool { hasAPIKey && !isSending }

    var isReplay: Bool { !record.transcript.isEmpty || (!record.question.isEmpty || !record.aiAnswer.isEmpty) }

    /// 起卦结果（用于摘要展示）。
    var result: CastResult { record.result }

    /// 记录创建时间（用于回放标注）。
    var recordDate: Date { record.date }

    init(
        record: CastRecord,
        client: LLMClient? = nil,
        settings: LLMSettings = .shared,
        store: CastHistoryStore = CastHistoryStore(),
        usageStore: TokenUsageStore = TokenUsageStore()
    ) {
        self.record = record
        self.client = client ?? LLMClient(config: settings.config, sessionID: record.id.uuidString)
        self.store = store
        self.usageStore = usageStore
        self.sessionUsage = record.aiUsage

        if !record.transcript.isEmpty {
            committed = record.transcript
            turns = record.transcript.map { AITurn(role: $0.role == .user ? .user : .assistant, content: $0.content) }
        } else if !record.question.isEmpty || !record.aiAnswer.isEmpty {
            let dTurns = [DialogueTurn.user(record.question), DialogueTurn.assistant(record.aiAnswer)]
            committed = dTurns
            turns = dTurns.map { AITurn(role: $0.role == .user ? .user : .assistant, content: $0.content) }
        } else {
            committed = []
        }
    }

    func interpret() {
        guard canSend else { return }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        // 留空发送 = 默认解卦：请模型基于当前卦象重新解读。
        let request = trimmed.isEmpty ? "请重新解读本卦卦象。" : trimmed

        let userTurn = DialogueTurn.user(trimmed.isEmpty ? "请解卦" : trimmed)
        turns.append(AITurn(role: .user, content: userTurn.content))
        question = ""
        errorMessage = nil

        // 与占卜无关的问题在本地直接拒绝，不走模型。
        guard DivinationTopic.relevance(of: trimmed, history: committed) == .divination else {
            let refusal = "这似乎与占卜无关。我是《周易》起卦解卦助手，只回答卦象、运势与所问之事相关的问题，请换个问题试试。"
            turns.append(AITurn(role: .assistant, content: refusal))
            committed.append(contentsOf: [userTurn, DialogueTurn.assistant(refusal)])
            var updated = record
            updated.question = trimmed
            updated.aiAnswer = refusal
            updated.transcript = committed
            store.save(updated)
            return
        }

        let conversation = HexagramInterpretation.buildConversation(
            result: result,
            question: request,
            history: committed
        )

        isSending = true
        // 留空提问（直接解卦）关闭思考、快速响应；具体问题开启思考以保证质量。
        let thinking = !trimmed.isEmpty

        // 流式占位气泡：思考与正文实时增量写入，完成后折叠思考过程。
        let placeholder = AITurn(role: .assistant, content: "", reasoning: "", isStreaming: true)
        turns.append(placeholder)

        Task {
            var reasoning = ""
            var content = ""

            do {
                let stream = try await client.chatStream(messages: conversation, thinking: thinking)
                var lastFlush = Date.distantPast
                var lastUsage: TokenUsage?
                for try await event in stream {
                    if let usage = event.usage {
                        lastUsage = usage
                    }
                    reasoning += event.reasoning
                    content += event.content
                    // 节流刷新 UI（约 50ms 一批），避免逐 token 重绘。
                    let now = Date()
                    if now.timeIntervalSince(lastFlush) >= 0.05 {
                        if let idx = turns.firstIndex(where: { $0.id == placeholder.id }) {
                            turns[idx] = AITurn(id: placeholder.id, role: .assistant, content: content, reasoning: reasoning, isStreaming: true)
                        }
                        lastFlush = now
                    }
                }
                guard let idx = turns.firstIndex(where: { $0.id == placeholder.id }) else { return }
                turns[idx] = AITurn(id: placeholder.id, role: .assistant, content: content, reasoning: reasoning, isStreaming: false)

                committed.append(contentsOf: [userTurn, DialogueTurn.assistant(content)])
                if let raw = lastUsage {
                    var usage = raw
                    usage.applyingCost(model: client.config.model, baseURL: client.config.baseURL)
                    usageStore.record(usage, model: client.config.model)
                    sessionUsage = sessionUsage.map { $0 + usage } ?? usage
                }
                var updated = record
                updated.question = trimmed
                updated.aiAnswer = content
                updated.transcript = committed
                updated.aiUsage = sessionUsage
                store.save(updated)
            } catch {
                if let idx = turns.firstIndex(where: { $0.id == placeholder.id }) {
                    turns[idx] = AITurn(id: placeholder.id, role: .assistant, content: content, reasoning: reasoning, isStreaming: false)
                }
                errorMessage = (error as? LLMClient.Error)?.message ?? error.localizedDescription
            }
            isSending = false
        }
    }
}