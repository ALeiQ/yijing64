import XCTest
@testable import YijingCore

final class SSEChunkParserTests: XCTestCase {

    func testParsesContent() {
        let chunk = SSEChunkParser.parse(
            line: #"data: {"choices":[{"delta":{"content":"你好"}}]}"#
        )
        XCTAssertEqual(chunk.content, "你好")
        XCTAssertEqual(chunk.reasoning, "")
        XCTAssertFalse(chunk.done)
    }

    func testParsesReasoningContent() {
        let chunk = SSEChunkParser.parse(
            line: #"data: {"choices":[{"delta":{"reasoning_content":"先分析一下"}}]}"#
        )
        XCTAssertEqual(chunk.reasoning, "先分析一下")
        XCTAssertEqual(chunk.content, "")
        XCTAssertFalse(chunk.done)
    }

    func testParsesDone() {
        let chunk = SSEChunkParser.parse(line: "data: [DONE]")
        XCTAssertTrue(chunk.done)
        XCTAssertEqual(chunk.content, "")
    }

    func testIgnoresNonDataLines() {
        for line in ["", "event: message", ": keep-alive comment", "id: 1"] {
            let chunk = SSEChunkParser.parse(line: line)
            XCTAssertEqual(chunk.content, "")
            XCTAssertFalse(chunk.done)
        }
    }

    func testParsesChunkWithBothDeltas() {
        let chunk = SSEChunkParser.parse(
            line: #"data: {"choices":[{"delta":{"reasoning_content":"想","content":"答"}}]}"#
        )
        XCTAssertEqual(chunk.reasoning, "想")
        XCTAssertEqual(chunk.content, "答")
    }

    func testIgnoresUsageChunkWithoutDelta() {
        // 仅含 single 未 complete usage 字段的块应无文本产出。
        let chunk = SSEChunkParser.parse(
            line: #"data: {"choices":[{"delta":{}}],"usage":{"total_tokens":10}}"#
        )
        XCTAssertEqual(chunk.content, "")
        XCTAssertFalse(chunk.done)
    }

    func testParsesUsageChunk() {
        // 流末 usage 块（无 choices）应产出用量。
        let chunk = SSEChunkParser.parse(
            line: #"data: {"choices":[],"usage":{"prompt_tokens":120,"completion_tokens":60,"total_tokens":180,"prompt_cache_hit_tokens":40,"prompt_cache_miss_tokens":80}}"#
        )
        let usage = chunk.usage
        XCTAssertNotNil(usage)
        XCTAssertEqual(usage?.promptTokens, 120)
        XCTAssertEqual(usage?.completionTokens, 60)
        XCTAssertEqual(usage?.totalTokens, 180)
        XCTAssertEqual(usage?.cacheHitTokens, 40)
        XCTAssertEqual(usage?.cacheMissTokens, 80)
        XCTAssertEqual(chunk.content, "")
        XCTAssertEqual(chunk.reasoning, "")
        XCTAssertFalse(chunk.done)
    }

    func testMalformedJSONIsIgnored() {
        let chunk = SSEChunkParser.parse(line: "data: {not-json")
        XCTAssertEqual(chunk.content, "")
        XCTAssertFalse(chunk.done)
    }
}