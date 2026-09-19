import SwiftUI
import YijingCore

/// 绘制一卦的六爻（自下而上），动爻加圆/叉标识。
struct HexagramDrawingView: View {
    let lines: [LineType]
    var lineSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: lineSpacing) {
            // 从最上爻开始绘制（上六在顶部）
            ForEach(Array(lines.enumerated().reversed()), id: \.offset) { index, line in
                HexagramLineView(line: line)
            }
        }
    }
}

/// 单爻（阳爻为整段，阴爻为两段，动爻叠加标记）。
struct HexagramLineView: View {
    let line: LineType
    var width: CGFloat = 44

    var body: some View {
        ZStack {
            HStack(spacing: 4) {
                if line.isYang {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.primary)
                        .frame(width: width, height: 6)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.primary)
                        .frame(width: width * 0.6, height: 6)
                    Spacer().frame(width: width * 0.4)
                }
            }

            if line.isMoving {
                Circle()
                    .fill(Color.red.opacity(0.9))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Text(line.isYang ? "○" : "×")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: width / 2 + 12, y: 0)
            }
        }
        .frame(width: width + 24, height: 12)
    }
}

/// 经卦徽标（先天八卦符号）。
struct TrigramBadgeView: View {
    let trigram: Trigram
    var size: CGFloat = 36

    var body: some View {
        VStack(spacing: 2) {
            Text(trigram.symbol)
                .font(.system(size: size))
            Text(trigram.name)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HexagramDrawingView(lines: [
            .oldYin, .youngYang, .youngYin, .oldYang, .youngYang, .youngYin
        ])
        HStack { TrigramBadgeView(trigram: Trigram(.qian)) }
    }
    .frame(width: 200)
}