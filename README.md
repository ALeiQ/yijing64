# 易经六十四卦 (Yijing64)

SwiftUI 编写的《周易》六十四卦 App，含线下排卦、多种起卦方式、卦辞白话查询与卦象分析。

## 功能

- **线下排卦**：手动录入线下摇卦结果，逐爻点击设置阴阳，可勾选动爻（存在则四态循环切换，否则仅在少阴/少阳间切换）；实时推断本卦/变卦/互卦/动爻/体用并展示卦辞。
- **起卦**：支持三枚铜钱（六爻摇钱法）、梅花易数时间起卦 / 报数起卦 / 随机起卦，逐爻演示动爻（老阳 ○ / 老阴 ×）。
- **卦库**：文王卦序、八宫分组浏览六十四卦；支持关键词搜索（卦名、卦序、上下卦、宫名、卦辞、爻辞、白话译文），命中片段高亮。
- **卦辞查询**：每卦含卦辞、六爻爻辞、用九/用六（乾坤）及白话译文；起卦结果中点击卦象可跳转到对应卦辞。

## 项目结构

```
Yijing64.xcodeproj     Xcode 工程（xcodegen 生成，见 project.yml）
Yijing64/              App Target
  Views/                各 Tab 与组件（RootTab、Divination、Library、About、Components）
  ViewModels/           起卦状态管理
YijingCore/            Swift Package：模型与业务逻辑
  Sources/YijingCore/
    Models/             Hexagram、Trigram、Palace、LineType、CastResult、卦象内容表
    Services/           起卦器（CoinCaster、PlumBlossomCaster）、卦库搜索
  Tests/                XCTest 单元测试
scripts/                Python 抓取与内容生成脚本
```

## 构建 / 测试

```bash
# 重新生成工程（新增 Swift 文件后需要）
brew install xcodegen && xcodegen generate

# 单测（YijingCore）
cd YijingCore && swift test

# 构建 App（模拟器）
xcodebuild build -project Yijing64.xcodeproj -scheme Yijing64 \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath .build/dd
```

## 内容来源

- 卦辞 / 爻辞原文：中文维基文库（公有领域），简体转写见 `scripts/fetch_yijing.py`。
- 白话译文：南怀瑾《白话易经》（此部分版式与文意由《白话易经》整理，见 `scripts/gen_content_data.py`；如需替换，调整该脚本即可重新生成 `HexagramContentData.swift`）。