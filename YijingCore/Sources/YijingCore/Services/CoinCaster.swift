import Foundation

/// 三枚铜钱起卦（六爻）。
///
/// 规则：正面得 3，反面得 2，三枚合计共 6 / 7 / 8 / 9 四值；
/// 6 为老阴、7 为少阳、8 为少阴、9 为老阳，其中老阴 / 老阳为动爻。
public enum CoinCaster {
    /// 一次抛掷（返回正面数 0...3）。
    public typealias Throw = () -> Bool

    /// 由三枚铜钱（true=正面）推断爻。
    public static func lineType(_ coin1: Bool, _ coin2: Bool, _ coin3: Bool) -> LineType {
        let heads = [coin1, coin2, coin3].filter { $0 }.count
        switch heads {
        case 0: return .oldYin    // 3 反 -> 6
        case 1: return .youngYang // 2 反 1 正 -> 7（背面多）
        case 2: return .youngYin  // 1 反 2 正 -> 8（正面多）
        default: return .oldYang  // 3 正 -> 9
        }
    }

    /// 连抛 6 次，自下而上生成一卦。
    public static func cast(throwCoin: Throw = { Bool.random() }) -> CastResult {
        var lines: [LineType] = []
        for _ in 0..<6 {
            lines.append(lineType(throwCoin(), throwCoin(), throwCoin()))
        }
        return CastResult(method: .threeCoins, originalLines: lines)
    }

    /// 生成单次结果（含爻辞展示用名称）。
    public static func lineSymbol(_ line: LineType) -> String {
        switch line {
        case .oldYin: return "老阴 ✕"
        case .youngYang: return "少阳 ─"
        case .youngYin: return "少阴 ─ ─"
        case .oldYang: return "老阳 ○"
        }
    }
}