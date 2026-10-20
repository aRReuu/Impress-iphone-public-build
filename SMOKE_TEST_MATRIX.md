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
