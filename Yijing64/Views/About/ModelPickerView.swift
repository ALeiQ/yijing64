import SwiftUI
import YijingCore

/// 模型选择器：从服务商拉取可用模型（带缓存），支持搜索与手动输入。
struct ModelPickerView: View {
    let provider: LLMProvider
    let baseURL: String
    let apiKey: String
    @Binding var selected: String

    @Environment(\.dismiss) private var dismiss

    private let settings = LLMSettings.shared

    @State private var models: [LLMModel] = []
    @State private var query = ""
    @State private var manual = ""
    @State private var phase: Phase = .loading
    @State private var message: String?

    private enum Phase: Equatable { case loading, loaded, failed }

    private var filtered: [LLMModel] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return models }
        return models.filter { $0.id.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let message {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section("手动输入") {
                    HStack {
                        TextField("模型 ID", text: $manual)
                            .noTextAutocapitalization()
                            .autocorrectionDisabled()
                            .onSubmit { apply(manual) }
                        Button("使用") { apply(manual) }
                            .disabled(manual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section {
                    if phase == .loading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在获取模型列表…")
                                .foregroundColor(.secondary)
                        }
                    } else if filtered.isEmpty {
                        Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无模型" : "无匹配模型")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filtered) { model in
                            modelRow(model)
                        }
                    }
                } header: {
                    HStack {
                        Text("模型")
                        Spacer()
                        Button {
                            Task { await fetch(force: true) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .disabled(phase == .loading)
                    }
                } footer: {
                    Text("列表来自服务商的 /models 接口；智谱等无该接口时显示预设，也可手动输入。")
                }
            }
            .searchable(text: $query, prompt: "搜索模型")
            .navigationTitle("选择模型")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .task { await loadIfNeeded() }
    }

    private func modelRow(_ model: LLMModel) -> some View {
        Button {
            apply(model.id)
        } label: {
            HStack {
                Text(model.id)
                    .foregroundColor(model.id == selected ? .accentColor : .primary)
                Spacer()
                if model.id == selected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func apply(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selected = trimmed
        dismiss()
    }

    private func loadIfNeeded() async {
        if let cached = settings.cachedModels(for: provider, baseURL: baseURL),
           !settings.isModelsCacheStale(for: provider) {
            models = cached
            phase = .loaded
            return
        }
        await fetch(force: false)
    }

    private func fetch(force: Bool) async {
        if !force,
           let cached = settings.cachedModels(for: provider, baseURL: baseURL),
           !settings.isModelsCacheStale(for: provider) {
            models = cached
            phase = .loaded
            return
        }

        phase = .loading
        message = nil
        let client = LLMClient(config: LLMConfig(baseURL: baseURL, model: selected, apiKey: apiKey))
        do {
            let chatModels = provider.filteringChatCompatible(try await client.fetchModels())
            guard !chatModels.isEmpty else {
                models = provider.presetModels.map(LLMModel.init)
                message = "该服务商没有可用于对话的模型，以下为预设。"
                phase = .loaded
                return
            }
            models = chatModels
            settings.saveModels(chatModels, for: provider, baseURL: baseURL)
            phase = .loaded
        } catch {
            models = provider.presetModels.map(LLMModel.init)
            message = fallbackMessage(error)
            phase = .failed
        }
    }

    private func fallbackMessage(_ error: Error) -> String {
        if apiKey.isEmpty, provider != .opencodeZen, provider != .opencodeGo {
            return "未填写 API Key，以下为预设模型；填写后可刷新获取完整列表。"
        }
        let detail = (error as? LLMClient.Error)?.message ?? error.localizedDescription
        return "获取模型列表失败：\(detail)"
    }
}
