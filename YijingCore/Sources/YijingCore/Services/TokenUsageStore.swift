import Foundation

/// 全局 Token 用量累计（UserDefaults JSON 明细）。
public final class TokenUsageStore {
    private let defaults: UserDefaults
    private let key = "llm.usage.records"
    /// 明细保留上限，超出删除最旧。
    private let maxRecords = 500

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 记录一次真实用量（仅记录产生了 token 的请求）。
    public func record(_ usage: TokenUsage, model: String, at date: Date = Date()) {
        guard usage.promptTokens > 0 || usage.completionTokens > 0 else { return }
        var all = records()
        all.append(TokenUsageRecord(date: date, model: model, usage: usage))
        if all.count > maxRecords {
            all.removeFirst(all.count - maxRecords)
        }
        write(all)
    }

    /// 全部明细（按时间正序）。
    public func records() -> [TokenUsageRecord] {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode([TokenUsageRecord].self, from: data) else {
            return []
        }
        return stored
    }

    /// 汇总统计。
    public struct Summary: Sendable, Equatable {
        public var requestCount: Int = 0
        public var promptTokens: Int = 0
        public var completionTokens: Int = 0
        public var cacheHitTokens: Int = 0
        public var cacheMissTokens: Int = 0
        public var estimatedCostCNY: Double = 0

        public init() {}
    }

    public func summary() -> Summary {
        var result = Summary()
        for item in records() {
            result.requestCount += 1
            result.promptTokens += item.usage.promptTokens
            result.completionTokens += item.usage.completionTokens
            result.cacheHitTokens += item.usage.cacheHitTokens
            result.cacheMissTokens += item.usage.cacheMissTokens
            if let cost = item.usage.costCNY {
                result.estimatedCostCNY += cost
            }
        }
        return result
    }

    /// 清空全部统计。
    public func clear() {
        defaults.removeObject(forKey: key)
    }

    private func write(_ items: [TokenUsageRecord]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }
}