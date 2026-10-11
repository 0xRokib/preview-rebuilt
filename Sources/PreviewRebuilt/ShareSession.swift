import AppKit
import PreviewCore

/// Owns private temporary copies through completion/cancel. Process crashes remain a release risk.
final class ShareSession: NSObject, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
    private let directory: URL
    private var picker: NSSharingServicePicker?
    var onFinish: (() -> Void)?
    init(model: PreviewDocument) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("PreviewShare-" + UUID().uuidString)
        super.init()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        do {
            let url = directory.appendingPathComponent("Document.pdf")
            try model.exportPDF(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            picker = NSSharingServicePicker(items: [url])
            picker?.delegate = self
        } catch { try? FileManager.default.removeItem(at: directory); throw error }
    }
    func show(in view: NSView) { picker?.show(relativeTo: .zero, of: view, preferredEdge: .minY) }
    private func finish() {
        try? FileManager.default.removeItem(at: directory)
        picker = nil
        onFinish?()
    }
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        if service == nil { finish() }
    }
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              delegateFor sharingService: NSSharingService) -> NSSharingServiceDelegate? { self }
    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) { finish() }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) { finish() }
    deinit { try? FileManager.default.removeItem(at: directory) }
}
