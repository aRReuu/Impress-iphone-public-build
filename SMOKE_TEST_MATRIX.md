> **精确执行矩阵：** [REQUIREMENT_EXECUTION_MATRIX_20261020.md](REQUIREMENT_EXECUTION_MATRIX_20261020.md)；以下 A01～A20 仅为旧回归记录，不可单独认定已验收。

> **2026-10-20 最新验收优先级：** 当前产品验收唯一依据 [PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md) 和 [IMPLEMENTATION_GAP_AUDIT_20261020.md](IMPLEMENTATION_GAP_AUDIT_20261020.md)。以下 A01～A20 是历史 G0～G6 追踪记录，不能凌驾于最新 CARD/CHAT/LOOP/OPEN/ACCEPT 编号。特别：旧 A02“首页周校准图”已取消；CARD-11“修改历史移入编辑器”必须实现；CHAT-03 新建与历史切换不等于数据库仅能保存多会话。本表尚未证明 ACCEPT-01～12 全部通过。

# SMOKE_TEST_MATRIX — Impress V3.2 acceptance evidence

## 2026-10-19 redesign A01–A20 evidence

**G2/G3 native verification request:** compile and run the complete iOS 26 native suite for the exact commit that includes the new weekly chart click test, stable-source Chat restore test and localization-key startup guard. Keep original Vault writes disabled; publish a QA IPA only after all required CI stages succeed.

For exact-SHA validation, CI must compile the iOS 26 Simulator target, execute native XCTest, and build an unsigned iPhoneOS ARM64 QA IPA. Separately record pure Swift tests, UIKit tests, real inference, iPhone Keychain, File Provider and production Vault consent. Never mark a device or real API gate from a build alone.

This section is the current navigation/knowledge acceptance contract. **Status is BLOCKED/NOT RUN unless backed by a CI run on the exact code SHA or a recorded device test.** The historical V3.2 results below are regressions only, not current pass evidence. Single authority: [KNOWLEDGE_LIFECYCLE_V1.md](KNOWLEDGE_LIFECYCLE_V1.md). No paid AI calls, real personal Vault tests, merge, or production-write bypass.

| ID | Required current scenario | Evidence target / current state |
| --- | --- | --- |
| A01 | Flashcards / Notes / Settings; calibration under Settings, correct tap router | Code + native XCTest submitted; current CI pending |
| A02 | Current local Monday–Sunday, missing/unfinished/excused/future gap, accessible net-only fixed Y | Core tests submitted; native/iPhone13 layout unverified |
| A03 | Home + adds 3 card types without restarting queue | Code submitted; native UI unverified |
| A04 | Edit QA/choices/image, no-op save, independent explanation | Existing editor partly reused; full semantics pending |
| A05 | Genuine content revision history and restore as new version | Atomic WCDB + native XCTest submitted; CI pending |
| A06 | Old LearningEntry archive compatibility/migration | Existing journal preserved; migration audit pending |
| A07 | Edits and rating interleaving, no stale display and no FSRS reset | Partial UI code; concurrency regression pending |
| A08 | Note search/selection/reader/draft and Markdown fidelity | Existing reader; new workflow pending |
| A09 | Chat model/prompt selection, provider scope | G3 native model chooser + provider consent code submitted; session prompt editing/native XCTest pending |
| A10 | Durable context, local Chat history and resume | G3 cardID/revision-bound UI, full local history/draft resume and native test submitted; Notes/selection contexts pending |
| A11 | Failure, cancel, retries and no-cost fallback | Failed message and unsent draft preserved; no silent paid fallback; native/retry/device verification pending |
| A12 | Distinguish summarize vs explicit update | Proposal schema; executor pending |
| A13 | Card → Chat → explicit test note safe diff/write/readback | BLOCKED until fixture executor/device |
| A14 | Preview cancel/conflict/idempotence | BLOCKED |
| A15 | Multi-card targets/new-note name conflicts | Not implemented |
| A16 | Notes/Chat common candidate pool | Existing note flow; Chat integration pending |
| A17 | Source revision stale prompts | Not implemented |
| A18 | Added history/Chat/proposals in ZIP and safe restore | Same V3 SQLite + unit tests submitted; full archive test pending |
| A19 | iPhone 13 / Dynamic Type / light-dark / 3 languages / STT | Simulator/device unverified |
| A20 | No key leak, no production Vault tests/write, truthful status | Production gate unchanged; independent review required |

## Current evidence boundary
The last verified V3.2 baseline is `58987edfe550f9ccd4f7b7168b12c1f83c98b920`, [CI #39093765853](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39093765853): 90/90 native UIKit XCTest, 17/17 portable Swift tests, Simulator and unsigned ARM64 candidate. The new theme, three-language UI, editable understanding and Notes redesign **require fresh CI on their own final HEAD**; no prior run is proof of these new edits. Simulator does not certify iPhone 13.

## Native Simulator / automation
| Area | Required actual gate |
| --- | --- |
| Branch / privacy | Public feature HEAD, no private/main changes, credential and source privacy checks |
| Core | All `ImpressReviewCore` tests including five-indicator scoring, calendar, mood skip, extras, trends and reminder plan |
| Navigation | Exactly three tabs ordered 闪卡 / 笔记 / 设置, with Card Collection right header only, + opening the V3 card editor; Daily Calibration is a Settings detail and notification target |
| Appearance & locale | System/Light/Dark persistent window overrides, System fallback; three independent language modes (zh-Hans, zh-Hant, en), immediate native navigation refresh, no mutation of personal content or persisted reviews |
| Understanding edit | Detail exposes explicit editor; successful CAS updates answer and appends previous revision to learning journal; invalid/blank/stale edits fail without changing data; ID, question, original AI feedback and FSRS remain stable |
| Flashcards | Show Answer, four swipes, exactly-one FSRS event, card CRUD/pagination/content CAS and V3 schema upgrade |
| Cards/media | Text QA, image BLOB, single/multiple choice, search, import, stale-save rejection |
| Obsidian | Native inset-grouped Notes table, central font/color/spacing tokens, restrained Markdown reader, external read-only Vault index, bounded 128-note enumeration progress, verified-scope provisional cache, folder/path search, 120-item list paging, local attachments and iCloud-not-downloaded error; no automatic original writes |
| Calibration check-ins | All five evaluated, unknown remains unknown, mood not scored, mutable current goals, immutable historic snapshots, manual +/- boundaries |
| Calibration UI/chart | Week 7 days, month 30 days, year monthly daily mean, axes, missing-day gaps, readable Dynamic Type |
| Notifications | Calibration IDs separate from FSRS, permissions, duplicate reconciliation, pending-day cancellation and click route |
| Backup V1 | Legacy 3-data-member ZIP remains readable; does not delete calibration ledger |
| Backup V2 | SQLite, JSON learning history, prompts, image BLOB, FSRS events and checkins all survive CRC/SHA/semantic validation |
| Restore | User confirmation, recovery preview, durable pre-image of SQLite/WAL, learning history, prompts and calibration; process-death recovery before WCDB opens; fault-injected rollback |
| Backup mutation race | Opaque mutation generations prevent concurrent writes clearing Dirty and reject mixed-era ZIP publication |
| Device build | iPhoneOS ARM64 unsigned app, no embedded XCTest, IPA ZIP integrity and SHA-256 Artifact |

## Device-only gates (not passed by Simulator)
- iPhone 13 unsigned-IPA signing and actual launch; installation and retention after free seven-day re-signing.
- iCloud Drive folder picker, stale bookmark after app restart, Files-provider local write versus server upload, offline retry.
- Recovery from ZIP on a fresh device and app termination between staged restore and next cold start; no partial SQLite/JSON/prompt/calibration restore.
- Local alert delivery at 20:00/22:00 across sleep/reboot, permission denial, Focus mode, timezone change, badges and FSRS coexistence.
- UIKit appearance, Dynamic Type, Safe Area and Y-axis readability on iPhone 13; manually switch System/Light/Dark and zh-Hans/zh-Hant/en while navigating Flashcards, Calibration, Settings, Vault and understanding editor. Check text truncation, keyboard layout, saved editor revisions and theme persistence across relaunch. Original iPhone icon visual and missing marketing 1024 icon remain a release gate.
- External Obsidian Vault remains read-only by design, including iCloud placeholders, images and safe path resolution.

## Mandatory evidence format
Record final Git SHA, Actions run URL, each job conclusion, **total native XCTest passed/failed**, portable Swift tests and unsigned IPA SHA-256. A compiled source file is not a test result, and a CI artifact is not proof of phone-level Files/iCloud entitlement.

## iOS 26 platform migration gate
| Gate | Verifiable requirement | Current evidence type |
| --- | --- | --- |
| Deployment settings | Six Xcode app/test deployment values, Podfile and generated Pods floor, three native build overrides all 26.0 | New static audit in CI |
| Binary | Signed state unchanged; unsigned ARM64 QA .app reports `MinimumOSVersion=26.0`, IPA ZIP/SHA valid | New native packaging assertion; pending CI |
| iPhone 13 | iOS 26 installation and SpeechTranscriber hardware/locale/download checks; old-system support intentionally dropped | **Device PENDING** |
| Global STT/Markdown | Apple SpeechAnalyzer and unified renderer/voice UI not yet implemented | **Development PENDING** |

## V3.3 speech gate
| Gate | Required evidence |
| --- | --- |
| Speech code | Real iOS 26 compilation against Apple Speech; no SFSpeechRecognizer, no third-party STT and no private audio log/disk path |
| Voice settings | Three independent recognition locales, engine availability, manual Apple model installation and microphone permissions displayed |
| Text insertion | UTF-16 selection replacement, cancel leaves source unchanged, stale edit rejected, final-only commit, single editor-change callback |
| Editor routing | Question, answer, options, batch import, understanding capture/edit, prompt inputs and Markdown **private drafts** provide one mic accessory; source Obsidian reader remains read-only |
| Real device | iPhone 13 microphone and interrupted session; per-locale model availability, first-download permission, latency, accuracy, background cancellation and VoiceOver **PENDING** |
| Markdown overhaul | One AST-backed parser and unified rendering pipeline **PENDING**; no old or external Vault document discarded |

## 双目标复核专项用例（必须在单一提交 SHA 通过，含 iPhone 13 QA）

- **DUPLEX-01 正向**：在复习原卡进入 Chat、完成讨论，在仅针对该 note 的私有草稿改一处 Markdown，编辑同一张标准原卡题目或答案，单屏完整预览两个目标，并分别打开/关闭两项选择。保存后卡片 cardID、FSRS 事件不变，未选对象无副作用。
- **DUPLEX-02 不可默默写生产 Vault**：即使双目标都被用户勾选，Release 的正式笔记写回必须失败且草稿保留；卡片目标回执独立，不能用草稿已保存或 Debug 副本成功冒充真正 Vault 已更新。
- **DUPLEX-03 Debug QA 文件实际回读**：在 Files 手动选定唯一授权文件夹 `Impress-Write-Test-Vault`；验证同名其他目录不可写、原文 SHA 变更拒绝覆盖、写前备份、按用户确认范围修改、协调写回和本机回读；不得据此声称 iCloud 服务器同步。
- **DUPLEX-04 断点与幂等**：让文件成功后卡片 CAS 失败，强杀与重启后只能通过显式恢复操作继续；文件不得二次追加，未应用的原卡不得被覆盖；允许取消剩余操作，保留已成功回执。
- **DUPLEX-05 逆向**：笔记从属卡片的 v2 源 digest 改变后，只在用户请求「来源核查」时提示；完整读当前 Markdown／原卡，确认不影响则只更新该 cardID 的已核验源摘要，不评分、不改变问题与答案；同名不同 Vault、缺失授权、变更中再次改文档均拒绝误关联。
- **DUPLEX-06 回退与兼容**：旧 Chat JSON 无 `pendingDuplex` 时仍能打开；原有独立草稿/FSRS/图片/选择题/三语言/夜间模式未回归。校准待定模块不作为本轮预置闭环。

## 数据保真与历史回执追加核验

- **P0-BYTE-01**：取包含 BOM 的 UTF-8 + CRLF Markdown（含 Frontmatter/WikiLink/大于 500 行），在 iPhone 13 中仅修正文中一行。预览必须只呈现那一行的原文／改文，且允许确认完整范围；经过授权 QA 副本写回后新文件仍保留 BOM 与全部原始 CRLF，未修改内容逐字节一致。
- **P0-BYTE-02**：原文为混合 LF/CRLF 时不得把纯换行归一化隐藏为「没有变更」。源文件被外部应用同时修改则冲突中止，不可覆盖、不可自动将建议覆盖已成功的原卡。
- **P0-SOURCE-01**：笔记详情 → 私有草稿编辑 →（QA 副本经授权写回）→ 返回笔记详情，重读授权源文件并刷新最新 Markdown。关闭授权／文件移动／下载未完成后，不能从旧缓存建立有效写回提案、上传过期章节或者误发旧版本 Chat。
- **P0-RECEIPT-01**：同一 Chat 顺序完成两次修改、首次只改原卡、第二次笔记冲突，强杀重启后历史回执仍逐项存在，可完整查看双方 cardID/Vault path/expected revision/部分结果；任何恢复行为都不得自动执行已保存修改。

## 安全撤销完整业务冒烟（LOOP-13）

- **UNDO-01（原卡）**：同一 cardID 人工批准修改问题／答案后，从 Chat 对应收据进入「安全撤销」。完整显示改前／改后字段、当前内容版本。二次确认后回原题／答案，卡片身份不变、FSRS dueAt/review events 不变、卡片内容历史保留批准版本与新 restored 版本。
- **UNDO-02（原卡冲突）**：批准之后原卡又被用户合法修改，旧撤销必须拒绝覆盖，旧内容和 FSRS 都不丢。中间若仅发生 FSRS 评分则允许依据 **最新 FSRS revision** 在不改评分的前提下撤销卡片内容。
- **UNDO-03（QA 笔记）**：在 Debug 显式授权独立测试副本写入含 BOM+CRLF／Frontmatter／WikiLink 的原始 Markdown，确认后通过完整反向 Diff 撤销。File Provider 回读须与第一版源字节完全一致，再次人工重试不产生重复写入。
- **UNDO-04（锁定／冲突）**：Release 正式 Vault 永远不能绕过生产写门禁；独立 QA 授权丢失时不能进入 undoing；源文第三方修改、同名但其他 Vault 等情况必须拒绝写回。
- **UNDO-05（崩溃恢复）**：写回后未记录成功收据即强杀，重启持久恢复 undoing 且零自动重放；用户再次手动确认并匹配目标已恢复的字节／内容版本，记为 reverted。归档旧提案的撤销不得覆盖后续提案与其他 Chat。

## 来源章节定位专项（ACCEPT-01/02/11、LOOP-03/07/08）

- **ANCHOR-01**：在可丢弃测试 Vault 的 Markdown 含两个不同章节时，从明确勾选的一处章节生成单证据卡片，保存后 `source_note_path` 具有相同 Vault+完整相对路径+文档 SHA+章节 SHA，返回笔记能找到原 cardID，任何同名其他 Vault 不匹配。
- **ANCHOR-02**：Obsidian 在其他章节增加段落/修改排版，刷新当前原文，若被引用章节完整文本仍唯一且未变动，反向核查不为这张卡创建无意义提示；已核实同源其他卡仍可独立核查。
- **ANCHOR-03**：被引用章节改变、被删、被拆分或重复导致无法唯一定位时，只报告来源定位置信度不足，保留人工核查和「不影响」/修订原卡入口；绝不根据同名标题自动覆盖。
- **ANCHOR-04**：老 v1/v2 来源、独立无来源卡、多证据引用和来源章节重复的卡继续采用原有安全回退，不触碰 FSRS 到期和历史；iPhone 13 复核实际导航、长 Markdown 和手势体验。

## 来源片段与出题隐私 QA

- **SOURCE-SEG-01**：从关联原卡打开来源笔记时先回读原 cardID/contentRevision/Vault 身份，v3 锚点提供完整当前章节原文只读阅读，用户仍可返回整篇笔记。来源章节移动但内容唯一时仍可定位；章节删除或重复出现则明确说明无法精确定位，不查同名其他 Vault。
- **AI-UPLOAD-01**：在用户勾选特定笔记章节并确认模型后、请求发送前模拟外部 Obsidian 修改选中章节，拒绝云端发送；修改未选章节仍由于全文 SHA 改变而拒绝发送，需重新确认最新版本。无授权/不同 Vault/材料篡改均不得发送。
- **AI-UPLOAD-02**：用户仅打开 Chat、候选池、来源/片段阅读、草稿和预览，不上传正文；实际发送前告知此次源版本与材料范围，不自动扩大发送上下文或转用付费模型。

## 2026-10-20 · 新增端到端模拟业务冒烟目标（未执行不标 PASS）

| 场景 | 证据测试（本次新增） | 自动化现态 | 真机现态 |
| --- | --- | --- | --- |
| ACCEPT-01/02 | `testDisposableVaultCardChatDuplexFullRoundTripAfterInterveningFSRS`：独立 Vault 笔记选章节→审定单候选→真实 WCDB cardID/来源锚点；跨 Vault 不匹配 | PENDING：需本次 exact SHA CI | BLOCKED |
| ACCEPT-03 | 原生长 Markdown / 手势系列原有测试，尚无本次 iPhone13 长文交互证据 | PENDING 全套原生测试 | BLOCKED |
| ACCEPT-04/05 | 同测试：内容 CAS、卡片原地版本/FSRS 插入评分后继续编辑 | PENDING | BLOCKED |
| ACCEPT-06 | 同测试：Chat 多会话/历史/草稿/提案跨数据库冷启动恢复 | PENDING | BLOCKED |
| ACCEPT-07 | `testAIQuestionMaterialRequiresExactLiveSourceBeforeHTTP`、现有上下文同意测试，不调用真实云端 | PENDING | BLOCKED |
| ACCEPT-08 | 现有 `testDuplexProposalPersistsAcrossChatColdStartWithoutReplayingWrites` 与 Diff 测试；完整交互 UI 尚缺设备认证 | PENDING | BLOCKED |
| ACCEPT-09/10 | 同测试：本地 QA fixture 源文件实际协调写、回读、备份、二次操作幂等、分对象回执；故障注入另见 `testDuplexPartialReceiptDoesNotReapplyWrittenQAFileOnCardConflict` | PENDING | BLOCKED |
| ACCEPT-11 | 同测试：章节无关变动不打扰、相关变动仍需人工核查；现有 `testSourceRevisionAcknowledgementKeepsOriginalCardAndReviewSchedule` | PENDING | BLOCKED |
| ACCEPT-12 | 同测试：逆向安全撤销、保留 FSRS/内容历史与会话、冷启动再读 | PENDING | BLOCKED |

旧 A02 已被最新产品契约取消，不恢复首页周校准图。无线上模型、iPhone13、生产文件写回的真实验证不在这次模拟运行中。

### 2026-10-20 后续：原生目标身份与未发送 Chat 模型

新增 `testDuplexDiffPreviewDisplaysExactVaultIDAndSourcePath`、`testUnsentChatModelAndPromptSurviveColdStartAndLegacyJSON`。分别覆盖笔记+原卡统一预览中 Vault ID/全相对路径/实际来源 SHA 的可见性，以及只选择模型未发送消息时，模型、提示词和草稿在已有 WCDB 会话冷启动后的保留。过去 Chat JSON 缺少可选新字段时仍可读取。仅有对应 exact SHA XCTest 成功才可标记自动化 PASS；iPhone13/真实 Vault/在线模型仍不可直接推定。
