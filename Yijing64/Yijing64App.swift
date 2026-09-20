import SwiftUI

@main
struct Yijing64App: App {
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(router)
        }
    }
}