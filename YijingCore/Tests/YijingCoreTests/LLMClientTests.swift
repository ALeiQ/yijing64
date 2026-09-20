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
            _ = try await client.chat(messages: [.user("hi")])
            XCTFail("应抛出未设置 Key 错误")
        } catch let error as LLMClient.Error {
            XCTAssertTrue(error.message.contains("API Key"))
        } catch {
            XCTFail("错误类型不符: \(error)")
        }
    }
}