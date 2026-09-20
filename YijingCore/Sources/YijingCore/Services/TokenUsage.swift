import Foundation

/// 单次请求的 token 用量（来自服务端 usage 字段）。
/// 费用为估算值，按设置模型自动匹配对应提供商的官方单价与请求时刻时段计算。
public struct TokenUsage: Codable, Sendable, Equatable {
    public var promptTokens: Int
    public var completionTokens: Int
    public var totalTokens: Int
    public var cacheHitTokens: Int
    public var cacheMissTokens: Int
    /// 本次请求的估算花费（人民币元）；未识别提供商为 nil。
    public var costCNY: Double?

    public init(
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        totalTokens: Int = 0,
        cacheHitTokens: Int = 0,
        cacheMissTokens: Int = 0,
        costCNY: Double? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.cacheHitTokens = cacheHitTokens
        self.cacheMissTokens = cacheMissTokens
        self.costCNY = costCNY
    }

    private enum CodingKeys: String, CodingKey {
        case promptTokens
        case completionTokens
        case totalTokens
        case cacheHitTokens
        case promptCacheHitTokens
        case cacheMissTokens
        case promptCacheMissTokens
        case costCNY
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        promptTokens = try c.decode(Int.self, forKey: .promptTokens)
        completionTokens = try c.decode(Int.self, forKey: .completionTokens)
        totalTokens = try c.decodeIfPresent(Int.self, forKey: .totalTokens) ?? (promptTokens + completionTokens)
        // 兼容服务端（prompt_cache_*，camel 后带 prompt 前缀）与本机存储（无前缀）两种键。
        cacheHitTokens = try c.decodeIfPresent(Int.self, forKey: .promptCacheHitTokens)
            ?? c.decodeIfPresent(Int.self, forKey: .cacheHitTokens) ?? 0
        cacheMissTokens = try c.decodeIfPresent(Int.self, forKey: .promptCacheMissTokens)
            ?? c.decodeIfPresent(Int.self, forKey: .cacheMissTokens) ?? 0
        costCNY = try c.decodeIfPresent(Double.self, forKey: .costCNY)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(promptTokens, forKey: .promptTokens)
        try c.encode(completionTokens, forKey: .completionTokens)
        try c.encode(totalTokens, forKey: .totalTokens)
        try c.encode(cacheHitTokens, forKey: .cacheHitTokens)
        try c.encode(cacheMissTokens, forKey: .cacheMissTokens)
        try c.encodeIfPresent(costCNY, forKey: .costCNY)
    }

    /// 按模型匹配的官方单价与请求时刻时段填充估算费用。
    public mutating func applyingCost(model: String, baseURL: String, at date: Date = Date()) {
        guard let pricing = TokenPricing.resolve(model: model, baseURL: baseURL) else {
            costCNY = nil
            return
        }
        costCNY = pricing.cost(
            cacheHit: cacheHitTokens,
            cacheMiss: cacheMissTokens,
            completion: completionTokens,
            at: date
        )
    }

    /// 容错解析 OpenAI/DeepSeek 兼容的 usage 字典（如流式末块或非流式响应）。
    /// 缓存细分兼容 `prompt_cache_hit_tokens` 与 `prompt_tokens_details.cached_tokens`。
    public static func parse(json: [String: Any]) -> TokenUsage? {
        guard let prompt = json["prompt_tokens"] as? Int,
              let completion = json["completion_tokens"] as? Int else {
            return nil
        }
        var hit = json["prompt_cache_hit_tokens"] as? Int ?? 0
        var miss = json["prompt_cache_miss_tokens"] as? Int ?? 0
        if hit == 0, miss == 0,
           let details = json["prompt_tokens_details"] as? [String: Any],
           let cached = details["cached_tokens"] as? Int {
            hit = max(cached, 0)
            miss = max(prompt - hit, 0)
        }
        // 未细分时保守按全部未命中计。
        if hit == 0, miss == 0 {
            miss = prompt
        }
        let total = json["total_tokens"] as? Int ?? (prompt + completion)
        return TokenUsage(
            promptTokens: prompt,
            completionTokens: completion,
            totalTokens: total,
            cacheHitTokens: hit,
            cacheMissTokens: miss,
            costCNY: nil
        )
    }

    /// 将两段用量合并（用于多轮会话累计）。
    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            promptTokens: lhs.promptTokens + rhs.promptTokens,
            completionTokens: lhs.completionTokens + rhs.completionTokens,
            totalTokens: lhs.totalTokens + rhs.totalTokens,
            cacheHitTokens: lhs.cacheHitTokens + rhs.cacheHitTokens,
            cacheMissTokens: lhs.cacheMissTokens + rhs.cacheMissTokens,
            costCNY: (lhs.costCNY ?? 0) + (rhs.costCNY ?? 0)
        )
    }
}

/// 大模型官方单价估算（元/百万 token，基于设置模型自动匹配提供商）。
/// DeepSeek：2026-09-10 起生效，高峰时段（北京时间周一至五 9:00-12:00、14:00-18:00）为闲时的 2 倍。
/// 智谱：免费档（glm-*-flash）全免；付费 GLM 无峰谷，按官价近似估算。
public struct TokenPricing: Sendable {
    public let cacheHitIdleCNYPerMillion: Double
    public let cacheMissIdleCNYPerMillion: Double
    public let outputIdleCNYPerMillion: Double
    /// 是否适用峰谷计价（高峰价 = 闲时 × 2）。仅 DeepSeek 启用。
    public let appliesPeak: Bool

    public init(
        cacheHitIdleCNYPerMillion: Double,
        cacheMissIdleCNYPerMillion: Double,
        outputIdleCNYPerMillion: Double,
        appliesPeak: Bool = false
    ) {
        self.cacheHitIdleCNYPerMillion = cacheHitIdleCNYPerMillion
        self.cacheMissIdleCNYPerMillion = cacheMissIdleCNYPerMillion
        self.outputIdleCNYPerMillion = outputIdleCNYPerMillion
        self.appliesPeak = appliesPeak
    }

    /// DeepSeek flash 系列当前价（2026-09-10 生效，进口：空闲高峰×2）。
    public static let deepSeekFlash = TokenPricing(
        cacheHitIdleCNYPerMillion: 0.02,
        cacheMissIdleCNYPerMillion: 1.0,
        outputIdleCNYPerMillion: 4.0,
        appliesPeak: true
    )

    /// 智谱免费档（glm-4.7-flash、glm-4.6v-flash 等）：输入/输出/缓存全免费。
    public static let zhipuFree = TokenPricing(
        cacheHitIdleCNYPerMillion: 0,
        cacheMissIdleCNYPerMillion: 0,
        outputIdleCNYPerMillion: 0
    )

    /// 智谱付费 GLM 近似档（按 GLM-4.7 官方价：缓存命中 ¥0.4 / 未命中 ¥2 / 输出 ¥8）。
    public static let zhipuDefault = TokenPricing(
        cacheHitIdleCNYPerMillion: 0.4,
        cacheMissIdleCNYPerMillion: 2.0,
        outputIdleCNYPerMillion: 8.0
    )

    /// 依据设置中的模型名与 Base URL 自动选择计费方式；未识别返回 nil（不估算费用）。
    public static func resolve(model: String, baseURL: String) -> TokenPricing? {
        switch LLMProvider.detect(model: model, baseURL: baseURL) {
        case .deepseek:
            return .deepSeekFlash
        case .zhipu:
            let m = model.lowercased()
            return m.contains("flash") || m.contains("free") ? .zhipuFree : .zhipuDefault
        case .opencodeZen, .opencodeGo, .custom:
            return nil
        }
    }

    /// 是否处于 DeepSeek 高峰时段（北京时间周一至五 9-12、14-18）。
    public func isPeak(_ date: Date = Date()) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.beijing
        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = comps.weekday, let hour = comps.hour, let minute = comps.minute else {
            return false
        }
        // 周日=1，周六=7；工作日为 2...6。
        let isWeekday = (2...6).contains(weekday)
        let minutes = hour * 60 + minute
        let morning = (540..<720).contains(minutes)
        let afternoon = (840..<1080).contains(minutes)
        return isWeekday && (morning || afternoon)
    }

    /// 估算一次请求费用（元）。
    public func cost(
        cacheHit: Int,
        cacheMiss: Int,
        completion: Int,
        at date: Date = Date()
    ) -> Double {
        let multiplier = appliesPeak && isPeak(date) ? 2.0 : 1.0
        let hit = Double(cacheHit) / 1_000_000 * cacheHitIdleCNYPerMillion * multiplier
        let miss = Double(cacheMiss) / 1_000_000 * cacheMissIdleCNYPerMillion * multiplier
        let output = Double(completion) / 1_000_000 * outputIdleCNYPerMillion * multiplier
        return hit + miss + output
    }

    private static var beijing: TimeZone {
        TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
    }
}

/// Token 用量明细条目。
public struct TokenUsageRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let date: Date
    public let model: String
    public var usage: TokenUsage

    public init(id: UUID = UUID(), date: Date = Date(), model: String, usage: TokenUsage) {
        self.id = id
        self.date = date
        self.model = model
        self.usage = usage
    }
}