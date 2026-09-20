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
    public static func buildConversation(
        result: CastResult,
        question: String,
        history: [DialogueTurn]
    ) -> [ChatMessage] {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        var messages: [ChatMessage] = [.system(systemPrompt), .user(buildContext(result))]
        for turn in history {
            messages.append(.init(role: turn.role.rawValue, content: turn.content))
        }
        if !trimmed.isEmpty {
            messages.append(.user(trimmed))
        }
        return messages
    }

    private static var systemPrompt: String {
        """
        你是一位精通《周易》与现代白话解卦的资深命理师。请以温和、务实、有条理的中文白话向普通用户解读卦象。
        要求：
        1. 先概括本卦卦名与整体象征；
        2. 逐条解读动爻的含义（若无动爻则说明该卦以静卦论，参考本卦卦辞）；
        3. 说明变卦所预示的趋势，以及互卦的辅助信息；
        4. 结合卦辞、爻辞原文（若有）给出通俗解释；
        5. 最后给出 2-3 条可操作的建议或提醒，语气客观平和，不迷信、不恐吓，强调“参考与启发”。
        输出使用分节标题（如「整体卦象」「动爻解读」「变卦启示」「建议」），语言流畅，避免堆砌古文术语。
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