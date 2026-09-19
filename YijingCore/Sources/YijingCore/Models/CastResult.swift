import Foundation

/// 起卦结果（本卦 / 变卦 / 互卦，均由本卦六爻推导）。
public struct CastResult: Sendable, Equatable {
    public let method: CastMethod
    public let originalLines: [LineType]
    public let original: Hexagram
    public let changed: Hexagram
    public let mutual: Hexagram

    public init(method: CastMethod, originalLines: [LineType]) {
        self.method = method
        self.originalLines = originalLines

        var originalBits: UInt8 = 0
        for (i, line) in originalLines.enumerated() where line.isYang {
            originalBits |= 1 << i
        }
        self.original = HexagramData.hexagram(withLines: originalBits)!

        var changedBits = originalBits
        for (i, line) in originalLines.enumerated() where line.isMoving {
            changedBits ^= 1 << i
        }
        self.changed = HexagramData.hexagram(withLines: changedBits)!

        self.mutual = HexagramData.hexagram(withLines: Hexagram.mutualLines(from: originalBits))!
    }

    /// 动爻（自下而上，0 起）。
    public var movingLines: [Int] {
        originalLines.enumerated().filter { $0.element.isMoving }.map(\.offset)
    }

    /// 动爻名称，如 ["初九"]。
    public var movingLineTitles: [String] {
        movingLines.map { original.lineTitle(at: $0) }
    }

    /// 只有一个动爻时的体卦 / 用卦（梅花易数）。
    /// 用卦为动爻所在之卦，体卦为另一方。
    public var bodyUse: (body: Trigram, use: Trigram)? {
        guard let moving = movingLines.first, movingLines.count == 1 else { return nil }
        if moving < 3 {
            // 动爻在下卦 -> 用卦为下卦，体卦为上卦
            return (original.upper, original.lower)
        } else {
            // 动爻在上卦 -> 用卦为上卦，体卦为下卦
            return (original.lower, original.upper)
        }
    }
}
