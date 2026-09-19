import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ManualCastTabView()
                .tabItem { Label("线下排卦", systemImage: "hand.tap.fill") }

            DivinationTabView()
                .tabItem { Label("起卦", systemImage: "dice.fill") }

            LibraryTabView()
                .tabItem { Label("卦库", systemImage: "book.fill") }

            AboutTabView()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
    }
}

#Preview {
    RootTabView()
}