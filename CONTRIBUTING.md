# Contributing

Preview Rebuilt is an experimental independent native macOS application. Contributions are welcome through issues and pull requests. No full Apple Preview parity or production-readiness claim is made.

## Development

Use macOS 13 or later with Swift 5.9 or later. Full Xcode is recommended for XCTest; select its developer directory if your command-line toolchain cannot resolve XCTest. There are no third-party runtime dependencies.

```bash
swift build --product PreviewRebuilt
swift test
swift run PreviewSmoke
python3 scripts/test-release-gates.py
# Requires an interactive macOS desktop:
bash scripts/verify.sh
```

CI checks builds, XCTest, core smoke scenarios and release-gate tests. Interactive tests, VoiceOver, older OS compatibility and actual distribution signing must be verified separately.

## Pull requests

- Keep changes focused; describe behavior, risks and verification results.
- Add regression tests for bugs and validate permission and original-file protection boundaries.
- Never include documents containing personal data, credentials, certificates, private keys, generated app bundles or Apple implementation/assets. Use synthetic fixtures.
- Keep feature and verification status honest in FEATURE_CHECKLIST.md and RELEASE_READINESS.md.
- Do not call overlay rectangles redaction; removal must be independently verifiable.
- Contributions are submitted under the project MIT license; only contribute material you have the right to license.

Be respectful and constructive. Security issues belong in private reports, not public issues.
