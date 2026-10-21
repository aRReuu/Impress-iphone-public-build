# Impress · 需求 × 代码 × 测试 × 设备验收执行矩阵

> **V1.1 开工前定稿；仅文档，未施工/未运行新测试。** 唯一需求权威：[PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)。只使用 `feature/impress-duplex-loop-v1`。本次确认的远端代码 SHA 为 `b7f5101187e37cffca87091bfd665eeaa94b9f59`（B0），成功 Actions Run `39443303363`（R0）；不是新 UI 或复杂格式的完成证据。
> 历史源码/测试不因新设计而被视为不存在。旧矩阵的 42 IN_PROGRESS、25 CODE_DONE、18 DEFERRED 仅作为迁移前记录；表中“旧”列完整保留。此次状态调整只反映需求变化与已知差距，不假造逐项测试结果。旧章节里“尚无统一预览/回执”的说法已过时，现有代码应复用。

## 1. 状态与证据分离

设计已定与实现已完不是同一维度。`IN_PROGRESS` 可以表示基线已实现、但新规格/异常/证据未补齐；不是命令重写全部。`CODE_DONE` 仅源码层，仍须复核；`TEST_PASS` 必须有该方法在精确 SHA 的结果；`E2E_PASS` 必须真实连续 UI 操作；`NOT_RUN` 无执行证据；`DEVICE_BLOCKED` 有明确外部设备/授权限制；`DEFERRED` 明确暂缓；`FAIL` 已复现失败。不得把内部缺代码写成设备阻塞。
本轮没有把任何条目提升为 TEST_PASS/E2E_PASS。旧 CI 只认证 B0 的原测试范围；UI 参数验证不是已批准像素验收。

## 2. 源码与测试定位索引

源码缩写均为精确仓库路径/同文件符号：

| 键 | 路径/入口 |
| --- | --- |
| NAV | `aReuImpress-iPhone/Base/ImTabBarViewController.swift` |
| REVIEW | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3ReviewViewController.swift` |
| CARD | `aReuImpress-iPhone/View/ImCard/ImMemoryCard/ImMemoryCardView.swift`；同目录上层 `ImMultipleChoiceCardView.swift` |
| OVERLAY | `aReuImpress-iPhone/View/ImCard/ImMemoryCard/ImMemoryCardOverlay.swift`；`Utils/Public/ImSwipQuickCard/SwipeCard/SwipeCard.swift` |
| EDITOR | `aReuImpress-iPhone/VC/MainVCs/ImCardVC/ImpressV3CardComposerViewController.swift` |
| CHAT | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAINativeChatViewController.swift`；Change/Approval/History controllers |
| DB | `aReuImpress-iPhone/DataBase/V3/ReviewWCDBRepository.swift` |
| NOTE | `aReuImpress-iPhone/VC/SubVCs/ImNoteListVC/ImMarkdownVC/ImMarkdownViewController.swift`；SourceImpactCardRevisionGate |
| SELECT | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAIQuestionFlow.swift` |
| VAULT | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImObsidianManager.swift` |
| CORE | `Packages/ImpressReviewCore/Sources/ImpressReviewCore/ImVaultSyncCore.swift`；`ImpressBatchParser.swift` |
| STYLE | `aReuImpress-iPhone/Utils/Constansts/ImColorConstants.swift`；`MarkdownKitRenderer.swift` |
| AI | `aReuImpress-iPhone/Utils/Public/ImAI/ImpressAISettingsViewController.swift`；`ImpressAIService.swift` |
| BACKUP | `aReuImpress-iPhone/Utils/Public/ImFileManager/ImpressV3BackupCoordinator.swift`；`ImpressV3BackupArchive.swift` |
| CAL | `aReuImpress-iPhone/VC/MainVCs/ImCalibrationVC/ImpressCalibrationViewController.swift`；`Packages/ImpressReviewCore/Sources/ImpressReviewCore/CalibrationScoreCore.swift` |
| GUARD | `.github/scripts/verify_product_contract.py`；`.github/workflows/public-ios-build.yml` |

B-* 为**已有证据定位**（不能仅凭名称标 PASS）；P-* 为**待实现测试名**，当前 NOT_RUN。已有测试主要位于 `aReuImpress-iPhoneTests/V3/ReviewWCDBRepositoryTests.swift`、`ImpressV3SwipeIntegrationTests.swift`；Cal 位于 `ImpressCalibrationIntegrationTests.swift`；纯 Core 位于 Package Tests。

| 键 | 方法/范围 |
| --- | --- |
| B-R | `testActualTinderSwipeSavesOneFSRSEventOnlyAfterRevealingAnswer`；`testAllFourDirectionsPersistCorrectFSRSRating` |
| B-E | **旧揭示前可见断言需替代并保留来源/FSRS 安全验证**：`testQuickEditAndVerifiedSourceVisibleBeforeAnswerWithoutScoring`；`testCardContentHistoryIsAtomicNoOpAndRestoresWithoutRescoring`；`testReturningAfterExternalCardEditRequiresRevealingTheNewAnswer` |
| B-F | `testManagedCardCRUDPreservesIdentityAndFSRSReviewEvents`；`testContentHistoryIsEditorOnly`；`testChoiceExplanationIsIndependentFromCorrectIndicesAndSurvivesLegacyReads` |
| B-C | `testOneSourceSupportsTwoIndependentChatSessionsWithoutOverwritingHistory`；`testUnsentChatModelAndPromptSurviveColdStartAndLegacyJSON` |
| B-M | `testAIQuestionMaterialRequiresExactLiveSourceBeforeHTTP`；`testChatNoteMaterialGateRejectsStaleForgedAndOversizedExcerpts`；`testChatProviderSwitchRequiresConsentAfterFailedFirstAttempt`；`testLongChatWarnsAboutRemoteWindowWithoutDiscardingLocalHistory` |
| B-L | `testNoteQuestionGenerationAnchorsOnlyUniqueEvidenceAndSkipsUnrelatedChanges`；`testBidirectionalVaultLinksUseExactIdentityAndPreserveOriginalCard`；`testOriginalCardOffersVerifiedSourceSectionWithoutReplacingFullNote` |
| B-D | `testDuplexDiffPreviewDisplaysExactVaultIDAndSourcePath`；`testDuplexProposalPersistsAcrossChatColdStartWithoutReplayingWrites`；`testDuplexPartialReceiptDoesNotReapplyWrittenQAFileOnCardConflict` |
| B-U | `testUserApprovalRequiredAndSuccessfulFixtureWriteIsRecoverable`；`testExplicitQAUndoRestoresExactBOMCRLFBytesAndBlocksLaterConflict`；`testTwoApprovedNoteRevisionsRemainIndependentAndUndoInReverseOrder` |
| B-S | `testSourceImpactRevisesOriginalCardWithFreshFSRSAndExactSource`；`testSourceImpactIncludesDirectOriginalCardEditorAndUnaffectedChoice`；`testSourceRevisionAcknowledgementKeepsOriginalCardAndReviewSchedule` |
| B-X | `testDisposableVaultCardChatDuplexFullRoundTripAfterInterveningFSRS`（服务层，不是 UI E2E） |
| B-B | `testChatSessionReopensDraftAndPreservesHistoryInV3Backup`；`testConfirmedDuplexHistoryRetainsReceiptsWhenNewerProposalIsSaved` |
| B-A | `testModelChooserShowsGLMAndDoesNotClaimFreeQAOnly`；原 AI/Keychain/模型目录 suite，施工前逐项定位 |
| P-N | `testFourTabsOpenExistingCalibrationWithoutRewritingScores`（计划） |
| P-R | `testQuestionIsAtMostThreeLinesAndFullTextReturnsWithoutRating`；`testOnlyOneEditAndChatPairInsideCard`；`testCenteredRatingFeedbackDoesNotInterceptReading`（计划） |
| P-C | `testMinimalChatChromeAndComposerStates`；`testHistorySearchRestoresMatchedSessionContext`；`testDeleteConversationPreservesAppliedReceiptsAndDoesNotResurrect`（计划） |
| P-M | `testStructuredSelectionMatchesVisibleSourceRanges`；`testCompositeMaterialsDoNotExpandConsent`（计划） |
| P-V | `testSupportedCompositeFormatsRenderSelectAndRestore`；`testLegacyAnchorsSurviveParserUpgrade`；`testReadTypeExpansionDoesNotAuthorizeWrites`（计划） |
| P-X | `testUIKnowledgeLoopAndReverseReviewAcrossColdLaunch`（计划，必须 XCUITest 连续操作，不以服务函数拼接冒充） |
| P-W | **已实测：** `CalibrationWidgetProjectionTests`（8 项：DST、Gregorian 日期验证、全豁免 nil、部分评估、跨年、隐私与坏快照），e6b77b2 / Core PASS；**待新 CI：** `testWidgetWeekMonthYearDeepLinksReusePrimaryCalibrationController`；**待设备：** 六原生 Widget 布局、App Group entitlement/安装（不可将 Core PASS 冒充设备 PASS） |

## 3. 85 个稳定需求 ID

“旧”列来自 B0 中既存矩阵，仅用于追溯；“当前”是本规格待施工状态。测试列 B-* 全部绑定 B0/R0 的待核对定位，P-* 没有执行结果。所有非暂缓项的 V1.1 UI E2E/设备状态目前为 NOT_RUN/DEVICE_BLOCKED；原因见 SMOKE 和 QA。完整条件以产品稿正文为准。

| ID（要求正文见产品稿同编号） | 旧 | 当前 | 入口 | 证据定位/待补 |
| --- | --- | --- | --- | --- |
| NAV-01 | CODE_DONE | IN_PROGRESS | NAV/REVIEW/CAL | P-N；B-R |
| NAV-02 | CODE_DONE | CODE_DONE | NAV/REVIEW/CAL | P-N；B-R |
| NAV-03 | IN_PROGRESS | IN_PROGRESS | NAV/REVIEW/CAL | P-N；B-R |
| NAV-04 | CODE_DONE | CODE_DONE | NAV/REVIEW/CAL | P-N；B-R |
| NAV-05 | IN_PROGRESS | IN_PROGRESS | NAV/REVIEW/CAL/Widget（待建） | P-N/P-W；B-R |
| NAV-06 | IN_PROGRESS | IN_PROGRESS | NAV/REVIEW/CAL | P-N；B-R |
| LOOP-01 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-02 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-03 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-04 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-05 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-06 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-07 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-08 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-09 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-10 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-11 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-12 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-13 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| LOOP-14 | IN_PROGRESS | IN_PROGRESS | CHAT/NOTE/DB/VAULT/CORE | B-L/B-D/B-S/B-X；P-X |
| CARD-01 | CODE_DONE | IN_PROGRESS | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-02 | CODE_DONE | IN_PROGRESS | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-03 | IN_PROGRESS | IN_PROGRESS | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-04 | CODE_DONE | CODE_DONE | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-05 | IN_PROGRESS | IN_PROGRESS | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-06 | IN_PROGRESS | IN_PROGRESS | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-07 | IN_PROGRESS | IN_PROGRESS | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-08 | IN_PROGRESS | IN_PROGRESS | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E（旧可见性待替代）/B-F；P-R |
| CARD-09 | CODE_DONE | CODE_DONE | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-10 | CODE_DONE | CODE_DONE | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-11 | CODE_DONE | CODE_DONE | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-12 | CODE_DONE | CODE_DONE | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-13 | IN_PROGRESS | IN_PROGRESS | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| CARD-14 | IN_PROGRESS | IN_PROGRESS | REVIEW/CARD/EDITOR/OVERLAY/DB | B-R/B-E/B-F；P-R |
| UI-01 | CODE_DONE | IN_PROGRESS | STYLE/NAV/REVIEW/CHAT/EDITOR | P-N/P-R/P-C；保存 checkmark 的三语言/主题原生截图 |
| UI-02 | CODE_DONE | IN_PROGRESS | STYLE/NAV/REVIEW/CHAT | P-N/P-R/P-C；三语言/主题截图 |
| UI-03 | CODE_DONE | IN_PROGRESS | STYLE/NAV/REVIEW/CHAT | P-N/P-R/P-C；三语言/主题截图 |
| UI-04 | IN_PROGRESS | IN_PROGRESS | STYLE/NAV/REVIEW/CHAT | P-N/P-R/P-C；三语言/主题截图 |
| AI-01 | CODE_DONE | CODE_DONE | AI/CHAT | B-A/B-M；真实服务 DEVICE_BLOCKED |
| AI-02 | CODE_DONE | CODE_DONE | AI/CHAT | B-A/B-M；真实服务 DEVICE_BLOCKED |
| AI-03 | CODE_DONE | CODE_DONE | AI/CHAT | B-A/B-M；真实服务 DEVICE_BLOCKED |
| AI-04 | IN_PROGRESS | IN_PROGRESS | AI/CHAT | B-A/B-M；真实服务 DEVICE_BLOCKED |
| AI-05 | IN_PROGRESS | IN_PROGRESS | AI/CHAT | B-A/B-M；真实服务 DEVICE_BLOCKED |
| AI-06 | IN_PROGRESS | IN_PROGRESS | AI/CHAT | B-A/B-M；真实服务 DEVICE_BLOCKED |
| AI-07 | CODE_DONE | CODE_DONE | AI/CHAT | B-A/B-M；真实服务 DEVICE_BLOCKED |
| CHAT-01 | IN_PROGRESS | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-02 | IN_PROGRESS | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-03 | CODE_DONE | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-04 | CODE_DONE | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-05 | CODE_DONE | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-06 | IN_PROGRESS | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-07 | IN_PROGRESS | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-08 | IN_PROGRESS | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-09 | IN_PROGRESS | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-10 | IN_PROGRESS | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CHAT-11 | IN_PROGRESS | IN_PROGRESS | CHAT/DB/SELECT/NOTE | B-C/B-M/B-D；P-C/P-M/P-X |
| CAL-01 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-02 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-03 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-04 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-05 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-06 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-07 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-08 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-09 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-10 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-11 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-12 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-13 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-14 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| CAL-15 | DEFERRED | DEFERRED | CAL | 原 Cal suite 只回归，不实施新规则 |
| LOCAL-01 | DEFERRED | DEFERRED | README / Issue #4 | DEFERRED；不下载/集成模型 |
| LOCAL-02 | DEFERRED | DEFERRED | README / Issue #4 | DEFERRED；不下载/集成模型 |
| LOCAL-03 | DEFERRED | DEFERRED | README / Issue #4 | DEFERRED；不下载/集成模型 |
| SAFE-01 | IN_PROGRESS | IN_PROGRESS | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-02 | IN_PROGRESS | IN_PROGRESS | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-03 | CODE_DONE | IN_PROGRESS | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-04 | CODE_DONE | CODE_DONE | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-05 | IN_PROGRESS | IN_PROGRESS | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-06 | CODE_DONE | IN_PROGRESS | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-07 | IN_PROGRESS | IN_PROGRESS | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-08 | IN_PROGRESS | IN_PROGRESS | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-09 | CODE_DONE | CODE_DONE | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-10 | CODE_DONE | CODE_DONE | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |
| SAFE-11 | IN_PROGRESS | IN_PROGRESS | VAULT/CORE/DB/BACKUP/GUARD | B-D/B-U/B-B；P-V/P-X；隐私检查 |

## 4. 新增能力的子项追踪（不增加/更名 85 个主 ID）

| 子项 | 父 ID | 施工范围 | 当前状态 | 验证 |
| --- | --- | --- | --- | --- |
| UI-03.a | UI-03/NAV-03/SAFE-03 | 笔记 Tab 一级页为 Obsidian 式原生折叠树；只显示名称、层级及必要 chevron，无图标/路径/摘要；覆盖全树搜索、来源身份、授权回读、分页与展开态 | IN_PROGRESS | 原生树形算法/控制器测试、SMOKE/设备视觉与 Vault 负向测试 |
| CARD-08.a | CARD-08/CARD-13/CARD-09 | 卡内编辑/讨论只在揭示后同时显示；内容失效/换卡/未揭示隐藏且不可聚焦，保 FSRS | CODE_DONE；原生 XCTest PASS（e6b77b2），设备视觉待验 | P-R；旧 B-E 揭示前断言已替换；ACCEPT-03/05 |
| UI-01.a | UI-01/UI-03/UI-04 | 新增页保存为统一导航样式的 SF Symbols checkmark；保校验/防重复/VoiceOver | CODE_DONE；原生 XCTest PASS（e6b77b2），视觉/真机待验 | P-R、ACCEPT-04，原生截图待验 |
| NAV-05.w | NAV-05/UI-03/UI-04 | WidgetKit 周近7、月近30、年本年 × Small/Medium 六视图；记录状态 B 方案；三时段深链 | 旧状态点/矩阵版本 CODE_DONE；用户新指定同源二维图表布局 IN_PROGRESS，完成 Core 共用绘制、六布局/视觉验收后才能标记代码完成 | P-W；W01～W06、W12 深链待实测、W14 unsigned 构建 PASS |
| SAFE-08.w | SAFE-08/SAFE-07/NAV-05 | 最小只读 App Group 统计快照、Timeline/WidgetCenter、跨日/恢复、签名与隐私 | CODE_DONE（已有最小快照/Portable Core TEST_PASS；新增同口径绘图投影与负向验证待补），签名/真实 App Group 与恢复设备待验 | P-W；W07/W08/W11 Core 已验证、W09/W10/W15 需设备及负向证据 |
| CHAT-03.a | CHAT-03 | 全本地会话搜索、正文命中定位、跨源上下文恢复 | NOT_STARTED | P-C |
| CHAT-03.b | CHAT-03/10, SAFE-07 | 明确删除、未执行取消、已执行回执保留可达、防异步复活 | NOT_STARTED | P-C/B-B |
| CHAT-06.a | CHAT-06, LOOP-03 | 真实层级/片段范围、父子去重、边界结构、源码映射 | IN_PROGRESS | P-M/B-L |
| CHAT-06.b | CHAT-06/08, SAFE-06 | 嵌入依赖清单、循环/权限/预算、选材与发送同范围 | NOT_STARTED | P-M |
| CHAT-06.c | CHAT-06, UI-03 | Excalidraw/Obsidian封装、资源、范围与版本化预览 | NOT_STARTED | P-V |
| CHAT-06.d | CHAT-06, SAFE-04 | JSON Canvas节点/分组/边/文件subpath，仅读不写 | NOT_STARTED | P-V |
| CHAT-06.e | CHAT-06, UI-03 | Mermaid/Markmap导图显示、分支/子树选择 | NOT_STARTED | P-V |
| CHAT-06.f | CHAT-07/08 | 文字/结构与图像理解分离，明确图像授权/模型能力 | NOT_STARTED | P-M/P-V |
| SAFE-03.a | SAFE-03, LOOP-03 | v1/v2/v3旧锚点、旧Chat JSON、备份兼容及安全降级 | IN_PROGRESS | B-L/B-B/P-V |
| SAFE-06.a | SAFE-06 | 本地资源/网页沙箱；不执行模板/插件脚本、不隐式外联 | IN_PROGRESS | P-V/负向资源测试 |
| SAFE-08.a | SAFE-08, UI-03 | 仅必要依赖升级，许可/版本/离线打包/性能证据 | NOT_STARTED | 依赖清单＋iPhone13资源记录 |

子项 NOT_STARTED 指明确新增适配/测试，不是否认现有 Markdown、Vault、Chat 基础。已识别格式不许一律降级为纯文本就宣布完成。

## 5. ACCEPT / OPEN / 历史证据处理

ACCEPT-01～12 的逐项入口、已有方法、计划、SHA/Run、Simulator/E2E/Device/阻塞见 [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md)；完整标准见产品稿。不得用 B-X 一项服务层测试代替十二项 UI 验收。
OPEN-01：Tab 入口已定，首页轻入口/新提醒不做；OPEN-02：手势区域/参数待原生验证；OPEN-03：右上双图标/中央反馈/编辑器历史已定，token 待验证；OPEN-04：Chat结构已定；OPEN-05：双目标业务规则已定，复用现有预览，视觉微调未认证；OPEN-06：校准新规则 DEFERRED。
历史 A01～A20 保留在 SMOKE 追踪。旧 A01 三 Tab/仅设置校准与 A02 首页周图已被替代，旧 CARD-01 全文首页滚动用例不能反向覆盖三行题干；其他卡片/来源/备份/语音回归仍有效。旧“尚无提案/回执”的阶段性描述不再代表当前代码。

## 6. 施工批次与可交付边界

G0 重新读取 HEAD、文档、测试/工作流，确认指定分支与安全门禁。
G1 完成 Chat/闪卡/四 Tab/历史功能、原生视觉记录与回归，更新旧布局断言而非删安全测试。
G2 复杂样例“显示→选材→实际预览→Chat→重开”，依赖验证后集成所有明确格式；不复制笔记库/插件平台。
G3 复用已有 Duplex/SourceImpact，实现 P0-A 实际建议到提案、P0-B 连续 UI、P0-C 故障恢复、P0-D 反向核查及备份兼容。
G4 同最终 SHA 全套 CI/证据/QA IPA；只有外部设备/Keychain/Files/授权可单独 BLOCKED，不可藏内部缺口。`productionWriteEnabled = false` 永不因集成或撤销而放开。

## 2026-10-21 · V1.1 实现核验补记（不替代85项原始需求状态）

工作分支仅 `feature/impress-duplex-loop-v1`，起点 `44fded0b`。代码证据：`b527764` LZ-String compressed-json；`b1211f3` 绘图阅读/选材/Chat 精确门禁；`692fa1c`、`5bc369e`、`2d2e051` 内嵌 PNG/JPEG 限量解码和测试；`9cd3f73`、`6c2808f` 人工只读中断核验；`b7a3e76` 原生 XCUITest Target + 四Tab冷启动导航/截图。

| 子项 | 当前实际状态 | 未完成边界 |
| --- | --- | --- |
| Excalidraw 压缩 JSON 及基础空间图形 | CODE_DONE（子项） | 全格式、完整附件、旋转细节/区域选择、全 UI 验收 NOT_RUN |
| Excalidraw 元素选材与 Chat | CODE_DONE（子项） | Vault/SHA/元素核验已接入；模型视觉理解仍独立许可，真实 UI E2E NOT_RUN |
| Mermaid、Markmap | IN_PROGRESS | 离线成熟引擎/图形选材/Chat 往返尚未实现 |
| F03/F04 中断核验 | CODE_DONE（子项） | F01～F13 全部异常注入未整体 TEST_PASS |
| 原生 XCUITest | CODE_DONE（四Tab测试） | 18步连续 E2E NOT_RUN，不能用四Tab冒烟代替 |
| ACCEPT-01～12 / QA IPA | NOT_RUN（最新版完整证据） | 必须按最终 HEAD 对应同一套成功 Actions 和真实 UI 回读 |

原有 85 个需求 ID、ACCEPT-01～12、OPEN-01～06、DEFERRED 均不作隐式变更。永久保持 `ImVaultGuardedWrite.productionWriteEnabled = false`；真实日常 Obsidian Vault 禁止自动写入测试。

## 2026-10-21 · 新增子项的验收边界

仅在 `feature/impress-duplex-loop-v1` 的 `a6051b46c78910cdb87ca8d16f8ccbd5b4467967` 代码核对后定稿：`CARD-08.a/UI-01.a/NAV-05.w/SAFE-08.w` 全部 **IN_PROGRESS/实际新测试 NOT_RUN**。不得把原校准器已有周/月/年曲线或主 App App Group entitlement 误标为 Widget 已实现。旧 QuickEdit **查看答案前可见**测试断言必须以当前产品需求替代，同时保留来源安全与评分守卫；原 85 个主 ID、12 ACCEPT、6 OPEN、18步 E2E、F01～F13、CAL-01～15 DEFERRED 不增删。完整细节以产品稿 §2.2/2.3 和 SMOKE §9 为准。

## 2026-10-21 · e6b77b2 实际 CI 证据（区分代码完成与验收完成）

- **精确提交**：`e6b77b2430c9f3ca6568d4471c3a1e327cfd054a`；**GitHub Actions Run**：`39586231838`，**Conclusion SUCCESS**。Portable Swift Core **99 个 PASS**；iOS 原生 XCTest **185/185 PASS**；XCUITest **7/7 PASS**（含 Excalidraw、Markmap、JSON Canvas、现有连续双目标审批/冷启动往返）。
- Debug 与 Release iOS Simulator PASS；unsigned Debug iPhoneOS ARM64 PASS；真实 `PlugIns/ImpressCalibrationWidgets.appex/ImpressCalibrationWidgets` 存在、Mach-O **arm64**、NSExtensionPointIdentifier 正确；IPA ZIP 自检 PASS。产物名 `Impress-V3.1-P0P2-e6b77b2430c9-unsigned.ipa`，大小 **7,430,753 字节**，SHA-256 `b7b1174a969103b1ec1dbf16b29aa8f7cf52b8d54a7b10d1146fcbbafba90b57`。
- **仍然 NOT_RUN / DEVICE_BLOCKED**：真实 iPhone13 安装/签名与 App Group provisioning、实际 SpringBoard 添加/Small+Medium 六布局截图、Timeline 生效时间、真实文件提供者权限、真实 AI Key/HTTP。不能因 CI success 直接提升全量 ACCEPT-01～12/18 步/F01～F13 为 E2E_PASS。Debug QA Vault 与生产 Vault 权限绝不混淆。
- **下一轮待运行**：`W12` 三时段真实系统 URL 深链 UI 测试；此前通过的双目标 UI E2E 将补强已批准源码重启回读、反向原卡核查和撤销入口检查。下一 SHA 的结果必须**重新归档**，不能继承 e6b77b2 的 PASS。
