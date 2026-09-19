import Foundation

/// 六爻卦（别卦）。`lines` 为低 6 位：line3..line5 为上卦，line0..line2 为下卦。
public struct Hexagram: Sendable, Hashable {
    public let kingWenNumber: Int
    public let name: String
    public let fullName: String
    public let lines: UInt8
    public let palace: Palace

    public init(kingWenNumber: Int, name: String, fullName: String, lines: UInt8, palace: Palace) {
        self.kingWenNumber = kingWenNumber
        self.name = name
        self.fullName = fullName
        self.lines = lines & 0b111111
        self.palace = palace
    }

    /// 上卦。
    public var upper: Trigram {
        Trigram(TrigramKind(rawValue: Int((lines >> 3) & 0b111))!)
    }

    /// 下卦。
    public var lower: Trigram {
        Trigram(TrigramKind(rawValue: Int(lines & 0b111))!)
    }

    public var guaImage: String { upper.symbol + lower.symbol }

    public func lineIsYang(at index: Int) -> Bool {
        ((lines >> index) & 1) == 1
    }

    /// 某爻的爻名，如"初九""六二"。
    public func lineTitle(at index: Int) -> String {
        let positions = ["初", "二", "三", "四", "五", "上"]
        let yang = lineIsYang(at: index)
        let yao = yang ? "九" : "六"
        if index == 0 { return "初\(yao)" }
        if index == 5 { return "上\(yao)" }
        return yao + positions[index]
    }

    /// 错卦（对宫阴阳全变 → 之后的卦，用于 错卦）。
    public func opposite() -> Hexagram {
        HexagramData.hexagram(withLines: (~lines) & 0b111111)!
    }

    /// 综卦（倒置 / 反象）。
    public func inverse() -> Hexagram {
        var reversed: UInt8 = 0
        for i in 0..<6 where lineIsYang(at: i) {
            reversed |= 1 << (5 - i)
        }
        return HexagramData.hexagram(withLines: reversed)!
    }

    /// 互卦：取二至五爻，二三四爻为下卦，三四五爻为上卦。
    public func mutual() -> Hexagram {
        HexagramData.hexagram(withLines: Hexagram.mutualLines(from: lines))!
    }

    public static func mutualLines(from lines: UInt8) -> UInt8 {
        var result: UInt8 = 0
        // 二三四爻 -> 下卦
        for i in 0..<3 {
            let y = (lines >> (i + 1)) & 1
            if y == 1 { result |= 1 << i }
        }
        // 三四五爻 -> 上卦
        for i in 0..<3 {
            let y = (lines >> (i + 2)) & 1
            if y == 1 { result |= 1 << (i + 3) }
        }
        return result
    }
}
