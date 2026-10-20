> **PRODUCT SOURCE NOTICE · 2026-10-20**：此前说明为历史内容，可能与当前已确认需求冲突。唯一产品要求与工作范围以 [PRODUCT_REQUIREMENTS_CURRENT.md](PRODUCT_REQUIREMENTS_CURRENT.md) 为准；执行差距与验收见 [IMPLEMENTATION_GAP_AUDIT_20261020.md](IMPLEMENTATION_GAP_AUDIT_20261020.md)。当前工作分支：`feature/impress-duplex-loop-v1`。完整校准周图必须移除，修改历史必须移入编辑器；旧文档中相反指示均已被替代。CI 成功≠产品完工。

# Impress — Public iPhone Development Branch

**Current 85-ID / 12-acceptance implementation status:** [REQUIREMENT_EXECUTION_MATRIX_20261020.md](REQUIREMENT_EXECUTION_MATRIX_20261020.md). Core user loop remains incomplete; no CI result or unsigned IPA is a final App acceptance.

This **public repository** is the active source for Impress development on `feature/impress-duplex-loop-v1` (the only development branch alongside stable `main`). It originated as a sanitized independent-history build mirror; historical private upstream SHA references in `SOURCE_MANIFEST.json` remain provenance **only**, not an instruction to modify the private repository.

## Knowledge lifecycle V1 — approved redesign (2026-10-19)

[KNOWLEDGE_LIFECYCLE_V1.md](KNOWLEDGE_LIFECYCLE_V1.md) is a **historical implementation plan (not the current authority)** for 闪卡 → Chat → 结构化笔记, G0–G6, A01–A20 and non-negotiable data, API and Vault safety. It supersedes the old quick-capture-first and separate Calibration Tab proposals. G0 documentation, G1 WCDB content-version/Chat persistence foundations, part of G2 native navigation/edit/weekly overview, and part of G3 card-source Chat persistence and model-override UI have code commits; **note/selection Chat contexts, prompt session editing, proposal execution, real device acceptance and production Vault writes are NOT delivered**. Actual evidence is recorded in [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md), not inferred from this design.

## Product and navigation
Impress combines low-friction structured recall with a deliberately small daily self-calibration instrument. UIKit has **three first-level tabs** in order: **闪卡 / 笔记 / 设置**. Notes is a primary destination with the existing Vault reader and folder/search capability; the flashcard header exposes only 卡片集 on the right, while + creates a V3 flashcard. Complete 每日校准 is under 设置 → 学习节奏 and the old compact Monday–Sunday calibration preview is no longer part of the flashcard home. The V3 WCDB/FSRS-6 review workflow is the only active flashcard data source; there is no legacy database migration. The calibration module uses five indicators (sleep, exercise, nutrition, non-scoring mood, custom), a separate atomic JSON ledger, and a single pure `CalibrationScoreCore` implementation.

The original four-direction flashcard gestures, card collection CRUD, protected Obsidian external Vault reading, and editable settings remain separate from calibration. Vault browsing uses the same native grouped-table design as Settings; note detail offers a restrained reading canvas with unified typography, color tokens and spacing, while keeping original documents read-only. Vault browsing adds hierarchical folder/path search, provisional local cache, background index batches and bounded UI list pages.

## Appearance, language and understanding edits
The Settings tab adds **Appearance** (System / Light / Dark, System default) and **App Language** (Simplified Chinese / Traditional Chinese / English) under a native appearance group. Modes persist independently in UserDefaults. Light/Dark applies at UIWindow level; app-owned interface text uses centralized `ImpressV3Appearance` and `ImpressV3Language` configuration, not per-screen fonts, color hex values or automatic translation of private notes. Three first-level tabs (Flashcards/Notes/Settings) and the single flashcard-header Card Collection action remain fixed.

Understanding timeline records open a dedicated editable detail. Only the user's answer body may be edited; saves perform an original-answer compare-and-swap, retain the prior text and change time as an append-only version list in `LearningEntry-v1.json`, and preserve original question, AI evaluation, entry ID, creation time and FSRS event history. The existing V2 ZIP includes this journal; no new database tables or Vault writes are introduced.

## V3.2 data protection
All flashcard, understanding-history, local prompts, and calibration check-ins use **one** V3 BackupCoordinator. Its V2 ZIP includes an additional `checkins-v1.json` and preserves legacy V1 archive readability. Recovery is explicitly confirmed and staged for cold launch. Durable pre-image recovery protects SQLite/WAL, learning history, prompts and calibration against process death, and blocks opening a half-restored WCDB. Opaque mutation generations reject mixed-era backup assemblies and preserve the Dirty marker. The existing iCloud Drive folder is used only after user selection. **These ZIP archives are not encrypted**, and Files-provider write acknowledgment does not prove remote iCloud upload completion. Obsidian originals, credentials, bookmarks and private source art are excluded.

## Build and release gates
GitHub Actions workflow: [R04.2 native regression](.github/workflows/r04-2-privacy-retirement-validation.yml). A successful run must include Swift Core, public-credential checks, full UIKit XCTest, iPhone Simulator, unsigned ARM64 iPhoneOS build, ZIP integrity and SHA-256. The source branch is not a device-install attestation.

The original `AppIcon.appiconset/icon_1024.png` is not available in the public source. The workflow's explicit **7icon-INCOMPLETE-unsigned** build is a test candidate only, not a final branded release. Do not invent or resize the original icon. Real iPhone 13 installation, free-signing entitlements, notification delivery and Files/iCloud authorization require physical testing.

Read [PUBLIC_BUILD_CONTRACT.md](PUBLIC_BUILD_CONTRACT.md), [CALIBRATION_V3_2_INTEGRATION.md](CALIBRATION_V3_2_INTEGRATION.md), [BUILD_AND_SIGN.md](BUILD_AND_SIGN.md), [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md), and [SOURCE_MANIFEST.json](SOURCE_MANIFEST.json). Never add personal notes, app user databases, certificates, API keys, screenshots, private Docs, or non-approved raster artwork to this public repository.

## iOS deployment baseline · 2026-10-18
The feature-branch app and test targets now require **iOS 26.0**; the Podfile platform, generated Pods post-install floor, and GitHub Actions build overrides are aligned. Earlier iOS 13–25 installation is intentionally unsupported. This configuration migration enables future Apple SpeechAnalyzer/SpeechTranscriber work; **STT is NOT implemented by this deployment-only commit**. iPhone 13 supports iOS 26 but device/locale model availability still requires runtime and physical-device checks. Preserve FSRS-6, WCDB, Obsidian original read-only rules and the missing-original-icon release gate.

## V3.3 native dictation implementation (iOS 26)
- A single `ImpressSpeechService` manages Apple `SpeechAnalyzer`, `SpeechTranscriber` and `DictationTranscriber`, on-device model availability and explicit `AssetInventory` installs. Legacy `SFSpeechRecognizer` and third-party/network STT are intentionally absent.
- Settings → 语音输入 / Voice Input exposes an independent Mandarin (zh-CN), Traditional Chinese (zh-TW) or English (en-US) dictation preference, transcriber availability, manual model downloads and microphone authorization status. The UI language preference is separate.
- A reusable native microphone keyboard accessory is attached to question, answer, choice-option, bulk import, understanding capture/edit, prompts and private Markdown draft editors. The original Obsidian source reader remains read-only with **no** microphone control.
- Speech partial results are provisional, final text is inserted only after explicit completion and checked against the original editor text and UTF-16 caret selection. No audio is written to disk, logged, or uploaded. No FSRS/Calibration schemas are changed.
- New UIKit tests cover volatile phrase replacement, Unicode ranges, stale editor rejection, one-change callback and settings navigation. CI validates an explicit mic purpose string and checks that no legacy/cloud speech code or private audio persistence path exists.
- Full iPhone 13 audio permission, model download, spontaneous speech accuracy, microphone interruptions, language availability and UI/keyboard acceptance remain **device PENDING** until physical testing. Old MarkdownKit/MarkdownView dependency modernization is a separate protected gate, not falsely claimed as complete.

## 2026-10-20 · 双向闭环测试补强（仍非发布认证）

在 `feature/impress-duplex-loop-v1` 中追加一个独立临时测试 Vault → Markdown 章节候选卡 → WCDB 原卡 → FSRS 评分 → Chat 多会话与双目标批准 → QA fixture 文件协调写入 / 回读 → 原卡 CAS → 来源变化核查 → 逆向撤销 → 冷启动恢复的 XCTest 回归（`testDisposableVaultCardChatDuplexFullRoundTripAfterInterveningFSRS`）。同时修复在合法 FSRS 评分后批准内容更新发生虚假调度冲突、以及意外取消正在进行的安全撤销记录的问题。详见本分支 `SMOKE_TEST_MATRIX.md` 与 `REQUIREMENT_EXECUTION_MATRIX_20261020.md`。

**验收级别严格分开：** 该测试使用合成文本和临时 SQLite，不代表远端大模型、真机 iPhone13、iCloud 同步或用户 Vault 已验证。必须以此代码 SHA 的全套 CI 实际完成为自动化 PASS 依据；正式写入仍为 `ImVaultGuardedWrite.productionWriteEnabled = false`。原始图标与正式签名限制不变；无签名 IPA 仅是 QA 候选。

## Duplex approved note revision retention (2026-10-20)

Original and proposed Markdown bytes of each approved note edit are now kept as an immutable, protected `ImVaultPrivateStore/ApprovedDraft` record keyed by Vault ID, full relative path, base SHA-256 and proposed SHA-256. Starting a new revision after an already-applied QA edit requires explicit user selection and a fresh coordinated source read; old Chat receipts must never read the newer mutable working draft. A missing legacy source snapshot fails closed. This is local private storage only: it is not an encrypted external backup or verified iCloud sync, and a device reinstall can lack prior draft bytes. The production Vault write switch remains `false`. See SMOKE_TEST_MATRIX for 2-revision/undo fixture tests and remaining iPhone13 validation.

## Source-impact direct original-card correction (2026-10-20)

The note-source impact reviewer now includes a direct original-card editor alongside the explicit “unaffected” decision, reusing the existing card composer rather than creating a competing card update path. A user-approved edit validates the current authorized Vault identity, document SHA, unchanged original card content revision and source key, and then applies WCDB CAS with the *current* FSRS scheduling revision. Review events and cardID survive; changed source-section anchors are conservatively downgraded to file-level identity. Requires matching SHA XCTest and device QA; does not permit a production Vault write.
