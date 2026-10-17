# SMOKE_TEST_MATRIX — Evidence, not assumptions

Status on first publication: ALL NEW NATIVE GATES PENDING. The earlier 111/111 R03 checks tested a browser prototype; earlier G5 44/44 tests and IPA were on an older SHA. Those are **not** current native results.

## CI automated gates
- Public-source scope and credential pattern checks
- Portable Swift core: swift test on Ubuntu, independent job
- Debug Simulator compilation with candidate startup condition
- iOS Simulator XCTest: shared Xcode scheme; check exact test counts in xcresult/log
- Release Simulator compilation (Release pilot policy unchanged)
- Debug iPhoneOS arm64 compile with CODE_SIGNING_ALLOWED=NO
- IPA Payload contains app executable, no bundled XCTest plug-in
- ZIP integrity, binary architecture, SHA-256 and public commit provenance

## Native functional smoke checklist
Record results per test case as PASS / FAIL / NOT TESTED with simulator type and iOS runtime. Tests are not automatically PASS merely because Xcode built.

1. Cold launch enters V3.1 flashcard view; exactly two tabs.
2. Show Answer; four swipes map to Hard / Good / Easy / Again.
3. Rating persistence, idempotency, FSRS6 rescheduling.
4. Create text, image and multiple-choice/single-choice cards.
5. PHPicker photo access (HEIC, PNG, JPEG), cancel; large file and storage failures.
6. Compression targets and card write atomicity.
7. Record Understanding cancel/commit; versioned history; AI feedback permission.
8. Provider configuration, bad credentials and offline errors; editable prompts.
9. Off / Smart / Daily Habit notification options and local reminder delivery.
10. Notes list, Markdown links, local attachments and duplicate basenames.
11. Authorized Obsidian Vault readonly indexing and folder identity.
12. Private draft; SHA/diff guard, conflict refusal, recovery backup, no write-on-cancel.
13. Long-answer scroll versus swipe gesture; dynamic type and small screens.

## Physical-device-only or still-open gates
- Security-Scoped Bookmark lifetime and iOS Files provider behavior: NOT TESTED
- iCloud File Provider read/restore and real-device permission flows: NOT TESTED
- Actual Photos picker HEIC performance on iPhone: NOT TESTED
- iPhone notifications across sleep/reboot: NOT TESTED
- Personal/free account entitlement provisioning and on-device install: NOT TESTED
- Production Vault writeback: DISABLED BY DESIGN, not a missing test

For a final release report, cross-link Actions run ID, exact SHA, XCTest .xcresult, build log and simulator video/screenshot evidence. A test source file is not itself a passing test report.
