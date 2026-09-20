import SwiftUI
import YijingCore

/// AI 解卦会话窗口：固定卦象摘要、气泡式多轮对话；支持回放历史记录。
struct AIInterpretationView: View {
    @StateObject private var viewModel: AIInterpretationViewModel
    @EnvironmentObject private var router: AppRouter

    /// 从一次起卦结果进入（新会话）。
    init(result: CastResult) {
        _viewModel = StateObject(wrappedValue: AIInterpretationViewModel(
            record: CastRecord(method: result.method, originalLines: result.originalLines)
        ))
    }

    /// 从历史记录进入（回放当时的会话）。
    init(record: CastRecord) {
        _viewModel = StateObject(wrappedValue: AIInterpretationViewModel(record: record))
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryHeader
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if showOutput {
                        ForEach(viewModel.messages) { turn in
                            bubble(for: turn)
                        }
                        if viewModel.isSending {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("AI 解卦中…")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                        }
                        if let error = viewModel.errorMessage {
                            errorCard(error)
                        }
                    } else {
                        emptyHint
                    }
                }
                .padding()
            }

            inputBar
        }
        .navigationTitle("AI 解卦")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 固定摘要（不随消息滚动）

    private var summaryHeader: some View {
        VStack(spacing: 10) {
            summaryCard
            if !viewModel.hasAPIKey { apiKeySetupBanner }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background {
            Color(.secondarySystemBackground)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var apiKeySetupBanner: some View {
        Button {
            router.showSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                Text("尚未设置 API Key，点此前往「关于」页配置")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
    }

    private var showOutput: Bool {
        !viewModel.messages.isEmpty || viewModel.isSending || viewModel.errorMessage != nil
    }

    private var summaryCard: some View {
        let result = viewModel.result
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HexagramDrawingView(lines: result.originalLines)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.original.fullName)
                        .font(.title3.bold())
                    if !result.movingLineTitles.isEmpty {
                        Text("动爻：\(result.movingLineTitles.joined(separator: "、"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("变卦：\(result.changed.fullName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(result.method.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            if viewModel.isReplay {
                Label("回放历史会话 · \(viewModel.recordDate.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        }
    }

    // MARK: - 消息气泡

    @ViewBuilder
    private func bubble(for turn: DialogueTurn) -> some View {
        switch turn.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(turn.content)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Capsule().fill(Color.accentColor))
            }
        case .assistant:
            Text(renderedMarkdown(turn.content))
                .font(.body)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                }
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("解卦失败", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                router.showSettings()
            } label: {
                Label("前往设置 API Key", systemImage: "key.fill")
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.08))
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("输入所问之事，点击发送开始解卦")
                .foregroundColor(.secondary)
            Text("可连续追问，对话会保留并保存到起卦记录。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    /// 将 AI 回答按 Markdown 渲染（解析失败时回退纯文本）。
    private func renderedMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .full))) ?? AttributedString(text)
    }

    // MARK: - 输入条

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("输入所问之事（可留空）", text: $viewModel.question, axis: .vertical)
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                }

            Button {
                viewModel.interpret()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(viewModel.canSend ? Color.accentColor : Color.gray))
            }
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview("新会话") {
    NavigationStack {
        AIInterpretationView(
            result: CastResult(method: .threeCoins, originalLines: [
                .oldYang, .youngYang, .youngYin, .youngYang, .youngYin, .youngYang,
            ])
        )
    }
    .environmentObject(AppRouter())
}