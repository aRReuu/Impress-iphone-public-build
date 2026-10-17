# Impress V3.1 — Public iOS Build Mirror

This repository is a **source-only, independent-history build mirror** for the Impress V3.1 R03 P0–P2 iOS client. It is **not** the authoritative product or design repository.

- Private upstream: aRReuu/Impress-iphone, branch feature/impress-v3-review-foundation
- Frozen upstream revision: 9078600d9be7be048a550d32d43322e55e7d866d
- UI baseline: 2026-10-15 V3.1 with 2026-10-16 R03 refinements
- Public goal: repeatable macOS GitHub Actions builds of an **unsigned arm64 iPhoneOS IPA** for private re-signing

**The unsigned IPA is not directly installable without a user-controlled signature.** No Apple login, key, certificate, private Vault, or provisioning profile belongs in this repository. This mirror intentionally excludes upstream internal Docs, docs, commit history, Xcode user state, Pods source copies and original images whose redistribution rights were not established. Neutral CI-generated placeholders keep Xcode resource references working; they are not final branded artwork.

See [BUILD_AND_SIGN.md](BUILD_AND_SIGN.md), [PUBLIC_BUILD_CONTRACT.md](PUBLIC_BUILD_CONTRACT.md), [SMOKE_TEST_MATRIX.md](SMOKE_TEST_MATRIX.md), and [SOURCE_MANIFEST.json](SOURCE_MANIFEST.json).

The Debug candidate should open the V3.1 review experience on first launch. Release behavior is not migrated. Obsidian production Vault writes remain disabled pending real-device authorization and File Provider testing. A simulator PASS never means an iCloud or physical-device PASS.
