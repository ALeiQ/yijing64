import Foundation

/// 八卦之体（经卦）。
public enum TrigramKind: Int, CaseIterable, Sendable, Hashable {
    case kun  = 0b000 // 坤 ☷
    case zhen = 0b001 // 震 ☳（初爻为阳，一阳在下）
    case kan  = 0b010 // 坎 ☵（中爻为阳）
    case dui  = 0b011 // 兑 ☱（下二爻为阳，一阴在上）
    case gen  = 0b100 // 艮 ☶（上爻为阳）
    case li   = 0b101 // 离 ☲（上下为阳，中虚）
    case xun  = 0b110 // 巽 ☴（下爻为阴，二阳在上）
    case qian = 0b111 // 乾 ☰
}

/// 经卦（三爻），爻位自下而上：最低位(line0)=下爻。
public struct Trigram: Sendable, Hashable {
    public let kind: TrigramKind

    public init(_ kind: TrigramKind) {
        self.kind = kind
    }

    /// 先天卦数（乾一 兑二 离三 震四 巽五 坎六 艮七 坤八）映射。
    public init?(fuxiNumber: Int) {
        switch fuxiNumber {
        case 1: self.init(.qian)
        case 2: self.init(.dui)
        case 3: self.init(.li)
        case 4: self.init(.zhen)
        case 5: self.init(.xun)
        case 6: self.init(.kan)
        case 7: self.init(.gen)
        case 8: self.init(.kun)
        default: return nil
        }
    }

    public var name: String {
        switch kind {
        case .qian: return "乾"
        case .dui:  return "兑"
        case .li:   return "离"
        case .zhen: return "震"
        case .xun:  return "巽"
        case .kan:  return "坎"
        case .gen:  return "艮"
        case .kun:  return "坤"
        }
    }

    /// 自然象征（天泽火雷风水山地）。
    public var nature: String {
        switch kind {
        case .qian: return "天"
        case .dui:  return "泽"
        case .li:   return "火"
        case .zhen: return "雷"
        case .xun:  return "风"
        case .kan:  return "水"
        case .gen:  return "山"
        case .kun:  return "地"
        }
    }

    public var symbol: String {
        switch kind {
        case .qian: return "☰"
        case .dui:  return "☱"
        case .li:   return "☲"
        case .zhen: return "☳"
        case .xun:  return "☴"
        case .kan:  return "☵"
        case .gen:  return "☶"
        case .kun:  return "☷"
        }
    }

    /// 五行。
    public var element: String {
        switch kind {
        case .qian, .dui: return "金"
        case .li:         return "火"
        case .zhen, .xun: return "木"
        case .kan:        return "水"
        case .gen, .kun:  return "土"
        }
    }

    /// 三爻阴阳，自下而上。
    public func lineIsYang(at index: Int) -> Bool {
        ((kind.rawValue >> index) & 1) == 1
    }
}
