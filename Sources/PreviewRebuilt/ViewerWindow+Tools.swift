import AppKit
import PDFKit
import Vision
import PreviewCore

extension ViewerWindow {
    @objc func printDocument() {
        guard let model, model.pdf.allowsPrinting,
              let operation = model.pdf.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleToFit, autoRotate: true) else { return }
        operation.run()
    }
    @objc func shareDocument() {
        guard let model, let view = window?.contentView, shareSession == nil else { return }
        do {
            let session = try ShareSession(model: model)
            session.onFinish = { [weak self] in self?.shareSession = nil }
            shareSession = session
            session.show(in: view)
        } catch { showError(error) }
    }
    @objc func goToPage() {
        guard let model, let values = numbers("Go to page", labels: ["Page number"], defaults: [1]),
              values[0] >= 1, values[0] <= Double(model.pdf.pageCount),
              let page = model.pdf.page(at: Int(values[0]) - 1) else { return }
        pdfView.go(to: page)
    }
    @objc func singlePage() { pdfView.displayMode = .singlePage }
    @objc func continuousPages() { pdfView.displayMode = .singlePageContinuous }
    @objc func twoPages() { pdfView.displayMode = .twoUpContinuous }
    @objc func fullScreen() { window?.toggleFullScreen(nil) }
    @objc func inspectDocument() {
        guard let model else { return }
        let alert = NSAlert()
        alert.messageText = "Document information"
        let page = pdfView.currentPage
        let size = page?.bounds(for: .mediaBox).size ?? .zero
        alert.informativeText = "Pages: \(model.pdf.pageCount)\nPage size: \(Int(size.width)) × \(Int(size.height)) pt\nEncrypted: \(model.pdf.isEncrypted)\nAssemble: \(model.canAssemble) · Annotate: \(model.canAnnotate) · Copy: \(model.canCopy)\n\(model.pdf.documentAttributes?.description ?? "")"
        alert.runModal()
    }
    @objc func recognizeText() {
        guard !ocrRunning, let model, model.canCopy, let page = pdfView.currentPage else { return }
        let size = page.bounds(for: .cropBox).size
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
        let factor = min(2, 2400 / max(size.width, size.height))
        let thumbnail = page.thumbnail(of: NSSize(width: size.width * factor, height: size.height * factor), for: .cropBox)
        guard let image = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        ocrRunning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.ocrRunning = false
                    guard self.model === model, self.window?.isVisible == true else { return }
                    let alert = NSAlert()
                    alert.messageText = "Recognized text"
                    let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 300))
                    scroll.hasVerticalScroller = true
                    let view = NSTextView(frame: scroll.bounds)
                    view.string = text
                    view.isEditable = false
                    scroll.documentView = view
                    alert.accessoryView = scroll
                    alert.addButton(withTitle: "Copy Text")
                    alert.addButton(withTitle: "Close")
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                }
            } catch { DispatchQueue.main.async {
                self?.ocrRunning = false
                if self?.model === model, self?.window?.isVisible == true { self?.showError(error) }
            } }
        }
    }
    @objc func underlineText() { markText(.underline) }
    @objc func strikeText() { markText(.strikeOut) }
    private func markText(_ type: PDFAnnotationSubtype) {
        guard let model, model.canAnnotate, let selection = pdfView.currentSelection else { return }
        var annotations: [(PDFPage, PDFAnnotation)] = []
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let annotation = PDFAnnotation(bounds: line.bounds(for: page), forType: type, withProperties: nil)
                annotation.color = .systemRed
                page.addAnnotation(annotation)
                annotations.append((page, annotation))
            }
        }
        guard !annotations.isEmpty else { return }
        undoEdits.append { annotations.forEach { $0.0.removeAnnotation($0.1) } }
        markEdited()
    }
    private func chooseAnnotation() -> (PDFPage, PDFAnnotation)? {
        guard let model, model.canAnnotate, let page = pdfView.currentPage else { return nil }
        let annotations = page.annotations.filter { $0.type != "Widget" && $0.type != "Link" }
        guard !annotations.isEmpty else { NSSound.beep(); return nil }
        let alert = NSAlert(); alert.messageText = "Choose annotation"
        let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 28))
        picker.addItems(withTitles: annotations.enumerated().map { "\($0.offset + 1): \($0.element.type ?? "Markup") \($0.element.contents ?? "")" })
        alert.accessoryView = picker
        alert.addButton(withTitle: "Choose"); alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return (page, annotations[picker.indexOfSelectedItem])
    }
    @objc func deleteAnnotation() {
        guard let (page, annotation) = chooseAnnotation() else { return }
        page.removeAnnotation(annotation)
        undoEdits.append { page.addAnnotation(annotation) }
        markEdited()
    }
    @objc func moveAnnotation() {
        guard let (page, annotation) = chooseAnnotation() else { return }
        let old = annotation.bounds
        guard let v = numbers("Move/resize annotation (PDF points)", labels: ["X", "Y", "Width", "Height"], defaults: [old.minX, old.minY, old.width, old.height].map(Double.init)) else { return }
        let rect = CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
        guard rect.width > 0, rect.height > 0, page.bounds(for: .cropBox).contains(rect) else { showError(PreviewError.invalidPage); return }
        annotation.bounds = rect
        undoEdits.append { annotation.bounds = old }
        markEdited()
    }
    @objc func rectangleMarkup() { addShape(.square) }
    @objc func ellipseMarkup() { addShape(.circle) }
    @objc func lineMarkup() { addShape(.line) }
    private func addShape(_ type: PDFAnnotationSubtype) {
        guard let model, model.canAnnotate, let page = pdfView.currentPage,
              let v = numbers("Markup bounds (PDF points)", labels: ["X", "Y", "Width", "Height"], defaults: [50, 50, 150, 80]) else { return }
        let rect = CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
        guard [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy({ $0.isFinite }),
              rect.width > 0, rect.height > 0, page.bounds(for: .cropBox).contains(rect) else { showError(PreviewError.invalidPage); return }
        let annotation = PDFAnnotation(bounds: rect, forType: type, withProperties: nil)
        annotation.color = .systemRed
        let border = PDFBorder(); border.lineWidth = 2; annotation.border = border
        if type == .line {
            annotation.startPoint = .zero
            annotation.endPoint = CGPoint(x: rect.width, y: rect.height)
            annotation.endLineStyle = .openArrow
        }
        page.addAnnotation(annotation)
        undoEdits.append { page.removeAnnotation(annotation) }
        markEdited()
    }
    @objc func exportProtected() {
        guard let model, model.canCopy, model.pdf.permissionsStatus == .owner else { return }
        let alert = NSAlert()
        alert.messageText = "Export password-protected copy"
        let password = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = password
        alert.addButton(withTitle: "Continue"); alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn, !password.stringValue.isEmpty else { return }
        let secret = password.stringValue
        password.stringValue = ""
        let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]; panel.nameFieldStringValue = "Protected copy.pdf"
        guard panel.runModal() == .OK, let url = panel.url,
              model.sourceURL?.resolvingSymlinksInPath().standardizedFileURL != url.resolvingSymlinksInPath().standardizedFileURL else { return }
        do {
            try model.validateDestination(url)
            guard let data = model.pdf.dataRepresentation(options: [PDFDocumentWriteOption.userPasswordOption: secret,
                PDFDocumentWriteOption.ownerPasswordOption: secret]) else { throw PreviewError.exportFailed }
            try data.write(to: url, options: .atomic)
        } catch { showError(error) }
    }
}
