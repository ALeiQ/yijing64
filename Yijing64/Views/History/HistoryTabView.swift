import SwiftUI
import YijingCore

/// 起卦记录：列出历史起卦，点击回放当时的 AI 解卦会话。
struct HistoryTabView: View {
    @State private var records: [CastRecord] = []
    @State private var showingClearConfirm = false

    private let store = CastHistoryStore()

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyState
                } else {
                    recordList
                }
            }
            .navigationTitle("起卦记录")
            .toolbar {
                if !records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .confirmationDialog("清空全部记录？", isPresented: $showingClearConfirm, titleVisibility: .visible) {
                            Button("清空", role: .destructive) {
                                store.clear()
                                reload()
                            }
                            Button("取消", role: .cancel) {}
                        }
                    }
                }
            }
        }
        .onAppear(perform: reload)
    }

    private var recordList: some View {
        List {
            ForEach(records) { record in
                NavigationLink {
                    AIInterpretationView(record: record)
                } label: {
                    HistoryRow(record: record)
                }
            }
            .onDelete { indexSet in
                let deleting = indexSet.map { records[$0] }
                for r in deleting { store.delete(id: r.id) }
                reload()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无起卦记录")
                .foregroundColor(.secondary)
            Text("起卦后点击「AI 解卦」即可保存到此。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reload() {
        records = store.load()
    }
}

private struct HistoryRow: View {
    let record: CastRecord

    var body: some View {
        let result = record.result
        HStack(spacing: 12) {
            Text(result.original.guaImage)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(result.original.kingWenNumber). \(result.original.fullName)")
                    .font(.body)
                HStack(spacing: 6) {
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    Text("·")
                    Text(record.method.rawValue)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                if let usage = record.aiUsage, usage.totalTokens > 0 {
                    HStack(spacing: 6) {
                        Text(costText(usage))
                        Text("·")
                        Text("\(tokenText(usage.totalTokens)) tokens")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
            if !record.aiAnswer.isEmpty {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("已有 AI 解卦")
            }
        }
        .padding(.vertical, 2)
    }

    private func costText(_ usage: TokenUsage) -> String {
        guard let cost = usage.costCNY else { return "费用—" }
        return String(format: "≈¥%.4f", cost)
    }

    private func tokenText(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000) : "\(count)"
    }
}

#Preview {
    HistoryTabView()
}