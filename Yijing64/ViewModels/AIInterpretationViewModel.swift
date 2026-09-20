import Foundation
import YijingCore

/// 对话展示模型（思考内容仅用于展示，不写入持久化 transcript）。
struct AITurn: Identifiable, Equatable {
    enum Role { case user, assistant }

    let id: UUID
    var role: Role
    var content: String
    var reasoning: String

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        reasoning: String = ""
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoning = reasoning
    }
}

/// 流式直播状态：高频增量更新只作用于订阅它的流式气泡，避免整页 10 次/秒重绘。
@MainActor
final class LiveStream: ObservableObject {
    @Published var reasoning = ""
    @Published var content = ""
    @Published var isStreaming = false

    func begin() {
        reasoning = ""
        content = ""
        isStreaming = true
    }

    func finish() {
        isStreaming = false
    }
}

@MainActor
final class AIInterpretationViewModel: ObservableObject {
    @Published var question = ""
    /// 已完成的对话气泡（流式内容在 `live` 中，完成后才落入此处）。
    @Published private(set) var turns: [AITurn] = []
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?
    /// 本次会话累计的 AI token 用量（含开始前的历史记录累计）。
    @Published private(set) var sessionUsage: TokenUsage?
    /// 进行中的流式内容（独立观察对象，避免整页重绘）。
    let live = LiveStream()

    private let client: LLMClient
    private let store: CastHistoryStore
    private let usageStore: TokenUsageStore
    private let record: CastRecord
    /// 是否将会话写入起卦记录（卦库浏览进入时为 false，避免污染历史）。
    private let persistsHistory: Bool
    /// 摘要处展示的起卦方式标签。
    let methodLabel: String
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
        usageStore: TokenUsageStore = TokenUsageStore(),
        persistsHistory: Bool = true,
        methodLabel: String? = nil
    ) {
        self.record = record
        self.persistsHistory = persistsHistory
        self.methodLabel = methodLabel ?? record.method.rawValue
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
            if persistsHistory { store.save(updated) }
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
        live.begin()

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
                    // 节流刷新直播内容（约 100ms 一批），只重绘流式气泡。
                    let now = Date()
                    if now.timeIntervalSince(lastFlush) >= 0.1 {
                        live.reasoning = reasoning
                        live.content = content
                        lastFlush = now
                    }
                }
                live.reasoning = reasoning
                live.content = content
                live.finish()
                turns.append(AITurn(role: .assistant, content: content, reasoning: reasoning))

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
                if persistsHistory { store.save(updated) }
            } catch {
                live.finish()
                if !content.isEmpty || !reasoning.isEmpty {
                    turns.append(AITurn(role: .assistant, content: content, reasoning: reasoning))
                }
                errorMessage = (error as? LLMClient.Error)?.message ?? error.localizedDescription
            }
            isSending = false
        }
    }
}
