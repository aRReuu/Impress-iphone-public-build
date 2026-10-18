# Impress V3.2 — Public iPhone Development Branch

This **public repository** is the active source authority for Impress V3.2 development on `feature/impress-v3-r04-2-build`. It originated as a sanitized independent-history build mirror; historical private upstream SHA references in `SOURCE_MANIFEST.json` remain provenance **only**, not an instruction to modify the private repository.

## Product and navigation
Impress combines low-friction structured recall with a deliberately small daily self-calibration instrument. UIKit has **three first-level tabs** in order: **闪卡 / 校准 / 设置**. The **笔记** Vault destination is opened through its own visibly labeled button in the flashcard header, beside the separate 卡片集 action. It is no longer a primary Tab. The V3 WCDB/FSRS-6 review workflow is the only active flashcard data source; there is no legacy database migration. The calibration module uses five indicators (sleep, exercise, nutrition, non-scoring mood, custom), a separate atomic JSON ledger, and a single pure `CalibrationScoreCore` implementation.

The original four-direction flashcard gestures, native dark/light appearance, card collection CRUD, protected Obsidian external Vault reading, and editable settings remain separate from calibration. Vault browsing adds hierarchical folder/path search, provisional local cache, background index batches and bounded UI list pages, without changing its read-only access model.

## V3.2 data protection
All flashcard, understanding-history, local prompts, and calibration check-ins use **one** V3 BackupCoordinator. Its V2 ZIP includes an additional `checkins-v1.json` and preserves legacy V1 archive readability. Recovery is explicitly confirmed and staged for cold launch. Durable pre-image recovery protects SQLite/WAL, learning history, prompts and calibration against process death, and blocks opening a half-restored WCDB. Opaque mutation generations reject mixed-era backup assemblies and preserve the Dirty marker. The existing iCloud Drive folder is used only after user selection. **These ZIP archives are not encrypted**, and Files-provider write acknowledgment does not prove remote iCloud upload completion. Obsidian originals, credentials, bookmarks and private source art are excluded.

## Build and release gates
GitHub Actions workflow: [R04.2 native regression](.github/workflows/r04-2-privacy-retirement-validation.yml). A successful run must include Swift Core, public-credential checks, full UIKit XCTest, iPhone Simulator, unsigned ARM64 iPhoneOS build, ZIP integrity and SHA-256. The source branch is not a device-install attestation.

The original `AppIcon.appiconset/icon_1024.png` is not available in the public source. The workflow's explicit **7icon-INCOMPLETE-unsigned** build is a test candidate only, not a final branded release. Do not invent or resize the original icon. Real iPhone 13 installation, free-signing entitlements, notification delivery and Files/iCloud authorization require physical testing.

Read [PUBLIC_BUILD_CONTRACT.md](PUBLIC_BUILD_CONTRACT.md), [CALIBRATION_V3_2_INTEGRATION.md](CALIBRATION_V3_2_INTEGRATION.md), [BUILD_AND_SIGN.md](BUILD_AND_SIGN.md), [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md), and [SOURCE_MANIFEST.json](SOURCE_MANIFEST.json). Never add personal notes, app user databases, certificates, API keys, screenshots, private Docs, or non-approved raster artwork to this public repository.
