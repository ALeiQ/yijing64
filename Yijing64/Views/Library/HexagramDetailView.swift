import SwiftUI
import YijingCore

/// 单卦详情：卦画、卦名、卦辞、爻辞、白话占断、相关卦。
struct HexagramDetailView: View {
    let hexagram: Hexagram
    private let content: HexagramContent

    init(hexagram: Hexagram) {
        self.hexagram = hexagram
        self.content = HexagramData.content(for: hexagram)
    }

    var body: some View {
        List {
            headerSection
            aiSection
            judgementSection
            linesSection
            relatedSection(content: content)
        }
        .navigationTitle("第\(hexagram.kingWenNumber)卦 · \(hexagram.fullName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var aiSection: some View {
        Section {
            NavigationLink {
                AIInterpretationView(hexagram: hexagram)
            } label: {
                Label("AI 解卦", systemImage: "sparkles")
                    .font(.body.weight(.medium))
            }
        }
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    TrigramBadgeView(trigram: hexagram.upper)
                    Image(systemName: "arrow.down")
                        .foregroundColor(.secondary)
                    TrigramBadgeView(trigram: hexagram.lower)
                }
                .padding(.vertical, 8)

                HexagramDrawingView(lines: {
                    var lines: [LineType] = []
                    for i in 0..<6 {
                        lines.append(hexagram.lineIsYang(at: i) ? .youngYang : .youngYin)
                    }
                    return lines
                }())
                .padding(.vertical, 8)

                Text("\(hexagram.upper.nature)上\(hexagram.lower.nature)下")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(hexagram.palace.name)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.secondarySystemFill))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var judgementSection: some View {
        Section("卦辞") {
            Text(content.judgementText)
                .font(.body)
        }
    }

    private var linesSection: some View {
        Section("爻辞") {
            ForEach(0..<6, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text(hexagram.lineTitle(at: i))
                        .font(.subheadline.bold())
                        .foregroundColor(.accentColor)
                        .frame(width: 48, alignment: .leading)
                    Text(content.lineTexts[safe: i] ?? "")
                        .font(.body)
                }
                .padding(.vertical, 2)
            }
            if let extra = content.extraLine, !extra.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Text(hexagram.name == "乾" ? "用九" : "用六")
                        .font(.subheadline.bold())
                        .foregroundColor(.accentColor)
                        .frame(width: 48, alignment: .leading)
                    Text(extra)
                        .font(.body)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func relatedSection(content: HexagramContent) -> some View {
        Section("白话解读") {
            Text(content.divinationText)
                .font(.body)
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        HexagramDetailView(hexagram: HexagramData.find(byKingWenNumber: 1)!)
    }
}