import Foundation

/// 大模型服务配置（智谱 GLM 或其他 OpenAI 兼容端点）。
public struct LLMConfig: Sendable, Equatable {
    public var baseURL: String
    public var model: String
    public var apiKey: String
    /// 单次回复的最大输出 token 数（非思考模式，约束篇幅，防冗长）。
    public var maxTokens: Int
    /// 思考模式下的最大输出 token 数（思考也计入预算，需预留更多空间）。
    public var thinkingMaxTokens: Int

    public init(baseURL: String = "https://api.deepseek.com", model: String = "deepseek-flash", apiKey: String = "", maxTokens: Int = 1000, thinkingMaxTokens: Int = 4000) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.maxTokens = maxTokens
        self.thinkingMaxTokens = thinkingMaxTokens
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

    /// 非流式对话结果：正文 + token 用量。
    public struct LLMChatResult: Sendable, Equatable {
        public let content: String
        public let usage: TokenUsage?

        public init(content: String, usage: TokenUsage?) {
            self.content = content
            self.usage = usage
        }
    }

    /// 发出对话，返回助手文本与用量。
    /// - Parameter thinking: 是否启用模型思考模式（DeepSeek V4 系默认启用思考，
    ///   思考 token 计入 max_tokens 预算；短输出场景建议关闭以保证拿到最终答案）。
    public func chat(messages: [ChatMessage], thinking: Bool) async throws -> LLMChatResult {
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

        request.httpBody = try JSONSerialization.data(withJSONObject: Self.requestBody(
            model: config.model,
            messages: messages,
            maxTokens: thinking ? config.thinkingMaxTokens : config.maxTokens,
            thinking: thinking,
            stream: false,
            includeUsage: true
        ))

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw Error("网络响应异常。")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw Error("请求失败（\(http.statusCode)）。\(Self.friendlyDetail(detail))")
        }

        let decoded = try ChatCompletionResponse.decode(data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw Self.emptyContentError(decoded)
        }
        var usage: TokenUsage? = nil
        if var tokens = decoded.usage, tokens.totalTokens > 0 {
            tokens.applyingCost(model: config.model, baseURL: config.baseURL)
            usage = tokens
        }
        return LLMChatResult(content: content, usage: usage)
    }

    /// 构造 chat.completions 请求体。
    static func requestBody(model: String, messages: [ChatMessage], maxTokens: Int, thinking: Bool, stream: Bool = false, includeUsage: Bool = false) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0.7,
            "max_tokens": maxTokens,
            "stream": stream,
        ]
        if thinking {
            body["thinking"] = ["type": "enabled"]
        } else {
            body["thinking"] = ["type": "disabled"]
        }
        if stream, includeUsage {
            body["stream_options"] = ["include_usage": true]
        }
        return body
    }

    /// 模型返回空时的可读错误（区分：思考截断 vs 真空白）。
    private static func emptyContentError(_ decoded: ChatCompletionResponse) -> Error {
        guard let message = decoded.choices.first?.message else {
            return Error("模型返回为空。")
        }
        if message.reasoningContent != nil {
            return Error("模型思考消耗了全部输出预算，未生成最终回答。")
        }
        return Error("模型返回为空。")
    }

    /// 流式对话：逐块产出（可包含思考与正文增量）。
    /// - Parameter thinking: 是否启用模型思考模式。
    /// - Returns: 事件流；`reasoning` 为思考增量、`content` 为正文增量，两者在流结束前都是累积语义下的新块。
    public func chatStream(messages: [ChatMessage], thinking: Bool) async throws -> AsyncThrowingStream<ChatStreamEvent, Swift.Error> {
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

        request.httpBody = try JSONSerialization.data(withJSONObject: Self.requestBody(
            model: config.model,
            messages: messages,
            maxTokens: thinking ? config.thinkingMaxTokens : config.maxTokens,
            thinking: thinking,
            stream: true,
            includeUsage: true
        ))

        let (bytes, response) = try await session.bytes(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw Error("网络响应异常。")
        }
        guard (200..<300).contains(http.statusCode) else {
            let data = try await bytes.reduce(into: Data()) { $0.append($1) }
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw Error("请求失败（\(http.statusCode)）。\(Self.friendlyDetail(detail))")
        }

        let stream: AsyncThrowingStream<ChatStreamEvent, Swift.Error> = AsyncThrowingStream {
            (continuation: AsyncThrowingStream<ChatStreamEvent, Swift.Error>.Continuation) in
            Task {
                do {
                    for try await line in bytes.lines {
                        let chunk = SSEChunkParser.parse(line: line)
                        if chunk.done {
                            continuation.finish()
                            return
                        }
                        if let usage = chunk.usage {
                            continuation.yield(ChatStreamEvent(usage: usage))
                        } else if !chunk.reasoning.isEmpty || !chunk.content.isEmpty {
                            continuation.yield(ChatStreamEvent(reasoning: chunk.reasoning, content: chunk.content))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Error("流式响应中断：\(error.localizedDescription)"))
                }
            }
        }
        return stream
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
            let content: String?
            /// DeepSeek 等思考模式返回的推理内容（仅用于诊断，不对外展示）。
            let reasoningContent: String?
            let finishReason: String?
        }
        let message: Message
        let finishReason: String?
    }
    let choices: [Choice]
    /// 非流式响应的 token 用量。
    let usage: TokenUsage?

    static func decode(_ data: Data) throws -> ChatCompletionResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ChatCompletionResponse.self, from: data)
    }
}

/// 流式输出的事件块。
public struct ChatStreamEvent: Sendable, Equatable {
    /// 思考（reasoning）增量。
    public let reasoning: String
    /// 正文增量。
    public let content: String
    /// 流末尾的 token 用量（开启 include_usage 后由服务端返回）。
    public let usage: TokenUsage?

    public init(reasoning: String = "", content: String = "", usage: TokenUsage? = nil) {
        self.reasoning = reasoning
        self.content = content
        self.usage = usage
    }
}

/// 解析 OpenAI 兼容的 SSE 流式行（如 `data: {"choices":[{"delta":{"content":"…"}}]}`）。
enum SSEChunkParser {
    struct Chunk: Sendable, Equatable {
        var reasoning: String
        var content: String
        var done: Bool
        var usage: TokenUsage?

        static let empty = Chunk(reasoning: "", content: "", done: false, usage: nil)
    }

    static func parse(line: String) -> Chunk {
        guard line.hasPrefix("data:") else { return .empty }
        var payload = line.dropFirst("data:".count)
        if payload.hasPrefix(" ") {
            payload = payload.dropFirst()
        }
        let data = String(payload).trimmingCharacters(in: .whitespacesAndNewlines)
        guard data != "[DONE]" else {
            return Chunk(reasoning: "", content: "", done: true, usage: nil)
        }
        guard let json = data.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else {
            return .empty
        }
        // 流末尾的 usage 块（choices 为空且带 usage）。
        if let usageJSON = obj["usage"] as? [String: Any],
           let usage = TokenUsage.parse(json: usageJSON) {
            return Chunk(reasoning: "", content: "", done: false, usage: usage)
        }
        guard let choices = obj["choices"] as? [[String: Any]],
              let first = choices.first else {
            return .empty
        }
        let delta = first["delta"] as? [String: Any] ?? [:]
        let reasoning = delta["reasoning_content"] as? String ?? ""
        let content = delta["content"] as? String ?? ""
        return Chunk(reasoning: reasoning, content: content, done: false, usage: nil)
    }
}