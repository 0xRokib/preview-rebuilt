# Human release QA report

Copy this file outside the repository and fill it with actual results. Do not convert TODOs to PASS without testing. Document OS versions, hardware, steps, results and defects.

Reviewer:
Date:
Version:
Build:

TODO dialogs: password retry/cancel, import/delete/extract, save/protected export reload, print preview/cancel.
TODO permissions-and-forms: restricted PDF user/owner paths, native widget mutation, unsaved-close/export behavior.
TODO large-corrupt-files: resource limits, malformed corpus, UI responsiveness, recovery.
TODO keyboard-voiceover: menus, focus, labels, error dialogs, keyboard-only document editing.
TODO appearance-and-layout: dark/light, minimum size, scrolling toolbar, screenshots.
TODO sharing-lifecycle: success/failure/cancel, recipient lifetime, private copy cleanup, crash recovery.
TODO macos-support: host and minimum supported macOS 13 on arm64; clean-Mac Gatekeeper/install/uninstall. Intel is not advertised.
TODO legal-and-support: owner-approved identifier/icon/license, support URL, privacy, non-affiliation and limitations.

For each passed category, replace its TODO line with:
`PASS category: tested steps, environment, outcome and evidence location`

The validator checks presence only, not authenticity. This report does not waive known defects.
