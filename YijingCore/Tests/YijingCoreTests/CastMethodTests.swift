import XCTest
@testable import YijingCore

final class CastMethodTests: XCTestCase {

    func testCastableMethodsExcludesManualAndLibrary() {
        let methods = CastMethod.castableMethods
        XCTAssertFalse(methods.contains(.manual))
        XCTAssertFalse(methods.contains(.hexagramLibrary))
        XCTAssertEqual(methods.count, 4)
    }

    func testAllMethodsHaveSubtitle() {
        for method in CastMethod.allCases {
            XCTAssertFalse(method.subtitle.isEmpty, "\(method.rawValue) 缺少副标题")
        }
    }

    func testCastRecordRoundTripWithHexagramLibrary() throws {
        let record = CastRecord(
            method: .hexagramLibrary,
            originalLines: [.youngYang, .youngYin, .youngYang, .youngYin, .youngYang, .youngYin]
        )
        let data = try JSONEncoder().encode([record])
        let decoded = try JSONDecoder().decode([CastRecord].self, from: data)
        XCTAssertEqual(decoded[0].method, .hexagramLibrary)
        XCTAssertEqual(decoded[0].result.original, record.result.original)
    }
}
