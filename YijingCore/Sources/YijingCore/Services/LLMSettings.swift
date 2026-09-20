import Foundation

/// 大模型配置的轻量持久化（UserDefaults）。
public final class LLMSettings {
    public static let shared = LLMSettings()

    private enum Keys {
        static let apiKey = "llm.apiKey"
        static let model = "llm.model"
        static let baseURL = "llm.baseURL"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var apiKey: String {
        get { defaults.string(forKey: Keys.apiKey) ?? "" }
        set { defaults.set(newValue, forKey: Keys.apiKey) }
    }

    public var model: String {
        get { defaults.string(forKey: Keys.model) ?? "deepseek-flash" }
        set { defaults.set(newValue, forKey: Keys.model) }
    }

    public var baseURL: String {
        get { defaults.string(forKey: Keys.baseURL) ?? "https://api.deepseek.com" }
        set { defaults.set(newValue, forKey: Keys.baseURL) }
    }

    public var config: LLMConfig {
        LLMConfig(baseURL: baseURL, model: model, apiKey: apiKey)
    }
}