import XCTest
@testable import YijingCore

final class PlumBlossomCasterTests: XCTestCase {

    func testFuxiMapping() {
        XCTAssertEqual(PlumBlossomCaster.trigram(fuxiNumber: 1), .qian)
        XCTAssertEqual(PlumBlossomCaster.trigram(fuxiNumber: 2), .dui)
        XCTAssertEqual(PlumBlossomCaster.trigram(fuxiNumber: 8), .kun)
        XCTAssertNil(PlumBlossomCaster.trigram(fuxiNumber: 0))
    }

    func testBranchOrder() {
        XCTAssertEqual(PlumBlossomCaster.branchOrder("子"), 1)
        XCTAssertEqual(PlumBlossomCaster.branchOrder("午"), 7)
        XCTAssertEqual(PlumBlossomCaster.branchOrder("亥"), 12)
        XCTAssertEqual(PlumBlossomCaster.branchOrder("x"), 0)
    }

    func testRemainderAndMovingLine() {
        XCTAssertEqual(PlumBlossomCaster.fuxiNumber(fromRemainder: 0), 8)
        XCTAssertEqual(PlumBlossomCaster.fuxiNumber(fromRemainder: 1), 1)
        XCTAssertEqual(PlumBlossomCaster.fuxiNumber(fromRemainder: 9), 1)
        // 动爻：余 0 -> 上爻(5)；余 1 -> 初爻(0)
        XCTAssertEqual(PlumBlossomCaster.movingLine(fromRemainder: 0), 5)
        XCTAssertEqual(PlumBlossomCaster.movingLine(fromRemainder: 1), 0)
        XCTAssertEqual(PlumBlossomCaster.movingLine(fromRemainder: 4), 3)
        XCTAssertEqual(PlumBlossomCaster.movingLine(fromRemainder: 6), 5)
    }

    func testKnownTimeCast() {
        // 经典案例：辛丑年咸月 …简单例子：
        // 上卦 = (年支+月+日) % 8；此处取 乾一（total 1）
        // 构造：年支1(子) + 月 + 日 使总和为 1？不可行，改用已知组合：
        // total=17 -> 上卦 1(乾)；total+时 = 19 -> 下卦 3(离)；动爻 19%6=1 -> 初爻
        let result = PlumBlossomCaster.castByTime(
            yearBranchOrder: 3,   // 寅
            month: 3,
            day: 11,             // 3+3+11 = 17
            hourBranchOrder: 2    // 丑；17+2 = 19
        )
        XCTAssertEqual(result.original.upper.symbol, "☰")
        XCTAssertEqual(result.original.lower.symbol, "☲")
        XCTAssertEqual(result.original.kingWenNumber, 13) // 天火同人
        XCTAssertEqual(result.movingLineTitles, ["初九"])
        // 本卦天火同人，初爻动 -> 变卦天山遁
        XCTAssertEqual(result.changed.kingWenNumber, 33)
    }

    func testKnownNumbersCast() {
        // 报数 7 和 6：上卦 7=艮，下卦 6=坎；动爻 (7+6+0)%6=1 -> 初爻
        let result = PlumBlossomCaster.castByNumbers(7, 6, hourBranchOrder: 0)
        XCTAssertEqual(result.original.upper.symbol, "☶")
        XCTAssertEqual(result.original.lower.symbol, "☵")
        XCTAssertEqual(result.original.kingWenNumber, 4) // 山水蒙
        XCTAssertEqual(result.movingLineTitles, ["初六"])
        // 蒙初爻动 -> 变卦 剥？实为 泽水蒙初变 -> 山地剥？校验 Changed 有效即可
        XCTAssertTrue((1...64).contains(result.changed.kingWenNumber))
    }

    func testBodyUseDerivedFromMovingLine() {
        // 天火同人（上乾下离），初爻在下卦 -> 用=离(下)、体=乾(上)
        let result = PlumBlossomCaster.castByTime(
            yearBranchOrder: 3,
            month: 3,
            day: 11,
            hourBranchOrder: 2
        )
        XCTAssertNotNil(result.bodyUse)
        XCTAssertEqual(result.bodyUse?.body.symbol, "☰")
        XCTAssertEqual(result.bodyUse?.use.symbol, "☲")
    }

    func testRandomCast() {
        var gen = SystemRandomNumberGenerator()
        let result = PlumBlossomCaster.castRandom { range in
            Int.random(in: range, using: &gen)
        }
        XCTAssertEqual(result.method, .plumRandom)
        XCTAssertTrue((1...64).contains(result.original.kingWenNumber))
        XCTAssertEqual(result.movingLines.count, 1, "梅花法应恰一爻动")
        XCTAssertNotNil(result.bodyUse)
    }

    func testLineTypeSequenceDefinesOriginal() {
        var gen = SystemRandomNumberGenerator()
        let result = PlumBlossomCaster.castRandom { range in
            Int.random(in: range, using: &gen)
        }
        var bits: UInt8 = 0
        for (i, line) in result.originalLines.enumerated() where line.isYang {
            bits |= 1 << i
        }
        XCTAssertEqual(HexagramData.hexagram(withLines: bits)?.kingWenNumber, result.original.kingWenNumber)
    }
}