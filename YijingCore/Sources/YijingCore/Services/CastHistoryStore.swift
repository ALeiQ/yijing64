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

    public init(
        id: UUID = UUID(),
        role: Role,
        content: String
    ) {
        self.id = id
        self.role = role
        self.content = content
    }

    public static func user(_ content: String) -> DialogueTurn { .init(role: .user, content: content) }
    public static func assistant(_ content: String) -> DialogueTurn { .init(role: .assistant, content: content) }
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

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        method: CastMethod,
        originalLines: [LineType],
        question: String = "",
        aiAnswer: String = "",
        transcript: [DialogueTurn] = []
    ) {
        self.id = id
        self.date = date
        self.method = method
        self.originalLines = originalLines
        self.question = question
        self.aiAnswer = aiAnswer
        self.transcript = transcript
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, method, originalLines, question, aiAnswer, transcript
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