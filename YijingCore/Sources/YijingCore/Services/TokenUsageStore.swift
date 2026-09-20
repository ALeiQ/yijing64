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
    public func record(_ usage: TokenUsage, model: String, provider: LLMProvider? = nil, baseURL: String? = nil, at date: Date = Date()) {
        guard usage.promptTokens > 0 || usage.completionTokens > 0 else { return }
        var all = records()
        all.append(TokenUsageRecord(date: date, model: model, usage: usage, provider: provider, baseURL: baseURL))
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

    /// 单个模型的用量汇总。
    public struct ModelUsageSummary: Sendable, Equatable, Identifiable {
        public var model: String
        public var provider: LLMProvider?
        public var requestCount: Int = 0
        public var promptTokens: Int = 0
        public var completionTokens: Int = 0
        public var cacheHitTokens: Int = 0
        public var cacheMissTokens: Int = 0
        public var estimatedCostCNY: Double = 0

        public var id: String { "\(provider?.rawValue ?? "?")|\(model)" }

        public init(model: String, provider: LLMProvider? = nil) {
            self.model = model
            self.provider = provider
        }

        public var totalTokens: Int { promptTokens + completionTokens }

        /// 服务商展示名；未知时为 nil。
        public var providerName: String? { provider?.displayName }

        /// 服务商 · 模型（未知服务商时仅模型名）。
        public var displayName: String {
            guard let providerName else { return model }
            return "\(providerName) · \(model)"
        }

        /// 缓存命中率（0...1）；无输入 token 时为 nil。
        public var hitRate: Double? {
            guard promptTokens > 0 else { return nil }
            return Double(cacheHitTokens) / Double(promptTokens)
        }
    }

    /// 按「服务商 + 模型」分组汇总，按 token 总量降序；模型名为空归入「未记录」。
    public func summariesByModel() -> [ModelUsageSummary] {
        var grouped: [String: ModelUsageSummary] = [:]
        for item in records() {
            let name = item.model.isEmpty ? "未记录" : item.model
            // 旧数据无服务商字段时按模型名回退推断（A 方案）。
            let provider = item.provider ?? LLMProvider.detect(model: name, baseURL: "")
            let key = "\(provider.rawValue)|\(name)"
            var summary = grouped[key] ?? ModelUsageSummary(model: name, provider: provider)
            summary.requestCount += 1
            summary.promptTokens += item.usage.promptTokens
            summary.completionTokens += item.usage.completionTokens
            summary.cacheHitTokens += item.usage.cacheHitTokens
            summary.cacheMissTokens += item.usage.cacheMissTokens
            if let cost = item.usage.costCNY {
                summary.estimatedCostCNY += cost
            }
            grouped[key] = summary
        }
        return grouped.values.sorted { lhs, rhs in
            if lhs.totalTokens != rhs.totalTokens { return lhs.totalTokens > rhs.totalTokens }
            return lhs.id < rhs.id
        }
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