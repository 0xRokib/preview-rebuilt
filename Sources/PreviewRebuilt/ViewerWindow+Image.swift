import AppKit
import PDFKit
import PreviewCore
import UniformTypeIdentifiers

extension ViewerWindow {
    func numbers(_ title: String, labels: [String], defaults: [Double]) -> [Double]? {
        let alert = NSAlert()
        alert.messageText = title
        let fields = defaults.map { NSTextField(string: String($0)) }
        for (label, field) in zip(labels, fields) { field.setAccessibilityLabel(label) }
        let rows = zip(labels, fields).map { label, field in
            NSStackView(views: [NSTextField(labelWithString: label), field])
        }
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.frame = NSRect(x: 0, y: 0, width: 360, height: labels.count * 36)
        alert.accessoryView = stack
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let values = fields.compactMap { Double($0.stringValue) }
        guard values.count == fields.count, values.allSatisfy({ $0.isFinite }) else {
            showError(PreviewError.invalidPage); return nil
        }
        return values
    }
    func editRaster(_ operation: (RasterImage) throws -> RasterImage) {
        guard let raster else { NSSound.beep(); return }
        guard model?.pdf.pageCount == 1, model?.pdf.page(at: 0)?.annotations.isEmpty == true,
              model?.pdf.page(at: 0)?.rotation == 0 else {
            let alert = NSAlert()
            alert.messageText = "Image edits require an unannotated, unrotated single image"
            alert.informativeText = "Undo PDF page/markup edits first. This prevents losing those edits during raster replacement."
            alert.runModal(); return
        }
        do {
            let result = try operation(raster)
            undoEdits.append { [weak self] in self?.applyRaster(raster) }
            applyRaster(result)
        } catch { showError(error) }
    }
    func applyRaster(_ value: RasterImage) {
        guard let page = PDFPage(image: NSImage(cgImage: value.image, size: .zero)), let model else { return }
        raster = value
        model.pdf.removePage(at: 0)
        model.pdf.insert(page, at: 0)
        refreshPages(at: 0)
    }
    @objc func resizeImage() {
        guard let raster, let v = numbers("Resize image (pixels)", labels: ["Width", "Height"],
             defaults: [Double(raster.image.width), Double(raster.image.height)]) else { return }
        guard v.allSatisfy({ (1...16384).contains($0) }) else { showError(PreviewError.invalidPage); return }
        editRaster { try $0.resize(width: Int(v[0]), height: Int(v[1])) }
    }
    @objc func cropImage() {
        guard let raster, let v = numbers("Crop image (pixels, top-left origin)", labels: ["X", "Y", "Width", "Height"],
             defaults: [0, 0, Double(raster.image.width), Double(raster.image.height)]) else { return }
        editRaster { try $0.crop(CGRect(x: v[0], y: v[1], width: v[2], height: v[3])) }
    }
    @objc func flipHorizontal() { editRaster { try $0.flip(horizontal: true) } }
    @objc func flipVertical() { editRaster { try $0.flip(horizontal: false) } }
    @objc func adjustColors() {
        guard let v = numbers("Adjust colors", labels: ["Exposure (-3…3)", "Contrast (0…3)", "Saturation (0…3)"], defaults: [0, 1, 1]) else { return }
        editRaster { try $0.adjust(exposure: v[0], contrast: v[1], saturation: v[2]) }
    }
    @objc func exportImage() {
        guard let raster else { NSSound.beep(); return }
        guard model?.pdf.pageCount == 1, model?.pdf.page(at: 0)?.annotations.isEmpty == true,
              model?.pdf.page(at: 0)?.rotation == 0 else { showError(PreviewError.exportFailed); return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
        panel.nameFieldStringValue = "Image copy.png"
        guard panel.runModal() == .OK, let url = panel.url,
              let type = UTType(filenameExtension: url.pathExtension),
              model?.sourceURL?.resolvingSymlinksInPath().standardizedFileURL != url.resolvingSymlinksInPath().standardizedFileURL else { return }
        do { try model?.validateDestination(url); try raster.export(to: url, type: type) } catch { showError(error) }
    }
}
