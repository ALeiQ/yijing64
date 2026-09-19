import Foundation

/// 卦库搜索：在卦名、卦序、上卦下卦、卦辞与白话译文中检索。
public enum HexagramSearch {

    /// 按关键词搜索，返回按文王卦序排列的结果。
    ///
    /// 匹配规则（不区分大小写、局部包含）：
    /// - 关键词为纯数字：匹配卦序（"12" 精确匹配 12；"1" 匹配含 1 的序号）
    /// - 其余：匹配 卦名、全名（乾为天）、宫名（乾宫）、上卦/下卦名与其自然（天/泽/…）、
    ///   以及卦辞与白话译文（子串）
    public static func search(query: String, in all: [Hexagram] = HexagramData.all()) -> [Hexagram] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { matches(hexagram: $0, query: trimmed) }
            .sorted { $0.kingWenNumber < $1.kingWenNumber }
    }

    /// 命中位置（用于高亮）。返回 `fullName` 中首个命中片段的 Range，未命中为 nil。
    public static func matchRange(in text: String, query: String) -> Range<String.Index>? {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
            ?? text.range(of: query, options: [.caseInsensitive])
    }

    private static func matches(hexagram: Hexagram, query: String) -> Bool {
        if let number = Int(query), number > 0, number <= 64 {
            // 纯数字：精确匹配或前缀匹配
            let numStr = String(hexagram.kingWenNumber)
            if hexagram.kingWenNumber == number || numStr.hasPrefix(query) { return true }
            // 输入 61 时也匹配 6、1：退化为包含判断
            if numStr.range(of: query) != nil { return true }
        }

        let content = HexagramData.content(for: hexagram)
        var haystacks: [String] = [
            hexagram.name,
            hexagram.fullName,
            hexagram.palace.name,
            hexagram.upper.name,
            hexagram.upper.nature,
            hexagram.lower.name,
            hexagram.lower.nature,
            content.judgementText,
            content.divinationText,
        ]
        haystacks += content.lineTexts
        if let extra = content.extraLine { haystacks.append(extra) }
        return haystacks.contains { $0.range(of: query, options: .caseInsensitive) != nil }
    }
}