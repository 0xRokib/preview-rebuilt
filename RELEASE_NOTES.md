# Preview Rebuilt — release candidate

Independent native PDF/image viewer for macOS. Not Apple Preview, not a feature-complete clone, and not recovered Apple source.

Includes document viewing/search, page management, basic annotations, numeric raster editing and PNG/JPEG/TIFF/HEIC export, local OCR, protected PDF export and native print/share commands.

Safety improvements include atomic copy exports, source-path/alias protection, resource limits, history-based unsaved-state tracking, private temporary sharing copies and repeatable build verification.

Current candidate is arm64-only; minimum macOS 13 is declared but still requires release testing. PDF parsing/search/export may block the UI. Native PDF widget edits, interactive workflows and share crash cleanup require QA. No autosave, redo, verified redaction, sandbox, iCloud integration, 3D viewing or full Preview parity.

Install a notarized candidate by extracting the ZIP and moving Preview Rebuilt.app to Applications. Do not disable Gatekeeper or strip quarantine to bypass a failed assessment. Remove the app to uninstall; explicitly exported files remain wherever you saved them.

See RELEASE_READINESS.md for public-release gates. No release is approved merely by generating this file.
