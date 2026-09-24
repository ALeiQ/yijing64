import Foundation

/// 由起卦结果构造 AI 解卦提示词。
public enum HexagramInterpretation {

    /// 生成 system + user 两条消息，供 LLM 解卦（单轮便捷入口）。
    public static func messages(for result: CastResult, question: String) -> [ChatMessage] {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        return [.system(systemPrompt), .user(buildUserTurn(result: result, question: trimmed))]
    }

    /// 生成完整对话消息序列：system + 卦象上下文始终在首，随后按历史追加 user/assistant，
    /// 最后追加本轮提问。
    /// **空白提问（默认解卦）严格只看卦象**：忽略全部历史上下文，避免与先前对话结合。
    public static func buildConversation(
        result: CastResult,
        question: String,
        history: [DialogueTurn]
    ) -> [ChatMessage] {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return messages(for: result, question: "")
        }
        var messages: [ChatMessage] = [.system(systemPrompt), .user(buildContext(result))]
        for turn in history {
            messages.append(.init(role: turn.role.rawValue, content: turn.content))
        }
        messages.append(.user(trimmed))
        return messages
    }

    private static var systemPrompt: String {
        """
        你是一位精通《周易》与现代白话解卦的资深命理师。请以务实、直率、就事论事的中文白话解读卦象，对吉凶给出明确判断，不回避、不软化。
        输出格式（必须严格遵守）：
        - 使用 Markdown 分节标题（## 标题）与列表（- 每条一到两句话）；
        - 恰好四个分节：「整体卦象」「动爻解读」（无动爻则改为「静卦说明」）「变卦启示」「给你的建议」；
        - 「整体卦象」的第 1 条必须先针对用户所问之事给出明确判词（如：可行／不可行、宜／不宜、吉／凶、能成／难成、可以／不建议），再展开依据；
        - 全文控制在 200-500 字，每节 2-5 条要点；
        - 不要输出引言、结语、或“以下是/总结”等客套话；
        - 全程使用中文，包括思考过程与最终回答；除专有名词、代码外不要夹用英文；
        - 将用户问题视为对所问之事的吉凶征询：凡关乎切身选择与利弊的问题，无论句式多朴素，都应结合本卦象解读——例如能不能出门、远行适不适合、要不要跳槽换工作、感情能否发展、考试能否通过、合作生意能否谈成、是否适合置业或投资、身体能否康复等；
        - 以“能不能/合适吗/顺利吗/要不要/哪天”询问某个具体活动（写代码、健身、上课、出差、复习、运动等）的时机吉凶时，视为对该活动占问吉凶，按卦解读，不要当作知识求助拒绝；
        - 如实判卦，不迎合：卦辞或爻辞出现「凶、吝、厉、悔、咎、无攸利、勿用、弗克、征凶」等，或动爻、变卦明显趋坏时，必须直接判为不利／不宜／难成，并说明原因与规避建议；
        - 禁止把不利弱化为折中说法，例如“适量”“适度”“短途可以”“不远行就行”“注意一点就好”“勉强可行”“虽然……但也不是不行”“看个人努力”“凡事皆有两面”；卦象不利就明确说不宜，不要为了让用户好受而含糊；
        - 若卦象确有转机或并非全凶，必须写明需要满足的具体条件，而不是笼统安慰；
        - 直言吉凶但不恐吓、不夸大、不宿命，语气客观平和，强调“参考与启发”，避免堆砌古文术语；
        - 仅当用户是请求完成某件与命理无关的任务、或询问客观事实/实时信息/无关知识时（如“帮我写一首诗”“这道数学题怎么做”“这段英文帮我翻译”、或“今天几号”“现在几点”“天气怎样”“谁当选总统”），才回复一句简短拒绝，如“这与占卜无关，请告诉我你想占卜的事情”；拒绝时禁止引用卦象，禁止生成任何卦象解读，也禁止在拒绝后回到卦象话题。
        """
    }

    private static func buildUserTurn(result: CastResult, question: String) -> String {
        var user = buildContext(result)
        if !question.isEmpty {
            user += "\n\n【所问之事】\n\(question)"
        }
        user += "\n\n请解读以上卦象。"
        return user
    }

    private static func buildContext(_ result: CastResult) -> String {
        let original = result.original
        var lines: [String] = []
        lines.append("本次起卦方式：\(result.method.rawValue)")
        lines.append("本卦：\(original.fullName)（第\(original.kingWenNumber)卦，\(original.upper.nature)上\(original.lower.nature)下）")

        let content = HexagramData.content(for: original)
        if !content.judgementText.isEmpty {
            lines.append("卦辞：\(content.judgementText)")
        }

        if result.movingLineTitles.isEmpty {
            lines.append("动爻：无（静卦，以本卦卦辞为主）")
        } else {
            let titles = result.movingLineTitles.joined(separator: "、")
            lines.append("动爻：\(titles)")
            for index in result.movingLines {
                let lineText = content.lineTexts.indices.contains(index) ? content.lineTexts[index] : ""
                lines.append("- \(original.lineTitle(at: index))：\(lineText)")
            }
            if result.mutual.kingWenNumber != original.kingWenNumber {
                let mutualName = "\(result.mutual.fullName)（\(result.mutual.kingWenNumber)）"
                lines.append("互卦：\(mutualName)")
            }
            if result.changed.kingWenNumber != original.kingWenNumber {
                let changedContent = HexagramData.content(for: result.changed)
                let changedText = changedContent.judgementText.isEmpty ? "" : "，卦辞“\(changedContent.judgementText)”"
                lines.append("变卦：\(result.changed.fullName)（\(result.changed.kingWenNumber)）\(changedText)")
            }
        }
        return lines.joined(separator: "\n")
    }
}