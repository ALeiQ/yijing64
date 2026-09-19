import Foundation

/// 八宫（京房八宫卦序）。
public enum Palace: Int, CaseIterable, Sendable, Hashable {
    case qian = 7
    case dui  = 3
    case li   = 5
    case zhen = 1
    case xun  = 6
    case kan  = 2
    case gen  = 4
    case kun  = 0

    public var name: String {
        switch self {
        case .qian: return "乾宫"
        case .dui:  return "兑宫"
        case .li:   return "离宫"
        case .zhen: return "震宫"
        case .xun:  return "巽宫"
        case .kan:  return "坎宫"
        case .gen:  return "艮宫"
        case .kun:  return "坤宫"
        }
    }

    /// 该宫对应的经卦。
    public var trigram: Trigram {
        Trigram(TrigramKind(rawValue: rawValue)!)
    }

    public var symbol: String { trigram.symbol }

    /// 宫之五行。
    public var element: String { trigram.element }

    public var symbolAndElement: String { "\(symbol) \(name)属\(element)" }
}
