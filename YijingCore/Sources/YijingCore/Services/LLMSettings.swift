import Foundation

/// 可选的大模型服务商，决定预设连接参数与各自独立存储的 Key。
public enum LLMProvider: String, CaseIterable, Sendable {
    case deepseek
    case zhipu
    case opencodeZen
    case custom

    public var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .zhipu: return "智谱"
        case .opencodeZen: return "opencode Zen"
        case .custom: return "自定义"
        }
    }

    /// 预设模型名；自定义为空。
    public var defaultModel: String {
        switch self {
        case .deepseek: return "deepseek-flash"
        case .zhipu: return "glm-4.7-flash"
        case .opencodeZen: return "big-pickle"
        case .custom: return ""
        }
    }

    /// 预设 Base URL；自定义为空。
    public var defaultBaseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4"
        case .opencodeZen: return "https://opencode.ai/zen/v1"
        case .custom: return ""
        }
    }

    /// 依据模型名与 Base URL 推断服务商（用于旧数据迁移与计费识别）。
    public static func detect(model: String, baseURL: String) -> LLMProvider {
        let m = model.lowercased()
        let url = baseURL.lowercased()
        if m.contains("deepseek") || url.contains("deepseek") {
            return .deepseek
        }
        if m.contains("glm") || m.contains("chatglm") || url.contains("bigmodel.cn") {
            return .zhipu
        }
        if url.contains("opencode.ai") {
            return .opencodeZen
        }
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
