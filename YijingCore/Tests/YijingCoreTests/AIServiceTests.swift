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

    func testSystemPromptRequiresStructuredMarkdown() {
        let result = CastResult(method: .manual, originalLines: Array(repeating: .youngYin, count: 6))
        let system = HexagramInterpretation.messages(for: result, question: "").first!.content
        XCTAssertTrue(system.contains("##"), "应要求分节标题")
        XCTAssertTrue(system.contains("- "), "应要求列表要点")
        XCTAssertTrue(system.contains("200-500"), "应约束篇幅")
        XCTAssertTrue(system.contains("2-5"), "每节要点条数约束")
        XCTAssertTrue(system.contains("整体卦象"), "应包含固定分节名")
        XCTAssertTrue(system.contains("给你的建议"), "应包含固定分节名")
        XCTAssertTrue(system.contains("能不能出门"), "应将出行吉凶等切身问题列为应解读场景")
        XCTAssertTrue(system.contains("写代码"), "应将活动时机吉凶（如写代码）列为应解读场景，而非知识求助")
    }

    func testSystemPromptRequiresDecisiveVerdict() {
        let result = CastResult(method: .manual, originalLines: Array(repeating: .youngYin, count: 6))
        let system = HexagramInterpretation.messages(for: result, question: "今天适合开车吗").first!.content
        XCTAssertTrue(system.contains("明确判词"), "应要求针对所问给出明确判词")
        XCTAssertTrue(system.contains("不宜"), "应要求卦象不利时直接判不宜")
        XCTAssertTrue(system.contains("禁止把不利弱化为折中说法"), "应禁止和稀泥表达")
        XCTAssertTrue(system.contains("勉强可行"), "应点名禁止“勉强可行”等措辞")
        XCTAssertTrue(system.contains("适量"), "应点名禁止“适量/适度”等回避措辞")
    }

    func testSystemPromptRequiresChineseThroughout() {
        let result = CastResult(method: .manual, originalLines: Array(repeating: .youngYin, count: 6))
        let system = HexagramInterpretation.messages(for: result, question: "").first!.content
        XCTAssertTrue(system.contains("全程使用中文"), "应要求思考与回答全程中文")
        XCTAssertTrue(system.contains("包括思考过程"), "应明确包含思考过程，避免中英混合")
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

    func testProviderDefaults() {
        let s = LLMSettings(defaults: freshDefaults())
        XCTAssertEqual(s.provider, .deepseek)
        XCTAssertEqual(LLMProvider.deepseek.defaultModel, "deepseek-flash")
        XCTAssertEqual(LLMProvider.zhipu.defaultModel, "glm-4.7-flash")
        XCTAssertEqual(LLMProvider.opencodeZen.defaultModel, "big-pickle")
        XCTAssertEqual(LLMProvider.opencodeZen.defaultBaseURL, "https://opencode.ai/zen/v1")
        XCTAssertEqual(LLMProvider.opencodeGo.defaultModel, "deepseek-v4.1-flash")
        XCTAssertEqual(LLMProvider.opencodeGo.defaultBaseURL, "https://opencode.ai/zen/go/v1")
        XCTAssertEqual(LLMProvider.custom.defaultModel, "")
    }

    func testProviderSwitchAppliesPreset() {
        let s = LLMSettings(defaults: freshDefaults())
        s.provider = .zhipu
        XCTAssertEqual(s.model, "glm-4.7-flash")
        XCTAssertTrue(s.baseURL.contains("bigmodel.cn"))
        s.provider = .opencodeZen
        XCTAssertEqual(s.model, "big-pickle")
        XCTAssertTrue(s.baseURL.contains("opencode.ai"))
        s.provider = .opencodeGo
        XCTAssertEqual(s.model, "deepseek-v4.1-flash")
        XCTAssertEqual(s.baseURL, "https://opencode.ai/zen/go/v1")
    }

    func testPerProviderKeyIsolated() {
        let s = LLMSettings(defaults: freshDefaults())
        s.provider = .deepseek
        s.apiKey = "deepseek-key"
        s.provider = .zhipu
        s.apiKey = "zhipu-key"

        XCTAssertEqual(s.apiKey, "zhipu-key")
        s.provider = .deepseek
        XCTAssertEqual(s.apiKey, "deepseek-key", "切回后应保留各自的 Key")
        XCTAssertEqual(s.apiKey(for: .zhipu), "zhipu-key")
    }

    func testPerProviderEditsPreserved() {
        let s = LLMSettings(defaults: freshDefaults())
        s.provider = .zhipu
        s.model = "glm-4.7"
        s.baseURL = "https://open.bigmodel.cn/api/paas/v4"

        s.provider = .deepseek
        XCTAssertEqual(s.model, "deepseek-flash")
        s.provider = .zhipu
        XCTAssertEqual(s.model, "glm-4.7", "预设项的手动修改应保留在各自槽位")
    }

    func testLegacyConfigMigration() {
        let defaults = freshDefaults()
        defaults.set("legacy-key", forKey: "llm.apiKey")
        defaults.set("glm-4.7", forKey: "llm.model")
        defaults.set("https://open.bigmodel.cn/api/paas/v4", forKey: "llm.baseURL")

        let s = LLMSettings(defaults: defaults)
        XCTAssertEqual(s.provider, .zhipu, "旧数据应推断为智谱")
        XCTAssertEqual(s.apiKey, "legacy-key", "旧 Key 应迁入对应服务商槽位")
        XCTAssertEqual(s.model, "glm-4.7")
    }

    func testProviderDetect() {
        XCTAssertEqual(LLMProvider.detect(model: "deepseek-flash", baseURL: ""), .deepseek)
        XCTAssertEqual(LLMProvider.detect(model: "glm-4.7-flash", baseURL: ""), .zhipu)
        XCTAssertEqual(LLMProvider.detect(model: "", baseURL: "https://open.bigmodel.cn/api/paas/v4"), .zhipu)
        XCTAssertEqual(LLMProvider.detect(model: "big-pickle", baseURL: "https://opencode.ai/zen/v1"), .opencodeZen)
        XCTAssertEqual(LLMProvider.detect(model: "deepseek-v4.1-flash", baseURL: "https://opencode.ai/zen/go/v1"), .opencodeGo)
        XCTAssertEqual(LLMProvider.detect(model: "glm-5.3-flash", baseURL: "https://opencode.ai/zen/go/v1"), .opencodeGo)
        XCTAssertEqual(LLMProvider.detect(model: "kimi-k2.5", baseURL: "https://api.moonshot.ai"), .custom)
    }

    func testProviderDetectByURLOnly() {
        XCTAssertEqual(LLMProvider.detect(baseURL: "https://api.deepseek.com"), .deepseek)
        XCTAssertEqual(LLMProvider.detect(baseURL: "https://open.bigmodel.cn/api/paas/v4"), .zhipu)
        XCTAssertEqual(LLMProvider.detect(baseURL: "https://opencode.ai/zen/v1"), .opencodeZen)
        XCTAssertEqual(LLMProvider.detect(baseURL: "https://opencode.ai/zen/go/v1"), .opencodeGo)
        // 只看 URL：opencode 的 deepseek 系模型不会被误判为 DeepSeek。
        XCTAssertEqual(LLMProvider.detect(baseURL: "https://opencode.ai/zen/go/v1"), .opencodeGo)
        XCTAssertEqual(LLMProvider.detect(baseURL: "https://api.moonshot.ai"), .custom)
        XCTAssertEqual(LLMProvider.detect(baseURL: ""), .custom)
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
            .assistant("乾卦主自强不息。", reasoning: "先看本卦乾，动爻初九……"),
            .user("财运呢？"),
            .assistant("六爻皆动，刚健不已，宜守正积极。", reasoning: "六爻皆动，势不可挡……"),
        ]
        store.save(record)

        let loaded = store.load().first
        XCTAssertEqual(loaded?.transcript.count, 4)
        XCTAssertEqual(loaded?.transcript.map(\.role), [.user, .assistant, .user, .assistant])
        XCTAssertEqual(loaded?.transcript.last?.content, "六爻皆动，刚健不已，宜守正积极。")
        XCTAssertEqual(loaded?.transcript.last?.reasoning, "六爻皆动，势不可挡……", "思考过程应随记录持久化")
        XCTAssertEqual(loaded?.transcript[1].reasoning, "先看本卦乾，动爻初九……")
    }

    func testDecodeLegacyTranscriptWithoutReasoning() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","date":0,"method":"三枚铜钱","originalLines":[9,7,7,7,7,7],
         "transcript":[{"id":"\(UUID().uuidString)","role":"assistant","content":"解卦……"}]}
        """
        let record = try JSONDecoder().decode(CastRecord.self, from: Data(legacy.utf8))
        XCTAssertEqual(record.transcript.first?.content, "解卦……")
        XCTAssertEqual(record.transcript.first?.reasoning, "", "旧数据缺 reasoning 应解码为空串")
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