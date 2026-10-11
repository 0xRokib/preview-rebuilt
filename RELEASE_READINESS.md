# Release readiness

Status: hardened development build, **not approved for public production distribution**. Feature parity and release readiness are separate. No distribution, credential changes, or notarization submission were performed.

## Implemented and verified

- Exact history identity for dirty-state tracking: undo to initial state is clean; undo after export is dirty; same-depth branches cannot masquerade as saved.
- Closed viewer controllers removed from application ownership.
- File loading rejects non-file URLs, directories, files over 256 MB and PDFs over 2,000 pages. ImageIO checks dimensions before pixel decode (40 million pixels, maximum dimension 16,384); EXIF orientation normalized.
- Core export guards reject original paths, symlinks, and hardlinks. Atomic exports protect against partial writes. This is not a defense against a concurrent hostile filesystem actor changing paths between validation and write.
- Toolbar horizontally scrollable at narrow widths; numeric input accessibility labels.
- OCR allows one operation per viewer and drops results after document replacement/window close. OCR itself is not cancellable yet.
- Share session retains its picker, creates private temporary copies (0700 directory/0600 file), and removes them after cancel/completion/failure or normal object destruction. Crash cleanup and actual sharing-service callback behavior need manual verification.
- Release script supports optional Developer ID signing with hardened runtime and timestamp; defaults explicitly to local ad-hoc signing. No signing identity supplied/tested.
- `bash scripts/verify.sh` passed: debug/release builds, smoke suite, plist lint, strict signature verification, native PDF/TIFF window smoke including undo-to-clean state.

## Public-release tooling

`release/README.md` documents the owner-configured workflow. `scripts/public-release.sh` fails closed without Developer ID, product metadata/icon/license/support URL, matching QA sign-offs and a local Keychain profile. Preparation creates a signed local archive labeled NOT-NOTARIZED. Only explicit `--notarize` submits to Apple, requires acceptance, staples, assesses Gatekeeper and produces a checksummed arm64 archive. No public publishing path exists.

Shell syntax and six release-gate tests passed; complete app verification passed before the final verification-script test hook was added. Real signing/notarization, icon validation and manual QA remain unverified. No owner identity, icon, license, support URL or completed QA report was supplied; no public candidate was generated.

## Blocking release gates

- [ ] Full Xcode CI: run XCTest, clean build, pin supported SDK/toolchain and establish a macOS test matrix. Current host cannot resolve XCTest.
- [ ] Test minimum supported macOS 13 and supported CPU architectures; current build tested only on host arm64.
- [ ] Manual dialogs: open cancel/wrong password/retry, merge/delete/extract, save overwrite/cancel, protected export reload, print preview/cancel, share success/failure/cancel.
- [ ] Verify PDFKit form/annotation edits cannot bypass permission guards or unsaved tracking. Unmanaged native widget edits are not yet tracked by our history.
- [ ] Corrupt/large/malicious PDF corpus and performance testing. PDF parsing/search/export still occur on main thread; size limits are mitigation, not isolation or responsiveness proof.
- [ ] Keyboard/VoiceOver, dark/light mode, narrow-window scrolling, error/focus behavior and actual screenshots.
- [ ] Verify share-copy crash cleanup and recipient lifetime. Sensitive documents may remain in temp after crashes.
- [ ] Product-owned bundle identifier, app icon, license/legal notices, release/support policy and versioning.
- [ ] Choose and validate sandbox/entitlement policy; current build is not sandboxed. Hardened runtime is not App Sandbox.
- [ ] Supply Developer ID locally, sign, notarize through a Keychain profile, staple and check Gatekeeper on a clean Mac. Do not send credentials in chat.

## Commands

```bash
bash scripts/verify.sh
# Only after release gates pass and a local signing identity is configured:
SIGNING_IDENTITY="Developer ID Application: Your Organization (TEAMID)" bash scripts/build-app.sh
```

The automated script does not claim manual QA, notarization, Apple Preview parity, or public production readiness. Known host warnings: absent CommandLineTools search paths; CoreGraphics diagnostic on some fixtures.
