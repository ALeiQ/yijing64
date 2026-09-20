import SwiftUI
import YijingCore

/// 卦库：按八宫分组浏览全部六十四卦，支持关键词搜索。
struct LibraryTabView: View {
    private let palaces: [Palace] = [
        .qian, .dui, .li, .zhen, .xun, .kan, .gen, .kun,
    ]
    @State private var query = ""

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: [Hexagram] {
        HexagramSearch.search(query: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    searchResultSection
                } else {
                    palaceSections
                }
            }
            .navigationTitle("六十四卦")
            .searchable(text: $query, prompt: "卦名、序数、卦辞、白话…")
        }
    }

    private var palaceSections: some View {
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

    private var searchResultSection: some View {
        Group {
            if searchResults.isEmpty {
                Section("搜索结果") {
                    Text("未找到相关卦")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            } else {
                ForEach(palaces, id: \.self) { palace in
                    let items = searchResults.filter { $0.palace == palace }
                    if !items.isEmpty {
                        Section(palace.name) {
                            ForEach(items, id: \.kingWenNumber) { hexagram in
                                NavigationLink {
                                    HexagramDetailView(hexagram: hexagram)
                                } label: {
                                    HexagramRow(hexagram: hexagram, query: query)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HexagramRow: View {
    let hexagram: Hexagram
    var query: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Text(hexagram.guaImage)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                highlight("\(hexagram.kingWenNumber). \(hexagram.fullName)")
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

    @ViewBuilder
    private func highlight(_ text: String) -> some View {
        if !query.isEmpty, let range = HexagramSearch.matchRange(in: text, query: query) {
            Text(text[..<range.lowerBound])
            + Text(text[range])
                .foregroundColor(.accentColor)
                .bold()
            + Text(text[range.upperBound...])
        } else {
            Text(text)
        }
    }
}

#Preview {
    LibraryTabView()
}