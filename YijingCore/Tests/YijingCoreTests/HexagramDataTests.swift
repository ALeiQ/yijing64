import XCTest
@testable import YijingCore

final class HexagramDataTests: XCTestCase {

    func testAllHexagramsCount() {
        XCTAssertEqual(HexagramData.all().count, 64)
    }

    func testKingWenNumbersAreUniqueAndComplete() {
        let numbers = HexagramData.all().map(\.kingWenNumber)
        XCTAssertEqual(Set(numbers).count, 64)
        XCTAssertEqual(numbers.sorted(), Array(1...64))
    }

    func testLineMasksAreAllDistinct() {
        let masks = HexagramData.all().map(\.lines)
        XCTAssertEqual(Set(masks).count, 64)
    }

    func testUpperLowerDecomposesWithKnownExamples() {
        // 乾为天
        let qian = HexagramData.find(byKingWenNumber: 1)!
        XCTAssertEqual(qian.lines, 0b111111)
        XCTAssertEqual(qian.upper.symbol, "☰")
        XCTAssertEqual(qian.lower.symbol, "☰")

        // 坤为地
        let kun = HexagramData.find(byKingWenNumber: 2)!
        XCTAssertEqual(kun.lines, 0)
        XCTAssertEqual(kun.upper.symbol, "☷")

        // 水雷屯 (上坎下震)
        let zhun = HexagramData.find(byKingWenNumber: 3)!
        XCTAssertEqual(zhun.upper.symbol, "☵")
        XCTAssertEqual(zhun.lower.symbol, "☳")

        // 革（泽火革）：上兑下离
        let ge = HexagramData.find(byKingWenNumber: 49)!
        XCTAssertEqual(ge.upper.symbol, "☱")
        XCTAssertEqual(ge.lower.symbol, "☲")
    }

    func testLookupByLinesRoundTrips() {
        for hexagram in HexagramData.all() {
            let found = HexagramData.hexagram(withLines: hexagram.lines)
            XCTAssertEqual(found, hexagram)
        }
    }

    func testOppositeAndInverse() {
        // 错卦：乾->坤
        XCTAssertEqual(HexagramData.find(byKingWenNumber: 1)!.opposite(),
                       HexagramData.find(byKingWenNumber: 2)!)
        // 综卦：乾自综
        XCTAssertEqual(HexagramData.find(byKingWenNumber: 1)!.inverse(),
                       HexagramData.find(byKingWenNumber: 1)!)
        // 乾互乾、坤互坤
        XCTAssertEqual(HexagramData.find(byKingWenNumber: 1)!.mutual(),
                       HexagramData.find(byKingWenNumber: 1)!)
        XCTAssertEqual(HexagramData.find(byKingWenNumber: 2)!.mutual(),
                       HexagramData.find(byKingWenNumber: 2)!)
        // 泰（地天泰）互卦：上震下兑 = 雷泽归妹(54)
        let tai = HexagramData.find(byKingWenNumber: 11)!
        XCTAssertEqual(tai.mutual(), HexagramData.find(byKingWenNumber: 54)!)
        // 否（天地否）互卦：上巽下艮 = 风山渐(53)
        let fou = HexagramData.find(byKingWenNumber: 12)!
        XCTAssertEqual(fou.mutual(), HexagramData.find(byKingWenNumber: 53)!)
        // 互卦与综卦自洽：泰综=否，互卦亦互为综
        XCTAssertEqual(tai.inverse(), fou)
        XCTAssertEqual(tai.mutual().inverse(), fou.mutual())
    }

    func testLineTitleNaming() {
        let qian = HexagramData.find(byKingWenNumber: 1)!
        XCTAssertEqual(qian.lineTitle(at: 0), "初九")
        XCTAssertEqual(qian.lineTitle(at: 5), "上九")
        let kun = HexagramData.find(byKingWenNumber: 2)!
        XCTAssertEqual(kun.lineTitle(at: 1), "六二")
        XCTAssertEqual(kun.lineTitle(at: 5), "上六")
    }

    func testAtomicTrigram() {
        let qian = Trigram(.qian)
        XCTAssertEqual(qian.symbol, "☰")
        XCTAssertEqual(qian.nature, "天")
        XCTAssertEqual(qian.element, "金")

        let dui = Trigram(fuxiNumber: 2)
        XCTAssertNotNil(dui)
        XCTAssertEqual(dui?.symbol, "☱")
        XCTAssertEqual(dui?.name, "兑")

        XCTAssertNil(Trigram(fuxiNumber: 0))
        XCTAssertNil(Trigram(fuxiNumber: 9))
    }

    func testContentCompleteForAllHexagrams() {
        for number in 1...64 {
            let content = HexagramData.content(forKingWenNumber: number)
            XCTAssertFalse(content.judgementText.trimmingCharacters(in: .whitespaces).isEmpty,
                           "卦辞缺失：\(number)")
            XCTAssertEqual(content.lineTexts.count, 6)
            for line in content.lineTexts {
                XCTAssertFalse(line.trimmingCharacters(in: .whitespaces).isEmpty,
                               "爻辞缺失：\(number)")
            }
            XCTAssertFalse(content.divinationText.trimmingCharacters(in: .whitespaces).isEmpty,
                           "白话缺失：\(number)")
        }
    }

    func testContentKnownTexts() {
        // 乾卦卦辞与初爻
        let qian = HexagramData.content(forKingWenNumber: 1)
        XCTAssertEqual(qian.judgementText, "元亨。利贞")
        XCTAssertEqual(qian.lineTexts[0], "潜龙勿用。")
        XCTAssertEqual(qian.extraLine, "见群龙无首，吉。")
        XCTAssertTrue(qian.divinationText.contains("《乾卦》象征天"))

        // 坤卦应有 用六
        let kun = HexagramData.content(forKingWenNumber: 2)
        XCTAssertEqual(kun.extraLine, "利永贞。")

        // 未济卦名与卦辞
        let weiji = HexagramData.content(forKingWenNumber: 64)
        XCTAssertEqual(weiji.judgementText, "亨。小狐汔济，濡其尾，无攸利")
        XCTAssertTrue(weiji.divinationText.contains("《未济卦》象征事未完成"))
    }

    func testSearchByName() {
        let results = HexagramSearch.search(query: "乾")
        let numbers = results.map(\.kingWenNumber)
        XCTAssertTrue(numbers.contains(1))
        XCTAssertTrue(numbers.contains(44)) // 天风姤：上乾下巽
    }

    func testSearchByFullName() {
        let results = HexagramSearch.search(query: "天泽履").map(\.kingWenNumber)
        XCTAssertEqual(results, [10])
    }

    func testSearchByNumber() {
        XCTAssertEqual(HexagramSearch.search(query: "13").map(\.kingWenNumber), [13])
        // 前缀匹配：输入 1 命中序数含 1 的卦
        let prefix = HexagramSearch.search(query: "1").map(\.kingWenNumber)
        XCTAssertTrue(prefix.contains(1))
        XCTAssertTrue(prefix.contains(10))
    }

    func testSearchByJudgementText() {
        // 「潜龙勿用」出现在乾卦爻辞，白话译文与爻辞原文都含该句
        let results = HexagramSearch.search(query: "潜龙勿用").map(\.kingWenNumber)
        XCTAssertTrue(results.contains(1))
    }

    func testSearchEmptyReturnsAll() {
        XCTAssertEqual(HexagramSearch.search(query: "").count, 64)
        XCTAssertEqual(HexagramSearch.search(query: "   ").count, 64)
    }

    func testSearchNoMatch() {
        XCTAssertTrue(HexagramSearch.search(query: "不存在的卦").isEmpty)
    }
}