import SwiftUI
import YijingCore

struct DivinationTabView: View {
    @StateObject private var viewModel = CastingViewModel()

    private static let bottomAnchorID = "divination-bottom"

    private enum MethodField: Hashable {
        case num1
        case num2
    }
    @FocusState private var focusedField: MethodField?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        regulationPicker
                        numberInputIfNeeded
                        castButton

                        switch viewModel.state {
                        case .idle:
                            idleHint
                        case .casting:
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("起卦中…")
                            }
                            .frame(maxWidth: .infinity)
                        case .done(let result):
                            CastResultView(result: result)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchorID)
                    }
                    .padding()
                }
                .onChange(of: viewModel.state) { _, newState in
                    // 起卦完成后自动滑到底端展示结果。
                    guard case .done = newState else { return }
                    scrollToBottom(proxy)
                }
            }
            .navigationTitle("起卦")
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(nil) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private var regulationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("起卦方式")
                .font(.headline)
            ForEach(CastMethod.castableMethods) { m in
                Button {
                    viewModel.method = m
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.rawValue)
                                .foregroundColor(.primary)
                            Text(m.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if viewModel.method == m {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var numberInputIfNeeded: some View {
        Group {
            if viewModel.method == .plumNumbers {
                HStack(spacing: 12) {
                    TextField("数一", text: $viewModel.num1)
                        .numberPadKeyboard()
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .num1)
                    TextField("数二", text: $viewModel.num2)
                        .numberPadKeyboard()
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .num2)
                }
            }
        }
    }

    private var castButton: some View {
        Button {
            focusedField = nil
            viewModel.cast()
        } label: {
            Text(viewModel.method == .threeCoins ? "掷铜钱" : "起卦")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var idleHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("选定方式后点“起卦”")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    DivinationTabView()
}