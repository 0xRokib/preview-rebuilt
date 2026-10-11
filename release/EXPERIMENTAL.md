# v0.1.0 Experimental — Apple Silicon

Experimental independent native macOS PDF/image viewer. Not affiliated with Apple; not a production-ready or feature-complete Preview clone.

## Download

Download `Preview-Rebuilt-0.1.0-experimental-arm64.dmg` and its `.sha256` checksum. The DMG contains the app, an Applications shortcut, MIT license, privacy notice and limitations. Drag the app to Applications.

**Ad-hoc signed, not Developer ID signed, not notarized. macOS Gatekeeper may block this download. Do not disable Gatekeeper or remove quarantine to bypass a failed security assessment. Build from reviewed source instead if blocked.**

Apple Silicon (arm64) only. macOS 13 minimum is declared; older macOS compatibility has not been verified. No Intel binary included.

## Features and limitations

PDF viewing/search, page management, basic markup, numeric raster crop/resize/flips/color adjustment, PNG/JPEG/TIFF/HEIC export, local OCR, protected PDF export, native print/share commands.

No autosave, redo, verified redaction, sandbox, full forms/lifecycle audit, iCloud or 3D support. Back up documents; in-memory edits may be lost in a crash. Native widget edit tracking, interactive workflows, accessibility, malformed-document performance and share crash cleanup remain QA gaps.

## Verification

Local debug/release builds, core smoke tests, six release-gate tests, PDF/TIFF native-window smoke, plist/signature validation passed. DMG checksum verification and read-only mount succeeded; packaged app signature, Applications link and warning notice checked. GitHub macOS CI passed on the preceding source commit; packaging update CI is tracked separately. No clean-Mac Gatekeeper success or notarization claimed.

Source: https://github.com/0xRokib/preview-rebuilt
License: MIT. No Apple binaries/artwork or local research outputs included.
