import AppKit
import PDFKit
import PreviewCore

extension ViewerWindow {
    private var currentIndex: Int? {
        guard let model, let page = pdfView.currentPage else { return nil }
        return model.pdf.index(for: page)
    }

    func refreshPages(at index: Int) {
        guard let model else { return }
        pdfView.document = nil
        pdfView.document = model.pdf
        if let page = model.pdf.page(at: min(max(index, 0), model.pdf.pageCount - 1)) { pdfView.go(to: page) }
        pdfView.layoutDocumentView()
        markEdited()
    }

    @objc func insertBlankPage() {
        guard let model, let index = currentIndex else { return }
        do {
            let page = try model.insertBlank(at: index + 1)
            undoEdits.append { [weak self] in
                model.pdf.removePage(at: model.pdf.index(for: page))
                self?.refreshPages(at: index)
            }
            refreshPages(at: index + 1)
        } catch { showError(error) }
    }

    @objc func insertFilePages() {
        guard let model, let index = currentIndex else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard let source = try openDocumentWithPassword(url) else { return }
            let count = try model.insertPages(from: source, at: index + 1)
            undoEdits.append { [weak self] in
                for _ in 0..<count { model.pdf.removePage(at: index + 1) }
                self?.refreshPages(at: index)
            }
            refreshPages(at: index + 1)
        } catch { showError(error) }
    }

    @objc func deleteCurrentPage() {
        guard let model, let index = currentIndex else { return }
        let alert = NSAlert()
        alert.messageText = "Delete page \(index + 1)?"
        alert.informativeText = "This changes the in-memory copy only. Use Undo to restore the page."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete Page")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            let page = try model.removePage(at: index)
            undoEdits.append { [weak self] in
                model.pdf.insert(page, at: index)
                self?.refreshPages(at: index)
            }
            refreshPages(at: index)
        } catch { showError(error) }
    }

    @objc func movePageEarlier() { moveCurrentPage(by: -1) }
    @objc func movePageLater() { moveCurrentPage(by: 1) }
    private func moveCurrentPage(by offset: Int) {
        guard let model, let index = currentIndex else { return }
        let destination = index + offset
        guard (0..<model.pdf.pageCount).contains(destination) else { NSSound.beep(); return }
        do {
            try model.movePage(from: index, to: destination)
            undoEdits.append { [weak self] in
                try? model.movePage(from: destination, to: index)
                self?.refreshPages(at: index)
            }
            refreshPages(at: destination)
        } catch { showError(error) }
    }

    @objc func extractCurrentPage() {
        guard let model, let index = currentIndex else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Page \(index + 1).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard model.sourceURL?.resolvingSymlinksInPath().standardizedFileURL != url.resolvingSymlinksInPath().standardizedFileURL else {
            showError(PreviewError.exportFailed)
            return
        }
        do { try model.extractPage(at: index, to: url) } catch { showError(error) }
    }
}
