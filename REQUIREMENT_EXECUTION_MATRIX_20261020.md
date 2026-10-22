# Impress · 需求 × 代码 × 测试 × 设备验收执行矩阵

> **V1.1 当前执行矩阵；开工前状态保留在“旧”列，已有持续施工和部分真实测试。** 唯一需求权威：[PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md)。只使用 `feature/impress-duplex-loop-v1`。本次确认的远端代码 SHA 为 `b7f5101187e37cffca87091bfd665eeaa94b9f59`（B0），成功 Actions Run `39443303363`（R0）；不是新 UI 或复杂格式的完成证据。
> 历史源码/测试不因新设计而被视为不存在。旧矩阵的 42 IN_PROGRESS、25 CODE_DONE、18 DEFERRED 仅作为迁移前记录；表中“旧”列完整保留。此次状态调整只反映需求变化与已知差距，不假造逐项测试结果。旧章节里“尚无统一预览/回执”的说法已过时，现有代码应复用。

## 1. 状态与证据分离

设计已定与实现已完不是同一维度。`IN_PROGRESS` 可以表示基线已实现、但新规格/异常/证据未补齐；不是命令重写全部。`CODE_DONE` 仅源码层，仍须复核；`TEST_PASS` 必须有该方法在精确 SHA 的结果；`E2E_PASS` 必须真实连续 UI 操作；`NOT_RUN` 无执行证据；`DEVICE_BLOCKED` 有明确外部设备/授权限制；`DEFERRED` 明确暂缓；`FAIL` 已复现失败。不得把内部缺代码写成设备阻塞。
原 B0 定稿时没有新 TEST_PASS/E2E_PASS；此后在精确 SHA 的原生 XCTest/XCUITest 已有分层 PASS，按本矩阵增量记录。原 UI 及当前 Widget 真机像素/完整十八步验收仍需独立证据。

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
| CHAT-03.a | CHAT-03 | 全本地会话搜索、正文命中定位、跨源上下文恢复 | CODE_DONE；历史筛选/正文命中ID/跨源激活已有实现，原生 XCTest testHistorySearchRestoresMatchedSessionContext 已在 Run #100 PASS；完整真实 UI/设备待验 | P-C，ACCEPT-06 |
| CHAT-03.b | CHAT-03/10, SAFE-07 | 明确删除、未执行取消、已执行回执保留可达、防异步复活 | CODE_DONE；WCDB tombstone/执行回执保全/竞态阻断与滑动确认已实现，原生 XCTest testDeleteConversationPreservesAppliedReceiptsAndDoesNotResurrect 在 Run #100 PASS；真实 UI/备份设备待验 | P-C/B-B，ACCEPT-06/10 |
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

## 2026-10-22 · 用户增量：CAL-01～03 有限解冻 / Widget 故障

| 子项 | 位置 | 本次执行与下一步验证 |
| --- | --- | --- |
| CAL-01.reading | CalibrationCheckInCore, CalibrationLocalStore, CalibrationViewController | 新四项 sleep/exercise/nutrition/reading；四项即可结算；同 SHA Core/Native XCTest 待实际 CI |
| CAL-02.legacy | 老 custom + mood Codable + 当天安全迁移 | 前三项保留、旧第四项原结果归档、阅读重新确认；旧历史得分不回算、备份仍可恢复 |
| CAL-03.remove-mood | 当日 UI 与完成门禁 | 无情绪行/交互；历史旧完结规则仍适用 |
| NAV-05.w / SAFE-08.w | CalibrationWidgetProjection v2 / Widget Extension | B方案覆盖 x/4、共享故障分因、唯一坐标绘图；真实 iPhone13 App Group 双 target 签名和六布局仍 DEVICE_BLOCKED |

原 85 项主 ID 保持不变；历史 18 DEFERRED 数字已经因用户新授权发生范围覆盖，其余尚未解冻项不得顺带实施。记录 CODE_DONE 不能冒充 CI/真机 PASS，Chat 继续讨论。

## 2026-10-22 · 本轮视觉修复与用户明确的 Chat 业务冻结

| 增量 | 文件及现有复用 | 审批界限 / 分层证据 |
| --- | --- | --- |
| CARD-08.a/UI-04.r | ImpressV3ReviewViewController / ratingGuide + ImpressV3RatingOverlay + ImpressV3Appearance | **旧四胶囊方案作废**；移除 ratingGuide 行并扩张 cardStack；单行/自适应状态说明提示映射，拖动单方向语义色；Reveal/FSRS 不改；U13/U14/U17 及真实截图未执行 |
| UI-01.nav | ImpressV3Appearance + SceneDelegate + 旧 Markdown 顶部自设 tint | 全部系统顶部操作符号跟随 label 黑白；选中 Tab 仍用品牌蓝，Dark/Light 实测 |
| CHAT-01.a | ImpressAINativeChatViewController composer 段（仅外观） | 黑白 44pt 发送键/加号/麦克风/伸展输入 + placeholder；发送业务、历史、模型与审批逻辑不得修改 |
| CAL/SAFE-08.w | 保留上一版四项和 Widget v2 数据协议 | 新 UI 本身不能认证 iPhone App Group，真机 SpringBoard/签名继续 DEVICE_BLOCKED |

所有项目均需以最终 SHA 的 Portable/Core + Native XCTest + XCUITest + iPhoneOS IPA 证据入账；文档 CODE_DONE 与待执行不同，绝不把先前 HEAD 的 PASS 当新版本 PASS。

## 2026-10-22 · 阅读专项增量追踪（复用既有 85 ID）

| 子项 | 归属 | 检验对象 | 开始状态 | 证据门禁 |
|---|---|---|---|---|
| UI-03.reader-a | UI-03/NAV-05 | 默认语义正文/嵌套列表/布局/主题 | IN_PROGRESS | RDR-01/02/07 |
| UI-03.reader-b | UI-03/SAFE-03 | typed Properties/无效 YAML 局部诊断/源码可达 | IN_PROGRESS | RDR-03/04 |
| UI-03.reader-c | UI-03/CHAT-06 | Mermaid/Markmap/Canvas/Excalidraw 真实呈现与嵌入 | IN_PROGRESS | RDR-05/06/08 |
| SAFE-03.reader-a | SAFE-03/SAFE-04 | BOM/CRLF/范围/SHA 来源恒定 | IN_PROGRESS | RDR-04/09 |
| SAFE-03.reader-b | SAFE-03/SAFE-07 | Vault 附件、缺件/路径/循环/拒绝外部网络 | IN_PROGRESS | RDR-06/10 |
| CHAT-06.reader-a | CHAT-06/CHAT-09 | 阅读→精准选材→预览→Chat→恢复 | IN_PROGRESS | RDR-11 |
| UI-03.reader-perf | UI-03/SAFE-08 | 首屏、长文、切换、缓存、退出回收 | NOT_RUN | RDR-07/12 |

**2026-10-22 G1 源码事实**：`ImVaultDocumentController.renderBody` 的 Markdown 分支仍调用 `MarkdownView.load`；`ImpressMarkdownStructure` 保留标题和原始 UTF8 区间但不构成完整阅读 AST；`safeMarkdownProjection` 目前支持有限本地图片、WikiLink/Callout 安全显示投影；Mermaid/Markmap 是单独 `ImpressDiagramReaderController`，Canvas/Excalidraw 已有原生视图且不可删除。G2 更新属于需求确认，不等于代码实现或截图验收。

## 2026-10-22 · 六图复核需求 × 代码 × 证据（最新冻结；本轮文档写入，不等于修复）

| 子项（复用主 ID） | 当前精确源码指向 | 源码与产品差距 | 下一验收门禁 / 状态 |
|---|---|---|---|
| CARD-08/UI-04 | `ImpressV3ReviewViewController.configureRatingGuide` / `setCurrentCardActionsRevealed` / `ImpressV3RatingOverlay` | 当前存在 `ratingGuide` 四个独立 chip、显示后持久占高；需要撤销并扩大卡面，恢复四方向彩色单标签 | U13/U14/U17 / **FIX_REQUIRED** |
| CHAT-01/05 UI-02 | `ImpressAINativeChatViewController` composer / `inputBar` / keyboardLayoutGuide | 当前四个 44pt 宽控件 + padding 造成总体臃肿；保留 44pt 点击区但缩减视觉/间距、正确垂直对齐、靠近键盘 | U16/U18 / **FIX_REQUIRED** |
| UI-01.nav | `ImpressV3Appearance`、题干全文 Controller 与所有独立 Navigation | 全局色口径虽已定义，所有顶栏/Modal 未完成真机逐页灰度验收 | U15/U19 / **AUDIT_REQUIRED** |
| UI-03.a NAV-03 | `ImpressNoteListTableViewController.tableViewSetting/refreshNotes/viewWillAppear` | 真实 `UIRefreshControl` 仍挂载，多个无条件 `reloadData`；移除手刷、增量 diff 和静默变化核验 | U20/U21 / **FIX_REQUIRED** |
| UI-03.reader-a/b | `ImVaultDocumentController.renderBody` / `ImpressMarkdownOfflineView` / `markdown-host.js` / `markdown-index.html` | 已有离线 WebKit+markdown-it 与 typed Properties；仍缺同级布局/嵌套排版及无双重边框的 Obsidian 视觉验收 | RDR-01/02/03/07/14/16 / **TECH_REVIEW_PENDING** |
| UI-03.reader-c | `ImVaultDocumentFormat.detect` / `ImpressExcalidrawScene` / `ImpressExcalidrawNativeView` | 已识别 `.excalidraw.md`，存在原生画布分支；截图所见仍是源文本，须比对安装 SHA、实际格式、bundle、解码及嵌入路径；不能据代码存在宣称图形通过 | RDR-06/08/13/15/16 / **DEVICE_FAIL_REPORTED; REPRO_PENDING** |
| SAFE-03/CHAT-06 | `ImVaultSafetyProjection` / `ImpressVaultEmbedLocator` / 现有 Chat 选材恢复 | 继续严格确认预览映射/范围/版本、无网络/无写入扩权；高保真引擎仅替换显示层 | RDR-09/10/11/15 / **REGRESSION_REQUIRED** |

**优先级**：先修正与用户指示矛盾的文档（已提交则只表示 SPEC_FROZEN）→ 阅读技术试验和选型讨论 → 实际代码 UI/渲染施工 → 自动化与相同 SHA 打包 → iPhone13 原图实测。不得利用旧 CI、文档状态或旧安装包宣称完成。新截图为用户私有输入，不同步到公开仓库。

**G2.1 已核源码细节（非完成状态）**：`ImpressV3Appearance.styleVaultDocument` 使整篇 WK 读者形成二次深色圆角卡片；`markdownReaderCSS` + `markdown-index.html` + 原生 header 叠加间距。Excalidraw Native 现按元素生成 `UIButton/CAShapeLayer` 和简化 UIBezierPath（非官方 RoughJS 绘图）；`ImVaultDocumentFormat.detect` 仅识别 `.excalidraw.md` 后缀而不检测普通 `.md` 有效绘图 payload。必须在 RDR-13/14/16 校验「普通 .md 内有效插件图形」「真实粗糙曲线/箭头/字体保真」「无巨型嵌套圆角卡片」，但这些是 TECH_REVIEW_REQUIRED，不能自行将猜测的用户文件后缀写为事实。

## 2026-10-22 · G3 连续阅读器实现切片（承接用户批准架构，未施工）

| 切片 / 既有主 ID | 触及已有源码 | 目标变更与不可妥协验收 | 状态 |
|---|---|---|---|
| G3-S1 / UI-03.reader-a/b | `ImVaultDocumentController`, `ImpressMarkdownOfflineView`, `markdown-host.js`, `markdown-index.html`, `ImpressV3Appearance` | Markdown title+typed Properties+正文=一个 WK 可滚动 DOM 流；UIKit 只留固定导航；不再调用整页 `styleVaultDocument`；不破坏 source/canvas 分支 | SPEC_APPROVED / CODE_PENDING |
| G3-S2 / UI-03.reader-a / CHAT-06.reader-a | `markdown-it` CSS/token + `ImpressMarkdownStructure` + Chat material picker | CSS 嵌套、标题去重、AST source UTF8 map、选区来源回读/预览/授权；无可靠范围不自动发送 | SPEC_APPROVED / CODE_PENDING |
| G3-S3 / UI-03.reader-c / SAFE-03.reader-b | `ImVaultDocumentFormat.detect`, `ImpressFrontmatterReader`, `ImpressExcalidrawScene`, generic Markdown draft guards | 后缀优先+普通 md 内有效 plugin/fence 的只读识别；源未变/无效写入安全拒绝；官方 Excalidraw SVG A/B 技术试验 | TECH_SPIKE_PENDING |
| G3-S4 / UI-03.reader-c / CHAT-06.reader-a | `ImpressVaultEmbedLocator`, `prepareAuthorizedPreview`, DiagramReader/Canvas/Excalidraw 视图 | 图形原位真实预览、独立交互页、缩放/区域选材/原始 SHA 核查，单文件缺件不干扰正文 | SPEC_APPROVED / CODE_PENDING |
| G3-S5 / SAFE-03 / UI-03 / NAV-03 | RDR-01～22 + UI smoke/CI/IPA/iPhone13 | 原 18 步业务/12 ACCEPT/F01～F13 零回归；同 SHA 可追溯，真机设备不冒充 CI | NOT_RUN |

**次序门禁**：S1 不需要等新 Excalidraw 包选型即可先实现；S3 的显示分类与写入门禁必须先于 S4 的图形嵌入发布。G3 仅为这六截图产生的 reader 方案，不改变此前已冻结的闪卡/Chat/静默笔记刷新和正式 Vault 只读要求。架构确认不等于代码、构建、设备成功。

## 2026-10-22 · d9711284bfe2 源码再审（最新执行状态）

实际远端 HEAD d9711284bfe2cf8af9ada1b67d109747e30e52ff；与用户提供的旧基线 identical。最近成功 Actions 39782229904。旧版 G3 的 CODE_PENDING 是设计定稿时刻，不覆盖现 HEAD 的实际代码；CODE_EXISTING 也不是视觉 PASS。

| 现有主需求 | HEAD 核验 | 下一门禁 |
|---|---|---|
| CHAT-01/05、U18 | 一个 UITextView/inputBar、44pt 四触控位、keyboardLayoutGuide、草稿与发送状态机已存在 | Composer 垂直基线/动态高度、键盘、附件复验；U18 NOT_RUN |
| UI-03.reader、RDR-01～04/14/17～19 | 离线 markdown-it/KaTeX + Swift typed Properties + 单 WK 文档流已存在；DOM→原 UTF8 选字映射尚缺 | 语义/排版/滚动与来源复验；VISUAL_NOT_RUN |
| UI-03.reader、RDR-05/06/13/15/20～22 | 已有离线 Mermaid/Markmap 与受限 Canvas/Excalidraw 内嵌、原生独立视图；RoughJS 级别保真未知 | 实图/嵌入/选材回归与离线官方 SVG A/B；NOT_RUN |
| CARD-08/UI-04、U17 | 当前源码不再包含 configureRatingGuide、ratingGuide 四 chip | 真机方向提示与卡片高度 U17 NOT_RUN |
| UI-03.a/NAV-03、U20/21 | 当前笔记列表 refreshControl=nil，但另有多处 reloadData | 有变化才更新、iCloud/Provider 与位置回归；U20/21 NOT_RUN |
| SAFE-03/08、ACCEPT/F01～13/18步 | 原 Vault 只读门禁/双目标审批及 FSRS 隔离仍为权威 | 最终同 SHA E2E 未全覆盖，继续 NOT_RUN |
| NAV-05.w/SAFE-08.w | Widget 基础代码已存在 | 侧载签名、App Group 与 iPhone13 六布局 DEVICE_BLOCKED |

顺序：源码/需求审计→Chat 修复→Markdown 语义→图形真实呈现→其他 UI→最终同 SHA CI/截图/IPA。仅标实际已执行证据，禁止继承上次 PASS。

## 2026-10-23 · 四项确认后的 UI/技术实施追踪（仅既有需求子项）

| 子项 | GitHub 现存源码事实（基线 7b0cea32982a7b89cbeb4e897649ca64b5c0f4f9） | 已批准实施方案 / 验收门禁 | 状态 |
|---|---|---|---|
| CHAT-UI / UI-02 | ImpressAINativeChatViewController 中 UITableView + 通用 ImpressChatMessageCell；roleLabel「我/AI」与整行背景色仍在 | ChatGPT iPhone 全状态 UI：右侧用户气泡、助手连续无整行色块/无角色标签、Markdown block 类型、消息操作、滚动、主题；优先 UICollectionView diffable + 原生可复用内容组件 | SPEC_CONFIRMED / CODE_PENDING |
| CHAT-COMPOSER / U18 | 一个 UITextView/inputBar/keyboardLayoutGuide，4×44pt 触控位 | 视觉文本中心、动态高度/安全区/键盘与历史；最小热区不缩水 | SPEC_CONFIRMED / VISUAL_NOT_RUN |
| CHAT-SYSTEM-ATTACH / B | 当前 + 只打开内部材料入口，API converse 仅 [role,content: String] | + 仅相册(PHPicker)、文件(UIDocumentPicker)、拍照(camera)；本地 preview/remove、类型/大小与来源权限、Provider 多模态能力检查、显式发送、持久恢复/删除，顶部菜单仍为笔记/卡片材料 | SPEC_CONFIRMED / CODE_PENDING |
| CHAT-STREAM | 当前 converse 为一次性 HTTP 文本与完成回填 | Provider 真实可用 stream 才增量渲染；SSE/事件解析/取消/不重复计费/中断 partial 处理，保留原 WCDB 状态机 | SPEC_CONFIRMED / CODE_PENDING |
| RDR-13/15/22 | 原生 Excalidraw text/body button 与 CAShapeLayer，缺高保真文本/笔触证据 | 图内文字与任务内容可读为 P0；官方 SVG 与原生对照，文本/绑定/旋转/frame/图像/选材/体积/许可/性能 | SPEC_CONFIRMED / VISUAL_FAIL_REPORTED / REPRO_PENDING |
| CAL-DAY-CLOSED | CalibrationDayCheckIn.isComplete 已存在；UI 始终 3 个 section、今日四项始终显示；store.save 未拒旧完成日变更 | 四项全部结算且保存成功 -> 当天隐藏四项 section 并锁定整日业务结果，store actor 原子拒绝复写，额外修正只读，Widget/跨日/恢复检验 | SPEC_CONFIRMED / CODE_PENDING |

注意：2026-10-22 文档中的「Chat 本批只动外观、不动业务」已被 2026-10-23 最新确认的系统附件及真实流式需求所覆盖；但保留既有 WCDB/Source/FSRS 与 Vault 写入门禁。历史 PASS 不继承，仍然只允许公开开发分支，不得碰 main/私库。
