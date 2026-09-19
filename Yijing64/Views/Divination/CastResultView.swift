import SwiftUI
import YijingCore

/// 起卦结果展示。
struct CastResultView: View {
    let result: CastResult

    var body: some View {
        VStack(spacing: 16) {
            heading
            pairComparison

            if let bodyUse = result.bodyUse {
                bodyUseRow(bodyUse)
            }

            if !result.movingLineTitles.isEmpty {
                movingLinesRow
            }

            mutualRow
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        }
    }

    private var heading: some View {
        VStack(spacing: 4) {
            Text(result.method.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("得卦 · \(result.original.fullName)（\(result.original.kingWenNumber)）")
                .font(.title3.bold())
            if !result.movingLineTitles.isEmpty {
                movingLegend
            }
        }
    }

    private var movingLegend: some View {
        HStack(spacing: 12) {
            legendItem(mark: "○", text: "阳变阴")
            legendItem(mark: "×", text: "阴变阳")
        }
    }

    private func legendItem(mark: String, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red.opacity(0.9))
                .frame(width: 12, height: 12)
                .overlay(
                    Text(mark)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                )
            Text(text)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private var pairComparison: some View {
        HStack(alignment: .top, spacing: 24) {
            hexagramLink(result.original, lines: result.originalLines, label: "本卦")
            hexagramLink(result.changed, lines: changedLines, label: "变卦")
        }
        .frame(maxWidth: .infinity)
    }

    private func hexagramLink(_ hexagram: Hexagram, lines: [LineType], label: String) -> some View {
        NavigationLink {
            HexagramDetailView(hexagram: hexagram)
        } label: {
            VStack(spacing: 8) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HexagramDrawingView(lines: lines)
                Text(hexagram.fullName)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text("\(hexagram.upper.symbol)\(hexagram.lower.symbol) · 查看卦辞")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var changedLines: [LineType] {
        result.originalLines.map { $0.changed }
    }

    private var movingLinesRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("动爻")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(result.movingLineTitles.joined(separator: "、"))
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.2))
        }
    }

    private var mutualRow: some View {
        NavigationLink {
            HexagramDetailView(hexagram: result.mutual)
        } label: {
            HStack {
                Text("互卦")
                Spacer()
                Text("\(result.mutual.fullName)（\(result.mutual.kingWenNumber)）")
                    .bold()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            .foregroundColor(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            }
        }
        .buttonStyle(.plain)
    }

    private func bodyUseRow(_ bodyUse: (body: Trigram, use: Trigram)) -> some View {
        HStack {
            VStack(spacing: 4) {
                Text("体卦")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(bodyUse.body.symbol)
                    .font(.system(size: 32))
                Text(bodyUse.body.name)
                    .font(.subheadline.bold())
            }
            Spacer()
            Text("用")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            VStack(spacing: 4) {
                Text("用卦")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(bodyUse.use.symbol)
                    .font(.system(size: 32))
                Text(bodyUse.use.name)
                    .font(.subheadline.bold())
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            CastResultView(
                result: CoinCaster.cast {
                    Bool.random()
                }
            )
        }
        .padding()
    }
}