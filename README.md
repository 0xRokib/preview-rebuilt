# Preview Rebuilt

Experimental · Native macOS · MIT licensed

Independent open-source project. Not affiliated with or endorsed by Apple. Source publication is not a production binary release.

```bash
git clone https://github.com/0xRokib/preview-rebuilt.git
cd preview-rebuilt
bash scripts/build-app.sh
open "dist/Preview Rebuilt.app"
```

See [Contributing](CONTRIBUTING.md), [Security](SECURITY.md), [Privacy](PRIVACY.md), and [release readiness](RELEASE_READINESS.md). An [experimental Apple Silicon DMG prerelease](https://github.com/0xRokib/preview-rebuilt/releases/tag/v0.1.0-experimental) is available. It is ad-hoc signed and **not notarized**; Gatekeeper may block it. Do not disable security checks to bypass rejection; build from reviewed source instead. Builds are ad-hoc signed unless you configure your own Developer ID.

Independent native macOS PDF/image viewer built with Swift, AppKit, and PDFKit. This is a scoped first version, not a complete clone or recovered Apple source. Apple Preview and original documents remain untouched.

## Run

```bash
open "dist/Preview Rebuilt.app"
```

## Build

```bash
bash scripts/build-app.sh
```

Requires macOS and Swift command-line tools. The bundle is locally ad-hoc signed, not notarized or sandboxed. Built and tested on this Mac (arm64, macOS 27 SDK); macOS 13 compatibility is declared but not verified on an older OS. No third-party dependencies. No network calls.

## Included

- Native windows, File/Open, Finder file-open handling, multiple windows
- PDF viewing and OS-supported static image import via NSImage
- PDF thumbnails, continuous scrolling, previous/next page, zoom, fit
- Clockwise page rotation; selected-text highlights; centered free-text notes
- In-memory edit undo
- Pages menu: blank insertion, merge PDF/image file pages, move earlier/later, delete (last-page guard), extract current page
- Secure password opening with retry/cancel and core edit/copy permission guards
- Numeric image crop/resize, flips, exposure/contrast/saturation, PNG/JPEG/TIFF/HEIC export
- Rectangle/ellipse/arrow, underline/strike-through, annotation delete/move/resize dialogs
- Page display modes, go-to-page, full screen, document information
- Vision page OCR and copy, protected PDF export, native print/share commands (interactive workflows unverified)
- PDF text search (Return searches; raster image text is not OCR-indexed)
- Export to a PDF copy, atomic writes, same-source-path overwrite guard
- Unsaved-edit warnings before replacing a document, closing, or quitting

Images have a native raster backing displayed through PDF pages; raster edits/export require a single unannotated, unrotated image to prevent dropping PDF edits. Notes start at page center and can be repositioned numerically. Undo covers app-managed edits and tracks saved-state identity; no redo. Native PDF widget edits require further lifecycle auditing. Original source files are not automatically saved.

## Release readiness

Hardened development build, not approved for public distribution. See `RELEASE_READINESS.md` for fixes, tests, and blocking release gates. Run `bash scripts/verify.sh` for repeatable automated checks. Developer ID signing is optional through `SIGNING_IDENTITY`; notarization, sandbox policy and manual QA remain outstanding.

## Not included

Drag cropping/selection, DPI/ICC controls, signatures, freehand drawing, permission editor, redo, verified redaction, multi-page selection/drag, 3D files, iCloud integration, full Preview menu/toolbar parity, or Apple artwork. These are future work, not claimed features. See `FEATURE_CHECKLIST.md` for the evidence-backed stage plan and verification ledger.

## Evidence and provenance

REA opened `/System/Applications/Preview.app/Contents/MacOS/Preview` as arm64 Mach-O with SHA-256 `9750218836c974537f8d9b671b90f47b986bb1a66320613d8fbd682862eb9c33`.

REA `inspect_plist` evidence `ev_cef020127639f4e0db3bb7375871b4be115062ab3f31250235757effa0dc4910` observed Preview version 11.0 (1147), PDF document class `PVPDFPageContainer`, and image class `PVImageContainer`, plus declared editor/viewer types. Complete evidence is retained locally and excluded from the public repository; it is not distributed under the MIT license. Plist declarations establish advertised types, not runtime behavior.

REA also parsed Preview's shipped MainMenu localization table: evidence `ev_76192e5f34beea3d94c725664044f592839513b7a2d8bf300077e8a729d9d7a1`, retained locally (raw Apple-derived evidence is excluded from the public repository). Menu labels inform the feature checklist but do not establish runtime behavior.

Deep analysis was unavailable: Ghidra not configured, Hopper launcher absent, IDA not configured. No Apple implementation was decompiled. Our architecture and feature choices are independent design decisions; UI parity was not measured against a running Apple Preview.

## License

Original project source and documentation are licensed under [MIT](LICENSE). Apple frameworks, trademarks and other third-party materials remain subject to their respective rights; no Apple binary, source or artwork is included. Local artifact-analysis outputs are excluded from publication.

## Verification

```bash
swift build --product PreviewRebuilt
swift run PreviewSmoke
PREVIEW_FIXTURE_DIR="$PWD/.build/fixtures" swift run PreviewSmoke
bash scripts/build-app.sh
"dist/Preview Rebuilt.app/Contents/MacOS/PreviewRebuilt" --ui-smoke-test "$PWD/.build/fixtures/sample.pdf"
swift test # requires a toolchain supplying XCTest (full Xcode on this host)
```

Passed on this host: debug build, release bundle build, core smoke checks (rotation wrap, load/export, annotation persistence, unchanged source bytes, TIFF import, invalid-file rejection), native-window runtime checks (document loaded, nonzero viewer layout, zoom/fit, rotation/undo, sidebar toggle). Runtime checks invoke controls programmatically; they do not prove keyboard, dialog, Finder integration, text search/highlight, or visual parity.

`swift test` could not resolve XCTest with this Mac's command-line-tools installation. Equivalent core scenarios ran through `PreviewSmoke`, but XCTest results are unverified. SDK linker search-path warnings are present; builds succeed. CoreGraphics logs a PDF error during intentional invalid-file rejection. No screenshot or manual accessibility audit was performed.
