import Foundation

/// 大模型服务配置（智谱 GLM 或其他 OpenAI 兼容端点）。
public struct LLMConfig: Sendable, Equatable {
    public var baseURL: String
    public var model: String
    public var apiKey: String

    public init(baseURL: String = "https://api.deepseek.com", model: String = "deepseek-flash", apiKey: String = "") {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
    }
}

/// 对话消息。
public struct ChatMessage: Sendable, Codable, Equatable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }

    public static func system(_ content: String) -> ChatMessage { .init(role: "system", content: content) }
    public static func user(_ content: String) -> ChatMessage { .init(role: "user", content: content) }
}

/// GLM / OpenAI 兼容的 chat.completions 客户端。
public final class LLMClient: Sendable {
    public struct Error: Swift.Error, Equatable, LocalizedError {
        public let message: String

        public init(_ message: String) {
            self.message = message
        }

        public var errorDescription: String? { message }
    }

    public let config: LLMConfig
    private let session: URLSession

    public init(config: LLMConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// 发送对话，返回助手文本。
    public func chat(messages: [ChatMessage]) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw Error("未设置 API Key，请先在“关于”页填写。")
        }
        guard let url = Self.endpointURL(baseURL: config.baseURL) else {
            throw Error("Base URL 无效。")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": config.model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0.7,
            "stream": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw Error("网络响应异常。")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw Error("请求失败（\(http.statusCode)）。\(Self.friendlyDetail(detail))")
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw Error("模型返回为空。")
        }
        return content
    }

    /// 由 Base URL 构造 chat/completions 端点（容错结尾斜杠）。
    static func endpointURL(baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.hasSuffix("/") ? trimmed : trimmed + "/"
        return URL(string: normalized + "chat/completions")
    }

    /// 从服务端错误正文提炼可读信息（如限流/鉴权错误）。
    private static func friendlyDetail(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return "请检查网络或 Key 是否有效。"
        }
        return message
    }
}

/// chat.completions 响应结构（取最小可用字段）。
struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}