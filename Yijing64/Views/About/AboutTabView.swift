import SwiftUI

struct AboutTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("易经六十四卦") {
                    LabeledContent("版本", value: "1.0")
                    LabeledContent("起卦方式", value: "三枚铜钱 · 梅花易数")
                    LabeledContent("卦库", value: "文王卦序 · 八宫")
                }
                Section("说明") {
                    Text("本应用以《周易》六十四卦为框架，提供起卦占卜与卦辞查询。内容仍在补充中。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("关于")
        }
    }
}

#Preview {
    AboutTabView()
}