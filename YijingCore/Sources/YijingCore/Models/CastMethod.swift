import Foundation

/// 起卦方式。
public enum CastMethod: String, CaseIterable, Sendable, Hashable, Identifiable {
    case manual = "线下·手动排卦"
    case threeCoins = "三枚铜钱"
    case plumTime = "梅花·时间起卦"
    case plumNumbers = "梅花·报数起卦"
    case plumRandom = "梅花·随机起卦"

    public var id: Self { self }

    public var subtitle: String {
        switch self {
        case .manual: return "点击设置六爻 · 录入线下摇卦结果"
        case .threeCoins: return "六爻摇钱法 · 抛掷六次"
        case .plumTime: return "以时间取上下卦与动爻"
        case .plumNumbers: return "以两个数字取卦"
        case .plumRandom: return "梅花易数 · 随机取卦"
        }
    }
}