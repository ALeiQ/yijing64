import SwiftUI
import YijingCore

struct AboutTabView: View {
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
                    SecureField("API Key（智谱开放平台）", text: $apiKey)
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
                    Text("默认 DeepSeek（base_url 无结尾斜杠，模型 deepseek-flash，OpenAI 兼容）。也可改用智谱免费模型 glm-4.7-flash（open.bigmodel.cn）。计费按所填模型自动匹配：DeepSeek 按官方价（含峰谷）；智谱免费档为 ¥0；其他模型不估算。")
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

    private static func tokenText(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)"
    }

    private static func hitRateText(_ summary: TokenUsageStore.Summary) -> String {
        guard summary.promptTokens > 0 else { return "—" }
        let percent = Double(summary.cacheHitTokens) / Double(summary.promptTokens) * 100
        return String(format: "%.0f%%", max(0, percent))
    }

    /// 依据当前设置识别计费方式。
    private static func billingSchemeText(model: String, baseURL: String) -> String {
        guard let pricing = TokenPricing.resolve(model: model, baseURL: baseURL) else {
            return "未识别（不估算）"
        }
        if pricing.appliesPeak {
            return "DeepSeek Flash（含峰谷）"
        }
        if pricing.cacheMissIdleCNYPerMillion <= 0 {
            return "智谱免费（¥0）"
        }
        return "智谱 GLM（近似）"
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