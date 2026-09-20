# 更新日志

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)；格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

说明：1.0.0–1.2.0 为回溯整理；自 **2.0.0** 起正式版本化，每个版本均打 Git 标签 `vX.Y.Z`。

## [2.4.1] - 2026-09-20

### Changed
- 「关于」页版本号只显示版本（如 2.4.1），不再显示 build 号

## [2.4.0] - 2026-09-20

### Added
- 卦库搜索结果按八宫分组展示（乾→兑→离→震→巽→坎→艮→坤），仅显示有命中的宫

## [2.3.0] - 2026-09-20

### Added
- 思考过程随记录持久化，历史回放可展开查看
- 起卦页起卦完成后自动滚动到底端展示结果
- 流式打字机效果（CADisplayLink 逐帧揭示，网络到达与显示解耦）
- 构建同步脚本 `scripts/sync.sh`（一键同步模拟器与真机）

### Changed
- 流式文本改用非滚动 `UITextView` 增量追加，主线程不再被长文本重排阻塞（更顺滑、应用内完成更快）
- 解卦会话容器改为非懒 `VStack`，根治「展开长思考后发送」的空白
- 思考/正文流式跟随滚动；用户手动上滑暂停，下次提问恢复
- 移除思考流式期间的尾部截断，完整展示思考内容

### Fixed
- 修复多轮会话「展开最后一轮思考后再次提问」稳定空白
- 修复键盘收放触发的会话空白；收起键盘保持当前滚动位置
- 修复思考过程折叠热区过窄（整行可点击）
- 修复流式期间文本选择手势与滚动争抢导致的卡顿

## [2.2.0] - 2026-09-20

### Changed
- 解卦改为直问直答：先在「整体卦象」给出明确判词；卦象不利时直接判「不宜/难成」，禁止「适量/短途/勉强可行」等折中回避
- 提示词要求全程使用中文（含思考过程），缓解中英混合
- 语气由「温和」调整为「务实直率」，保留不恐吓、不夸大、不宿命

## [2.1.0] - 2026-09-20

### Added
- 卦库每卦详情页新增「AI 解卦」入口（静态卦，不写入起卦记录）

## [2.0.0] - 2026-09-20

### Added
- AI 解卦：多轮对话、固定卦象摘要、Markdown 气泡、与占卜无关问题本地拦截
- AI 解卦流式输出与思考过程展示、自动滚底
- Token 用量统计与费用估算（关于页 / 记录 / 解卦页三处展示）
- 按模型与请求时段自动计费（DeepSeek 峰谷价、智谱免费/近似档、未知模型不估算）
- 模型服务切换：DeepSeek / 智谱 / opencode Zen / opencode Go / 自定义；各服务商独立记忆 Key 与配置，旧配置自动迁移
- opencode 网关适配：请求补 `x-opencode-session` 与 `User-Agent`

### Changed
- 解卦页键盘收起方式调整；设置页描述与计费说明更新

### Internal
- 引入一键构建同步脚本与 `AGENTS.md` 协作约定

## [1.2.0] - 2026-09-19

### Added
- 线下排卦：逐爻设置阴阳，可勾选动爻并实时推断本卦/变卦/互卦/动爻/体用
- 卦库关键词搜索（卦名、卦序、上下卦、宫名、卦辞、爻辞、白话译文），命中片段高亮

## [1.1.0] - 2026-09-19

### Added
- 六十四卦完整卦辞 / 爻辞（中文维基文库）与南怀瑾《白话易经》译文

## [1.0.0] - 2026-09-19

### Added
- 初版：六十四卦模型、八卦 / 八宫、三枚铜钱与梅花易数起卦、卦库浏览

[2.4.1]: https://github.com/ALeiQ/yijing64/releases/tag/v2.4.1
[2.4.0]: https://github.com/ALeiQ/yijing64/releases/tag/v2.4.0
[2.3.0]: https://github.com/ALeiQ/yijing64/releases/tag/v2.3.0
[2.2.0]: https://github.com/ALeiQ/yijing64/releases/tag/v2.2.0
[2.1.0]: https://github.com/ALeiQ/yijing64/releases/tag/v2.1.0
[2.0.0]: https://github.com/ALeiQ/yijing64/releases/tag/v2.0.0
[1.2.0]: https://github.com/ALeiQ/yijing64/releases/tag/v1.2.0
[1.1.0]: https://github.com/ALeiQ/yijing64/releases/tag/v1.1.0
[1.0.0]: https://github.com/ALeiQ/yijing64/releases/tag/v1.0.0
