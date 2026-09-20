import XCTest
@testable import YijingCore

final class AIServiceTests: XCTestCase {

    func testMessagesContainKeyContext() {
        // 乾卦变姤（初九动，老阳：初九 潜龙勿用）
        let lines: [LineType] = [.oldYang, .youngYang, .youngYang, .youngYang, .youngYang, .youngYang]
        let result = CastResult(method: .threeCoins, originalLines: lines)
        let messages = HexagramInterpretation.messages(for: result, question: "事业")

        XCTAssertEqual(messages.count, 2)
        let userText = messages[1].content
        XCTAssertTrue(userText.contains("乾为天"), "应含本卦名")
        XCTAssertTrue(userText.contains("潜龙勿用"), "应含动爻爻辞")
        XCTAssertTrue(userText.contains("初九"), "应含动爻爻名")
        XCTAssertTrue(userText.contains("变卦"), "应含变卦")
        XCTAssertTrue(userText.contains("事业"), "应含所问之事")
    }

    func testMessagesWithoutQuestion() {
        let result = CastResult(method: .manual, originalLines: Array(repeating: .youngYang, count: 6))
        let messages = HexagramInterpretation.messages(for: result, question: "   ")
        XCTAssertFalse(messages[1].content.contains("所问之事"))
    }

    func testStaticNoMovingLineNote() {
        let result = CastResult(method: .manual, originalLines: Array(repeating: .youngYin, count: 6))
        let messages = HexagramInterpretation.messages(for: result, question: "")
        XCTAssertTrue(messages[1].content.contains("无（静卦"))
    }

    func testBuildConversationFirstTurnMatchesSingle() {
        let lines: [LineType] = [.oldYang, .youngYang, .youngYang, .youngYang, .youngYang, .youngYang]
        let result = CastResult(method: .threeCoins, originalLines: lines)
        let single = HexagramInterpretation.messages(for: result, question: "事业")
        let multi = HexagramInterpretation.buildConversation(result: result, question: "事业", history: [])
        XCTAssertEqual(multi.count, 3)
        XCTAssertEqual(multi[0].role, "system")
        XCTAssertTrue(multi[1].content.contains("乾为天"))
        XCTAssertEqual(multi[2].content, "事业")
        XCTAssertEqual(single.count, 2, "单轮便捷入口仍是 2 条")
    }

    func testBuildConversationAppendsHistoryAndQuestion() {
        let lines: [LineType] = [.oldYang, .youngYang, .youngYang, .youngYang, .youngYang, .youngYang]
        let result = CastResult(method: .threeCoins, originalLines: lines)
        let history = [
            DialogueTurn.user("事业"),
            DialogueTurn.assistant("乾卦主自强不息。"),
            DialogueTurn.user("那财运呢？"),
        ]
        let messages = HexagramInterpretation.buildConversation(result: result, question: "再讲讲", history: history)
        XCTAssertEqual(messages.count, 6)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertTrue(messages[1].content.contains("乾为天"), "卦象上下文仍在前")
        XCTAssertEqual(messages[2].role, "user")
        XCTAssertEqual(messages[2].content, "事业")
        XCTAssertEqual(messages[3].role, "assistant")
        XCTAssertEqual(messages[4].role, "user")
        XCTAssertEqual(messages[5].role, "user")
        XCTAssertEqual(messages[5].content, "再讲讲")
    }

    func testBuildConversationEmptyQuestionWithoutHistory() {
        let result = CastResult(method: .manual, originalLines: Array(repeating: .youngYang, count: 6))
        let messages = HexagramInterpretation.buildConversation(result: result, question: "", history: [])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[1].role, "user")
    }

    func testDuplicateQuestionsNotMerged() {
        let result = CastResult(method: .manual, originalLines: Array(repeating: .youngYang, count: 6))
        let history = [DialogueTurn.user("求财")]
        // 追问相同问题也应作为新一条 user 消息
        let messages = HexagramInterpretation.buildConversation(result: result, question: "求财", history: history)
        XCTAssertEqual(messages.filter { $0.role == "user" }.count, 3, "卦象上下文 + 历史提问 + 本轮提问")
        XCTAssertEqual(messages.last?.content, "求财")
    }
}

final class LLMSettingsTests: XCTestCase {
    private let suite = "YijingTests.LLMSettings"

    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func testDefaults() {
        let s = LLMSettings(defaults: freshDefaults())
        XCTAssertEqual(s.model, "deepseek-flash")
        XCTAssertEqual(s.apiKey, "")
        XCTAssertTrue(s.baseURL.contains("deepseek.com"))
    }

    func testRoundTrip() {
        let defaults = freshDefaults()
        let s = LLMSettings(defaults: defaults)
        s.apiKey = "test-key"
        s.model = "glm-5"
        s.baseURL = "https://example.com/v4/"

        let s2 = LLMSettings(defaults: defaults)
        XCTAssertEqual(s2.apiKey, "test-key")
        XCTAssertEqual(s2.model, "glm-5")
        XCTAssertEqual(s2.baseURL, "https://example.com/v4/")
        XCTAssertEqual(s2.config.apiKey, "test-key")
    }
}

final class CastHistoryStoreTests: XCTestCase {
    private let suite = "YijingTests.CastHistory"

    private func freshStore() -> CastHistoryStore {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return CastHistoryStore(defaults: d)
    }

    func testSaveLoadsNewestFirst() throws {
        let store = freshStore()
        let older = CastRecord(method: .manual, originalLines: Array(repeating: .youngYin, count: 6))
        var newer = CastRecord(method: .threeCoins, originalLines: Array(repeating: .youngYang, count: 6))
        newer = CastRecord(id: newer.id, date: older.date.addingTimeInterval(100), method: .threeCoins, originalLines: newer.originalLines)
        store.save(newer)
        store.save(older)

        let loaded = store.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.id, newer.id, "最新在前")
        XCTAssertEqual(loaded.last?.id, older.id)
    }

    func testUpdateByID() {
        let store = freshStore()
        var record = CastRecord(method: .manual, originalLines: Array(repeating: .youngYang, count: 6))
        store.save(record)
        record.question = "求财"
        record.aiAnswer = "解析……"
        store.save(record)

        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.question, "求财")
        XCTAssertEqual(loaded.first?.aiAnswer, "解析……")
    }

    func testDeleteAndClear() {
        let store = freshStore()
        let r1 = CastRecord(method: .manual, originalLines: Array(repeating: .youngYin, count: 6))
        let r2 = CastRecord(method: .threeCoins, originalLines: Array(repeating: .youngYang, count: 6))
        store.save(r1)
        store.save(r2)

        store.delete(id: r1.id)
        XCTAssertEqual(store.load().count, 1)

        store.clear()
        XCTAssertTrue(store.load().isEmpty)
    }

    func testResultReconstruction() {
        let lines: [LineType] = [.oldYang, .youngYang, .youngYang, .youngYang, .youngYang, .youngYang]
        let record = CastRecord(method: .manual, originalLines: lines)
        let result = record.result
        XCTAssertEqual(result.original.kingWenNumber, 1, "乾卦")
        XCTAssertEqual(result.changed.kingWenNumber, 44, "初爻变阴 -> 天风姤")
    }

    func testTranscriptRoundTrip() {
        let store = freshStore()
        var record = CastRecord(method: .manual, originalLines: Array(repeating: .youngYang, count: 6))
        record.transcript = [
            .user("事业"),
            .assistant("乾卦主自强不息。"),
            .user("财运呢？"),
            .assistant("六爻皆动，刚健不已，宜守正积极。"),
        ]
        store.save(record)

        let loaded = store.load().first
        XCTAssertEqual(loaded?.transcript.count, 4)
        XCTAssertEqual(loaded?.transcript.map(\.role), [.user, .assistant, .user, .assistant])
        XCTAssertEqual(loaded?.transcript.last?.content, "六爻皆动，刚健不已，宜守正积极。")
    }

    func testDecodeLegacyRecordWithoutTranscript() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","date":0,"method":"三枚铜钱","originalLines":[9,7,7,7,7,7],"question":"求财","aiAnswer":"解析……"}
        """
        let record = try JSONDecoder().decode(CastRecord.self, from: Data(legacy.utf8))
        XCTAssertEqual(record.question, "求财")
        XCTAssertEqual(record.aiAnswer, "解析……")
        XCTAssertTrue(record.transcript.isEmpty, "旧数据应解码出空 transcript")
        XCTAssertEqual(record.originalLines, [.oldYang, .youngYang, .youngYang, .youngYang, .youngYang, .youngYang])
    }
}