import SwiftUI
import UIKit
import MarkdownUI
import YijingCore

/// AI 解卦会话窗口：固定卦象摘要、气泡式多轮对话；支持回放历史记录。
struct AIInterpretationView: View {
    @StateObject private var viewModel: AIInterpretationViewModel
    @EnvironmentObject private var router: AppRouter

    /// 对话底部的稳定锚点，避免以高度变化的气泡作为滚动目标。
    private static let bottomAnchorID = "chat-bottom"

    /// 聊天气泡主题：响应式言文（无块级背景），颜色跟随系统深浅模式。
    private static let chatTheme: Theme = Theme()
        .text {
            ForegroundColor(.primary)
            FontSize(16)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            BackgroundColor(Color(.quaternarySystemFill))
        }
        .strong {
            FontWeight(.semibold)
        }
        .emphasis {
            FontStyle(.italic)
        }
        .link {
            ForegroundColor(.blue)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.4))
                }
                .markdownMargin(top: 18, bottom: 10)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.25))
                }
                .markdownMargin(top: 18, bottom: 10)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.1))
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                }
                .markdownMargin(top: 14, bottom: 8)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.medium)
                    FontSize(.em(0.95))
                }
                .markdownMargin(top: 14, bottom: 8)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(0.9))
                    ForegroundColor(.secondary)
                }
                .markdownMargin(top: 14, bottom: 8)
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 12)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.separator))
                    .relativeFrame(width: .em(0.2))
                configuration.label
                    .markdownTextStyle { ForegroundColor(.secondary) }
                    .relativePadding(.horizontal, length: .em(1))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.225))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(14)
            }
            .background(Color(.quaternarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .markdownMargin(top: 0, bottom: 12)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.2))
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(color: Color(.separator)))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color(.secondarySystemBackground), Color(.quaternarySystemFill))
                )
                .markdownMargin(top: 0, bottom: 12)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                    BackgroundColor(nil)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 13)
                .relativeLineSpacing(.em(0.25))
        }

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

    /// 从卦库单卦详情进入（静态卦、不写入起卦记录）。
    init(hexagram: Hexagram) {
        let lines: [LineType] = (0..<6).map { hexagram.lineIsYang(at: $0) ? .youngYang : .youngYin }
        _viewModel = StateObject(wrappedValue: AIInterpretationViewModel(
            record: CastRecord(method: .manual, originalLines: lines),
            persistsHistory: false,
            methodLabel: "卦库·单卦解读"
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryHeader
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if showOutput {
                            ForEach(viewModel.turns) { turn in
                                bubble(for: turn)
                                    .id(turn.id)
                            }
                            StreamingBubble(live: viewModel.live)
                            if let error = viewModel.errorMessage {
                                errorCard(error)
                            }
                        } else {
                            emptyHint
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchorID)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded {
                    hideKeyboard()
                })
                .onAppear {
                    // 回放历史会话时自动滚到底部（最新对话）；新会话保持顶部。
                    guard viewModel.isReplay else { return }
                    scrollToBottom(proxy, after: 0.15)
                }
                .onChange(of: viewModel.turns.count) { _, _ in
                    // 仅在新气泡落定时滚动；思考流式期间不自动跟随，避免与手动滑动抢主线程。
                    scrollToBottom(proxy, after: 0.15)
                }
            }

            usageLine

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
        !viewModel.turns.isEmpty || viewModel.errorMessage != nil
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
                    Text(viewModel.methodLabel)
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
    private func bubble(for turn: AITurn) -> some View {
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
            AssistantBubble(turn: turn, theme: Self.chatTheme)
        }
    }

    /// AI 气泡（已完成轮次）：思考过程可折叠展开 + Markdown 正文。
    private struct AssistantBubble: View {
        let turn: AITurn
        let theme: Theme

        @State private var expanded = false

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if !turn.reasoning.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "brain")
                            Text("思考过程")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    if expanded {
                        Text(turn.reasoning)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                if !turn.content.isEmpty {
                    Markdown(turn.content)
                        .markdownTheme(theme)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            }
        }
    }

    /// 流式气泡：单独订阅 `LiveStream`，高频更新只重绘自身；
    /// 流式期间用纯文本并禁用选择，展示完整思考与正文。
    private struct StreamingBubble: View {
        @ObservedObject var live: LiveStream

        var body: some View {
            if live.isStreaming {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                        Text("思考中…")
                        Spacer()
                        ProgressView()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if !live.reasoning.isEmpty {
                        StreamingTextView(text: live.reasoning, color: .secondaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !live.content.isEmpty {
                        StreamingTextView(text: live.content, color: .label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                }
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
                hideKeyboard()
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

    // MARK: - 用量条

    @ViewBuilder
    private var usageLine: some View {
        if let usage = viewModel.sessionUsage, usage.totalTokens > 0 {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.caption2)
                Text("\(viewModel.isReplay ? "该次用量" : "本次用量")：输入 \(Self.tokenText(usage.promptTokens)) · 输出 \(Self.tokenText(usage.completionTokens)) · \(Self.costText(usage))")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }

    private static func tokenText(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)"
    }

    private static func costText(_ usage: TokenUsage) -> String {
        guard let cost = usage.costCNY else { return "费用—" }
        return String(format: "≈¥%.4f", cost)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// 滚动到底部锚点。延后一个 runloop，避开布局未完成与键盘收起动画的窗口，
    /// 防止滚动到空白区域。仅在新气泡落定时调用，思考流式期间不跟随。
    private func scrollToBottom(_ proxy: ScrollViewProxy, after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(nil) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        }
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

/// 流式纯文本视图：基于非滚动 `UITextView`，新内容以**增量追加**方式写入
/// `textStorage`，只让 CoreText 排布新增部分，避免长文本每次全量重排导致卡顿。
/// 流式期间不可选中，也避免文本选择手势与滚动争抢。
private struct StreamingTextView: UIViewRepresentable {
    let text: String
    var color: UIColor = .label

    private var font: UIFont { .preferredFont(forTextStyle: .subheadline) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.font = font
        view.textColor = color
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.font = font
        view.textColor = color
        let current = view.text ?? ""
        if text == current { return }
        if !current.isEmpty, text.hasPrefix(current) {
            let delta = String(text.dropFirst(current.count))
            view.textStorage.append(NSAttributedString(string: delta, attributes: [
                .font: font,
                .foregroundColor: color,
            ]))
        } else {
            view.text = text
            view.font = font
            view.textColor = color
        }
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}