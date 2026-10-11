import AppKit
import PreviewCore

extension ViewerWindow {
    /// Password is used for this open attempt only; never persisted or logged.
    func openDocumentWithPassword(_ url: URL) throws -> PreviewDocument? {
        do { return try PreviewDocument(url: url) } catch PreviewError.locked {
            var wrongPassword = false
            while true {
                let alert = NSAlert()
                alert.messageText = wrongPassword ? "Incorrect password" : "Password required"
                alert.informativeText = "Enter the password for \(url.lastPathComponent). It will not be saved."
                let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                field.setAccessibilityLabel("PDF password")
                alert.accessoryView = field
                alert.addButton(withTitle: "Unlock")
                alert.addButton(withTitle: "Cancel")
                alert.window.initialFirstResponder = field
                guard alert.runModal() == .alertFirstButtonReturn else { return nil }
                let password = field.stringValue
                field.stringValue = ""
                do { return try PreviewDocument(url: url, password: password) }
                catch PreviewError.locked { wrongPassword = true }
            }
        }
    }
}
