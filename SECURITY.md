# Security policy

This project is experimental, with no guaranteed response time or supported production release. Security fixes target the default branch. Do not rely on it for sensitive or hostile documents without independent review.

## Report a vulnerability

Use GitHub private vulnerability reporting under the repository Security tab when available. If unavailable, open a public issue requesting a private contact without including exploit details, affected personal files, credentials or confidential data.

Include affected revision/macOS, synthetic reproduction, expected/actual behavior and impact. Do not publish exploitable details before coordinating a fix.

## Known boundaries

- Not sandboxed; PDFKit/ImageIO process document inputs locally. Resource caps are not parser isolation.
- Permission/form-widget behavior and crash recovery need further auditing.
- Path checks prevent ordinary original-file overwrite but are not protection against concurrent hostile filesystem changes.
- Share copies are private and normally removed; crashes may leave temporary documents.
- Password strings are not intentionally persisted/logged, but secure memory erasure is not guaranteed.
- No verified redaction, autosave or production certification.

Do not disable Gatekeeper to run untrusted binaries. Prefer building from reviewed source; only distribute binaries after release gates are satisfied.
