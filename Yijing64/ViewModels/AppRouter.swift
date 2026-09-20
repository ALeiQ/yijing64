import SwiftUI

/// 跨 Tab 页导航：供「去设置」等跳转使用。
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Int {
        case manual = 0
        case divination = 1
        case history = 2
        case library = 3
        case about = 4
    }

    @Published var selectedTab: Tab = .manual

    init() {}

    /// 切换到「关于」设置页。
    func showSettings() {
        selectedTab = .about
    }
}