# Impress · 需求 × 代码 × 测试 × 设备验收执行矩阵

> 2026-10-20 基准。本文是实施状态，不是完工声明。源代码证据基线：`c38efbe7cb1c54c95a1074421d79d0397f1b7c87`；后续提交须以对应 CI SHA 更新验收。唯一开发分支 `feature/impress-duplex-loop-v1`，不修改 `main` / 私库。
> 权威：用户最新指示 > `PRODUCT_REQUIREMENTS_CURRENT.md` > v1.0 稳定编号 > 历史文档。旧校准周图和复习底栏历史已被替代。 `ImVaultGuardedWrite.productionWriteEnabled` 仍为 `false`。

## 状态词典与实测边界

`NOT_STARTED` 未有可操作主链；`IN_PROGRESS` 部分接通或缺边界；`CODE_DONE` 已见源码但 **不代表** 最新 CI 或真实设备通过；`CI_PASS` 同一 HEAD 的完整自动化全部通过；`DEVICE_PASS` iPhone 13 及被允许范围真机通过；`BLOCKED` 外部权限或完整验收阻塞；`DEFERRED` 已确定暂缓。本矩阵不将局部 XCTest 等价于 ACCEPT 成功。

起始已通过 CI 是 `4658914c78b05ab7584009930d5b649575c0a22a` 对应 [Run #39378473813](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39378473813)，不适用于之后的源码提交。后续源码提交 `897895c`（选择题解析）和 `c38efbe`（现场编辑＋来源）均有各自原生测试待 CI 复核；iPhone 13 实机尚无证据。

## 85 个稳定需求 ID（逐项工作表）

| 编号 | 需求（原文简述） | 当前状态 | 源码／核验入口 | 自动化证据 | 尚缺门禁 |
| --- | --- | --- | --- | --- | --- |
| NAV-01 | 一级 Tab 保持“闪卡／笔记／设置”。Chat 重要但不新增第四个 Tab。 | CODE_DONE | `aReuImpress-iPhone/Base/ImTabBarViewController.swift` | 候选：testV3ReviewUsesExplicitRevealAndKeepsFourDirectionSwipeStack / 三 Tab 结构回归 | 代码存在；不得自动推断 CI/真机 |
| NAV-02 | 平时复习链路保持短：看问题→自行回忆→查看答案→评分→下一张。Chat、整理笔记、校准均非必经步骤。 | CODE_DONE | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| NAV-03 | 首页保留新增卡片和卡片集的职责区分；当前卡片的编辑／来源入口属于当前对象，不与全局功能混放。 | IN_PROGRESS | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 需要精确场景与证据 |
| NAV-04 | 删除闪卡上方常驻的完整校准周图，不让图表挤占问题／答案阅读空间。 | CODE_DONE | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| NAV-05 | 校准器仍须容易找到；已讨论首页轻量一键入口＋设置入口，但首页具体位置、文案、提醒时机尚未最终定版。每次冷启动强制弹出并未获准。 | IN_PROGRESS | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 需要精确场景与证据 |
| NAV-06 | 不新增实践卡、本轮尝试、实验状态、预期结果等独立管理模块；现实发现问题可以直接回到现有 Chat／笔记修正。 | IN_PROGRESS | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 需要精确场景与证据 |
| LOOP-01 | 正向：从关联卡片发现疑问，直接编辑或经 Chat 澄清，把新理解整理进对应笔记。反向：笔记相关内容变化后，核查并修订已有卡片，再继续复习。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| LOOP-02 | 双向闭环不是无条件自动同步，也不是两边全文相同。笔记保存结构与解释，卡片保存可检验的题目及答案。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| LOOP-03 | 卡片可打开来源笔记及可可靠定位的片段；笔记可查看相关卡片。从笔记出题或确认整理目标时自动建立关联，用户不手工维护编号。 | IN_PROGRESS | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/ImpressBatchParser.swift` | 候选：testBidirectionalVaultLinksUseExactIdentityAndPreserveOriginalCard（片段定位未验收） | 需要精确场景与证据 |
| LOOP-04 | 独立创建的卡片允许没有来源，不强制归入笔记。不按同名标题猜关联，不把新建的同名文件误认作旧来源。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| LOOP-05 | 讨论结论优先增量修订已有笔记的相关章节，不默认复制整段聊天，不默认创建多个“总结第 N 版”。没有合适目标时才明确选择其他笔记或新建。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| LOOP-06 | 新增知识点与修订已有知识点分开处理：前者可生成候选新卡；后者优先改原卡。不能通过不断生成新卡代替维护旧卡。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| LOOP-07 | 来源变化只提示核查，不自动断言旧卡错误。只改排版或无关章节，不应打扰相关卡。定位不可靠时如实提示，不能假装精确。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 源码已有交互及回归测试；需本次 SHA CI + 真机进一步验证 | 设备/授权 Vault/人工完整回执需复核 |
| LOOP-08 | 核查后可更新原卡，也可确认不受影响。提示低权重，不弹窗强迫处理，不形成必须清空的任务债务。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 源码已有交互及回归测试；需本次 SHA CI + 真机进一步验证 | 设备/授权 Vault/人工完整回执需复核 |
| LOOP-09 | 卡片先被修正时，不用尚未更新的旧笔记覆盖它。用户确认的具体修改是本次操作权威，笔记不是永远正确的裁决者。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 源码已有交互及回归测试；需本次 SHA CI + 真机进一步验证 | 设备/授权 Vault/人工完整回执需复核 |
| LOOP-10 | 一个修改预览流程可显示“笔记改动”和“关联卡片改动”；只显示实际必要的改动，允许分别勾选，最终一次确认所选对象。不强制两边同时改。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 源码已有交互及回归测试；需本次 SHA CI + 真机进一步验证 | 设备/授权 Vault/人工完整回执需复核 |
| LOOP-11 | 预览明确目标、位置、原文和修改结果；确认只针对当时看见的内容与版本。提案／目标／源文改变后旧确认失效。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 源码已有交互及回归测试；需本次 SHA CI + 真机进一步验证 | 设备/授权 Vault/人工完整回执需复核 |
| LOOP-12 | 文件与数据库不是单一事务。必须能报告部分成功、保留待处理项、幂等重试，不能重试时重复追加或误报全部成功。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 源码已有交互及回归测试；需本次 SHA CI + 真机进一步验证 | 设备/授权 Vault/人工完整回执需复核 |
| LOOP-13 | 退出、重启或重试不丢待确认内容；恢复后不自动重放已执行修改。撤销也要检查当前版本，不覆盖后来发生的合法编辑。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 源码已有交互及回归测试；需本次 SHA CI + 真机进一步验证 | 设备/授权 Vault/人工完整回执需复核 |
| LOOP-14 | 第一轮验收聚焦一篇笔记与一张原卡的真实往返。全库自动分析、跨多文档重构和批量联动全部旧卡，不作为第一轮前置条件。 | IN_PROGRESS | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CARD-01 | 问题、答案均能在首页完整阅读；内容长可以滚动，不能依靠截断或强制去另一页面才看完。全屏阅读可辅助，但不能掩盖首页缺陷。 | CODE_DONE | `aReuImpress-iPhone/View/ImCard/ImMemoryCard/ImMemoryCardView.swift` | 候选：testV3LongMarkdownQuestionAndAnswerHaveIndependentScrollRegions | 代码存在；不得自动推断 CI/真机 |
| CARD-02 | 问题／答案统一支持相应 Markdown 层级，重点处理 H1、H2、长段落、列表、引用、代码块、表格及图片卡既有语义。原始内容不因排版修改。 | CODE_DONE | `aReuImpress-iPhone/View/ImCard/ImMemoryCard/ImMemoryCardView.swift` | 候选：testV3LongMarkdownQuestionAndAnswerHaveIndependentScrollRegions | 代码存在；不得自动推断 CI/真机 |
| CARD-03 | 不靠无限缩字塞进卡片；字体、行距、标题层级、留白适配 iPhone 13、系统字号与深浅色。此前建议的字号仅是草案，未冻结像素值。 | IN_PROGRESS | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3CardComposerViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CARD-04 | 四向评分映射保持：左 Hard／困难，上 Good／良好，右 Easy／容易，下 Again／重来。未揭示答案不能评分。 | CODE_DONE | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3CardComposerViewController.swift` | 候选：testActualTinderSwipeSavesOneFSRSEventOnlyAfterRevealingAnswer | 代码存在；不得自动推断 CI/真机 |
| CARD-05 | 难度提示必须更明显，重新设计位置；拖动时知道当前方向和松手结果，取消拖动不记分。不能只追求轻巧装饰而牺牲可辨认性。 | IN_PROGRESS | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3CardComposerViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CARD-06 | 固定反馈浮层的位置、大小、显隐及触觉阈值仍需交互稿确认。正文滚动与四向评分必须隔离，但“边框／底部拖动区”的具体方案未最终锁定。 | IN_PROGRESS | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3CardComposerViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CARD-07 | 复习现场发现错误，直接打开同一张卡的编辑器，不经卡片集搜索。卡片集编辑仍保留，两入口共用实现。 | IN_PROGRESS | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift` | 候选：testQuickEditAndVerifiedSourceVisibleBeforeAnswerWithoutScoring（待最新 CI） | 需要精确场景与证据 |
| CARD-08 | 已讨论采用当前卡片上低权重直接编辑图标；不得退回只能多级菜单或卡片集编辑。最终图标具体位置需与长文／手势布局一起验证。 | IN_PROGRESS | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift` | 候选：testQuickEditAndVerifiedSourceVisibleBeforeAnswerWithoutScoring（待最新 CI） | 需要精确场景与证据 |
| CARD-09 | 保存回到同一张卡、同一轮复习，不重新构建全部队列。实际内容变化后不得使用旧答案提交评分；无改动保存不生成版本、不改变状态或不必要地重置揭示。 | CODE_DONE | `aReuImpress-iPhone/DataBase/V3/ReviewWCDBRepository.swift` | 候选：testCardContentHistoryIsAtomicNoOpAndRestoresWithoutRescoring | 代码存在；不得自动推断 CI/真机 |
| CARD-10 | 内容编辑与 FSRS 调度分离：不自动评分、改到期、重置熟练度或删除复习记录。实质变成另一道题时明确建议新建，不默默迁移旧进度。 | CODE_DONE | `aReuImpress-iPhone/DataBase/V3/ReviewWCDBRepository.swift` | 候选：testManagedCardCRUDPreservesIdentityAndFSRSReviewEvents | 代码存在；不得自动推断 CI/真机 |
| CARD-11 | 修改历史保留，但退出复习主操作区；可从编辑器访问。区分“卡片内容修改历史”“理解记录”“FSRS 复习历史”，不混成一种历史。 | CODE_DONE | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3CardComposerViewController.swift` | 候选：testContentHistoryIsEditorOnly | 代码存在；不得自动推断 CI/真机 |
| CARD-12 | 旧卡没有记录过的历史不能伪造。恢复旧内容应创建当前新版本，保留中间版本与图片引用。 | CODE_DONE | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3CardComposerViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| CARD-13 | 答案后 AI 讨论保持直接可达但低权重，不与“查看答案”和评分争夺主导。未揭示时不得因材料预览或来源入口静默泄露答案。 | IN_PROGRESS | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3CardComposerViewController.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CARD-14 | 既有产品契约要求选择题独立解析；当前已读输入／内容结构仅见题干、答案、选项、正确项，未见独立解析字段。后续必须核查并补齐或明确分期，不能因本轮聚焦普通卡而遗漏。 | IN_PROGRESS | `aReuImpress-iPhone/View/ImCard/ImMultipleChoiceCardView.swift` | 候选：testChoiceExplanationIsIndependentFromCorrectIndicesAndSurvivesLegacyReads（待最新 CI） | 需要精确场景与证据 |
| UI-01 | “查看答案”的颜色风格作为参考，编辑、AI 讨论、修改历史相关控件以及创建卡片 Segment 保持同一视觉体系。 | CODE_DONE | `aReuImpress-iPhone/Utils/Constansts/ImColorConstants.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| UI-02 | 统一色系不等于所有按钮一样大、一样填满。保留主／次层级；Segment 选中态统一、未选中态清楚；删除／错误仍有独立语义。 | CODE_DONE | `aReuImpress-iPhone/Utils/Constansts/ImColorConstants.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| UI-03 | 使用现有集中颜色、字体、间距、圆角配置；不在控制器里散布独立常量。优先原生组件，不为外观另造一套业务控件。 | CODE_DONE | `aReuImpress-iPhone/Utils/Constansts/ImColorConstants.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| UI-04 | 简体／繁体／英文、深浅色及跟随系统、系统字号、按钮可点击范围均列入验收；视觉统一不能以牺牲可读性为代价。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Constansts/ImColorConstants.swift` | 候选：ImpressV3SwipeIntegrationTests（须逐项确认覆盖） | 需要精确场景与证据 |
| AI-01 | 默认服务商入口收敛为 Claude、OpenAI、Gemini、DeepSeek，另加“自定义 API”。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAISettingsViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| AI-02 | 预设是配置入口，不虚构已配置可用的连接。未设置 Key 的项不能表现为可用；自定义为统一入口，不限制只能保存一个自定义厂商。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAISettingsViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| AI-03 | 保留用户现有 GLM／其他自定义连接和密钥引用。精简默认菜单不是删除已有账户或停止自定义兼容。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAISettingsViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| AI-04 | 所有涉及模型列表／选择的地方增加搜索：服务商目录、业务默认模型、Chat 会话选择、出题和后续编辑。搜索模型显示名和 ID，跨连接时标明所属连接。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAISettingsViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| AI-05 | 尽量共用一个可搜索选择器；搜索／刷新不丢失当前选择，不擅自换模型。区分无匹配、目录失败、未配置、不适合该任务。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAISettingsViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| AI-06 | 搜索过滤已取得的数据，不每输入一个字就调用推理或收费探针。普通 Chat、结构化出题、编辑提案的能力门槛分开，不能因缺 JSON 能力禁用普通对话。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAISettingsViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| AI-07 | 会话内模型覆盖不改变全局默认。保留删除单连接／全部连接能力，不自动重生已删除连接；Free QA 限制不扩散到普通厂商。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAISettingsViewController.swift` | 候选：testModelChooserShowsGLMAndDoesNotClaimFreeQAOnly | 代码存在；不得自动推断 CI/真机 |
| CHAT-01 | 明确为闪卡碎片理解与结构化笔记之间的共用讨论工作区；参考 ChatGPT 移动端的消息阅读、输入区与材料操作方式，而不是只换气泡。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CHAT-02 | 卡片、笔记和选中片段可进入同一 Chat；来源身份与会话身份分离，同一来源可有多次独立讨论。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CHAT-03 | 显式新建对话、一键继续已有对话、历史列表必须完整。新会话不覆盖旧消息，不自动继承全部旧上下文。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 候选：testNativeChatUIListsAndPreservesMultipleSessions | 代码存在；不得自动推断 CI/真机 |
| CHAT-04 | 消息支持 Markdown、选择、复制、合理的长文阅读；输入区支持多行、既有语音转文字、发送／停止，失败保留输入与历史。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 候选：testNativeChatRendersSelectableMarkdownAndVisibleContextControls | 代码存在；不得自动推断 CI/真机 |
| CHAT-05 | Chat 内可选择、预览提示词；默认“第一性原理＋奥卡姆剃刀”。会话临时修改不覆盖全局模板；保存为模板是另一个明确操作。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| CHAT-06 | 可搜索选择笔记／章节／片段以及卡片指定内容；材料标签可预览、移除、显示范围。添加资料不是立即发送，更不是授权写入。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CHAT-07 | 长文和长会话采用明确、有限的发送范围；不偷偷截断仍声称已读全文。本地保存完整历史不等于每次全部发送。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CHAT-08 | 首次发送材料、扩大范围或更换云端服务商时确认；进入 Chat 不自动发送；撤销权限后不能继续读取。图片未送入支持模型不能假装识图。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CHAT-09 | 结果按需整理到笔记／修改当前卡片／生成候选卡，不把所有回复自动转成待写内容。普通总结只回复。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 源码已有交互及回归测试；需本次 SHA CI + 真机进一步验证 | 设备/授权 Vault/人工完整回执需复核 |
| CHAT-10 | 保留会话、草稿、来源版本、待确认提案和执行回执；已保存／未发送／失败／待确认／已应用等状态不能混淆。 | IN_PROGRESS | `aReuImpress-iPhone/DataBase/V3/ReviewWCDBRepository.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CHAT-11 | 新建按钮、历史入口、模型选择、提示词标签和材料区的最终布局尚需图稿确认。“笔记 Tab 顶栏最近讨论”只是曾提出的方案，不自动增加为硬需求。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| CAL-01 | 四固定指标明确为睡眠、运动、饮食、阅读。不是旧三项，也不能把 reading 与 custom 混为一项。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-02 | 自定义目标独立、可动态添加／暂停／归档，不稀释固定指标的比较口径；未启用的占位自定义不阻塞评估。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-03 | 情绪独立记录、独立可视化，不和行为执行分相加；未填写情绪不遮住已完成的行为结果。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-04 | 完成、未完成、不适用、待评估分开；没有记录不是失败也不是 0。部分结果与最终结果明确区分。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-05 | 任务增减和目标调整保留每日快照／版本，未来停用不删除过去。旧时期没有阅读记录，不能补成阅读未完成。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-06 | 固定行为未完成时允许低摩擦、可跳过的主要原因选择；原因绑定具体任务和日期，不强制文字，不影响评分保存。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-07 | 周／月／年可视化必须能追溯到日期，看到具体哪项未完成和当时记录的原因。未记录原因如实显示，不让系统猜。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-08 | 统计区分“未完成任务次数”和“天数”；展示记录覆盖情况。任务目标变更需标记，不把标准变松导致的完成率上升直接解释成进步。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-09 | 目的是帮助观察中断、调整与恢复，不是惩罚或人格评判；减少因记录负担造成的额外压力，不要求无限解释。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-10 | 固定行为达成率拟替代旧正负总分，但具体最终公式、豁免分母、临时值展示、旧规则迁移、额外加减分去留要一起定稿，不提前改历史。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-11 | 对齐时间轴的行为／情绪分图、四项矩阵、月历热力图、年度月份概览均为候选呈现，不能当作已经批准的像素图纸。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-12 | 六类原因（时间不足、精力不足、临时打断、目标过高、忘记执行、其他）、原位展开、单选为已讨论建议；标签和最终交互仍待定。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-13 | 首页轻量入口、每日首次打开可选提醒、复习后提示、通知次数与跳过规则尚未冻结。每次冷启动必弹和不完成就永远催促均不是本轮实施要求。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-14 | 中断后恢复时间、重复目标提示、原因统计等扩展可后评估。恢复统计遇到缺失记录不能推断完整中断长度；不得把相关性当因果。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| CAL-15 | 睡眠归属哪一天、目标修改默认次日生效等需要确定；允许当天调整也须显式记录，而不是隐藏重算。 | DEFERRED | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| LOCAL-01 | 已记入公开仓库 Issue #4。iPhone 13 上验证中文笔记整理和卡片编辑的质量、加载／延迟／峰值内存／热状态／取消／前后台行为。 | DEFERRED | `README.md` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| LOCAL-02 | 不预先固定 Qwen 某版本、参数量、量化文件或 llama.cpp／MLX 技术选型；此前具体建议不是已批准集成方案，不复述未核实速度为性能承诺。 | DEFERRED | `README.md` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| LOCAL-03 | 本地模型只提出建议，不获直接写 Vault／数据库权限，不自动回退收费云端，不把权重加入 Git／LFS。 | DEFERRED | `README.md` | 保留规则，不作为本轮验收 | 需要精确场景与证据 |
| SAFE-01 | 复用 WCDB、现有编辑器、Chat 存储、备份与外部文件写入器；不另建竞争的卡片库、笔记库或备份系统。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| SAFE-02 | 人工与 AI 走同一受控写入链路：身份／权限、预期版本、完整预览、明确确认、写前备份、协调写入、回读、可恢复回执。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| SAFE-03 | 原始 Markdown 字节是权威，不用富文本或 HTML 反序列化覆盖原文。保护 Frontmatter、WikiLink、代码块、附件引用、编码和未修改区域。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| SAFE-04 | 生产 Vault 门禁保持。先在临时 fixture／用户独立授权的可丢弃测试 Vault 验证；生产开放需另行真机验收和具体范围授权。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：testUserApprovalRequiredAndSuccessfulFixtureWriteIsRecoverable | 代码存在；不得自动推断 CI/真机 |
| SAFE-05 | 草稿已存、测试源写入且回读、生产原件更新、云端同步是不同状态。不得以其中一种冒充另一种；完整产品闭环不能永远用“草稿已存”代替实际目标内容更新。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| SAFE-06 | 模型输出／笔记内容是待验证数据，不执行任意路径、命令或 SQL。密钥只走设备 Keychain；不进入源码、日志、CI 或报告；不自动上传私人材料。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| SAFE-07 | 备份／恢复应纳入新辅助记录的兼容与幂等策略；保留现有卡片、理解、提示词和校准数据。现有备份 ZIP 不因新功能就宣称加密。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImpressV3BackupCoordinator.swift` | 候选：testChatSessionReopensDraftAndPreservesHistoryInV3Backup | 需要精确场景与证据 |
| SAFE-08 | 保留 iOS 26+、iPhone 13 目标、三语言、深浅色、语音输入、卡片类型／批量导入、通知与备份既有能力。此次不重新大范围升级依赖。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |
| SAFE-09 | 未来开发仍优先公开仓库既有基线；遵守公开仓库最多 main＋一个开发分支的约束。分支名在真正获准开发时确定，不现在创建。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| SAFE-10 | 私有 main 同步、合并和分支清理不因本次定版自动获得授权；保留私有原始 icon、图片、Pods、历史文档，不反向泄露到公开仓库。 | CODE_DONE | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 代码存在；不得自动推断 CI/真机 |
| SAFE-11 | 编译、Mock、模拟器 XCTest、IPA 打包、真实云端推理、iPhone Keychain、File Provider 和生产写回分别验收。不得互相替代。 | IN_PROGRESS | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` | 候选：ReviewWCDBRepositoryTests（须逐项确认覆盖） | 需要精确场景与证据 |

## ACCEPT-01～12：代码、测试与真机证据逐项分层（正式验收尚未全部通过）

> 记录基准：上一完整成功 Run [39435321232](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39435321232)（`dabbc9db7aa964979af38f14760f39cfc6db04ff`、158/158 iOS XCTest、28/28 Core），不自动覆盖后续 SHA。表中测试是可定位证据而不是“ACCEPT 全场景 PASS”；最新改动应在最终 SHA 对应的完整 CI 中另行确认。测试方法名和精确路径的完整列表见 `SMOKE_TEST_MATRIX.md`。

| ID | 稳定需求 ID | 源码入口（均位于 `aReuImpress-iPhone/`，Package 路径特别注明） | 自动化定位测试 | 端到端状态 | 设备／遗留问题 |
| --- | --- | --- | --- | --- | --- |
| ACCEPT-01 | LOOP-03/AI-04 | `Utils/Public/ImAI/ImpressAIQuestionFlow.swift · sourceKey + DataBase/V3/ReviewWCDBRepository.swift · insertBatchCards` | `testNoteQuestionGenerationAnchorsOnlyUniqueEvidenceAndSkipsUnrelatedChanges；testDisposableVaultCardChatDuplexFullRoundTripAfterInterveningFSRS` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-02 | LOOP-03/04 | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/ImpressBatchParser.swift · ImpressBatchSourceKey；ImMarkdownViewController.swift · openVerifiedSourceSection` | `testBidirectionalVaultLinksUseExactIdentityAndPreserveOriginalCard；testOriginalCardOffersVerifiedSourceSectionWithoutReplacingFullNote` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-03 | CARD-01～06 | `View/ImCard/ImMemoryCard/ImMemoryCardView.swift · Markdown reader + VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift` | `testV3LongMarkdownQuestionAndAnswerHaveIndependentScrollRegions；testActualTinderSwipeSavesOneFSRSEventOnlyAfterRevealingAnswer` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-04 | CARD-07～09 | `VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift · quick edit + CardComposerViewController.swift · saveCard` | `testQuickEditAndVerifiedSourceVisibleBeforeAnswerWithoutScoring；testCardContentHistoryIsAtomicNoOpAndRestoresWithoutRescoring` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-05 | CARD-09/10 | `DataBase/V3/ReviewWCDBRepository.swift · updateManagedCard/contentRevision + review controller · re-reveal` | `testReturningAfterExternalCardEditRequiresRevealingTheNewAnswer；testManagedCardCRUDPreservesIdentityAndFSRSReviewEvents` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-06 | CHAT-02/03/10 | `Utils/Public/ImAI/ImpressAINativeChatViewController.swift · persistLocal/switchDiscussion + WCDB ChatSessions` | `testOneSourceSupportsTwoIndependentChatSessionsWithoutOverwritingHistory；testConfirmedDuplexHistoryRetainsReceiptsWhenNewerProposalIsSaved` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-07 | CHAT-05～08/AI-04 | `Utils/Public/ImAI/ImpressAINativeChatViewController.swift · performSend/ImpressChatNoteUploadGate` | `testAIQuestionMaterialRequiresExactLiveSourceBeforeHTTP；testChatNoteMaterialGateRejectsStaleForgedAndOversizedExcerpts；testChatProviderSwitchRequiresConsentAfterFailedFirstAttempt` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-08 | LOOP-10/11 | `Utils/Public/ImAI/ImpressAINativeChatViewController.swift · ImpressDuplexApprovalController` | `testDuplexDiffPreviewDisplaysExactVaultIDAndSourcePath；testDuplexProposalPersistsAcrossChatColdStartWithoutReplayingWrites` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-09 | SAFE-02～05 | `Utils/Public/ImFileManager/ImObsidianManager.swift · commitAuthorized/commitFixture + WCDB updateManagedCard` | `testUserApprovalRequiredAndSuccessfulFixtureWriteIsRecoverable；testExplicitQAUndoRestoresExactBOMCRLFBytesAndBlocksLaterConflict` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-10 | LOOP-12/13 | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/ImVaultSyncCore.swift · ImDuplexApprovalState + ImpressAINativeChatViewController.swift · execute/executeUndo` | `testDuplexPartialReceiptDoesNotReapplyWrittenQAFileOnCardConflict；testDuplexProposalPersistsAcrossChatColdStartWithoutReplayingWrites` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-11 | LOOP-07～09 | `ImMarkdownViewController.swift · ImpressNoteSourceImpactController/ImpressSourceImpactCardRevisionGate` | `testSourceImpactRevisesOriginalCardWithFreshFSRSAndExactSource；testSourceRevisionAcknowledgementKeepsOriginalCardAndReviewSchedule` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |
| ACCEPT-12 | LOOP-01～14 | `ReviewWCDBRepository.swift + ImObsidianManager.swift + ImpressAINativeChatViewController.swift` | `testDisposableVaultCardChatDuplexFullRoundTripAfterInterveningFSRS；testTwoApprovedNoteRevisionsRemainIndependentAndUndoInReverseOrder` | 自动化：部分覆盖，新增项待本 SHA CI；实际完整往返：**BLOCKED** | iPhone13/File Provider/Keychain/生产写回按项目单独 BLOCKED |

**生产写回状态**：`ImVaultGuardedWrite.productionWriteEnabled = false`。合成 fixture 写入、WCDB 数据测试、网络 Mock、无签名 IPA 与真机、File Provider/iCloud 真实回读、真实 Keychain 模型调用互不等价。只允许按照真实执行过的证据把单独层级标成 PASS；本表的 END-TO-END 最终状态仍为 BLOCKED。

## A01～A20：历史回归（旧业务编号，不覆盖最新契约）

| ID | 历史检查场景 | 状态 | 来源与证据入口 |
| --- | --- | --- | --- |
| A01 | Flashcards / Notes / Settings; calibration under Settings, correct tap router | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A02 | Current local Monday–Sunday, missing/unfinished/excused/future gap, accessible net-only fixed Y | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A03 | Home + adds 3 card types without restarting queue | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A04 | Edit QA/choices/image, no-op save, independent explanation | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A05 | Genuine content revision history and restore as new version | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A06 | Old LearningEntry archive compatibility/migration | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A07 | Edits and rating interleaving, no stale display and no FSRS reset | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A08 | Note search/selection/reader/draft and Markdown fidelity | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A09 | Chat model/prompt selection, provider scope | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A10 | Durable context, local Chat history and resume | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A11 | Failure, cancel, retries and no-cost fallback | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A12 | Distinguish summarize vs explicit update | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A13 | Card → Chat → explicit test note safe diff/write/readback | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A14 | Preview cancel/conflict/idempotence | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A15 | Multi-card targets/new-note name conflicts | NOT_STARTED | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A16 | Notes/Chat common candidate pool | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A17 | Source revision stale prompts | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A18 | Added history/Chat/proposals in ZIP and safe restore | NOT_STARTED | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A19 | iPhone 13 / Dynamic Type / light-dark / 3 languages / STT | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |
| A20 | No key leak, no production Vault tests/write, truthful status | IN_PROGRESS | [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；须对最新契约与 exact HEAD 复核 |

## OPEN-01～06：已确认职责与未定交互分开

| ID | 仍须核对 | 状态 | 规则 |
| --- | --- | --- | --- |
| OPEN-01 | 校准轻入口的位置及提醒方式。 | DEFERRED | 整体暂缓，不阻断知识闭环 |
| OPEN-02 | 长文滚动与四向评分的准确触发区域。 | IN_PROGRESS | 不得用位置未定取消功能；采用可逆原生方案但不声称视觉定版 |
| OPEN-03 | 现场编辑、AI 讨论、评分浮层、历史入口的最终位置与尺寸。 | IN_PROGRESS | 不得用位置未定取消功能；采用可逆原生方案但不声称视觉定版 |
| OPEN-04 | Chat 顶栏、新建／历史、模型、提示词与材料区的排列。 | IN_PROGRESS | 不得用位置未定取消功能；采用可逆原生方案但不声称视觉定版 |
| OPEN-05 | 统一修改预览与部分成功／重试的呈现。 | IN_PROGRESS | 不得用位置未定取消功能；采用可逆原生方案但不声称视觉定版 |
| OPEN-06 | 校准公式、原因、图型、通知、迁移等整体方案。 | DEFERRED | 整体暂缓，不阻断知识闭环 |

## 已识别但不得误报的高优先缺口

- **CHAT-09～10 / LOOP-07～13 / ACCEPT-08～12**：现有 `pendingProposal` 只是数据结构，尚缺同时选择笔记与原卡、具体片段统一 Diff、分对象执行回执、部分成功后幂等恢复及来源变化反向卡片核查。不可宣称知识闭环完成。
- **CHAT-03～04**：最新源码已有完整同源多会话列表／新建／选择、消息 Markdown 和草稿 CAS，但须完整旧设备真实数据库、强杀／断网／迁移与备份复原验证。
- **CARD-01～03**：长文和 Markdown 的 UIKit 自动化已有，iPhone 13 的动态字体、表格、滚动／滑动冲突仍需设备证据。
- **CARD-07～09、LOOP-03**：新顶端图标可在揭示前编辑／开启来源笔记，来源读操作仅按验证身份；iPhone 13 Safe Area、来源版本及权限撤销测试仍未完成。
- **CARD-14**：本轮实现解析编码和 Reveal 后展示，已补原生测试；需对应最新 CI 通过、三语言及旧数据回归。
- **SAFE-02～07**：现有 fixture/QA Vault 写入具备 SHA、协调、备份回读的基础；没有原卡与笔记一体化提交结果回执，不具备生产 Vault 修改授权。
- **真实调用**：未使用用户 Keychain 或在线收费 API；真实可用免费模型须官方证实且由用户配置，未完成应 BLOCKED。

## 交付判定

只有 `ACCEPT-01～12` 各自完整通过、全量自动化在同一源码 SHA 成功，并在 iPhone 13 与 File Provider 完成要求的设备验收，才能宣称正式交付。签名、实际密钥和生产 Vault 授权未具备时，只能提供已验证源码、QA 包、明确外部阻塞；本地回读≠iCloud 已同步。

## 2026-10-20：返回复习的内容版本防护

新增 `contentRevision` 回读校验：从 Chat、笔记等页面返回当前复习卡时，先关闭评分与揭示按钮，重新读取 WCDB 权威内容；如果原卡已发生变更，则原位置替换卡片内容、收起旧答案后才允许继续。XCTest：`testReturningAfterExternalCardEditRequiresRevealingTheNewAnswer`（待新 CI）；不宣称 iPhone 13 已验收。

## 2026-10-20 · Chat 结果的三个明确操作（阶段性业务入口）
- 已完成 AI 回复提供：**修订关联原卡**（使用原 cardID、共用 Editor、WCDB CAS，不自动粘贴模型输出；成功后禁止继续使用旧来源版本发送）、**在关联笔记草稿中整理**（现有保护草稿／Diff／QA 文件门禁）和 **生成关联笔记候选卡**（复用既有章节选择与候选池／明确发送确认）。只有有身份的对象显示相应操作；未完成回复不提供写入相关动作。
- Chat 提示词与材料可完整滚动预览，标签显示实际字节范围；不将只显示前 350/1000 字符冒充完整预览。
- 此阶段仍**不具备**统一笔记＋原卡双选 Diff、联合执行回执、部分成功幂等恢复及正式 Vault 写入；LOOP-10～13、ACCEPT-08～12 继续 BLOCKED，需后续整体集成和真机验证。

## 2026-10-20 · 原笔记／原卡两目标人工批准执行链（源码待 HEAD CI 验证）

- Chat 已完成回复提供「统一预览笔记与原卡修订」；从卡片进入绑定原 cardID，从笔记进入先列出同一个 Vault+相对路径的原卡供明确选择。并非将回复自动写入：用户先在唯一私有草稿里整理局部 Markdown，在原卡输入题目／答案，只有完整 diff 和明确双目标选择后才能执行。选择题／图片卡仍调用原卡编辑器，不在普通题答案输入框丢失选项或图片。
- 提案在原 Chat 会话的 WCDB 存储 `pendingDuplex`；只保留 Vault 身份、原始／拟议摘要、卡片字段、预期 revision、分对象状态及回执，不把整份 Obsidian Markdown 复制进 SQLite。原文字节与原文修改仍由私有 `ImVaultDraft` 保存。退出／重启仅恢复待办，不自动重放；可明确放弃尚未执行的目标。
- 文件写回沿用 `ImVaultGuardedWrite.commitAuthorized`（SHA 对照、独立恢复副本、NSFileCoordinator、回读，源版本冲突拒绝覆盖），原卡沿用 `ReviewWCDBRepository.updateManagedCard` 双 revision CAS（cardID／FSRS 不变）。执行先持久化状态，每一步持久化回执；失败后人工明确重试，仅处理尚未 applied 的目标，文件已写时 `alreadyApplied` 不重复追加。
- 笔记详情「核查笔记更新是否影响原卡」是手动反向核验入口。仅对已记录了 v2 源文件 digest 且 digest 变化的卡片提供核对；先在可滚动页面展示 **完整当前笔记** 与 **原卡题目、答案**；用户显式确认「不影响」后，只更新此卡的来源 digest 元数据，并由 WCDB CAS 保存，绝不伪称精确片段定位、自动污染其他原卡或产生 FSRS 评分。
- 自动化新增：双目标分状态／重启恢复／文件写后卡冲突回执／测试 fixture 再次提交幂等／不影响确认原卡身份与调度保护。此处「已有源码」**不等于**模拟器测试通过；以同 HEAD Actions 成功为准。**不代表**实际 iPhone 13／File Provider／生产 Obsidian 写回已完成。
- **安全门禁保持不变**：`ImVaultGuardedWrite.productionWriteEnabled = false`；仅 Debug 使用用户选择的独立 `Impress-Write-Test-Vault` 可以测试写源文件。正式 Vault 的生产写回仍须独立授权＋真机核验，未经授权不打开。真实密钥、联网大模型和 iCloud 远端同步均未由该实现验证。

## 2026-10-20 · 源文刷新、换行保持与完整历史回执补强（待最新 CI）

- 笔记详情从子页返回时会对授权的当前源文重新进行协调读取；打开 Chat、笔记出题和首次创建修改草稿前亦单独取 **最新** 源文件，而不相信旧详情页缓存。读取失败时停止使用旧快照执行资料相关操作，并明确提示页面可能已过期。刷新不会上传材料或自行更新闪卡。
- 统一 Diff 以原文件实际换行规则计算逻辑行。在 **整份统一 CRLF 或老式 CR** 文件中，UIKit 将编辑区换行为 LF 时不得误把 1 行文字编辑显示成数千行修改；混合换行仍须完整显示实际变更，不可静默归一化。与上一提交保持 BOM、换行的 `proposedBytes` 字节门禁配套。
- 过去确认的双目标提案和逐对象回执保存在同源 Chat `duplexHistory`，后续新提案不会覆盖旧收据。原 Chat 消息菜单可查看完整（不截断为前 100 条）修订回执历史、身份、版本及应用结果。记录在原 ReviewV3.sqlite 内复用备份；不把 Obsidian 原文复制进收据，也不暗中重试旧提案。
- 代码测试新增：长 CRLF 一行修改与混合行尾 Diff、双目标多次收据跨进程重建和原生回执列表。所有以上均只能称为**源码实现，未据此认证真机 iPhone 13 或生产 Vault 写入**；正式源文件写权限仍保持关闭，实机 QA 仅可用独立测试副本。

## 2026-10-20 · CAS 安全撤销与断点恢复（待最新 CI）

- 为本轮 LOOP-13 受控撤销新增 **反向独立审批**：已写入的原卡、独立 QA 笔记副本均可分别请求撤销。撤销必须先看到滚动完整反向 Diff / 原问题与原答案，再二次确认；不会把 Chat 文本当作可执行写入。
- 每个已批准目标保存 `undoing` → `reverted` 状态。崩溃后 `undoing` 只可由用户再次显式检查；**不能重新执行正向更改**，也不会自动执行逆向操作。每次写前保存意图，写后保存回执。Chat 记录历史保留原始应用结果及撤销结果。
- 原卡安全撤销在 WCDB 中生成一个新的内容版本 `.restored`；先比对原卡 cardID 与精确 content revision / 原始与拟议字段，随后使用当时最新的 FSRS 调度 revision CAS，**绝不删除、重置评分事件**。别人修改过原卡则冲突阻断。
- Obsidian 源文安全撤销只使用本机保护草稿保存的原始字节，将草稿的 `proposedBytes` 当作逆向基准，逐字节恢复原始 BOM、Frontmatter、WikiLink 与换行；重新走现有协调写入、版本 SHA、独立恢复副本及回读。**正式 Vault 不允许因撤销例外而写入**：只有获授权的 Debug 可丢弃测试副本才允许写回；没有授权时甚至不会记录不可执行的 undoing 状态。
- 历史收据可从原 Chat 打开，只有与收据对应的提案允许独立安全撤销；归档中的旧提案更新归档条目，不覆写较新的当前提案。验收证据必须核对当前 HEAD CI 与真机设备条件；单元测试不代替用户真实来源的 File Provider 授权。

## 2026-10-20 · 关联来源章节的可核实定位（下一 HEAD 待 CI）

- `ImpressBatchSourceKey` 在不迁移 WCDB / FSRS 的情况下增加 **v3 Vault + relativePath + 全文 SHA + 单一章节 SHA**。既有 v1（文件身份）和 v2（全文 SHA）链接继续读取；无来源的独立卡片保持原样。
- 笔记候选池 **仅当** AI 引用了一项有效证据、且该来源章节可在用户获授权的原 Markdown 中唯一匹配时，才将该章节 SHA 附在新创建的 **原 cardID** 来源链接上。引用多段、不存在的或内容重复的章节，一律保持旧 v2 文件级关联，禁止靠标题猜测。
- 反向「核查笔记更新是否影响原卡」读取真实当前 Markdown：即使全文 SHA 变化，仍能唯一定位并且内容 SHA 不变的 v3 来源章节，则**不**把无关章节的变动当作关联原卡需核查的任务；相关章节变化、章节定位丢失或历史 v1/v2 文件级关联均维持人工核查，不宣称可以定位发生改变的准确字符位置。
- 章节提取对 CRLF/CR 的逻辑换行进行一致解析，但不改动 Obsidian 原始字节；真实源文件写权限仍锁定。
- Portable XCTest 覆盖 v1/v2/v3 编解码、跨 Vault 区分和伪造摘要拒绝；iOS XCTest 覆盖单片段／多片段／重复章节降级、无关章节变化低打扰、相关章节变化不放过以及 WCDB 持续原卡身份。**必须以新提交对应完整 CI 成功为自动化证据，不代表 iPhone 13 真机验收**。

## 2026-10-20 · 当前证据范围、片段导航及 AI 上传前 Gate（下一批 CI 待验证）

- 已有来源章节 SHA 的原卡，从复习界面点「打开来源笔记」时重新查询当前 WCDB 的原 cardID 与 `contentRevision`、核实 Vault/path 后才允许进入笔记；源文详情保留完整 Obsidian Markdown 只读展示，同时提供「查看核实过的来源片段」，此入口重新按已授权的最新原文件检查唯一匹配的章节 SHA，匹配不唯一或失效则 **拒绝宣称精确定位**。
- 笔记指定章节 AI 出题在用户选择材料与模型、点击最终生成后，HTTP 请求前再次使用 File Provider 协调读取真实原文；核验 Vault 身份、全文 SHA、每个选定章节 ID/标题/全文与用户确认快照均一致。外部笔记被修改、权限撤销或材料变动即停止发送，不使用旧截图/本地过期材料，也不在验证失败时收费重试。
- 新增 iOS XCTest 使用无凭据、无网络、无真实 Vault 的临时 fixture，检查来源片段菜单和 v1/v2 兼容，以及 AI 出题发送前身份/全文/片段失败门禁。真实用户 Keychain、云端 API、iCloud 远端回读、iPhone 13 实机访问仍须另外验证。
- 所有更改仅在 `feature/impress-duplex-loop-v1`；正式 `ImVaultGuardedWrite.productionWriteEnabled = false` 不改变；不能把 Debug 测试副本回读误报为生产 Vault 写回。

## 2026-10-20 · 全业务可丢弃 Fixture 联调与安全修复（验收待最终 CI）

> **证据分级：代码/测试新增，不自动记为 PASS。** 仅在本仓库 `feature/impress-duplex-loop-v1`。新增 `ReviewWCDBRepositoryTests.testDisposableVaultCardChatDuplexFullRoundTripAfterInterveningFSRS`（需最新同 SHA CI 成功）使用 TemporaryDirectory 独立 Markdown、WCDB、带 BOM/CRLF 原件、安全草稿、核实章节、候选卡、FSRS、两条独立 Chat、双目标逐项修改、写前备份与回读、来源差异核对、幂等、逆向撤销及数据库冷启动恢复。**不使用用户 Vault、付费 API、Keychain 或 iCloud。**

**修正源文件：** `ImVaultSyncCore.swift` 持久 `undoing` 即使旧错误快照取消选择仍不能变成“已完成”；`ImpressAINativeChatViewController.swift` 不再允许“放弃未完成项”篡改撤销中的目标，双目标原卡正向 CAS 依据最新 FSRS revision 与原 contentRevision 而不是已过时调度快照；`ImMarkdownViewController.swift` 反向“无影响”确认同样以最新 FSRS revision 且保持内容/来源 CAS。Portable 回归 `ImVaultSyncCoreTests.deselectionCannotErasePendingUndoAfterCrash`。

**分层证据：** 新代码构建/Portable/iOS XCTest 均需后续实际 CI Run 和 exact commit SHA；真实 iPhone 13、真实 Files/iCloud Provider、在线模型推理、用户 Keychain 和正式 Vault 写回 **BLOCKED（外部设备或独立授权）**。十二项 ACCEPT **不能**因这个测试一次成功而全部标记 PASS；该测试覆盖部分 P0 数据链与故障分支，不执行完整触屏 UI / 真机操作。

### 2026-10-20 业务闭环补充：会话独立模型选择及目标身份

新增 `WCDBV3ChatSession.selectedChatModelID`（可选字段，对旧 JSON 向后兼容）；`ImpressAINativeChatViewController` 选定模型立即加入本地 CAS 会话持久化，恢复失效选择时不静默切换服务商。无原卡/笔记的独立 Chat 使用专属 `chat:standalone:v1` 会话源；笔记兜底使用 Vault ID + 全路径哈希，不基于同名标题。批准、撤销、反向核查、历史回执明确显示 Vault ID/完整相对路径。新增两项原生 XCTest，必须由最新同 SHA CI 提供真实结果；不解除生产写回禁令。

## 2026-10-20 · P0-03/05/07 多次原笔记修订原字节保存（待 CI）

发现单个可变 `ImVaultDraft` 被二次修订覆盖后，旧双目标 Chat 回执可能不能精确还原当时的 Markdown 差异。已在原有私有 `ImVaultPrivateStore` 中增加不可变、SHA 双版本＋完整 Vault 身份索引的 `ApprovedDraft`：提案持久化前先固化、执行／预览／撤销从相同快照提取；旧版无快照时只能从完全一致的原活动草稿安全回退，否则拒绝覆盖。新的草稿必须经用户选择、源文协调回读，保护先前已应用的内容与历史。新增三项原生 XCTest（见 SMOKE）。不增加笔记数据库，不改变 WCDB/FSRS 权威和三 Tab/校准暂缓；真机/云端/生产门禁仍 BLOCKED。

### 2026-10-20 · 长 Markdown 差异预览中的非连续真实修改

发现旧 `ImVaultDiff.summary` 只裁剪公共前缀/后缀：两个很远的改动会把中间全部未修改行当作变更，超过 200 行门限就阻断有效小规模修订。改为行级有界 CollectionDifference 并分离每个非连续修改区，只计数真实 +/- 行；超过安全处理预算的输入维持旧式保守完整预览和截断禁止批准，不会在漏显示内容时授权写入。两个纯 Swift Test 覆盖非相邻局部改动和分离增删，验收仍以相应 exact SHA CI / 真机为准。

### 2026-10-20 · LOOP-07～09/ACCEPT-11 反向核查直接编辑原卡

新增笔记来源变化核查页上的原 cardID 编辑入口，调用现有 `ImpressV3CardComposerViewController`，与“确认不影响”并列；所有卡片类型仍使用同一个编辑器。提交时核对当前 File Provider 来源身份和实际字节 SHA、原 cardID/contentRevision/source key，WCDB 以当时最新 FSRS revision 更新内容，不改变评分历史。人工确认后的新链接以最新版完整文件摘要保存，绝不将已变化的章节误标为“原精确锚点仍有效”。新增原生测试 `testSourceImpactIncludesDirectOriginalCardEditorAndUnaffectedChoice` 和 `testSourceImpactRevisesOriginalCardWithFreshFSRSAndExactSource`；本代码/测试尚需对应 HEAD 的 CI 实际成功，真机和生产 Vault 仍外部阻塞。

## 2026-10-20 · LOOP-08/09、CHAT-08、SAFE-02、ACCEPT-07/11 联合补强（最新 CI 待运行）

- **反向修订原卡**：新 `ImpressSourceImpactCardRevisionGate.refreshedInput` 显式拒绝无实际卡片内容变更的保存；不把点击编辑器保存伪装成“已人工确认不影响”。保存前重新确认 File Provider 授权 Vault ID、当前文件字节 SHA、原 cardID/source key/contentRevision；成功更新引用版本并保持 FSRS 事件和原卡身份。
- **Chat 原文发送前的精确范围 Gate**：`ImpressChatNoteUploadGate.validate` 检查真实已授权原文件全文 SHA、当前 Vault+全路径和本次会话身份；仅接受与当前原文件精确一致的全文（明确批准范围时）或当前唯一选取的 Markdown 章节正文。伪造材料、过期来源、另一会话材料、无授权摘要或超过 40KB 的引用被拒绝并保留未发送草稿；不默默截断、不收费重试。
- **跨服务商二次确认**：失败或取消的首次发送仍可包含私人材料；`ImpressChatProviderConsentGate` 检查已尝试用户消息中的 Provider ID。用户改选另一个服务商时必须重新批准，不再只以 `completed` 消息判断是否披露过材料。
- **不可加密 ZIP 的真实边界**：批准的 Markdown 字节恢复快照仅存本机受保护目录，普通备份 ZIP 不包含这些私人明文；历史回执与预览明确提示卸载/跨设备迁移后的安全撤销可能被阻断，不能把 SQLite Chat 元数据当作文件原件备份。
- **本批证据尚未通过**：新增 `testChatNoteMaterialGateRejectsStaleForgedAndOversizedExcerpts`、`testChatProviderSwitchRequiresConsentAfterFailedFirstAttempt`、`testDuplexSourceRevisionAndPrivacyWarningsAreLocalized` 等，须核对对应最新代码 SHA 的全部 Core/iOS XCTest、Debug/Release、ARM64/IPA。真实 iPhone13/Keychain/模型 HTTP/File Provider/生产 Vault 仍单独 BLOCKED。

### 2026-10-20 · CHAT-07 长历史远端范围告知

原本 `performSend` 使用最近 16 条已完成消息作为 API 上下文，但未提前告知用户早期消息被排除。现仅在已完成记录超过 16 时展示一次该会话的明确发送范围确认；用户可取消，早期消息依旧完整保存在 WCDB。切换 Chat 会话需要独立确认。新增原生 `testLongChatWarnsAboutRemoteWindowWithoutDiscardingLocalHistory`（待同 SHA CI），真实 API/设备验收不可据此标记 PASS。
