import SwiftUI
import YijingCore

struct AboutTabView: View {
    @State private var provider = LLMSettings.shared.provider
    @State private var apiKey = LLMSettings.shared.apiKey
    @State private var model = LLMSettings.shared.model
    @State private var baseURL = LLMSettings.shared.baseURL
    @State private var savedHint: SaveHint?
    @State private var usageSummary = TokenUsageStore.Summary()

    private let usageStore = TokenUsageStore()

    private enum SaveHint: Equatable {
        case key
        case model
        case baseURL

        var text: String {
            switch self {
            case .key: return "Key 已保存 ✓"
            case .model: return "模型已保存 ✓"
            case .baseURL: return "Base URL 已保存 ✓"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("模型服务", selection: $provider) {
                        ForEach(LLMProvider.allCases, id: \.self) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .onChange(of: provider) { _, newValue in
                        LLMSettings.shared.provider = newValue
                        loadFromSettings()
                    }
                    SecureField(keyPlaceholder, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, newValue in
                            LLMSettings.shared.apiKey = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            flash(.key)
                        }
                    TextField("模型", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: model) { _, newValue in
                            LLMSettings.shared.model = newValue
                            flash(.model)
                        }
                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: baseURL) { _, newValue in
                            LLMSettings.shared.baseURL = newValue
                            flash(.baseURL)
                        }
                    Text(providerNote)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if savedHint != nil {
                        Text(currentSavedText)
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                } header: {
                    Text("AI 解卦设置")
                }
                Section {
                    LabeledContent("当前计费", value: Self.billingSchemeText(model: model, baseURL: baseURL))
                    LabeledContent("请求次数", value: "\(usageSummary.requestCount)")
                    LabeledContent("输入 tokens", value: Self.tokenText(usageSummary.promptTokens))
                    LabeledContent("输出 tokens", value: Self.tokenText(usageSummary.completionTokens))
                    LabeledContent("缓存命中率", value: Self.hitRateText(usageSummary))
                    LabeledContent("估算费用", value: String(format: "¥%.4f", usageSummary.estimatedCostCNY))
                    if usageSummary.requestCount > 0 {
                        Button("清空统计", role: .destructive) {
                            usageStore.clear()
                            reload()
                        }
                    }
                } header: {
                    Text("Token 用量")
                } footer: {
                    Text("按设置模型对应的官方单价与请求时刻时段估算，实际费用以平台账单为准。")
                }
                Section("易经六十四卦") {
                    LabeledContent("版本", value: "1.0")
                    LabeledContent("起卦方式", value: "三枚铜钱 · 梅花易数")
                    LabeledContent("卦库", value: "文王卦序 · 八宫")
                }
                Section("说明") {
                    Text("本应用以《周易》六十四卦为框架，提供起卦占卜与卦辞查询。内容仍在补充中。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("关于")
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        usageSummary = usageStore.summary()
    }

    /// 切换服务商后，载入该服务商已保存（或预设）的 Key / 模型 / Base URL。
    private func loadFromSettings() {
        apiKey = LLMSettings.shared.apiKey
        model = LLMSettings.shared.model
        baseURL = LLMSettings.shared.baseURL
        savedHint = nil
    }

    private var keyPlaceholder: String {
        switch provider {
        case .deepseek: return "API Key（DeepSeek）"
        case .zhipu: return "API Key（智谱）"
        case .opencodeZen: return "API Key（opencode Zen）"
        case .custom: return "API Key"
        }
    }

    private var providerNote: String {
        switch provider {
        case .deepseek:
            return "DeepSeek 官方接口（base_url 无结尾斜杠，模型 deepseek-flash，OpenAI 兼容）。计费按官方价（含峰谷）估算。"
        case .zhipu:
            return "智谱开放平台（open.bigmodel.cn），glm-4.7-flash 为免费档。付费 GLM 按近似价估算。"
        case .opencodeZen:
            return "opencode Zen 网关（限时免费体验模型，需 Zen Key）。用量不参与费用估算。"
        case .custom:
            return "自定义任意 OpenAI 兼容服务：填写模型名与 Base URL。未识别的服务商不估算费用。"
        }
    }

    private static func tokenText(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)"
    }

    private static func hitRateText(_ summary: TokenUsageStore.Summary) -> String {
        guard summary.promptTokens > 0 else { return "—" }
        let percent = Double(summary.cacheHitTokens) / Double(summary.promptTokens) * 100
        return String(format: "%.0f%%", max(0, percent))
    }

    /// 依据当前模型与 Base URL 识别计费方式。
    private static func billingSchemeText(model: String, baseURL: String) -> String {
        guard let pricing = TokenPricing.resolve(model: model, baseURL: baseURL) else {
            return baseURL.lowercased().contains("opencode.ai") ? "opencode Zen（不估算）" : "未识别（不估算）"
        }
        if pricing.appliesPeak {
            return "DeepSeek Flash（含峰谷）"
        }
        return pricing.cacheMissIdleCNYPerMillion <= 0 ? "智谱免费（¥0）" : "智谱 GLM（近似）"
    }

    private var currentSavedText: String {
        savedHint?.text ?? ""
    }

    private func flash(_ hint: SaveHint) {
        withAnimation(.easeInOut(duration: 0.2)) {
            savedHint = hint
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard savedHint == hint else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                savedHint = nil
            }
        }
    }
}

#Preview {
    AboutTabView()
}
