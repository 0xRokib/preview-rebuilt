# Preview parity checklist and staged implementation

## Evidence boundary

Target: installed Apple Preview 11.0 (1147), arm64. REA plist evidence: `ev_cef020127639f4e0db3bb7375871b4be115062ab3f31250235757effa0dc4910`. REA menu localization evidence: `ev_76192e5f34beea3d94c725664044f592839513b7a2d8bf300077e8a729d9d7a1`, saved in `Research/preview-menu-evidence.json` (en_GB labels). These establish declarations/labels, not whether commands are enabled or how they behave. Deep decompilation remains unavailable. No exhaustive runtime parity claim.

Status: implemented = code exposed to users; tested = named executable checks passed; pending = not delivered. Manual UI/accessibility/dialog checks remain pending unless explicitly recorded. Candidate features without menu labels require further runtime/help evidence.

## Stage 0 — baseline and inventory

- [x] PDF/static image import, thumbnails, continuous view, page navigation, zoom/fit, rotate right — baseline smoke tested.
- [x] PDF search, selected-text highlight, centered text notes — implemented; search/highlight interaction not manually tested.
- [x] PDF-copy export and source preservation — smoke tested.
- [x] Basic edit undo, unsaved warnings — implemented; dialog flow manual check pending.
- [x] Establish evidence-backed menu inventory and staged checklist.

## Stage 1 — PDF page management

- [x] Insert blank page after current page (`Blank Page`).
- [x] Insert all pages from another PDF/image (`Page from File…`); merge is a rebuild design choice.
- [x] Move current page earlier/later; drag/multi-select parity remains pending.
- [x] Delete current page (`Delete`), refuse deleting final page.
- [x] Extract current page to PDF copy; multi-page ranges remain pending.
- Acceptance: insertion copies pages without mutating source, correct page identity/order, boundary and invalid-index rejection, delete/insert/move undo, export/reload preservation.
- Verification: `swift run PreviewSmoke`, native page-action smoke mode, release build.

## Stage 2 — protected documents

- [x] Secure password prompt on opening locked PDF (`Enter Password…`) and importing protected pages.
- [x] Wrong password/cancel leaves current document unchanged (implemented; interactive cancel/retry audit pending).
- [x] Enforce edit/copy permissions before core page/annotation changes and export; restricted-reader fixture tested. Native PDFView widget permission behavior requires separate audit.
- [ ] Password-protected export and `Edit Permissions…` — later security-sensitive slice.
- Acceptance: generated encrypted fixture rejects missing/wrong password, accepts correct password; password never logged or persisted.

## Stage 3 — image editing and format export

- [x] Native raster backing with EXIF-oriented decoding and pixel-size bounds.
- [x] Numeric crop/resize and horizontal/vertical flip, with undo and source preservation.
- [ ] Drag rectangular selection, DPI/aspect lock, raster rotate left/right.
- [x] Exposure/contrast/saturation adjustment with undo.
- [ ] Sharpness, reset, redo.
- [x] PNG/JPEG/TIFF/HEIC export and dimension/format reload tests; fixed quality 0.9.
- [ ] Quality controls and pixel orientation/alpha/DPI tests.
- [ ] Automatic selection/mask/background removal; ICC assign/soft proof, image background.
- Acceptance: known pixel fixtures verify dimensions, orientation, alpha, export format, reversible edits, unchanged source.

## Stage 4 — markup and annotation editing

- [x] Underline/strike-through selection; choose/delete/move/resize annotations through dialogs.
- [ ] Annotation sidebar, direct drag selection.
- [ ] Draggable/resizable styled notes/text, rectangle/oval/line/arrow/polygon/star/speech bubble.
- [ ] Freehand drawing, signatures (typed/drawn first; camera/trackpad capture separately).
- [ ] Redo and clean-state tracking after undo/export.
- [ ] True redaction, only after tests prove removed text and images cannot be recovered. Covering content with a rectangle is NOT redaction.
- Acceptance: annotation types/geometry/style survive reload; undo/redo and rotated-page coordinate tests.

## Stage 5 — navigation, inspector, text/forms

- [ ] Single/two-page modes, contact sheet, table of contents, bookmarks, go-to-page, actual size, zoom selection, magnifier, full screen/slideshow.
- [ ] Find next/previous/selection, clipboard, metadata/location inspector.
- [ ] PDF forms and OCR/Live Text (candidates requiring runtime evidence, not established by menu labels).
- [ ] Speech, spelling/grammar through native text controls.
- Acceptance: searchable text fixtures, editable widget persistence, OCR sample accuracy, page/outline navigation tests.

## Stage 6 — native integrations and document lifecycle

- [ ] Print (preview/cancel first), share, open recent, new from clipboard.
- [ ] Save/duplicate/revert/version lifecycle; deliberate source-save policy with backups.
- [ ] Scanner/camera/screenshot imports (permissions and hardware-dependent).
- [ ] Preferences, customizable toolbar, keyboard shortcuts, Services, window cleanup.
- [ ] iCloud/document coordination (candidate; plist declares container).
- Acceptance: dialogs cancel without writes, authorized exports only, lifecycle/recent-file checks and manual hardware tests.

## Stage 7 — specialised formats and final parity audit

- [ ] Plist-advertised image/raw/legacy formats, animated/multi-frame image behavior.
- [ ] 3D viewing/manipulation/rendering, supported scene export, Vision Pro integration.
- [ ] Runtime compare every supported command with Apple Preview using synthetic documents; unsupported/hardware-dependent cases stay explicit.
- [ ] Keyboard-only, VoiceOver, dark/light appearance, minimum window size, large-file responsiveness, corrupt-file checks.
- [ ] Packaging/notarization/sandbox policy after scope agreement (no publishing authorized).

## Verification ledger

Baseline: release build and PDF/TIFF runtime smoke passed; core smoke passed. XCTest unavailable (`unable to resolve module dependency: 'XCTest'`) with this host's command-line tools. No manual visual verification. Further stage results recorded here as work completes.

Stage 1: core smoke passed for blank insertion, identity/order and reverse move, deletion/final-page guard, merge cloning, extract/reload annotation preservation, invalid index. Native smoke passed insert/move/undo using the actual window. Merge/delete/extract dialogs and menu dispatch need manual interaction checks.

Stage 2 opening slice: encrypted fixtures passed missing/wrong password rejection and correct owner-password opening. Restricted user fixture passed edit/annotation/copy denial and refused insert/rotate/note/export. Secure prompt implemented; manual cancel/retry and native widget checks pending. Password export/edit-permissions remain open.

Updated release bundle built and strict ad-hoc signature verification passed. XCTest still unavailable on host; smoke runner is the executable verification path. Additional slices delivered below; full parity remains incomplete.

Raster slice: smoke passed crop/resize dimensions, double-flip dimensions (pixel identity not yet checked), color-filter execution, PNG/JPEG/TIFF/HEIC encoding/type/dimension reload, invalid-size denial, and unchanged source. Image edits are refused on merged/annotated/rotated documents to prevent losing PDF edits.

Additional commands implemented: rectangle/ellipse/arrow markup, underline/strike-through, annotation choose/delete/numeric move/resize, single/continuous/two-page modes, go-to-page, full screen, metadata inspector, password-protected export, print, PDF-copy sharing, and asynchronous page OCR/copy. Vision OCR recognized the synthetic fixture; native dialog workflows, printing/sharing recipients, annotation persistence and protected-export UI remain manually unverified. Protected-export passwords match owner/user; permission editor is still pending. Sharing retains a generated temporary PDF for recipients; cleanup policy remains pending.

Core source-destination guard added, including symlink aliases; smoke passed direct and symlink overwrite denial. Release build, existing native PDF smoke, and strict signature verification passed after these changes.
