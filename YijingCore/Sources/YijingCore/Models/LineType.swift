import Foundation

/// 六爻自下而上的爻的类型。
///
/// 数值采用传统"五行策数"：6 老阴、7 少阳、8 少阴、9 老阳。
public enum LineType: Int, CaseIterable, Sendable, Hashable {
    case oldYin   = 6  // 老阴 ✕（动爻）
    case youngYang = 7 // 少阳 ─（静爻）
    case youngYin  = 8 // 少阴 ─ ─（静爻）
    case oldYang   = 9 // 老阳 ○（动爻）

    /// 是否为阳爻。
    public var isYang: Bool {
        self == .youngYang || self == .oldYang
    }

    /// 是否为动爻（老阴 / 老阳）。
    public var isMoving: Bool {
        self == .oldYin || self == .oldYang
    }

    /// 动爻变化后的爻（老阴→少阳，老阳→少阴；静爻保持原样）。
    public var changed: LineType {
        switch self {
        case .oldYin:   return .youngYang
        case .oldYang:  return .youngYin
        case .youngYin: return .youngYin
        case .youngYang:return .youngYang
        }
    }

    /// 变化后的阴阳位（true 为阳）。
    public var changedYang: Bool {
        changed.isYang
    }

    public var name: String {
        switch self {
        case .oldYin:   return "老阴"
        case .youngYang:return "少阳"
        case .youngYin: return "少阴"
        case .oldYang:  return "老阳"
        }
    }

    /// 爻名（如 老阳→"九"）。
    public var lineName: String {
        isYang ? "九" : "六"
    }
}
