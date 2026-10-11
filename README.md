# Preview Rebuilt

[![macOS CI](https://github.com/0xRokib/preview-rebuilt/actions/workflows/ci.yml/badge.svg)](https://github.com/0xRokib/preview-rebuilt/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An independent, open-source PDF and image viewer for macOS, built with Swift, AppKit, PDFKit, ImageIO, Core Image, and Vision.

**Experimental. Not a complete Apple Preview replacement or production-certified application.** Not affiliated with or endorsed by Apple. No Apple source, binary, or artwork is included.

## Download and install

**[Download v0.1.0 experimental DMG — Apple Silicon](https://github.com/0xRokib/preview-rebuilt/releases/download/v0.1.0-experimental/Preview-Rebuilt-0.1.0-experimental-arm64.dmg)**

[Release notes and SHA-256 checksum](https://github.com/0xRokib/preview-rebuilt/releases/tag/v0.1.0-experimental)

1. Download the DMG and, optionally, its `.sha256` checksum file.
2. Open the DMG and read `READ-ME-FIRST.txt`.
3. Drag **Preview Rebuilt.app** to the **Applications** shortcut.
4. Eject the disk image and launch the app from Applications.

**This prerelease is ad-hoc signed, not Developer ID signed or notarized. macOS Gatekeeper may block it. Do not disable Gatekeeper or remove quarantine to bypass a failed security assessment. If blocked, build from reviewed source instead.**

The downloadable binary supports **Apple Silicon (arm64) only**. macOS 13 is the declared minimum, but compatibility on older supported OS versions has not been verified. No Intel binary is provided.

To verify the download, put the DMG and checksum file in the same directory, then run:

```bash
shasum -a 256 -c Preview-Rebuilt-0.1.0-experimental-arm64.dmg.sha256
```

A matching checksum verifies file integrity, not notarization or application safety.

## Features

### PDF viewing and editing

- Native windows, multiple documents, Open dialogs, and Finder file-open handling
- Thumbnails, page navigation, zoom/fit, single-page/continuous/two-page modes, and full screen
- Text search, go-to-page, and document information
- Insert blank pages, merge pages from PDF/image files, move pages earlier/later, delete with a final-page guard, and extract the current page
- Clockwise rotation, text highlights, underline, strike-through, and text notes
- Rectangle, ellipse, and arrow markup; annotation selection, deletion, and numeric move/resize dialogs
- Secure password-opening prompts, core edit/copy permission guards, and password-protected PDF-copy export
- App-managed edit undo with saved-state tracking and unsaved-edit warnings

### Images and text recognition

- Static image decoding with EXIF orientation normalization and native raster backing
- Numeric crop/resize, horizontal/vertical flip, exposure, contrast, and saturation adjustment
- PNG, JPEG, TIFF, and HEIC export
- Local page OCR using Apple Vision, with recognized-text copying

### macOS integration

- Native print and PDF-copy sharing commands
- Atomic copy exports and original-file path/symlink/hardlink protection
- File/page/pixel limits and private temporary sharing copies

Interactive dialogs, printing/sharing, accessibility, and native PDF widget behavior still need further QA. See the [feature checklist](FEATURE_CHECKLIST.md) for implementation and verification details.

## Important limitations

- **Back up your documents.** App-managed edits stay in memory until explicitly exported and can be lost in a crash. No autosave or redo.
- Original documents are not automatically saved. PDF export creates a copy; ordinary source-path aliases are rejected. This is not protection against concurrent hostile filesystem changes.
- Raster editing/export requires a single unannotated, unrotated image to avoid dropping PDF edits. Images are displayed through PDF pages.
- Notes start at page center; annotation repositioning is numeric, not direct dragging.
- No verified redaction, signatures, freehand drawing, drag crop/selection, DPI/ICC controls, permission editor, multi-page selection/drag, iCloud integration, or 3D viewing.
- OCR returns text but does not add a searchable text layer to the PDF.
- Native PDF widget edits are not fully audited for permission enforcement or unsaved-state tracking.
- PDF parsing/search/export can block the UI. Resource caps do not provide parser isolation. The app is not sandboxed.
- Sharing services may transmit documents, and crashes may leave temporary share copies. See [Privacy](PRIVACY.md).

## Build from source

Requires macOS 13 or later and a Swift 5.9+ toolchain. Full Xcode is recommended for XCTest. No third-party runtime dependencies.

```bash
git clone https://github.com/0xRokib/preview-rebuilt.git
cd preview-rebuilt
bash scripts/build-app.sh
open "dist/Preview Rebuilt.app"
```

Default builds are locally ad-hoc signed and not notarized. Building from source does not certify security or compatibility. The app has no built-in analytics or network client; macOS sharing and printing can use network destinations.

To package an experimental arm64 DMG after building:

```bash
bash scripts/build-experimental-dmg.sh
```

The script refuses to overwrite an existing DMG. Output is under `dist/`, which is excluded from Git.

## Tests and verification

```bash
swift build --product PreviewRebuilt
swift test
swift run PreviewSmoke
python3 scripts/test-release-gates.py
# Includes release bundle and native-window smoke checks; requires a desktop session:
bash scripts/verify.sh
```

GitHub macOS CI runs builds, XCTest, core smoke tests, release-gate tests, and bundle validation. The initial published source CI passed; the badge links to current results.

Local checks passed for core document edits/export, raster encoding/reload, OCR fixture recognition, permission guards, resource limits, source-file protection, edit-history state, PDF/TIFF native-window smoke, plist/signature validation, and DMG checksum/read-only mount inspection.

The local command-line-tools installation could not resolve XCTest; GitHub CI with Xcode supplies that check. Native-window smoke invokes actions programmatically, not through manual keyboard/dialog interactions. Manual VoiceOver, clean-Mac Gatekeeper, minimum-OS compatibility, and full Apple Preview parity checks remain outstanding. Known local diagnostics include missing CommandLineTools linker search paths and CoreGraphics warnings on some fixtures.

## Release status

The GitHub DMG is an **experimental prerelease**, not a stable production release. Developer ID signing, notarization, sandbox-policy review, supported-OS testing, and manual QA remain release gates.

- [Release readiness](RELEASE_READINESS.md)
- [Signed/notarized release workflow](release/README.md)
- [Experimental release notes](release/EXPERIMENTAL.md)

Source publication and experimental binary publication do not establish production readiness.

## Contributing and security

Issues and focused pull requests are welcome. Read [Contributing](CONTRIBUTING.md) for development and test expectations.

Report vulnerabilities through GitHub private vulnerability reporting; see [Security](SECURITY.md). Do not attach private documents or credentials to public issues. There is no guaranteed support or security-response timeframe.

## Provenance and license

Feature inventory was informed by local REA inspection of the installed Apple Preview 11.0 (1147) executable identity, document declarations, and shipped menu labels. No Apple implementation was decompiled. Those declarations do not prove runtime behavior; this application's architecture and implementation are independent. Raw Apple-derived research output is retained locally and excluded from the public repository.

Original project source and documentation are licensed under [MIT](LICENSE). Apple frameworks, trademarks, and other third-party materials remain subject to their respective rights.
