# PUBLIC_BUILD_CONTRACT — Impress V3.1 R03 P0–P2

## Authority and scope
The private feature branch aRReuu/Impress-iphone / feature/impress-v3-review-foundation is authoritative. This public repository contains a sanitized, single-snapshot source mirror and technical build rules only. It has an independent Git history. Do not copy upstream Docs, docs, notes, histories, or personal images.

## Startup and navigation
AppDelegate -> SceneDelegate.initRootVC() -> ImTabBarViewController. In Debug, the public candidate compilation condition IMPRESS_V3_CANDIDATE makes ImpressV3ReviewEnvironment.pilotEnabled default to true on a fresh installation. Only two main tabs exist: 闪卡 and 笔记. Release behavior remains unchanged and must not silently migrate old user data.

## Review core
ImpressV3ReviewViewController -> review environment and database facade -> ReviewWCDBRepository -> FSRS6ReviewCalculator, with ImpressReviewCore for portable review state contracts and reminder planning. Use the existing WCDB atomic transaction and idempotency guarantees. Do not invent a parallel score algorithm. Show Answer precedes rating; directions: left Hard, up Good, right Easy, down Again. Card types: text QA, image, single/multiple choice. Long answers must scroll without triggering rating.

## User understanding / AI
Record Understanding is an independent Sheet. Cancel means no persistence. Each committed answer forms a version in the history timeline; AI evaluation is separate and respects consent. Never upload private notes or Vault content to any provider absent explicit user confirmation. Provider keys are entered on-device, never embedded in this mirror or CI.

## Obsidian P0 safety
ImObsidianManager and ImVaultSyncCore coordinate security-scoped folder access, readonly relative-path Markdown indexing, private drafts, original content hashing, diff/conflict refusal, backup and writeback read-after-write checks. ImVaultGuardedWrite.productionWriteEnabled is intentionally false for production Vaults. Do not change this before real-device iCloud/File Provider testing.

## P1 image pipeline
PHPicker limited photo access, file-based ImageIO thumbnail decoding, cancellation without side effects, background compression, and atomic card creation; policy: ordinary photos <=1280px and target <=240KB; text screenshot <=2000px and target <=480KB; hard limit ~650KB. UI/database behavior requires simulator tests and real-device validation.

## Notifications
Existing ImpressV3NotificationCoordinator implements Off / Smart / Daily Habit. Do not change FSRS due-date calculations to satisfy reminder behavior.

## Package and project files
Packages/ImpressReviewCore -> portable Swift tests. Podfile + Podfile.lock -> WCDB, MarkdownKit, IQKeyboardManagerSwift, MarkdownView dependencies; CI runs pod install rather than copying Pods. Shared Xcode project, workspace, and scheme support Debug/Release and iPhoneOS arm64. Build with CODE_SIGNING_ALLOWED=NO and no personal DEVELOPMENT_TEAM. Real signing is done off-repository.

## Public security / asset policy
Never add Docs, docs, xcuserdata, original upstream git history, secrets, certs, provisioning profiles, true Vaults or notebook databases. No upstream raster originals with unknown redistribution rights. The CI neutral image generator fills required image paths before build. These substitutions affect appearance only and are disclosed; do not assert pixel-perfect R03 art reproduction from public build without comparison.

## Acceptance
Three distinct axes: source/security audit, executable Swift and Xcode tests, and simulator UI smoke. A passing archive test does not imply a successful runtime. Physical device iCloud entitlement and Vault writeback validation remain NOT TESTED until conducted on an owned iPhone.
