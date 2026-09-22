import Foundation

/// 平台返回的可用模型条目（OpenAI 兼容 `GET {base}/models`）。
public struct LLMModel: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

/// 模型列表的端点构造与容错解析。
public enum ModelCatalog {
    /// 由 Base URL 构造 models 端点（容错结尾斜杠）。
    public static func modelsURL(baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.hasSuffix("/") ? trimmed : trimmed + "/"
        return URL(string: normalized + "models")
    }

    /// 容错解析模型列表：兼容 `{data:[{id}]}`、`{data:[String]}`、`{models:[...]}` 以及裸数组。
    public static func parseModels(_ data: Data) -> [LLMModel] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        return parse(json: json)
    }

    static func parse(json: Any) -> [LLMModel] {
        let arrays: [[Any]]
        if let array = json as? [Any] {
            arrays = [array]
        } else if let dict = json as? [String: Any] {
            arrays = ["data", "models"].compactMap { dict[$0] as? [Any] }
        } else {
            arrays = []
        }
        for array in arrays {
            let models = dedupe(array.compactMap(modelID).map(LLMModel.init))
            if !models.isEmpty { return models }
        }
        return []
    }

    private static func modelID(_ element: Any) -> String? {
        if let id = (element as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            return id
        }
        if let dict = element as? [String: Any] {
            if let id = (dict["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
                return id
            }
            if let name = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                return name
            }
        }
        return nil
    }

    private static func dedupe(_ models: [LLMModel]) -> [LLMModel] {
        var seen = Set<String>()
        return models.filter { seen.insert($0.id).inserted }
    }
}

extension LLMProvider {
    /// 离线兜底用的常用模型；平台无 models 接口或拉取失败时展示。
    public var presetModels: [String] {
        switch self {
        case .deepseek:
            return ["deepseek-flash", "deepseek-v4-flash", "deepseek-v4-pro", "deepseek-chat", "deepseek-reasoner"]
        case .zhipu:
            return ["glm-4.7-flash", "glm-5.3-flash", "glm-5.3", "glm-5.2", "glm-5.1", "glm-5"]
        case .opencodeZen:
            return ["big-pickle", "deepseek-v4.1-flash", "glm-5.3-flash", "minimax-m3", "kimi-k2.6"]
        case .opencodeGo:
            return ["deepseek-v4.1-flash", "deepseek-flash", "glm-5.3-flash", "glm-5.2", "minimax-m3", "kimi-k2.7-code"]
        case .custom:
            return []
        }
    }

    /// opencode 网关中非 chat/completions 端点的模型前缀（本 App 只走 chat/completions）。
    /// 依据官方端点表：GPT/Grok/Muse→`/responses`，Claude/Qwen→`/messages`，Gemini→`/models/{id}`，Jev→`/systemone`。
    var chatIncompatiblePrefixes: [String] {
        switch self {
        case .opencodeZen, .opencodeGo:
            return ["gpt-", "grok-", "muse-spark-", "claude-", "qwen", "gemini-", "jev-"]
        case .deepseek, .zhipu, .custom:
            return []
        }
    }

    /// 过滤掉无法通过 chat/completions 调用的模型（未知前缀默认保留）。
    public func filteringChatCompatible(_ models: [LLMModel]) -> [LLMModel] {
        let prefixes = chatIncompatiblePrefixes
        guard !prefixes.isEmpty else { return models }
        return models.filter { model in
            let lower = model.id.lowercased()
            return !prefixes.contains { lower.hasPrefix($0) }
        }
    }
}
