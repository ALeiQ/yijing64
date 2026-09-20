import XCTest
@testable import YijingCore

final class LLMClientTests: XCTestCase {

    func testDeepSeekBaseURLWithoutSlash() {
        let url = LLMClient.endpointURL(baseURL: "https://api.deepseek.com")
        XCTAssertEqual(url?.absoluteString, "https://api.deepseek.com/chat/completions")
    }

    func testZhipuBaseURLWithSlash() {
        let url = LLMClient.endpointURL(baseURL: "https://open.bigmodel.cn/api/paas/v4/")
        XCTAssertEqual(url?.absoluteString, "https://open.bigmodel.cn/api/paas/v4/chat/completions")
    }

    func testBaseURLWithSingleSlash() {
        let url = LLMClient.endpointURL(baseURL: "https://api.deepseek.com/")
        XCTAssertEqual(url?.absoluteString, "https://api.deepseek.com/chat/completions")
        XCTAssertFalse(url!.absoluteString.contains("//chat"))
    }

    func testBaseURLWithPathSegmentV1() {
        let url = LLMClient.endpointURL(baseURL: "https://example.com/v1")
        XCTAssertEqual(url?.absoluteString, "https://example.com/v1/chat/completions")
    }

    func testEmptyAndBlankBaseURL() {
        XCTAssertNil(LLMClient.endpointURL(baseURL: ""))
        XCTAssertNil(LLMClient.endpointURL(baseURL: "   "))
    }

    func testChatThrowsWithoutAPIKey() async {
        let client = LLMClient(config: LLMConfig(apiKey: ""))
        do {
            _ = try await client.chat(messages: [.user("hi")], thinking: false)
            XCTFail("应抛出未设置 Key 错误")
        } catch let error as LLMClient.Error {
            XCTAssertTrue(error.message.contains("API Key"))
        } catch {
            XCTFail("错误类型不符: \(error)")
        }
    }

    func testRequestBodyDisablesThinking() {
        let body = LLMClient.requestBody(
            model: "deepseek-flash",
            messages: [.user("hello")],
            maxTokens: 1000,
            thinking: false
        )
        XCTAssertEqual(body["max_tokens"] as? Int, 1000)
        let thinking = body["thinking"] as? [String: String]
        XCTAssertEqual(thinking?["type"], "disabled")
    }

    func testRequestBodyEnablesThinking() {
        let body = LLMClient.requestBody(
            model: "deepseek-flash",
            messages: [.user("hello")],
            maxTokens: 4000,
            thinking: true
        )
        XCTAssertEqual(body["max_tokens"] as? Int, 4000)
        let thinking = body["thinking"] as? [String: String]
        XCTAssertEqual(thinking?["type"], "enabled")
    }

    func testRequestBodyStreamFlag() {
        let streaming = LLMClient.requestBody(
            model: "deepseek-flash",
            messages: [.user("hello")],
            maxTokens: 1000,
            thinking: false,
            stream: true
        )
        XCTAssertEqual(streaming["stream"] as? Bool, true)

        let buffered = LLMClient.requestBody(
            model: "deepseek-flash",
            messages: [.user("hello")],
            maxTokens: 1000,
            thinking: false
        )
        XCTAssertEqual(buffered["stream"] as? Bool, false, "默认非流式")
    }

    func testRequestBodyStreamOptionsOnlyWhenStreamAndIncludeUsage() {
        let streaming = LLMClient.requestBody(
            model: "deepseek-flash",
            messages: [.user("hello")],
            maxTokens: 1000,
            thinking: false,
            stream: true,
            includeUsage: true
        )
        XCTAssertEqual(streaming["stream_options"] as? [String: Bool], ["include_usage": true])

        let noUsage = LLMClient.requestBody(
            model: "deepseek-flash",
            messages: [.user("hello")],
            maxTokens: 1000,
            thinking: false,
            stream: true
        )
        XCTAssertNil(noUsage["stream_options"], "未请求用量时不应带 stream_options")

        let buffered = LLMClient.requestBody(
            model: "deepseek-flash",
            messages: [.user("hello")],
            maxTokens: 1000,
            thinking: false,
            stream: false,
            includeUsage: true
        )
        XCTAssertNil(buffered["stream_options"], "非流式不应带 stream_options")
    }

    func testChatStripsWhitespaceAndReturnsContent() async throws {
        let session = LLMClientTests.session(expecting: .singleComplete, status: 200)
        let client = LLMClient(config: LLMConfig(apiKey: "sk-test"), session: session)
        let result = try await client.chat(messages: [.user("hello")], thinking: false)
        XCTAssertEqual(result.content, "你好")
        XCTAssertEqual(result.usage?.promptTokens, 120)
        XCTAssertEqual(result.usage?.completionTokens, 60)
        XCTAssertEqual(result.usage?.cacheHitTokens, 40)
    }

    func testChatThrowsOnServerError() async throws {
        let session = LLMClientTests.session(expecting: .errorBody, status: 429)
        let client = LLMClient(config: LLMConfig(apiKey: "sk-test"), session: session)
        do {
            _ = try await client.chat(messages: [.user("hello")], thinking: false)
            XCTFail("应抛出请求失败错误")
        } catch let error as LLMClient.Error {
            XCTAssertTrue(error.message.contains("429"))
        } catch {
            XCTFail("错误类型不符: \(error)")
        }
    }

    func testOpencodeSendsSessionHeader() async throws {
        var captured: URLRequest?
        let session = LLMClientTests.session(expecting: .singleComplete, status: 200) { captured = $0 }
        let client = LLMClient(
            config: LLMConfig(baseURL: "https://opencode.ai/zen/go/v1", model: "deepseek-v4.1-flash", apiKey: "sk-test"),
            session: session,
            sessionID: "session-123"
        )
        _ = try await client.chat(messages: [.user("hi")], thinking: false)
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "x-opencode-session"), "session-123")
        XCTAssertFalse((captured?.value(forHTTPHeaderField: "User-Agent") ?? "").isEmpty)
    }

    func testNonOpencodeOmitsSessionHeader() async throws {
        var captured: URLRequest?
        let session = LLMClientTests.session(expecting: .singleComplete, status: 200) { captured = $0 }
        let client = LLMClient(
            config: LLMConfig(baseURL: "https://api.deepseek.com", model: "deepseek-flash", apiKey: "sk-test"),
            session: session
        )
        _ = try await client.chat(messages: [.user("hi")], thinking: false)
        XCTAssertNil(captured?.value(forHTTPHeaderField: "x-opencode-session"), "非 opencode 端点不应带会话头")
    }

    // MARK: - 模拟 URLSession

    private enum StubKind {
        case singleComplete
        case errorBody
    }

    private static func session(expecting stub: StubKind, status: Int, onRequest: ((URLRequest) -> Void)? = nil) -> URLSession {
        StubURLProtocol.requestHandler = { request in
            onRequest?(request)
            let statusCode: Int
            let body: String
            if status >= 400 {
                statusCode = status
                body = #"{"error":{"message":"Rate limit exceeded"}}"#
            } else {
                statusCode = 200
                body = #"""
                {"choices":[{"index":0,"message":{"role":"assistant","content":"你好"},"finish_reason":"stop"}],
                 "usage":{"prompt_tokens":120,"completion_tokens":60,"total_tokens":180,"prompt_cache_hit_tokens":40,"prompt_cache_miss_tokens":80}}
                """#
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(body.utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private final class StubURLProtocol: URLProtocol {
        static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            let (response, data) = handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }
}