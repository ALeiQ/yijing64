import Foundation
import YijingCore

@MainActor
final class AIInterpretationViewModel: ObservableObject {
    @Published var question = ""
    /// 本次会话已展示的对话气泡（含等待中的最近一轮提问）。
    @Published private(set) var messages: [DialogueTurn] = []
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    private let client: LLMClient
    private let store: CastHistoryStore
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
        store: CastHistoryStore = CastHistoryStore()
    ) {
        self.record = record
        self.client = client ?? LLMClient(config: settings.config)
        self.store = store

        if !record.transcript.isEmpty {
            committed = record.transcript
            messages = record.transcript
        } else if !record.question.isEmpty || !record.aiAnswer.isEmpty {
            let turns = [DialogueTurn.user(record.question), DialogueTurn.assistant(record.aiAnswer)]
            committed = turns
            messages = turns
        } else {
            committed = []
        }
    }

    func interpret() {
        guard canSend else { return }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard messages.isEmpty || !trimmed.isEmpty else { return }

        let userTurn = DialogueTurn.user(trimmed.isEmpty ? "请解卦" : trimmed)
        messages.append(userTurn)
        question = ""
        isSending = true
        errorMessage = nil

        let conversation = HexagramInterpretation.buildConversation(
            result: result,
            question: trimmed,
            history: committed
        )

        Task {
            do {
                let answer = try await client.chat(messages: conversation)
                let answerTurn = DialogueTurn.assistant(answer)
                messages.append(answerTurn)
                committed.append(contentsOf: [userTurn, answerTurn])

                var updated = record
                updated.question = trimmed
                updated.aiAnswer = answer
                updated.transcript = committed
                store.save(updated)
            } catch {
                errorMessage = (error as? LLMClient.Error)?.message ?? error.localizedDescription
            }
            isSending = false
        }
    }
}