import AppKit
import PDFKit
import PreviewCore

final class ViewerWindow: NSWindowController, NSWindowDelegate {
    let pdfView = PDFView()
    private let thumbnails = PDFThumbnailView()
    private let status = NSTextField(labelWithString: "Open a PDF or image to get started")
    private let search = NSSearchField()
    private let split = NSSplitView()
    var model: PreviewDocument?
    var raster: RasterImage?
    private var edited = false
    private var pageObserver: NSObjectProtocol?
    let undoEdits = EditHistory()
    var onClose: (() -> Void)?
    var ocrRunning = false
    var shareSession: ShareSession?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "Preview Rebuilt"
        window.minSize = NSSize(width: 700, height: 460)
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        buildUI()
        pageObserver = NotificationCenter.default.addObserver(forName: .PDFViewPageChanged,
                                                               object: pdfView, queue: .main) { [weak self] _ in
            self?.updateStatus()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { if let pageObserver { NotificationCenter.default.removeObserver(pageObserver) } }

    private func button(_ title: String, _ symbol: String, _ action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title)!,
                              target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.toolTip = title
        button.setAccessibilityLabel(title)
        return button
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        search.placeholderString = "Find in PDF"
        search.setAccessibilityLabel("Find in PDF")
        search.target = self
        search.action = #selector(findText)
        search.sendsSearchStringImmediately = false
        search.widthAnchor.constraint(equalToConstant: 190).isActive = true
        let controls: [NSView] = [
            button("Open…", "folder", #selector(openFile)),
            button("Toggle thumbnails", "sidebar.left", #selector(toggleSidebar)),
            button("Previous page", "chevron.up", #selector(previousPage)),
            button("Next page", "chevron.down", #selector(nextPage)),
            button("Zoom out", "minus.magnifyingglass", #selector(zoomOut)),
            button("Zoom in", "plus.magnifyingglass", #selector(zoomIn)),
            button("Fit page", "arrow.up.left.and.arrow.down.right", #selector(fitPage)),
            button("Rotate clockwise", "rotate.right", #selector(rotatePage)),
            button("Highlight selected text", "highlighter", #selector(highlightText)),
            button("Add text note", "text.bubble", #selector(addNote)),
            button("Undo edit", "arrow.uturn.backward", #selector(undoEdit)),
            button("Export PDF copy…", "square.and.arrow.up", #selector(exportCopy)), search
        ]
        let toolbar = NSStackView(views: controls)
        let toolbarScroll = NSScrollView()
        toolbarScroll.hasHorizontalScroller = true
        toolbarScroll.autohidesScrollers = true
        toolbarScroll.drawsBackground = false
        toolbarScroll.documentView = toolbar
        toolbarScroll.heightAnchor.constraint(equalToConstant: 60).isActive = true
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.widthAnchor.constraint(greaterThanOrEqualToConstant: 850).isActive = true
        toolbar.spacing = 6
        toolbar.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        toolbar.orientation = .horizontal
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .underPageBackgroundColor
        thumbnails.pdfView = pdfView
        thumbnails.thumbnailSize = NSSize(width: 110, height: 145)
        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(thumbnails)
        split.addArrangedSubview(pdfView)
        thumbnails.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        status.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 11)
        let footer = NSStackView(views: [status])
        footer.edgeInsets = NSEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        let stack = NSStackView(views: [toolbarScroll, split, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            toolbarScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            split.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        split.setPosition(160, ofDividerAt: 0)
    }

    private func canDiscard() -> Bool {
        guard edited else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard unsaved edits?"
        alert.informativeText = "Edits are only in memory. Export a PDF copy before closing to keep them. Your original file is unchanged."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { canDiscard() }
    func prepareToQuit() -> Bool { canDiscard() }
    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func load(_ url: URL) {
        guard canDiscard() else { return }
        do {
            guard let document = try openDocumentWithPassword(url) else { return }
            let loadedRaster = document.isImage ? try RasterImage(url: url) : nil
            model = document
            raster = loadedRaster
            if let loadedRaster, let page = PDFPage(image: NSImage(cgImage: loadedRaster.image, size: .zero)) {
                document.pdf.removePage(at: 0)
                document.pdf.insert(page, at: 0)
            }
            pdfView.document = document.pdf
            pdfView.autoScales = true
            window?.title = url.lastPathComponent + " — Preview Rebuilt"
            window?.representedURL = url
            edited = false
            undoEdits.removeAll()
            window?.isDocumentEdited = false
            search.stringValue = ""
            updateStatus()
        } catch { showError(error) }
    }

    func showError(_ error: Error) { NSAlert(error: error).runModal() }
    func markEdited() {
        edited = undoEdits.isDirty
        window?.isDocumentEdited = edited
        pdfView.needsDisplay = true
        updateStatus()
    }
    private func updateStatus() {
        guard let model else { return }
        let index = pdfView.currentPage.map { model.pdf.index(for: $0) + 1 } ?? 1
        status.stringValue = "Page \(index) of \(model.pdf.pageCount) · \(model.isImage ? "Image" : "PDF")\(edited ? " · Unsaved edits" : "") · Original unchanged"
    }
    @objc func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .image]
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }
    @objc func toggleSidebar() { thumbnails.isHidden.toggle() }
    @objc func previousPage() { pdfView.goToPreviousPage(nil) }
    @objc func nextPage() { pdfView.goToNextPage(nil) }
    @objc func zoomIn() { pdfView.autoScales = false; pdfView.zoomIn(nil) }
    @objc func zoomOut() { pdfView.autoScales = false; pdfView.zoomOut(nil) }
    @objc func fitPage() { pdfView.autoScales = true }
    @objc func rotatePage() {
        guard let model, let page = pdfView.currentPage else { return }
        let old = page.rotation
        do { try model.rotate(page) } catch { showError(error); return }
        undoEdits.append { page.rotation = old }
        pdfView.layoutDocumentView()
        markEdited()
    }
    @objc func highlightText() {
        guard let model, let selection = pdfView.currentSelection else { NSSound.beep(); return }
        let annotations: [(PDFPage, PDFAnnotation)]
        do { annotations = try model.highlight(selection) } catch { showError(error); return }
        guard !annotations.isEmpty else { return }
        undoEdits.append { annotations.forEach { $0.0.removeAnnotation($0.1) } }
        markEdited()
    }
    @objc func addNote() {
        guard let model, let page = pdfView.currentPage else { return }
        let alert = NSAlert()
        alert.messageText = "Add text note"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "Note text"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return }
        let annotation: PDFAnnotation
        do { annotation = try model.addNote(to: page, text: field.stringValue) } catch { showError(error); return }
        undoEdits.append { page.removeAnnotation(annotation) }
        markEdited()
    }
    @objc func undoEdit() {
        guard let undo = undoEdits.popLast() else { return }
        undo()
        pdfView.layoutDocumentView()
        markEdited()
    }
    @objc func findText() {
        guard let model else { return }
        guard !search.stringValue.isEmpty else {
            pdfView.highlightedSelections = nil
            updateStatus()
            return
        }
        let matches = model.pdf.findString(search.stringValue, withOptions: .caseInsensitive)
        pdfView.highlightedSelections = matches
        if let first = matches.first { pdfView.setCurrentSelection(first, animate: true); pdfView.go(to: first) }
        status.stringValue = "\(matches.count) matches · \(search.stringValue)"
    }
    @objc func exportCopy() {
        guard let model else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = (model.sourceURL?.deletingPathExtension().lastPathComponent ?? "Document") + " copy.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let source = model.sourceURL,
           url.resolvingSymlinksInPath().standardizedFileURL == source.resolvingSymlinksInPath().standardizedFileURL {
            let alert = NSAlert()
            alert.messageText = "Choose a different destination"
            alert.informativeText = "Export saves a copy; the original file is never overwritten."
            alert.runModal()
            return
        }
        do {
            try model.exportPDF(to: url)
            undoEdits.markSaved()
            edited = false
            window?.isDocumentEdited = false
            updateStatus()
        } catch { showError(error) }
    }
}
