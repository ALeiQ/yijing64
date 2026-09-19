import Foundation

/// 六十四卦静态数据表（按文王卦序 1-64）。
///
/// `lines` 为低 6 位：line3..line5 为上卦，line0..line2 为下卦。
public enum HexagramData {
    // MARK: - 记录

    /// 单卦记录（卦序数据与内容分离：此处只保存结构性数据）。
    private struct Record {
        let number: Int
        let name: String
        let fullName: String
        let upper: TrigramKind
        let lower: TrigramKind
        let palace: Palace
    }

    // MARK: - 六十四卦表（文王卦序）

    private static let records: [Record] = [
        // 乾宫
        Record(number: 1, name: "乾", fullName: "乾为天", upper: .qian, lower: .qian, palace: .qian),
        Record(number: 44, name: "姤", fullName: "天风姤", upper: .qian, lower: .xun, palace: .qian),
        Record(number: 33, name: "遁", fullName: "天山遁", upper: .qian, lower: .gen, palace: .qian),
        Record(number: 12, name: "否", fullName: "天地否", upper: .qian, lower: .kun, palace: .qian),
        Record(number: 20, name: "观", fullName: "风地观", upper: .xun, lower: .kun, palace: .qian),
        Record(number: 23, name: "剥", fullName: "山地剥", upper: .gen, lower: .kun, palace: .qian),
        Record(number: 35, name: "晋", fullName: "火地晋", upper: .li, lower: .kun, palace: .qian),
        Record(number: 14, name: "大有", fullName: "火天大有", upper: .li, lower: .qian, palace: .qian),
        // 兑宫
        Record(number: 58, name: "兑", fullName: "兑为泽", upper: .dui, lower: .dui, palace: .dui),
        Record(number: 47, name: "困", fullName: "泽水困", upper: .dui, lower: .kan, palace: .dui),
        Record(number: 45, name: "萃", fullName: "泽地萃", upper: .dui, lower: .kun, palace: .dui),
        Record(number: 31, name: "咸", fullName: "泽山咸", upper: .dui, lower: .gen, palace: .dui),
        Record(number: 39, name: "蹇", fullName: "水山蹇", upper: .kan, lower: .gen, palace: .dui),
        Record(number: 15, name: "谦", fullName: "地山谦", upper: .kun, lower: .gen, palace: .dui),
        Record(number: 62, name: "小过", fullName: "雷山小过", upper: .zhen, lower: .gen, palace: .dui),
        Record(number: 54, name: "归妹", fullName: "雷泽归妹", upper: .zhen, lower: .dui, palace: .dui),
        // 离宫
        Record(number: 30, name: "离", fullName: "离为火", upper: .li, lower: .li, palace: .li),
        Record(number: 56, name: "旅", fullName: "火山旅", upper: .li, lower: .gen, palace: .li),
        Record(number: 50, name: "鼎", fullName: "火风鼎", upper: .li, lower: .xun, palace: .li),
        Record(number: 64, name: "未济", fullName: "火水未济", upper: .li, lower: .kan, palace: .li),
        Record(number: 4, name: "蒙", fullName: "山水蒙", upper: .gen, lower: .kan, palace: .li),
        Record(number: 59, name: "涣", fullName: "风水涣", upper: .xun, lower: .kan, palace: .li),
        Record(number: 6, name: "讼", fullName: "天水讼", upper: .qian, lower: .kan, palace: .li),
        Record(number: 13, name: "同人", fullName: "天火同人", upper: .qian, lower: .li, palace: .li),
        // 震宫
        Record(number: 51, name: "震", fullName: "震为雷", upper: .zhen, lower: .zhen, palace: .zhen),
        Record(number: 16, name: "豫", fullName: "雷地豫", upper: .zhen, lower: .kun, palace: .zhen),
        Record(number: 40, name: "解", fullName: "雷水解", upper: .zhen, lower: .kan, palace: .zhen),
        Record(number: 32, name: "恒", fullName: "雷风恒", upper: .zhen, lower: .xun, palace: .zhen),
        Record(number: 46, name: "升", fullName: "地风升", upper: .kun, lower: .xun, palace: .zhen),
        Record(number: 48, name: "井", fullName: "水风井", upper: .kan, lower: .xun, palace: .zhen),
        Record(number: 28, name: "大过", fullName: "泽风大过", upper: .dui, lower: .xun, palace: .zhen),
        Record(number: 17, name: "随", fullName: "泽雷随", upper: .dui, lower: .zhen, palace: .zhen),
        // 巽宫
        Record(number: 57, name: "巽", fullName: "巽为风", upper: .xun, lower: .xun, palace: .xun),
        Record(number: 9, name: "小畜", fullName: "风天小畜", upper: .xun, lower: .qian, palace: .xun),
        Record(number: 37, name: "家人", fullName: "风火家人", upper: .xun, lower: .li, palace: .xun),
        Record(number: 42, name: "益", fullName: "风雷益", upper: .xun, lower: .zhen, palace: .xun),
        Record(number: 25, name: "无妄", fullName: "天雷无妄", upper: .qian, lower: .zhen, palace: .xun),
        Record(number: 21, name: "噬嗑", fullName: "火雷噬嗑", upper: .li, lower: .zhen, palace: .xun),
        Record(number: 27, name: "颐", fullName: "山雷颐", upper: .gen, lower: .zhen, palace: .xun),
        Record(number: 18, name: "蛊", fullName: "山风蛊", upper: .gen, lower: .xun, palace: .xun),
        // 坎宫
        Record(number: 29, name: "坎", fullName: "坎为水", upper: .kan, lower: .kan, palace: .kan),
        Record(number: 60, name: "节", fullName: "水泽节", upper: .kan, lower: .dui, palace: .kan),
        Record(number: 3, name: "屯", fullName: "水雷屯", upper: .kan, lower: .zhen, palace: .kan),
        Record(number: 63, name: "既济", fullName: "水火既济", upper: .kan, lower: .li, palace: .kan),
        Record(number: 49, name: "革", fullName: "泽火革", upper: .dui, lower: .li, palace: .kan),
        Record(number: 55, name: "丰", fullName: "雷火丰", upper: .zhen, lower: .li, palace: .kan),
        Record(number: 36, name: "明夷", fullName: "地火明夷", upper: .kun, lower: .li, palace: .kan),
        Record(number: 7, name: "师", fullName: "地水师", upper: .kun, lower: .kan, palace: .kan),
        // 艮宫
        Record(number: 52, name: "艮", fullName: "艮为山", upper: .gen, lower: .gen, palace: .gen),
        Record(number: 22, name: "贲", fullName: "山火贲", upper: .gen, lower: .li, palace: .gen),
        Record(number: 26, name: "大畜", fullName: "山天大畜", upper: .gen, lower: .qian, palace: .gen),
        Record(number: 41, name: "损", fullName: "山泽损", upper: .gen, lower: .dui, palace: .gen),
        Record(number: 38, name: "睽", fullName: "火泽睽", upper: .li, lower: .dui, palace: .gen),
        Record(number: 10, name: "履", fullName: "天泽履", upper: .qian, lower: .dui, palace: .gen),
        Record(number: 61, name: "中孚", fullName: "风泽中孚", upper: .xun, lower: .dui, palace: .gen),
        Record(number: 53, name: "渐", fullName: "风山渐", upper: .xun, lower: .gen, palace: .gen),
        // 坤宫
        Record(number: 2, name: "坤", fullName: "坤为地", upper: .kun, lower: .kun, palace: .kun),
        Record(number: 24, name: "复", fullName: "地雷复", upper: .kun, lower: .zhen, palace: .kun),
        Record(number: 19, name: "临", fullName: "地泽临", upper: .kun, lower: .dui, palace: .kun),
        Record(number: 11, name: "泰", fullName: "地天泰", upper: .kun, lower: .qian, palace: .kun),
        Record(number: 34, name: "大壮", fullName: "雷天大壮", upper: .zhen, lower: .qian, palace: .kun),
        Record(number: 43, name: "夬", fullName: "泽天夬", upper: .dui, lower: .qian, palace: .kun),
        Record(number: 5, name: "需", fullName: "水天需", upper: .kan, lower: .qian, palace: .kun),
        Record(number: 8, name: "比", fullName: "水地比", upper: .kan, lower: .kun, palace: .kun),
    ]

    // MARK: - 卦对象缓存

    private static let allHexagrams: [Hexagram] = records.map {
        Hexagram(
            kingWenNumber: $0.number,
            name: $0.name,
            fullName: $0.fullName,
            lines: (UInt8($0.upper.rawValue) << 3) | UInt8($0.lower.rawValue),
            palace: $0.palace
        )
    }

    private static let byKingWenNumber: [Int: Hexagram] = Dictionary(uniqueKeysWithValues: allHexagrams.map { ($0.kingWenNumber, $0) })
    private static let byLines: [UInt8: Hexagram] = Dictionary(uniqueKeysWithValues: allHexagrams.map { ($0.lines, $0) })

    // MARK: - 查询

    /// 全部六十四卦（文王卦序）。
    public static func all() -> [Hexagram] { allHexagrams }

    /// 按文王卦序号查询。
    public static func find(byKingWenNumber number: Int) -> Hexagram? {
        byKingWenNumber[number]
    }

    /// 按给定六爻位查询。`bit i` 为阳则第 i 爻（自下而上）为阳。
    public static func find(withLines lines: UInt8) -> Hexagram? {
        byLines[lines & 0b111111]
    }

    public static func hexagram(withLines lines: UInt8) -> Hexagram? {
        find(withLines: lines)
    }

    /// 按卦画（经卦组合）查询 —— 由"上卦 + 下卦"重组。
    public static func find(upper: Trigram, lower: Trigram) -> Hexagram? {
        find(withLines: (UInt8(upper.kind.rawValue) << 3) | UInt8(lower.kind.rawValue))
    }

    // MARK: - 内容

    /// 按文王卦序取解卦内容。越界或数据缺失时回退到占位文本。
    public static func content(forKingWenNumber number: Int) -> HexagramContent {
        guard (1...64).contains(number) else {
            return HexagramContent(judgementText: "[卦辞待补充]", lineTexts: (0..<6).map { _ in "[爻辞待补充]" }, divinationText: "[白话解读待补充]")
        }
        let data = HexagramContentData.items[number - 1]
        if data.judgementText.isEmpty || data.lineTexts.allSatisfy({ $0.isEmpty }) {
            return HexagramContent(judgementText: "[卦辞待补充]", lineTexts: (0..<6).map { _ in "[爻辞待补充]" }, divinationText: "[白话解读待补充]")
        }
        return data
    }

    public static func content(for hexagram: Hexagram) -> HexagramContent {
        content(forKingWenNumber: hexagram.kingWenNumber)
    }
}

/// 卦辞 / 爻辞 / 白话占断的占位容器。
public struct HexagramContent: Sendable, Equatable, Hashable {
    public let judgementText: String
    public let lineTexts: [String]
    public let divinationText: String
    /// 用九 / 用六（仅乾坤二卦存在）。
    public let extraLine: String?

    public init(judgementText: String, lineTexts: [String], divinationText: String, extraLine: String? = nil) {
        self.judgementText = judgementText
        self.lineTexts = lineTexts
        self.divinationText = divinationText
        self.extraLine = extraLine
    }
}
