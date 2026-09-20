import Foundation

/// 判断用户提问是否与占卜/解卦相关。
///
/// 策略采用「默认放行」：只有明确命中无关关键词才判为无关；
/// 命中占卜相关词则判为占卜；其余模糊表述一律放行，
/// 避免误伤正常的占卜提问（宁可让模型多回答一次，也不轻易拒绝）。
///
/// 无关词表只保留「客观事实/实时信息」类强信号：这类问题模型无法获取
/// 答案却可能硬套卦象，因此本地直接拒绝。内容类词汇（编程、写诗、菜谱等）
/// 不参与本地拦截——它们可能被用作占问对象（如"这几天写代码合适吗"），
/// 语义判定交给模型侧 prompt 兜底。
///
/// 注意：解卦历史不参与判定——无关问题不会因对话已进行多轮而被放行；
/// 自然的追问（"那再看看财运""再讲讲"）由相关词命中或默认兜底覆盖。
public enum DivinationTopic {
    public enum Relevance: Equatable {
        case divination
        case unrelated
    }

    /// 与占卜强无关的客观事实/实时信息信号词（命中即判无关）。
    private static let unrelatedKeywords: [String] = [
        "天气", "气温", "今天几号", "今天日期", "今天是几号", "今天星期几", "星期几",
        "现在几点", "现在几点了", "几点钟", "新闻", "政治",
    ]

    /// 占卜相关信号词。
    private static let relatedKeywords: [String] = [
        "卦", "爻", "占卜", "起卦", "解卦", "预测", "运势", "事业", "财运", "工作",
        "感情", "姻缘", "婚恋", "健康", "学业", "考运", "考试", "吉凶", "祸福", "方位", "择日",
        "正缘", "贵人", "小人", "流年", "太岁", "风水", "八字", "命理", "犯太岁", "搬家",
        "出行", "出门", "远行", "出差", "旅行", "面试", "跳槽", "求职", "找工作", "升职",
        "合作", "买房", "装修", "相亲", "手术", "治病", "康复", "官司",
        "测", "算一卦", "摇卦", "铜钱",
    ]

    /// 判断一段提问的领域相关度。history 为兼容参数，不参与判定。
    public static func relevance(of question: String, history _: [DialogueTurn]) -> Relevance {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .divination }

        let lower = text.lowercased()

        // 命中无关强信号 → 判无关（除非同样命中占卜相关词，避免误伤"占卜天气出行"类表达）。
        if unrelatedKeywords.contains(where: { lower.contains($0) }) {
            if !relatedKeywords.contains(where: { lower.contains($0) }) {
                return .unrelated
            }
        }

        // 命中占卜相关词 → 判占卜。
        if relatedKeywords.contains(where: { lower.contains($0) }) {
            return .divination
        }

        // 其余一律放行。
        return .divination
    }
}