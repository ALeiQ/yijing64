import SwiftUI
import YijingCore

/// 卦库：按八宫分组浏览全部六十四卦。
struct LibraryTabView: View {
    private let palaces: [Palace] = [
        .qian, .dui, .li, .zhen, .xun, .kan, .gen, .kun,
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(palaces, id: \.self) { palace in
                    Section(palace.name) {
                        ForEach(HexagramData.all().filter { $0.palace == palace }, id: \.kingWenNumber) { hexagram in
                            NavigationLink {
                                HexagramDetailView(hexagram: hexagram)
                            } label: {
                                HexagramRow(hexagram: hexagram)
                            }
                        }
                    }
                }
            }
            .navigationTitle("六十四卦")
        }
    }
}

private struct HexagramRow: View {
    let hexagram: Hexagram

    var body: some View {
        HStack(spacing: 12) {
            Text(hexagram.guaImage)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(hexagram.kingWenNumber). \(hexagram.fullName)")
                    .font(.body)
                Text("\(hexagram.upper.nature)上\(hexagram.lower.nature)下 · \(hexagram.name)卦")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(hexagram.upper.symbol)\(hexagram.lower.symbol)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    LibraryTabView()
}