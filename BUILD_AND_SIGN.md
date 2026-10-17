# BUILD_AND_SIGN — Unsigned iPhoneOS arm64 Debug candidate

## GitHub-hosted build
Open the Actions tab in this public repository and select Impress V3.1 P0-P2 Public Build. A push to main also initiates the build. The workflow installs Pods, generates independently authored neutral build assets, tests portable Swift, builds Debug/Release Simulator, runs Xcode XCTest, builds Debug iphoneos and packages only Payload/aReuImpress-iPhone.app into an unsigned IPA. It verifies ZIP integrity and publishes an IPA SHA-256 manifest and logs.

The IPA is named Impress-V3.1-P0P2-<PUBLIC_SHA12>-unsigned.ipa. The commit SHA in this name is the sanitized public snapshot, not the private upstream commit. The package manifest records both. If CI fails, do not treat an uploaded partial log as proof of a complete IPA.

## Reproducible local macOS build (no Apple signing credentials)
Use a compatible Xcode installation and CocoaPods. In the repository root:

    python3 .github/scripts/generate_neutral_assets.py
    pod install
    swift test --package-path Packages/ImpressReviewCore
    xcodebuild -workspace aReuImpress-iPhone.xcworkspace -scheme aReuImpress-iPhone -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

Find the app under the selected DerivedData/Build/Products/Debug-iphoneos directory, package a Payload directory into a ZIP with an .ipa suffix, and verify with unzip -tq. Do not publish device credentials to CI.

## Private personal-account re-signing
An unsigned IPA cannot be installed directly. Use a device-side sideload/resigning tool that supports an IPA, or sign the built app with your own free Personal Team provisioning profile using Xcode on a Mac. For Windows-based sideloading, verify the chosen tool supports the iOS release and Apple personal-account restrictions.

Free personal provisioning commonly limits certificate lifetime (often seven days) and may not provide iCloud or App Groups capabilities. This project's entitlements request App Groups and iCloud. A signing attempt may fail unless **a separate local signing copy** uses an eligible Bundle ID and strips unsupported entitlements and matching capabilities. Keep the repository and original private project unchanged. Disabling those entitlements may make iCloud-dependent features unavailable even when the app launches; validate and disclose this limitation. Never remove Vault conflict controls or enable production writes to work around signing constraints.

## Provenance
SOURCE_MANIFEST.json pins private upstream revision and public source rules; the Actions package-manifest.json embeds the actual public HEAD, upstream HEAD, SHA-256, build mode and unsigned status. Compare sha256sum / shasum -a 256 to the downloaded IPA before trusting it.
