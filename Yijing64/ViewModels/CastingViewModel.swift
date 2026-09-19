import Foundation
import YijingCore

@MainActor
final class CastingViewModel: ObservableObject {
    enum CastState {
        case idle
        case casting
        case done(CastResult)
    }

    @Published var method: CastMethod = .threeCoins
    @Published var state: CastState = .idle
    @Published var num1 = ""
    @Published var num2 = ""

    /// 摇钱过程中逐爻揭示的反馈（步进动画）。
    @Published var throwing = false

    func cast() {
        switch method {
        case .threeCoins:
            state = .casting
            throwing = true
            let result = CoinCaster.cast()
            finish(with: result)
        case .plumTime:
            let result = PlumBlossomCaster.castByTime(
                yearBranchOrder: Self.currentYearBranchOrder,
                month: Self.lunarMonth,
                day: Self.lunarDay,
                hourBranchOrder: Self.currentHourBranchOrder
            )
            finish(with: result)
        case .plumNumbers:
            let a = Int(num1) ?? 1
            let b = Int(num2) ?? 2
            let result = PlumBlossomCaster.castByNumbers(
                a, b,
                hourBranchOrder: Self.currentHourBranchOrder
            )
            finish(with: result)
        case .plumRandom:
            var gen = SystemRandomNumberGenerator()
            let result = PlumBlossomCaster.castRandom { range in
                Int.random(in: range, using: &gen)
            }
            finish(with: result)
        }
    }

    private func finish(with result: CastResult) {
        state = .done(result)
        throwing = false
    }

    // MARK: - 时间起卦用到的农历/干支换算（近似：用公历日期代替，供占位）

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .chinese)
        cal.locale = Locale(identifier: "zh_CN")
        return cal
    }

    private static var currentYearBranchOrder: Int {
        let year = Calendar.current.component(.year, from: Date())
        // 生肖地支序：2024 甲辰（辰=5）；地支序 = (year - 4) % 12 + 1
        let order = (year - 4) % 12
        return order <= 0 ? order + 12 : order
    }

    private static var lunarMonth: Int {
        calendar.component(.month, from: Date())
    }

    private static var lunarDay: Int {
        calendar.component(.day, from: Date())
    }

    private static var currentHourBranchOrder: Int {
        let hour = Calendar.current.component(.hour, from: Date())
        // 子(23-1) 丑(1-3) ... 亥(21-23)
        let branches = [1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 1]
        guard hour >= 0, hour < 24 else { return 1 }
        return branches[hour]
    }
}