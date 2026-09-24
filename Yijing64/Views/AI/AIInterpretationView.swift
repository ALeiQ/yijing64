import SwiftUI
import MarkdownUI
import YijingCore

/// AI 解卦会话窗口：固定卦象摘要、气泡式多轮对话；支持回放历史记录。
struct AIInterpretationView: View {
    @StateObject private var viewModel: AIInterpretationViewModel
    @EnvironmentObject private var router: AppRouter

    /// 对话底部的稳定锚点，避免以高度变化的气泡作为滚动目标。
    private static let bottomAnchorID = "chat-bottom"
    /// 滚动协调：引用类型持有，修改属性不会触发 View 重绘。
    private final class ScrollCoordinator {
        var lastStreamScroll = Date.distantPast
        /// 是否跟随流式内容贴底；用户手动滑动后暂停，下次提问恢复。
        var follow = true
    }
    @State private var scrollCoordinator = ScrollCoordinator()

    /// 聊天气泡主题：响应式言文（无块级背景），颜色跟随系统深浅模式。
    private static let chatTheme: Theme = Theme()
        .text {
            ForegroundColor(.primary)
            FontSize(16)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            BackgroundColor(Color.quaternarySystemFill)
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
                    .fill(Color.separatorLine)
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
            .background(Color.quaternarySystemFill)
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
                .markdownTableBorderStyle(.init(color: Color.separatorLine))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.secondarySystemBackground, Color.quaternarySystemFill)
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

    /// 从卦库单卦详情进入（静态卦，同样写入起卦记录）。
    init(hexagram: Hexagram) {
        let lines: [LineType] = (0..<6).map { hexagram.lineIsYang(at: $0) ? .youngYang : .youngYin }
        _viewModel = StateObject(wrappedValue: AIInterpretationViewModel(
            record: CastRecord(method: .hexagramLibrary, originalLines: lines)
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryHeader
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if showOutput {
                            ForEach(viewModel.turns) { turn in
                                bubble(for: turn, proxy: proxy)
                                    .id(turn.id)
                            }
                            if let error = viewModel.errorMessage {
                                errorCard(error)
                            }
                        } else {
                            emptyHint
                        }
                        // 非懒容器内，锚点始终实例化，滚动定位可靠。
                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchorID)
                    }
                    .padding()
                }
                .dismissKeyboardOnScroll()
                .simultaneousGesture(TapGesture().onEnded {
                    // 收起键盘但保持当前滚动位置，不强制跳到底部。
                    hideKeyboard()
                })
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8).onChanged { _ in
                        // 用户手动滑动 → 暂停流式跟随，直到下次提问。
                        scrollCoordinator.follow = false
                    }
                )
                .onAppear {
                    // 回放历史会话时自动滚到底部（最新对话）；新会话保持顶部。
                    guard viewModel.isReplay else { return }
                    scrollCoordinator.follow = true
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.turns.count) { _, _ in
                    // 新提问/新气泡：恢复跟随并贴底。
                    scrollCoordinator.follow = true
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.turns.last?.isStreaming) { _, isStreaming in
                    // 完成折叠后内容变矮，补滚一次重新贴底（若用户已手动上滑则不打扰）。
                    guard isStreaming == false else { return }
                    scrollToBottom(proxy)
                }
            }

            usageLine

            inputBar
        }
        .navigationTitle("AI 解卦")
        .inlineNavigationTitle()
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
            Color.secondarySystemBackground
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
        let original = result.original
        let hasMoving = !result.movingLineTitles.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                Spacer()

                hexagramTile(name: original.fullName, lines: result.originalLines) {
                    HexagramDetailView(hexagram: original)
                }

                if hasMoving {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.right")
                            .font(.body.bold())
                            .foregroundColor(.orange)
                        Text("变")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 20)

                    hexagramTile(name: result.changed.fullName, lines: result.originalLines.map { $0.changed }) {
                        HexagramDetailView(hexagram: result.changed)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                if hasMoving {
                    Label("动爻 \(result.movingLineTitles.joined(separator: "、"))", systemImage: "sparkles")
                } else {
                    Label("静卦 · 无动爻", systemImage: "moon.stars")
                }
                Spacer()
                Text(viewModel.methodLabel)
            }
            .font(.caption2)
            .foregroundColor(.secondary)

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
                .fill(Color.systemBackground)
        }
    }

    private func hexagramTile(
        name: String,
        lines: [LineType],
        @ViewBuilder destination: @escaping () -> HexagramDetailView
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 6) {
                HexagramDrawingView(lines: lines)
                Text(name)
                    .font(.subheadline.bold())
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 消息气泡

    @ViewBuilder
    private func bubble(for turn: AITurn, proxy: ScrollViewProxy) -> some View {
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
            if turn.isStreaming {
                StreamingBubble(live: viewModel.live) {
                    scrollToBottom(proxy, streaming: true)
                }
            } else {
                AssistantBubble(turn: turn, theme: Self.chatTheme)
            }
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
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
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
                    .fill(Color.secondarySystemBackground)
            }
        }
    }

    /// 流式气泡：单独订阅 `LiveStream`，高频更新只重绘自身；
    /// 流式期间用纯文本并禁用选择，展示完整思考与正文；内容增长时回调跟随滚动。
    private struct StreamingBubble: View {
        @ObservedObject var live: LiveStream
        let onGrow: () -> Void

        var body: some View {
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
                    StreamingTextView(text: live.reasoning, color: .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !live.content.isEmpty {
                    StreamingTextView(text: live.content, color: .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondarySystemBackground)
            }
            .onChange(of: live.reasoning) { _, _ in onGrow() }
            .onChange(of: live.content) { _, _ in onGrow() }
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
                        .fill(Color.secondarySystemBackground)
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
                Text("\(viewModel.isReplay ? "该次用量" : "本次用量")\(modelSuffix)：输入 \(Self.tokenText(usage.promptTokens)) · 输出 \(Self.tokenText(usage.completionTokens)) · \(Self.costText(usage))")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }

    private var modelSuffix: String {
        guard let label = viewModel.modelLabel else { return "" }
        return " · \(label)"
    }

    private static func tokenText(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)"
    }

    private static func costText(_ usage: TokenUsage) -> String {
        guard let cost = usage.costCNY else { return "费用—" }
        return String(format: "≈¥%.4f", cost)
    }

    private func hideKeyboard() {
        dismissKeyboard()
    }

    /// 滚动到底部锚点。流式跟随（`streaming`）按 ~0.2s 节流，避免高频滚动；
    /// 其余时机多段补滚（0.05s / 0.35s）覆盖布局未完成与 Markdown 异步排版。
    /// 用户手动上滑后会暂停跟随（`follow == false`），下次提问恢复。
    private func scrollToBottom(_ proxy: ScrollViewProxy, streaming: Bool = false) {
        guard scrollCoordinator.follow else { return }
        if streaming {
            let now = Date()
            guard now.timeIntervalSince(scrollCoordinator.lastStreamScroll) >= 0.1 else { return }
            scrollCoordinator.lastStreamScroll = now
            DispatchQueue.main.async {
                withAnimation(nil) {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            }
            return
        }
        for delay in [0.05, 0.35] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(nil) {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
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

/// 流式纯文本视图：基于非滚动 `UITextView`（iOS）/ `NSTextView`（macOS），新内容以
/// **增量追加**方式写入 `textStorage`，只让 CoreText 排布新增部分，避免长文本每次全量重排导致卡顿。
/// 用 `CADisplayLink` 做打字机式平滑揭示：网络到达多少字与显示多少字解耦，
/// 每帧追加少量字符（落后越多追加越快），把突发到达抹平为顺滑输出。
/// 流式期间不可选中，也避免文本选择手势与滚动争抢。
private struct StreamingTextView: View {
    let text: String
    var color: Color = .primary

    var body: some View {
        #if os(iOS)
        StreamingTextUIView(text: text, color: UIColor(color))
        #else
        StreamingTextUIView(text: text, color: NSColor(color))
        #endif
    }
}

#if os(iOS)
private struct StreamingTextUIView: UIViewRepresentable {
    let text: String
    var color: UIColor

    private var font: UIFont { .preferredFont(forTextStyle: .subheadline) }

    func makeCoordinator() -> Coordinator {
        Coordinator(font: font, color: color)
    }

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
        context.coordinator.attach(view)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.update(font: font, color: color, target: text)
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    /// 逐帧揭示文本（打字机）：`target` 是完整目标文本，`displayed` 是已显示部分。
    final class Coordinator: NSObject {
        private weak var view: UITextView?
        private var link: CADisplayLink?
        private var displayed = ""
        private var target = ""
        private var font: UIFont
        private var color: UIColor

        init(font: UIFont, color: UIColor) {
            self.font = font
            self.color = color
        }

        func attach(_ view: UITextView) {
            self.view = view
        }

        func update(font: UIFont, color: UIColor, target: String) {
            self.font = font
            self.color = color
            // 目标不是已显示内容的前缀（如重新生成）→ 重置。
            if !target.hasPrefix(displayed) {
                displayed = ""
                view?.text = ""
            }
            self.target = target
            guard let view else { return }
            if displayed.count >= target.count {
                stop()
                return
            }
            if link == nil {
                let link = CADisplayLink(target: self, selector: #selector(tick))
                link.add(to: .main, forMode: .common)
                self.link = link
            }
            view.invalidateIntrinsicContentSize()
        }

        func stop() {
            link?.invalidate()
            link = nil
        }

        @objc private func tick() {
            guard let view else { stop(); return }
            let remaining = target.count - displayed.count
            if remaining <= 0 { stop(); return }
            // 落后越多追加越快（几何追赶），平时每帧 1 字，避免暴冲。
            let step = max(1, remaining / 6)
            let newCount = min(displayed.count + step, target.count)
            let end = target.index(target.startIndex, offsetBy: newCount)
            let newText = String(target[..<end])
            let delta = String(newText.dropFirst(displayed.count))
            view.textStorage.append(NSAttributedString(string: delta, attributes: [
                .font: font,
                .foregroundColor: color,
            ]))
            displayed = newText
            view.invalidateIntrinsicContentSize()
            if displayed.count >= target.count { stop() }
        }

        deinit {
            link?.invalidate()
        }
    }
}
#else
private struct StreamingTextUIView: NSViewRepresentable {
    let text: String
    var color: NSColor

    private var font: NSFont { .preferredFont(forTextStyle: .subheadline) }

    func makeCoordinator() -> Coordinator {
        Coordinator(font: font, color: color)
    }

    func makeNSView(context: Context) -> NSTextView {
        let view = NSTextView()
        view.isEditable = false
        view.isSelectable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.font = font
        view.textColor = color
        view.isRichText = false
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = true
        context.coordinator.attach(view)
        return view
    }

    func updateNSView(_ view: NSTextView, context: Context) {
        context.coordinator.update(font: font, color: color, target: text)
    }

    static func dismantleNSView(_ nsView: NSTextView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        guard let layoutManager = nsView.layoutManager, let container = nsView.textContainer else { return nil }
        let width = proposal.width ?? nsView.bounds.width
        guard width > 0 else { return nil }
        container.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        return CGSize(width: width, height: ceil(used.height))
    }

    final class Coordinator: NSObject {
        private weak var view: NSTextView?
        private var link: CADisplayLink?
        private var displayed = ""
        private var target = ""
        private var font: NSFont
        private var color: NSColor

        init(font: NSFont, color: NSColor) {
            self.font = font
            self.color = color
        }

        func attach(_ view: NSTextView) {
            self.view = view
        }

        func update(font: NSFont, color: NSColor, target: String) {
            self.font = font
            self.color = color
            if !target.hasPrefix(displayed) {
                displayed = ""
                view?.textStorage?.setAttributedString(NSAttributedString(string: ""))
            }
            self.target = target
            guard let view else { return }
            if displayed.count >= target.count {
                stop()
                return
            }
            if link == nil {
                let link = view.displayLink(target: self, selector: #selector(tick))
                link.add(to: .main, forMode: .common)
                self.link = link
            }
            view.invalidateIntrinsicContentSize()
        }

        func stop() {
            link?.invalidate()
            link = nil
        }

        @objc private func tick() {
            guard let view else { stop(); return }
            let remaining = target.count - displayed.count
            if remaining <= 0 { stop(); return }
            let step = max(1, remaining / 6)
            let newCount = min(displayed.count + step, target.count)
            let end = target.index(target.startIndex, offsetBy: newCount)
            let newText = String(target[..<end])
            let delta = String(newText.dropFirst(displayed.count))
            view.textStorage?.append(NSAttributedString(string: delta, attributes: [
                .font: font,
                .foregroundColor: color,
            ]))
            displayed = newText
            view.invalidateIntrinsicContentSize()
            if displayed.count >= target.count { stop() }
        }

        deinit {
            link?.invalidate()
        }
    }
}
#endif