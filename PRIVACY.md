# Privacy and local data

Preview Rebuilt is an independent local macOS PDF/image application, not affiliated with or endorsed by Apple.

- The application has no built-in analytics, account system, server upload or network client.
- Documents are opened locally. App-managed changes stay in memory until explicit export; source files are not automatically saved. Unsaved changes can be lost in a crash.
- Page text recognition uses Apple Vision on the Mac. Copying recognized text places it on the system clipboard; other applications and system clipboard features can access it.
- Sharing creates a private temporary PDF and passes it to the chosen macOS sharing service. That service may transmit it according to its own privacy terms. The app attempts removal after completion, cancellation or failure; crashes can leave a temporary copy.
- Printing sends document content to the selected macOS print destination, which may be a network printer.
- Opening/export passwords are not intentionally logged or stored by this app; ordinary Swift strings and system frameworks do not guarantee secure memory erasure. Exported protected documents contain encrypted content.
- macOS may create crash reports, recent-file metadata or caches outside application control.

For sensitive documents, review clipboard, sharing, print and system settings. Contact the support URL supplied by the distributor. This document describes implemented behavior, not an independent privacy/security certification.
