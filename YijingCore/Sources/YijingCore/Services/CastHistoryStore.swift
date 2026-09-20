import Foundation

/// 一轮多轮对话（用户提问或 AI 答复）。
public struct DialogueTurn: Identifiable, Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    public let id: UUID
    public var role: Role
    public var content: String
    /// AI 思考过程（仅 assistant 有；旧数据缺该字段时解码为 ""）。
    public var reasoning: String

    public init(
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

    public static func user(_ content: String) -> DialogueTurn { .init(role: .user, content: content) }
    public static func assistant(_ content: String, reasoning: String = "") -> DialogueTurn {
        .init(role: .assistant, content: content, reasoning: reasoning)
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, content, reasoning
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(Role.self, forKey: .role)
        content = try c.decode(String.self, forKey: .content)
        reasoning = try c.decodeIfPresent(String.self, forKey: .reasoning) ?? ""
    }
}

/// 一次起卦记录（可还原卦象与当时的 AI 解卦会话）。
public struct CastRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var date: Date
    public let method: CastMethod
    public let originalLines: [LineType]
    public var question: String
    public var aiAnswer: String
    /// 完整多轮对话（旧数据缺该字段时解码为 []）。
    public var transcript: [DialogueTurn]
    /// 该次会话的 AI token 用量累计（旧数据缺该字段时解码为 nil）。
    public var aiUsage: TokenUsage?
    /// 该次会话使用的模型名（旧数据缺该字段时解码为 nil）。
    public var model: String?
    /// 该次会话使用的服务商（旧数据缺该字段时解码为 nil）。
    public var provider: LLMProvider?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        method: CastMethod,
        originalLines: [LineType],
        question: String = "",
        aiAnswer: String = "",
        transcript: [DialogueTurn] = [],
        aiUsage: TokenUsage? = nil,
        model: String? = nil,
        provider: LLMProvider? = nil
    ) {
        self.id = id
        self.date = date
        self.method = method
        self.originalLines = originalLines
        self.question = question
        self.aiAnswer = aiAnswer
        self.transcript = transcript
        self.aiUsage = aiUsage
        self.model = model
        self.provider = provider
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, method, originalLines, question, aiAnswer, transcript, aiUsage, model, provider
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        method = try c.decode(CastMethod.self, forKey: .method)
        originalLines = try c.decode([LineType].self, forKey: .originalLines)
        question = try c.decodeIfPresent(String.self, forKey: .question) ?? ""
        aiAnswer = try c.decodeIfPresent(String.self, forKey: .aiAnswer) ?? ""
        transcript = try c.decodeIfPresent([DialogueTurn].self, forKey: .transcript) ?? []
        aiUsage = try c.decodeIfPresent(TokenUsage.self, forKey: .aiUsage)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        provider = try c.decodeIfPresent(LLMProvider.self, forKey: .provider)
    }

    /// 由记录还原完整分析结果。
    public var result: CastResult {
        CastResult(method: method, originalLines: originalLines)
    }
}

/// 起卦记录存取（UserDefaults JSON 归档）。
public final class CastHistoryStore {
    private let defaults: UserDefaults
    private let key = "castHistory.records"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 按时间倒序返回全部记录。
    public func load() -> [CastRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([CastRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.date > $1.date }
    }

    /// 保存（新增或按 id 更新）。
    public func save(_ record: CastRecord) {
        var all = load()
        if let idx = all.firstIndex(where: { $0.id == record.id }) {
            all[idx] = record
        } else {
            all.append(record)
        }
        all.sort { $0.date > $1.date }
        write(all)
    }

    /// 删除指定 id。
    public func delete(id: UUID) {
        var all = load()
        all.removeAll { $0.id == id }
        write(all)
    }

    /// 清空全部。
    public func clear() {
        write([])
    }

    private func write(_ records: [CastRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
        }
    }
}