import XCTest
@testable import YijingCore

final class TokenUsageTests: XCTestCase {

    // MARK: - 时段判定（北京时间）

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private var pricing: TokenPricing { .deepSeekFlash }

    func testPeakWeekdayBusinessHours() {
        let monday = date(2026, 9, 21, 9, 0)   // 周一 09:00
        XCTAssertTrue(pricing.isPeak(monday))
        let mondayAfternoon = date(2026, 9, 21, 14, 0)
        XCTAssertTrue(pricing.isPeak(mondayAfternoon))
    }

    func testOffPeakBoundaries() {
        XCTAssertFalse(pricing.isPeak(date(2026, 9, 21, 8, 59)), "08:59 高峰前")
        XCTAssertFalse(pricing.isPeak(date(2026, 9, 21, 12, 0)), "12:00 午休")
        XCTAssertFalse(pricing.isPeak(date(2026, 9, 21, 18, 0)), "18:00 高峰结束")
        XCTAssertFalse(pricing.isPeak(date(2026, 9, 21, 20, 0)), "晚间闲时")
        XCTAssertFalse(pricing.isPeak(date(2026, 9, 20, 15, 0)), "周日高峰不生效")
        XCTAssertFalse(pricing.isPeak(date(2026, 9, 26, 10, 0)), "周六高峰不生效")
    }

    func testOffPeakMorningMidday() {
        XCTAssertFalse(pricing.isPeak(date(2026, 9, 21, 12, 1)))
        XCTAssertFalse(pricing.isPeak(date(2026, 9, 21, 13, 59)))
    }

    // MARK: - 成本估算

    func testCostIdleFlash() {
        // 周日闲时：1M 未命中 + 1M 输出 + 0 命中。
        let idleDate = date(2026, 9, 20, 20, 0)
        let cost = pricing.cost(cacheHit: 0, cacheMiss: 1_000_000, completion: 1_000_000, at: idleDate)
        XCTAssertEqual(cost, 5.0, accuracy: 1e-9)
    }

    func testCostPeakDoubles() {
        let peakDate = date(2026, 9, 21, 10, 0)
        let cost = pricing.cost(cacheHit: 0, cacheMiss: 1_000_000, completion: 1_000_000, at: peakDate)
        XCTAssertEqual(cost, 10.0, accuracy: 1e-9)
    }

    func testCostCacheHitIsCheap() {
        let idleDate = date(2026, 9, 20, 20, 0)
        let cost = pricing.cost(cacheHit: 1_000_000, cacheMiss: 0, completion: 0, at: idleDate)
        XCTAssertEqual(cost, 0.02, accuracy: 1e-9)
    }

    // MARK: - 计费方式自动匹配

    func testResolveDeepSeek() {
        let pricing = TokenPricing.resolve(model: "deepseek-flash", baseURL: "https://api.deepseek.com")
        XCTAssertNotNil(pricing)
        XCTAssertTrue(pricing?.appliesPeak == true)
        // 旧名 deepseek-v4-flash 路由到 V4.1 Flash，同价计费。
        XCTAssertTrue(TokenPricing.resolve(model: "deepseek-v4-flash", baseURL: "https://api.deepseek.com")?.appliesPeak == true)
    }

    func testResolveZhipuFree() {
        let pricing = TokenPricing.resolve(model: "glm-4.7-flash", baseURL: "https://open.bigmodel.cn/api/paas/v4")
        XCTAssertNotNil(pricing)
        XCTAssertEqual(pricing?.cacheMissIdleCNYPerMillion ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(pricing?.appliesPeak, false, "智谱无峰谷")
    }

    func testResolveZhipuPaidApprox() {
        let pricing = TokenPricing.resolve(model: "glm-4.7", baseURL: "https://open.bigmodel.cn/api/paas/v4")
        XCTAssertNotNil(pricing)
        XCTAssertEqual(pricing?.cacheHitIdleCNYPerMillion ?? -1, 0.4, accuracy: 1e-9)
        XCTAssertEqual(pricing?.cacheMissIdleCNYPerMillion ?? -1, 2.0, accuracy: 1e-9)
        XCTAssertEqual(pricing?.outputIdleCNYPerMillion ?? -1, 8.0, accuracy: 1e-9)
        // 按 Base URL 识别：即便模型名不含 glm 也归为智谱付费档。
        let byURL = TokenPricing.resolve(model: "一段自定义模型", baseURL: "https://open.bigmodel.cn/api/paas/v4")
        XCTAssertNotNil(byURL)
    }

    func testResolveUnknownReturnsNil() {
        XCTAssertNil(TokenPricing.resolve(model: "kimi-k2.5", baseURL: "https://api.moonshot.ai"))
        XCTAssertNil(TokenPricing.resolve(model: "qwen-max", baseURL: "https://dashscope.aliyuncs.com"))
    }

    func testApplyingCostFreeZhipuIsZero() {
        var usage = TokenUsage(promptTokens: 1000, completionTokens: 500)
        usage.applyingCost(model: "glm-4.7-flash", baseURL: "https://open.bigmodel.cn/api/paas/v4")
        XCTAssertEqual(usage.costCNY ?? -1, 0, accuracy: 1e-9)
    }

    func testApplyingCostUnknownIsNil() {
        var usage = TokenUsage(promptTokens: 1000, completionTokens: 500)
        usage.applyingCost(model: "kimi-k2.5", baseURL: "https://api.moonshot.ai")
        XCTAssertNil(usage.costCNY)
    }

    func testApplyingCostDeepSeekUsesPeak() {
        let idle = date(2026, 9, 20, 20, 0)
        var usage = TokenUsage(promptTokens: 1000, completionTokens: 500, cacheHitTokens: 300, cacheMissTokens: 700)
        usage.applyingCost(model: "deepseek-flash", baseURL: "https://api.deepseek.com", at: idle)
        let hit = Double(300) * 0.02 / 1_000_000
        let miss = Double(700) * 1.0 / 1_000_000
        let output = Double(500) * 4.0 / 1_000_000
        let expected = hit + miss + output
        XCTAssertEqual(usage.costCNY ?? -1, expected, accuracy: 1e-9)
    }

    // MARK: - usage 解析

    func testParseDeepSeekUsageJSON() throws {
        let json: [String: Any] = [
            "prompt_tokens": 120,
            "completion_tokens": 60,
            "total_tokens": 180,
            "prompt_cache_hit_tokens": 40,
            "prompt_cache_miss_tokens": 80,
        ]
        let usage = try XCTUnwrap(TokenUsage.parse(json: json))
        XCTAssertEqual(usage.promptTokens, 120)
        XCTAssertEqual(usage.completionTokens, 60)
        XCTAssertEqual(usage.totalTokens, 180)
        XCTAssertEqual(usage.cacheHitTokens, 40)
        XCTAssertEqual(usage.cacheMissTokens, 80)
        XCTAssertNil(usage.costCNY)
    }

    func testParseOpenAICompatCachedTokens() throws {
        let json: [String: Any] = [
            "prompt_tokens": 100,
            "completion_tokens": 20,
            "prompt_tokens_details": ["cached_tokens": 40],
        ]
        let usage = try XCTUnwrap(TokenUsage.parse(json: json))
        XCTAssertEqual(usage.cacheHitTokens, 40)
        XCTAssertEqual(usage.cacheMissTokens, 60, "未命中的输入应等于输入减命中")
        XCTAssertEqual(usage.totalTokens, 120, "缺 total 时按 prompt+completion 兜底")
    }

    func testParseNoCacheInfoDefaultsToAllMiss() throws {
        let json: [String: Any] = ["prompt_tokens": 100, "completion_tokens": 20]
        let usage = try XCTUnwrap(TokenUsage.parse(json: json))
        XCTAssertEqual(usage.cacheHitTokens, 0)
        XCTAssertEqual(usage.cacheMissTokens, 100, "未细分时保守按全部未命中计")
    }

    func testParseInvalidUsageReturnsNil() {
        XCTAssertNil(TokenUsage.parse(json: [String: Any]()))
        XCTAssertNil(TokenUsage.parse(json: ["prompt_tokens": 1]))
    }

    func testMergeUsageAccumulatesCostsAndTokens() {
        let a = TokenUsage(
            promptTokens: 100, completionTokens: 50, totalTokens: 150,
            cacheHitTokens: 30, cacheMissTokens: 70, costCNY: 0.5
        )
        let b = TokenUsage(
            promptTokens: 200, completionTokens: 60, totalTokens: 260,
            cacheHitTokens: 10, cacheMissTokens: 190, costCNY: 0.3
        )
        let merged = a + b
        XCTAssertEqual(merged.promptTokens, 300)
        XCTAssertEqual(merged.completionTokens, 110)
        XCTAssertEqual(merged.cacheHitTokens, 40)
        XCTAssertEqual(merged.costCNY ?? -1, 0.8, accuracy: 1e-9)
    }

    // MARK: - 存储

    func testStoreSummaryAndClear() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "test.token.usage.store"))
        suite.removePersistentDomain(forName: "test.token.usage.store")
        let store = TokenUsageStore(defaults: suite)

        store.record(TokenUsage(promptTokens: 100, completionTokens: 50, totalTokens: 150, cacheHitTokens: 30, cacheMissTokens: 70, costCNY: 0.5), model: "deepseek-flash")
        store.record(TokenUsage(promptTokens: 200, completionTokens: 60, totalTokens: 260, cacheHitTokens: 10, cacheMissTokens: 190, costCNY: 0.3), model: "deepseek-flash")

        let summary = store.summary()
        XCTAssertEqual(summary.requestCount, 2)
        XCTAssertEqual(summary.promptTokens, 300)
        XCTAssertEqual(summary.completionTokens, 110)
        XCTAssertEqual(summary.cacheHitTokens, 40)
        XCTAssertEqual(summary.estimatedCostCNY, 0.8, accuracy: 1e-9)

        store.clear()
        XCTAssertEqual(store.summary().requestCount, 0)
        suite.removePersistentDomain(forName: "test.token.usage.store")
    }

    func testStoreIgnoresZeroUsage() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "test.token.usage.zero"))
        suite.removePersistentDomain(forName: "test.token.usage.zero")
        let store = TokenUsageStore(defaults: suite)
        store.record(TokenUsage(), model: "deepseek-flash")
        XCTAssertEqual(store.summary().requestCount, 0)
        suite.removePersistentDomain(forName: "test.token.usage.zero")
    }

    func testStoreTrimsToLimit() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "test.token.usage.trim"))
        suite.removePersistentDomain(forName: "test.token.usage.trim")
        let store = TokenUsageStore(defaults: suite)
        for _ in 0..<505 {
            store.record(TokenUsage(promptTokens: 1, completionTokens: 1, totalTokens: 2), model: "deepseek-flash")
        }
        XCTAssertEqual(store.records().count, 500)
        suite.removePersistentDomain(forName: "test.token.usage.trim")
    }

    // MARK: - CastRecord 兼容

    func testCastRecordDecodesLegacyDataWithoutAIUsage() throws {
        let json = """
        [
          {
            "id": "A0000000-0000-0000-0000-000000000001",
            "date": 700000000,
            "method": "三枚铜钱",
            "originalLines": [7, 8, 6, 7, 9, 7],
            "question": "今天运势",
            "aiAnswer": "解卦…",
            "transcript": [
              {"id": "B0000000-0000-0000-0000-000000000002", "role": "user", "content": "今天运势"}
            ]
          }
        ]
        """
        let records = try JSONDecoder().decode([CastRecord].self, from: Data(json.utf8))
        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records[0].aiUsage, "旧数据缺 aiUsage 应解码为 nil")
    }

    func testCastRecordRoundTripWithAIUsage() throws {
        let record = CastRecord(
            method: .threeCoins,
            originalLines: [.youngYang, .youngYin, .oldYin, .youngYang, .oldYang, .youngYang],
            question: "hi",
            aiAnswer: "answer",
            aiUsage: TokenUsage(promptTokens: 10, completionTokens: 5, totalTokens: 15, cacheHitTokens: 2, cacheMissTokens: 8, costCNY: 0.01)
        )
        let data = try JSONEncoder().encode([record])
        let decoded = try JSONDecoder().decode([CastRecord].self, from: data)
        XCTAssertEqual(decoded[0].aiUsage?.promptTokens, 10)
        XCTAssertEqual(decoded[0].aiUsage?.costCNY, 0.01)
    }
}