import XCTest
@testable import YijingCore

final class ModelCatalogTests: XCTestCase {

    func testModelsURLNormalizesTrailingSlash() {
        XCTAssertEqual(ModelCatalog.modelsURL(baseURL: "https://api.deepseek.com")?.absoluteString, "https://api.deepseek.com/models")
        XCTAssertEqual(ModelCatalog.modelsURL(baseURL: "https://opencode.ai/zen/v1")?.absoluteString, "https://opencode.ai/zen/v1/models")
        XCTAssertEqual(ModelCatalog.modelsURL(baseURL: "https://open.bigmodel.cn/api/paas/v4/")?.absoluteString, "https://open.bigmodel.cn/api/paas/v4/models")
        XCTAssertNil(ModelCatalog.modelsURL(baseURL: "   "))
    }

    func testParseOpenAIList() {
        let json = #"{"object":"list","data":[{"id":"deepseek-flash","object":"model"},{"id":"deepseek-v4-pro","object":"model"}]}"#
        let models = ModelCatalog.parseModels(Data(json.utf8))
        XCTAssertEqual(models.map(\.id), ["deepseek-flash", "deepseek-v4-pro"])
    }

    func testParseStringArrayAndModelsKey() {
        let strings = #"{"data":["a","b","a"]}"#
        XCTAssertEqual(ModelCatalog.parseModels(Data(strings.utf8)).map(\.id), ["a", "b"], "应去重")

        let modelsKey = #"{"models":[{"id":"glm-5.2"},{"name":"glm-5.3"}]}"#
        XCTAssertEqual(ModelCatalog.parseModels(Data(modelsKey.utf8)).map(\.id), ["glm-5.2", "glm-5.3"])
    }

    func testParseBareArrayAndEmpty() {
        XCTAssertEqual(ModelCatalog.parseModels(Data(#"["x","y"]"#.utf8)).map(\.id), ["x", "y"])
        XCTAssertTrue(ModelCatalog.parseModels(Data(#"{"object":"list"}"#.utf8)).isEmpty)
        XCTAssertTrue(ModelCatalog.parseModels(Data("not json".utf8)).isEmpty)
    }

    func testOpencodeFiltersNonChatModels() {
        let models = [
            "gpt-5.5", "claude-opus-5", "gemini-3.8-flash", "qwen3.7-max",
            "jev-1.13", "grok-4.7", "muse-spark-1.3",
            "deepseek-v4.1-flash", "glm-5.3-flash", "kimi-k2.6", "big-pickle",
        ].map(LLMModel.init)

        let filtered = LLMProvider.opencodeGo.filteringChatCompatible(models).map(\.id)
        XCTAssertEqual(filtered, ["deepseek-v4.1-flash", "glm-5.3-flash", "kimi-k2.6", "big-pickle"])
    }

    func testNonOpencodeDoesNotFilter() {
        let models = ["gpt-5.5", "glm-4.7-flash"].map(LLMModel.init)
        XCTAssertEqual(LLMProvider.deepseek.filteringChatCompatible(models).map(\.id), ["gpt-5.5", "glm-4.7-flash"])
        XCTAssertEqual(LLMProvider.custom.filteringChatCompatible(models).map(\.id), ["gpt-5.5", "glm-4.7-flash"])
    }

    func testPresetModels() {
        XCTAssertFalse(LLMProvider.deepseek.presetModels.isEmpty)
        XCTAssertFalse(LLMProvider.zhipu.presetModels.isEmpty)
        XCTAssertTrue(LLMProvider.custom.presetModels.isEmpty)
    }

    // MARK: - 缓存

    func testModelsCacheRoundTripAndInvalidation() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "test.models.cache"))
        suite.removePersistentDomain(forName: "test.models.cache")
        let settings = LLMSettings(defaults: suite)

        XCTAssertNil(settings.cachedModels(for: .deepseek, baseURL: "https://api.deepseek.com"))
        XCTAssertTrue(settings.isModelsCacheStale(for: .deepseek))

        settings.saveModels([LLMModel(id: "deepseek-flash"), LLMModel(id: "deepseek-v4-pro")],
                            for: .deepseek, baseURL: "https://api.deepseek.com")

        XCTAssertEqual(settings.cachedModels(for: .deepseek, baseURL: "https://api.deepseek.com")?.map(\.id),
                       ["deepseek-flash", "deepseek-v4-pro"])
        XCTAssertFalse(settings.isModelsCacheStale(for: .deepseek))
        // Base URL 变化：缓存失效。
        XCTAssertNil(settings.cachedModels(for: .deepseek, baseURL: "https://other.example.com"))
        // 不同服务商互不影响。
        XCTAssertNil(settings.cachedModels(for: .zhipu, baseURL: "https://open.bigmodel.cn/api/paas/v4"))

        suite.removePersistentDomain(forName: "test.models.cache")
    }
}
