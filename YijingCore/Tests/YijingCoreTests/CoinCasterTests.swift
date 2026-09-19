import XCTest
@testable import YijingCore

final class CoinCasterTests: XCTestCase {

    func testLineTypeMapping() {
        // 三正：老阳(9)，动爻
        XCTAssertEqual(CoinCaster.lineType(true, true, true), .oldYang)
        // 两正一反：少阴(8)
        XCTAssertEqual(CoinCaster.lineType(true, true, false), .youngYin)
        // 一正两反：少阳(7)
        XCTAssertEqual(CoinCaster.lineType(true, false, false), .youngYang)
        // 三反：老阴(6)，动爻
        XCTAssertEqual(CoinCaster.lineType(false, false, false), .oldYin)
    }

    func testCastProducesSixLinesAndValidHexagram() {
        let result = CoinCaster.cast { Bool.random() }
        XCTAssertEqual(result.originalLines.count, 6)
        XCTAssertTrue((1...64).contains(result.original.kingWenNumber))
        XCTAssertTrue((1...64).contains(result.changed.kingWenNumber))
        XCTAssertLessThanOrEqual(result.movingLines.count, 6)
        XCTAssertEqual(result.mutual.kingWenNumber >= 1, true)
    }

    func testKnownDeterministicThrow() {
        // 六次皆三正 -> 六爻皆老阳 -> 本卦应为乾，且六爻皆动
        var queue = Array(repeating: true, count: 18)
        let result = CoinCaster.cast(throwCoin: { queue.removeFirst() })
        XCTAssertEqual(result.original.kingWenNumber, 1)
        XCTAssertEqual(result.originalLines, Array(repeating: .oldYang, count: 6))
        XCTAssertEqual(result.movingLines, [0, 1, 2, 3, 4, 5])
        // 本卦乾，变卦坤
        XCTAssertEqual(result.changed.kingWenNumber, 2)
    }

    func testDistributionOverManyThrows() {
        // 每次抛掷三枚：老阴/老阳各 1/8，少阴/少阳各 3/8（容差 5%）
        var counters: [LineType: Int] = [:]
        let total = 40_000
        var coin: () -> Bool = { Bool.random() }
        for _ in 0..<total {
            let line = CoinCaster.lineType(coin(), coin(), coin())
            counters[line, default: 0] += 1
        }
        let ratio = { (t: LineType) -> Double in Double(counters[t, default: 0]) / Double(total) }
        XCTAssertEqual(ratio(.oldYin), 0.125, accuracy: 0.05)
        XCTAssertEqual(ratio(.oldYang), 0.125, accuracy: 0.05)
        XCTAssertEqual(ratio(.youngYin), 0.375, accuracy: 0.05)
        XCTAssertEqual(ratio(.youngYang), 0.375, accuracy: 0.05)
    }
}