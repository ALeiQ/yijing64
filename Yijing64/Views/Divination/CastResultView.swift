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
        }
    }

    private var pairComparison: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 8) {
                Text("本卦")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HexagramDrawingView(lines: result.originalLines)
                Text(result.original.fullName)
                    .font(.subheadline.bold())
                Text("\(result.original.upper.symbol)\(result.original.lower.symbol)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            VStack(spacing: 8) {
                Text("变卦")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HexagramDrawingView(lines: changedLines)
                Text(result.changed.fullName)
                    .font(.subheadline.bold())
                Text("\(result.changed.upper.symbol)\(result.changed.lower.symbol)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
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
        HStack {
            Text("互卦")
            Spacer()
            Text("\(result.mutual.fullName)（\(result.mutual.kingWenNumber)）")
                .bold()
        }
        .font(.subheadline)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        }
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
    ScrollView {
        CastResultView(
            result: CoinCaster.cast {
                Bool.random()
            }
        )
    }
    .padding()
}