import Foundation

/// 梅花易数起卦。
///
/// 上下卦皆按先天卦数「乾一兑二离三震四巽五坎六艮七坤八」取余，动爻取总数除以 6 之余。
///
/// 时间起卦：上卦 = (年支序数 + 月 + 日) % 8；下卦、动爻加入时辰。
public enum PlumBlossomCaster {

    /// 干支配数（地支序数：子=1 丑=2 ... 亥=12，年支序也同此表）。
    public static func branchOrder(_ name: String) -> Int {
        switch name {
        case "子": return 1
        case "丑": return 2
        case "寅": return 3
        case "卯": return 4
        case "辰": return 5
        case "巳": return 6
        case "午": return 7
        case "未": return 8
        case "申": return 9
        case "酉": return 10
        case "戌": return 11
        case "亥": return 12
        default: return 0
        }
    }

    /// 先天数（1-8）→ 卦。
    public static func trigram(fuxiNumber: Int) -> TrigramKind? {
        switch fuxiNumber {
        case 1: return .qian
        case 2: return .dui
        case 3: return .li
        case 4: return .zhen
        case 5: return .xun
        case 6: return .kan
        case 7: return .gen
        case 8: return .kun
        default: return nil
        }
    }

    /// 余数与先天数互转（0 -> 8）。
    public static func fuxiNumber(fromRemainder remainder: Int) -> Int {
        let r = positiveRemainder(remainder, mod: 8)
        return r == 0 ? 8 : r
    }

    /// 动爻（0-5，0 = 初爻）。
    public static func movingLine(fromRemainder remainder: Int) -> Int {
        let r = positiveRemainder(remainder, mod: 6)
        return r == 0 ? 5 : r - 1
    }

    private static func positiveRemainder(_ value: Int, mod: Int) -> Int {
        let r = value % mod
        return r >= 0 ? r : r + mod
    }

    // MARK: 时间起卦

    /// 时间起卦（农历年支序 + 月 + 日，另加时辰支序）。
    public static func castByTime(yearBranchOrder: Int, month: Int, day: Int, hourBranchOrder: Int) -> CastResult {
        let base = yearBranchOrder + month + day

        let upperNum = fuxiNumber(fromRemainder: base)
        let upper = trigram(fuxiNumber: upperNum)?.rawValue ?? 0

        let total = base + hourBranchOrder
        let lowerNum = fuxiNumber(fromRemainder: total)
        let lower = trigram(fuxiNumber: lowerNum)?.rawValue ?? 0

        let moving = movingLine(fromRemainder: total)

        let bits: UInt8 = (UInt8(upper) << 3) | UInt8(lower)
        guard let original = HexagramData.hexagram(withLines: bits) else {
            return CastResult(method: .plumTime, originalLines: [.youngYang, .youngYang, .youngYang, .youngYang, .youngYang, .youngYang])
        }

        // 由动爻点爻（静爻照旧，动爻翻转）。
        let lineSeq = Self.sixLines(of: original, moving: moving)
        return CastResult(method: .plumTime, originalLines: lineSeq)
    }

    // MARK: 报数起卦

    /// 报数起卦：两数分别取上下卦；动爻取 (数一 + 数二 + 时辰支序) % 6。
    public static func castByNumbers(_ num1: Int, _ num2: Int, hourBranchOrder: Int = 0) -> CastResult {
        let upperNum = fuxiNumber(fromRemainder: num1)
        let lowerNum = fuxiNumber(fromRemainder: num2)
        let moving = movingLine(fromRemainder: num1 + num2 + hourBranchOrder)

        let upper = trigram(fuxiNumber: upperNum)?.rawValue ?? 0
        let lower = trigram(fuxiNumber: lowerNum)?.rawValue ?? 0

        let bits: UInt8 = (UInt8(upper) << 3) | UInt8(lower)
        guard let original = HexagramData.hexagram(withLines: bits) else {
            return CastResult(method: .plumNumbers, originalLines: [.youngYang, .youngYang, .youngYang, .youngYang, .youngYang, .youngYang])
        }

        let lineSeq = Self.sixLines(of: original, moving: moving)
        return CastResult(method: .plumNumbers, originalLines: lineSeq)
    }

    // MARK: 随机起卦

    /// 随机起卦。
    public static func castRandom(randomInt: (_ range: Range<Int>) -> Int) -> CastResult {
        let upperNum = (randomInt(1..<9))
        let lowerNum = (randomInt(1..<9))
        let moving = (randomInt(0..<6))

        let upper = trigram(fuxiNumber: upperNum)?.rawValue ?? 0
        let lower = trigram(fuxiNumber: lowerNum)?.rawValue ?? 0
        let bits: UInt8 = (UInt8(upper) << 3) | UInt8(lower)
        guard let original = HexagramData.hexagram(withLines: bits) else {
            return CastResult(method: .plumRandom, originalLines: [.youngYang, .youngYang, .youngYang, .youngYang, .youngYang, .youngYang])
        }
        let lineSeq = Self.sixLines(of: original, moving: moving)
        return CastResult(method: .plumRandom, originalLines: lineSeq)
    }

    /// 依主卦与动爻生成六爻序列（动爻为老，其余为少；性别翻转一致）。
    private static func sixLines(of hexagram: Hexagram, moving: Int) -> [LineType] {
        (0..<6).map { i in
            let yang = hexagram.lineIsYang(at: i)
            if i == moving {
                return yang ? .oldYang : .oldYin
            }
            return yang ? .youngYang : .youngYin
        }
    }
}