# SMOKE_TEST_MATRIX — Impress V3.2 acceptance evidence

## Current evidence boundary
Baseline R04.2 commit `e9eb5e92679907ab95c6aff615d5a6719b69eb46` completed [CI #39054675238](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39054675238): 78/78 UIKit XCTest, Core, Simulator and ARM64 candidate. **That run predates V3.2 calibration integration and does not sign off the newly added code.** Update this matrix only from the final target SHA and its real Actions log.

## Native Simulator / automation
| Area | Required actual gate |
| --- | --- |
| Branch / privacy | Public feature HEAD, no private/main changes, credential and source privacy checks |
| Core | All `ImpressReviewCore` tests including five-indicator scoring, calendar, mood skip, extras, trends and reminder plan |
| Navigation | Exactly three tabs ordered 闪卡 / 校准 / 设置; distinct visible 笔记 and 卡片集 right-header actions on flashcard home; Notes pushes the existing read-only Vault list without changing the review session |
| Flashcards | Show Answer, four swipes, exactly-one FSRS event, card CRUD/pagination/content CAS and V3 schema upgrade |
| Cards/media | Text QA, image BLOB, single/multiple choice, search, import, stale-save rejection |
| Obsidian | External Vault read-only index, path containment, search and local attachments; no automatic original writes |
| Calibration check-ins | All five evaluated, unknown remains unknown, mood not scored, mutable current goals, immutable historic snapshots, manual +/- boundaries |
| Calibration UI/chart | Week 7 days, month 30 days, year monthly daily mean, axes, missing-day gaps, readable Dynamic Type |
| Notifications | Calibration IDs separate from FSRS, permissions, duplicate reconciliation, pending-day cancellation and click route |
| Backup V1 | Legacy 3-data-member ZIP remains readable; does not delete calibration ledger |
| Backup V2 | SQLite, JSON learning history, prompts, image BLOB, FSRS events and checkins all survive CRC/SHA/semantic validation |
| Restore | User confirmation, recovery preview, local rollback snapshot, cold-start substitution and fault-injected failure recovery |
| Device build | iPhoneOS ARM64 unsigned app, no embedded XCTest, IPA ZIP integrity and SHA-256 Artifact |

## Device-only gates (not passed by Simulator)
- iPhone 13 unsigned-IPA signing and actual launch; installation and retention after free seven-day re-signing.
- iCloud Drive folder picker, stale bookmark after app restart, Files-provider local write versus server upload, offline retry.
- Recovery from ZIP on a fresh device and app termination between staged restore and next cold start; no partial SQLite/JSON/prompt/calibration restore.
- Local alert delivery at 20:00/22:00 across sleep/reboot, permission denial, Focus mode, timezone change, badges and FSRS coexistence.
- UIKit appearance, Dynamic Type, Safe Area and Y-axis readability on iPhone 13, original iPhone App Icon visible; missing marketing 1024 icon still blocks final release.
- External Obsidian Vault remains read-only by design, including iCloud placeholders, images and safe path resolution.

## Mandatory evidence format
Record final Git SHA, Actions run URL, each job conclusion, **total native XCTest passed/failed**, portable Swift tests and unsigned IPA SHA-256. A compiled source file is not a test result, and a CI artifact is not proof of phone-level Files/iCloud entitlement.
