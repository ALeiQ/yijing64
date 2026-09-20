import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ManualCastTabView()
                .tabItem { Label("线下排卦", systemImage: "hand.tap.fill") }
                .tag(AppRouter.Tab.manual)

            DivinationTabView()
                .tabItem { Label("起卦", systemImage: "dice.fill") }
                .tag(AppRouter.Tab.divination)

            HistoryTabView()
                .tabItem { Label("记录", systemImage: "clock.arrow.circlepath") }
                .tag(AppRouter.Tab.history)

            LibraryTabView()
                .tabItem { Label("卦库", systemImage: "book.fill") }
                .tag(AppRouter.Tab.library)

            AboutTabView()
                .tabItem { Label("关于", systemImage: "info.circle") }
                .tag(AppRouter.Tab.about)
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppRouter())
}