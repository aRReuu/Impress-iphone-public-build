# BUILD_AND_SIGN — Impress V3.2 public feature branch

**2026-10-19 knowledge-workflow candidate:** run current [KNOWLEDGE_LIFECYCLE_V1.md](KNOWLEDGE_LIFECYCLE_V1.md) requirements and [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md) on the exact final head. Old run artifacts do not attest to G0–G6. A QA unsigned IPA, if created, remains non-release and does not establish Keychain/real provider/Obsidian device permissions.

## Current executable workflow (2026-10-22 V1.1)
**唯一有效的施工分支**为 `feature/impress-duplex-loop-v1`，完整 iOS 构建与 Native XCTest / XCUITest / unsigned ARM64 + Widget IPA 工作流为 `.github/workflows/public-ios-build.yml`。每次通过该分支最新 HEAD 的 Actions Run 检查所有测试层级，并将产物内 `IPA_SHA256.txt` 与安装前文件的 SHA-256 对照；历史 V3.2 / R03 的原分支与工作流不是本轮交付权威。

Last known stable CI before new UI E2E expansion: `738a333d8a6ccd656117e0316bac6396ccf9f262`, [Actions #39648988015](https://github.com/aRReuu/Impress-iphone-public-build/actions/runs/39648988015), 191/191 Native XCTest and 8/8 XCUITest PASS. It produced `Impress-V3.1-P0P2-738a333d8a6c-unsigned.ipa`, SHA-256 `0323cf20e93104272f8cc5e72b32b0949878c0938b99d70aa4797f0bc5b6d628`; newer HEADs must pass independently. A future successful run only proves simulator + unsigned package, not iPhone13 or App Group entitlements.

GitHub Actions installs pinned CocoaPods, runs all portable Swift Core tests (including calibration), audits retired native Chat and public Git history for credentials, compiles the Simulator app, runs full UIKit XCTest, compiles the `aReuImpress-iPhone-AltStore` iPhoneOS ARM64 app with `CODE_SIGNING_ALLOWED=NO`, verifies executable, unsigned state, ZIP and SHA-256, and uploads the testing Artifact.

## Explicitly incomplete original App Icon
Public source intentionally includes seven unchanged original iPhone AppIcon PNGs but lacks byte-identical `AppIcon.appiconset/icon_1024.png` (expected Git blob `f5a0edd2f317c7104441ee8798fb0fbf00cff9e5`). No image is generated or scaled to replace it.
The native-qa CI modifies `Contents.json` **only inside its ephemeral runner** to omit the unavailable App Store marketing slot. An artifact whose IPA name includes `7icon-INCOMPLETE-unsigned` is thus a development candidate, never a Release PASS. `.github/scripts/verify_public_mirror.py` intentionally continues to fail the full eight-icon release gate until the owner explicitly supplies the authentic binary. Do not turn the gate off.

## Validation commands
On a trusted Mac with matching Xcode/CocoaPods:

```bash
swift test --package-path Packages/ImpressReviewCore --parallel
python3 .github/scripts/verify_retired_native_chat.py
python3 .github/scripts/check_git_history_secrets.py
pod install --repo-update
xcodebuild -workspace aReuImpress-iPhone.xcworkspace -scheme aReuImpress-iPhone -configuration Debug -destination 'generic/platform=iOS Simulator' IPHONEOS_DEPLOYMENT_TARGET=26.0 CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace aReuImpress-iPhone.xcworkspace -scheme aReuImpress-iPhone-AltStore -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' IPHONEOS_DEPLOYMENT_TARGET=26.0 CODE_SIGNING_ALLOWED=NO CODE_SIGN_ENTITLEMENTS= ENABLE_DEBUG_DYLIB=NO build
```

The full XCTest requires a real available iPhone Simulator destination and the project's shared XCTest scheme; consult CI rather than substituting a build-only command for the test result. New acceptance requires regression of live System/Light/Dark switching, three persisted UI languages, stale-safe understanding edits with historical revisions, native Notes grouped-list style and read-only Markdown document presentation. Do not run the six non-icon placeholder generator on original icons.

## User signing and iCloud limitations
The IPA is unsigned and must be signed with the user's own Apple identity/provisioning on a compatible tool. A free Personal Team can restrict iCloud and App Groups entitlements; removing entitlement requests may allow installation **but does not certify iCloud Files Provider access**. iCloud backup folder selection, security-scoped bookmarks, notification delivery after reboot, time-zone changes and dark/light UI require iPhone 13 physical QA.

## Provenance
Use GitHub Actions Artifact URL from the exact target SHA, SHA256SUMS / IPA_SHA256, Xcode job logs, and the application's bundle ID. `SOURCE_MANIFEST.json` preserves historical mirror provenance but its historical blob digests are not a claim that current V3.2 files are byte-identical to that snapshot. Never declare a Release, or modify private/main branches, without separate authorization.

## iOS 26 deployment migration
App and XCTest targets now require iOS 26.0. CocoaPods and all CI compiler overrides match the same minimum. The native packaging job verifies the built app's `MinimumOSVersion` is exactly `26.0` in addition to ARM64, unsigned status and SHA-256. This is strictly a platform-floor change: STT, new Markdown rendering and full iPhone 13 voice acceptance remain separate pending work. Keep original App Icon release blockade and all data safety gates intact.

## iOS 26 native STT candidate
The iOS 26 branch adds Apple-only `SpeechAnalyzer` voice input, a new Settings page, isolated editor accessory and microphone-use reason. CI uses `.github/scripts/verify_apple_stt_contract.py` for static privacy/route checks and UIKit regression tests for transcription buffer and insertion rules. The unsigned candidate name uses `Impress-V3.3-<HEAD>-7icon-INCOMPLETE-unsigned.ipa` and is not directly installable. A green simulator test cannot prove microphone, available Apple models or cloud-independent recognition on iPhone 13; do not describe them as device-PASS.

## 2026-10-22 · 实际 Widget 侧载签名与四指标排障

当前 `aReuImpress-iPhone.entitlements` 和 `ImpressCalibrationWidgets.entitlements` 都指定 `group.areu.impress`，但通用 iPhoneOS CI 采用 `CODE_SIGNING_ALLOWED=NO CODE_SIGN_ENTITLEMENTS=` 产出 unsigned IPA，不能据此声称该组已被安装设备的两个进程授权。侧载工具重新签名后，必须核查主 App 和 `.appex` 分别具备同一 `com.apple.security.application-groups` 值、对应 Bundle ID/Team/Profile 能力，随后打开主 App 校准器执行单向共享投影与 Widget 刷新。若签名工具无法给扩展授予 App Group 权限，Swift 不可能绕过系统沙箱，应保留可诊断空态和 DEVICE_BLOCKED。不要往 GitHub 上传 .mobileprovision、证书、私密账本。

新版本的 `CalibrationWidgetSnapshot.currentVersion=2`，兼容目录文件名仍为 `calibration-widget-v1.json`；老 5 口径缓存失效并重新投影，不重建计分器。现有 `checkins-v1.json` 原账本继续唯一权威；新四行为睡眠/运动/饮食/阅读，历史 custom/mood 保留在旧记录中，不参与新卡片输入。
