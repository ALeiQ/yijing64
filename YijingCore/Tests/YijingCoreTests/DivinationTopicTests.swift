import XCTest
@testable import YijingCore

final class DivinationTopicTests: XCTestCase {

    func testRealtimeInformationQuestionsRejected() {
        XCTAssertEqual(DivinationTopic.relevance(of: "今天几号", history: []), .unrelated)
        XCTAssertEqual(DivinationTopic.relevance(of: "今天是几号", history: []), .unrelated)
        XCTAssertEqual(DivinationTopic.relevance(of: "今天星期几", history: []), .unrelated)
        XCTAssertEqual(DivinationTopic.relevance(of: "现在几点", history: []), .unrelated)
        XCTAssertEqual(DivinationTopic.relevance(of: "现在几点了", history: []), .unrelated)
        XCTAssertEqual(DivinationTopic.relevance(of: "明天天气怎么样", history: []), .unrelated)
    }

    func testContentRelatedQuestionsPassToModel() {
        // 内容类词汇（编程/写诗/菜谱）不再本地拦截，交给模型侧 prompt 兜底。
        XCTAssertEqual(DivinationTopic.relevance(of: "用 Python 写个排序", history: []), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "帮我写首诗", history: []), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "怎么做番茄炒蛋", history: []), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "这几天写代码合适吗", history: []), .divination)
    }

    func testDivinationKeywordsAllowed() {
        XCTAssertEqual(DivinationTopic.relevance(of: "我工作运势如何", history: []), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "感情会顺利吗", history: []), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "帮我解这一卦", history: []), .divination)
    }

    func testAmbiguousQuestionPassesByDefault() {
        XCTAssertEqual(DivinationTopic.relevance(of: "帮我看看", history: []), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "下一步怎么办", history: []), .divination)
    }

    func testEmptyQuestionTreatedAsDivination() {
        XCTAssertEqual(DivinationTopic.relevance(of: "", history: []), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "   ", history: []), .divination)
    }

    func testUnrelatedRejectedEvenInOngoingConversation() {
        // 解卦历史不应放行无关问题（历史不参与判定）。
        let history = [
            DialogueTurn.user("是否应该跳槽"),
            DialogueTurn.assistant("卦象显示……"),
        ]
        XCTAssertEqual(DivinationTopic.relevance(of: "今天几号", history: history), .unrelated)
        XCTAssertEqual(DivinationTopic.relevance(of: "明天天气怎么样", history: history), .unrelated)
    }

    func testOngoingDivinationConversationPasses() {
        // 正常追问由相关词命中放行（"财运"），与历史无关。
        let history = [
            DialogueTurn.user("是否应该跳槽"),
            DialogueTurn.assistant("卦象显示……"),
        ]
        XCTAssertEqual(DivinationTopic.relevance(of: "那再看看财运", history: history), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "再讲讲", history: history), .divination)
    }

    func testDivinationKeywordsIntervenedQuestionsPass() {
        // 命中也含"几号"表达的择日/搬家场景，因相关词"搬家"而放行。
        XCTAssertEqual(DivinationTopic.relevance(of: "下个月几号搬家合适", history: []), .divination)
    }

    func testTravelAndAfterlifeQuestionsPass() {
        XCTAssertEqual(DivinationTopic.relevance(of: "今天可以出门吗", history: []), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "适合远行吗", history: []), .divination)
        XCTAssertEqual(DivinationTopic.relevance(of: "下周去面试能成吗", history: []), .divination)
    }

    func testUnrelatedOverriddenByRelatedSignal() {
        // 同时命中无关与相关词时，按占卜放行（默认放行策略）。
        XCTAssertEqual(DivinationTopic.relevance(of: "想测一下明天出行顺不顺", history: []), .divination)
    }
}