import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension View {
    /// iOS 上使用内联导航标题；macOS 无此修饰符。
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// 关闭自动首字母大写。`textInputAutocapitalization` 仅在 iOS 可用。
    @ViewBuilder
    func noTextAutocapitalization() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    /// iOS 弹出数字键盘；macOS 无对应概念。
    @ViewBuilder
    func numberPadKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }

    /// 滚动时收起键盘：iOS 16+ 支持，其他平台忽略。
    @ViewBuilder
    func dismissKeyboardOnScroll() -> some View {
        #if os(iOS)
        scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}

/// 跨平台语义色：以 iOS 系统色为基准，映射到 AppKit 的近似色。
extension Color {
    static var systemBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var secondarySystemBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var secondarySystemFill: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemFill)
        #else
        Color(nsColor: .quaternaryLabelColor)
        #endif
    }

    static var quaternarySystemFill: Color {
        #if os(iOS)
        Color(uiColor: .quaternarySystemFill)
        #else
        Color(nsColor: .quaternaryLabelColor)
        #endif
    }

    static var separatorLine: Color {
        #if os(iOS)
        Color(uiColor: .separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }
}

/// 跨平台工具栏右侧位置：iOS 用 `.topBarTrailing`，macOS 用 `.primaryAction`。
extension ToolbarItemPlacement {
    static var trailingAction: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}

/// 收起当前输入焦点。iOS 通过 UIKit 发送 resign 动作，macOS 让窗口放弃第一响应者。
func dismissKeyboard() {
    #if os(iOS)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #elseif os(macOS)
    NSApp.keyWindow?.makeFirstResponder(nil)
    #endif
}
