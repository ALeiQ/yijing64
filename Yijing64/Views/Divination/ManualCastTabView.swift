import SwiftUI
import YijingCore

/// 线下排卦：手动录入六爻（点击爻位切换），实时推断本卦并分析。
struct ManualCastTabView: View {
    /// 全局动爻勾选：勾选时点击爻位可设老阴/老阳，未勾选仅在少阴/少阳间切换。
    @State private var allowMoving = false
    @State private var lines: [LineType] = Array(repeating: .youngYang, count: 6)

    private var result: CastResult {
        CastResult(method: .manual, originalLines: lines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    lineEditor
                    CastResultView(result: result)
                }
                .padding()
            }
            .navigationTitle("线下排卦")
        }
    }

    private var lineEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("逐爻设置")
                .font(.headline)

            Button {
                allowMoving.toggle()
                if !allowMoving { downgradeMovingLines() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: allowMoving ? "checkmark.square.fill" : "square")
                        .foregroundColor(allowMoving ? .accentColor : .secondary)
                    Text("可设动爻")
                        .foregroundColor(.primary)
                }
                .font(.subheadline)
            }
            .buttonStyle(.plain)

            cycleHint

            ForEach(Array(lines.enumerated().reversed()), id: \.offset) { index, line in
                lineButton(index: index)
            }

            HStack {
                Button("重置") {
                    lines = Array(repeating: .youngYang, count: 6)
                }
                .font(.subheadline)
                Spacer()
                let movingCount = lines.filter(\.isMoving).count
                Text("共 \(movingCount) 个动爻")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondarySystemBackground)
        }
    }

    @ViewBuilder
    private var cycleHint: some View {
        if allowMoving {
            HStack(spacing: 8) {
                legend(mark: "─", markColor: .primary, text: "少阳")
                legend(mark: "─ ─", markColor: .primary, text: "少阴")
                legend(mark: "○", markColor: .red, text: "老阳(动)")
                legend(mark: "×", markColor: .red, text: "老阴(动)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 4)
        } else {
            HStack(spacing: 8) {
                legend(mark: "─", markColor: .primary, text: "少阳")
                legend(mark: "─ ─", markColor: .primary, text: "少阴")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 4)
        }
    }

    private func legend(mark: String, markColor: Color, text: String) -> some View {
        HStack(spacing: 3) {
            Text(mark)
                .font(.caption.bold())
                .foregroundColor(markColor)
            Text(text)
        }
    }

    private func lineButton(index: Int) -> some View {
        Button {
            toggleLine(at: index)
        } label: {
            HStack(spacing: 12) {
                Text(result.original.lineTitle(at: index))
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .frame(width: 40, alignment: .leading)
                HexagramLineView(line: lines[index])
                Spacer()
                Text(lines[index].name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if lines[index].isMoving {
                    Circle()
                        .fill(Color.red.opacity(0.9))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Text(lines[index].isYang ? "○" : "×")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.systemBackground)
            }
        }
        .buttonStyle(.plain)
    }

    /// 点击爻位的切换逻辑：有动爻时四态循环，否则仅在少阴/少阳间切换。
    private func toggleLine(at index: Int) {
        if allowMoving {
            lines[index] = nextType(current: lines[index])
        } else {
            lines[index] = lines[index].isYang ? .youngYin : .youngYang
        }
    }

    /// 四态循环：少阴 → 少阳 → 老阴 → 老阳 → 少阴
    private func nextType(current: LineType) -> LineType {
        switch current {
        case .youngYin: return .youngYang
        case .youngYang: return .oldYin
        case .oldYin: return .oldYang
        case .oldYang: return .youngYin
        }
    }

    /// 关闭动爻时将老阳/老阴降级为同阴阳的静爻。
    private func downgradeMovingLines() {
        lines = lines.map { line in
            if line.isMoving {
                return line.isYang ? .youngYang : .youngYin
            }
            return line
        }
    }
}

#Preview {
    ManualCastTabView()
}