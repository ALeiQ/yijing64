import Foundation

/// 可选的大模型服务商，决定预设连接参数与各自独立存储的 Key。
public enum LLMProvider: String, CaseIterable, Sendable, Codable {
    case deepseek
    case zhipu
    case opencodeZen
    case opencodeGo
    case custom

    public var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .zhipu: return "智谱"
        case .opencodeZen: return "opencode Zen"
        case .opencodeGo: return "opencode Go"
        case .custom: return "自定义"
        }
    }

    /// 预设模型名；自定义为空。
    public var defaultModel: String {
        switch self {
        case .deepseek: return "deepseek-flash"
        case .zhipu: return "glm-4.7-flash"
        case .opencodeZen: return "big-pickle"
        case .opencodeGo: return "deepseek-v4.1-flash"
        case .custom: return ""
        }
    }

    /// 预设 Base URL；自定义为空。
    public var defaultBaseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4"
        case .opencodeZen: return "https://opencode.ai/zen/v1"
        case .opencodeGo: return "https://opencode.ai/zen/go/v1"
        case .custom: return ""
        }
    }

    /// 仅依据 Base URL 识别服务商；识别不到即 `.custom`（新记录存服务商时以此为准）。
    public static func detect(baseURL: String) -> LLMProvider {
        let url = baseURL.lowercased()
        if url.contains("opencode.ai") {
            return url.contains("/zen/go") ? .opencodeGo : .opencodeZen
        }
        if url.contains("deepseek") {
            return .deepseek
        }
        if url.contains("bigmodel.cn") {
            return .zhipu
        }
        return .custom
    }

    /// 依据模型名与 Base URL 推断服务商（用于旧数据迁移与历史记录回退）。
    /// 优先看 Base URL，其次才看模型名。
    public static func detect(model: String, baseURL: String) -> LLMProvider {
        let byURL = detect(baseURL: baseURL)
        if byURL != .custom { return byURL }
        let m = model.lowercased()
        if m.contains("deepseek") { return .deepseek }
        if m.contains("glm") || m.contains("chatglm") { return .zhipu }
        return .custom
    }
}

/// 大模型配置的轻量持久化（UserDefaults）。
/// 每个服务商独立保存 API Key / 模型 / Base URL，切换时自动带出各自的值。
public final class LLMSettings {
    public static let shared = LLMSettings()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateIfNeeded()
    }

    // MARK: - 服务商

    private static let providerKey = "llm.provider"

    /// 当前选中的服务商。
    public var provider: LLMProvider {
        get {
            guard let raw = defaults.string(forKey: Self.providerKey),
                  let value = LLMProvider(rawValue: raw) else {
                return .deepseek
            }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Self.providerKey) }
    }

    // MARK: - 当前服务商的配置

    public var apiKey: String {
        get { value(for: .apiKey, provider: provider) }
        set { setValue(newValue, for: .apiKey, provider: provider) }
    }

    public var model: String {
        get {
            let stored = value(for: .model, provider: provider)
            return stored.isEmpty ? provider.defaultModel : stored
        }
        set { setValue(newValue, for: .model, provider: provider) }
    }

    public var baseURL: String {
        get {
            let stored = value(for: .baseURL, provider: provider)
            return stored.isEmpty ? provider.defaultBaseURL : stored
        }
        set { setValue(newValue, for: .baseURL, provider: provider) }
    }

    public var config: LLMConfig {
        LLMConfig(baseURL: baseURL, model: model, apiKey: apiKey)
    }

    /// 读取指定服务商已保存的 Key（供界面切换时预填）。
    public func apiKey(for provider: LLMProvider) -> String {
        value(for: .apiKey, provider: provider)
    }

    // MARK: - 模型列表缓存

    /// 模型列表缓存有效期。
    public static let modelsCacheTTL: TimeInterval = 24 * 3600

    private func modelsKey(_ provider: LLMProvider) -> String { "llm.\(provider.rawValue).models" }
    private func modelsBaseURLKey(_ provider: LLMProvider) -> String { "llm.\(provider.rawValue).models.baseURL" }
    private func modelsDateKey(_ provider: LLMProvider) -> String { "llm.\(provider.rawValue).models.fetchedAt" }

    /// 读取缓存的模型列表；Base URL 变化或没有缓存时返回 nil。
    public func cachedModels(for provider: LLMProvider, baseURL: String) -> [LLMModel]? {
        guard defaults.string(forKey: modelsBaseURLKey(provider)) == baseURL,
              let json = defaults.string(forKey: modelsKey(provider)),
              let data = json.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data),
              !ids.isEmpty else {
            return nil
        }
        return ids.map(LLMModel.init)
    }

    /// 缓存是否已过期（无缓存视为过期）。
    public func isModelsCacheStale(for provider: LLMProvider) -> Bool {
        guard let date = defaults.object(forKey: modelsDateKey(provider)) as? Date else { return true }
        return Date().timeIntervalSince(date) > Self.modelsCacheTTL
    }

    /// 写入模型列表缓存。
    public func saveModels(_ models: [LLMModel], for provider: LLMProvider, baseURL: String) {
        guard !models.isEmpty else { return }
        if let data = try? JSONEncoder().encode(models.map(\.id)),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: modelsKey(provider))
        }
        defaults.set(baseURL, forKey: modelsBaseURLKey(provider))
        defaults.set(Date(), forKey: modelsDateKey(provider))
    }

    // MARK: - 存储

    private enum Field: String {
        case apiKey
        case model
        case baseURL
    }

    private func storageKey(_ field: Field, provider: LLMProvider) -> String {
        "llm.\(provider.rawValue).\(field.rawValue)"
    }

    private func value(for field: Field, provider: LLMProvider) -> String {
        defaults.string(forKey: storageKey(field, provider: provider)) ?? ""
    }

    private func setValue(_ value: String, for field: Field, provider: LLMProvider) {
        defaults.set(value, forKey: storageKey(field, provider: provider))
    }

    /// 旧版单一配置（llm.apiKey/model/baseURL）迁移到对应服务商槽位。
    private func migrateIfNeeded() {
        guard defaults.string(forKey: Self.providerKey) == nil else { return }
        let legacyModel = defaults.string(forKey: "llm.model") ?? ""
        let legacyBaseURL = defaults.string(forKey: "llm.baseURL") ?? ""
        let legacyKey = defaults.string(forKey: "llm.apiKey") ?? ""
        guard !legacyModel.isEmpty || !legacyBaseURL.isEmpty || !legacyKey.isEmpty else {
            provider = .deepseek
            return
        }
        let detected = LLMProvider.detect(model: legacyModel, baseURL: legacyBaseURL)
        provider = detected
        if !legacyModel.isEmpty { setValue(legacyModel, for: .model, provider: detected) }
        if !legacyBaseURL.isEmpty { setValue(legacyBaseURL, for: .baseURL, provider: detected) }
        if !legacyKey.isEmpty { setValue(legacyKey, for: .apiKey, provider: detected) }
    }
}
