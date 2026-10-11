import AppKit
import PDFKit

public enum PreviewError: LocalizedError {
    case unreadable, locked, exportFailed, invalidPage, lastPage, permissionDenied, tooLarge

    public var errorDescription: String? {
        switch self {
        case .tooLarge: return "This file exceeds the supported limit (256 MB or 2,000 PDF pages)."
        case .unreadable: return "This file could not be opened as a PDF or image."
        case .locked: return "This PDF needs the correct password to open."
        case .exportFailed: return "The copy could not be saved. Check the destination and try again."
        case .invalidPage: return "Choose a valid page position."
        case .lastPage: return "The final page cannot be deleted."
        case .permissionDenied: return "This PDF does not permit this operation. Open it with the owner password to edit permissions."
        }
    }
}

/// Edits live in memory. Only explicit export writes a file.
public final class PreviewDocument {
    public let pdf: PDFDocument
    public let sourceURL: URL?
    public let isImage: Bool

    public init(url: URL, password: String? = nil) throws {
        guard url.isFileURL else { throw PreviewError.unreadable }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw PreviewError.unreadable }
        guard (values.fileSize ?? 0) <= 256 * 1024 * 1024 else { throw PreviewError.tooLarge }
        sourceURL = url
        if let document = PDFDocument(url: url) {
            if document.isLocked, let password { _ = document.unlock(withPassword: password) }
            guard !document.isLocked else { throw PreviewError.locked }
            guard document.pageCount > 0 else { throw PreviewError.unreadable }
            guard document.pageCount <= 2000 else { throw PreviewError.tooLarge }
            pdf = document
            isImage = false
        } else {
            let raster = try RasterImage(url: url)
            guard let page = PDFPage(image: NSImage(cgImage: raster.image, size: .zero)) else {
                throw PreviewError.unreadable
            }
            pdf = PDFDocument()
            pdf.insert(page, at: 0)
            isImage = true
        }
    }

    public init(pdf: PDFDocument) {
        self.pdf = pdf
        sourceURL = nil
        isImage = false
    }

    public var canAssemble: Bool { pdf.permissionsStatus == .owner || pdf.allowsDocumentAssembly }
    public var canAnnotate: Bool { pdf.permissionsStatus == .owner || pdf.allowsCommenting }
    public var canCopy: Bool { pdf.permissionsStatus == .owner || pdf.allowsCopying }

    public func rotate(_ page: PDFPage) throws {
        guard canAssemble else { throw PreviewError.permissionDenied }
        page.rotation = (page.rotation + 90) % 360
    }

    @discardableResult
    public func addNote(to page: PDFPage, text: String) throws -> PDFAnnotation {
        guard canAnnotate else { throw PreviewError.permissionDenied }
        let bounds = page.bounds(for: .cropBox)
        let annotation = PDFAnnotation(bounds: CGRect(x: bounds.midX - 90, y: bounds.midY - 24,
                                                      width: 180, height: 48),
                                       forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = .systemFont(ofSize: 16)
        annotation.fontColor = .labelColor
        annotation.color = .systemYellow.withAlphaComponent(0.4)
        page.addAnnotation(annotation)
        return annotation
    }

    @discardableResult
    public func highlight(_ selection: PDFSelection) throws -> [(PDFPage, PDFAnnotation)] {
        guard canAnnotate else { throw PreviewError.permissionDenied }
        var result: [(PDFPage, PDFAnnotation)] = []
        for line in selection.selectionsByLine() {
            for page in line.pages {
                let annotation = PDFAnnotation(bounds: line.bounds(for: page), forType: .highlight,
                                               withProperties: nil)
                annotation.color = .systemYellow.withAlphaComponent(0.5)
                page.addAnnotation(annotation)
                result.append((page, annotation))
            }
        }
        return result
    }

    @discardableResult
    public func insertBlank(at index: Int) throws -> PDFPage {
        guard canAssemble else { throw PreviewError.permissionDenied }
        guard (0...pdf.pageCount).contains(index) else { throw PreviewError.invalidPage }
        guard pdf.pageCount < 2000 else { throw PreviewError.tooLarge }
        let page = PDFPage()
        page.setBounds(CGRect(x: 0, y: 0, width: 612, height: 792), for: .mediaBox)
        pdf.insert(page, at: index)
        return page
    }

    /// Clone all incoming pages before mutating this document (including self-insertion).
    @discardableResult
    public func insertPages(from source: PreviewDocument, at index: Int) throws -> Int {
        guard canAssemble, source.canCopy else { throw PreviewError.permissionDenied }
        guard (0...pdf.pageCount).contains(index) else { throw PreviewError.invalidPage }
        guard pdf.pageCount + source.pdf.pageCount <= 2000 else { throw PreviewError.tooLarge }
        let copies = try (0..<source.pdf.pageCount).map { position -> PDFPage in
            guard let page = source.pdf.page(at: position)?.copy() as? PDFPage else {
                throw PreviewError.unreadable
            }
            return page
        }
        for (offset, page) in copies.enumerated() { pdf.insert(page, at: index + offset) }
        return copies.count
    }

    @discardableResult
    public func removePage(at index: Int) throws -> PDFPage {
        guard canAssemble else { throw PreviewError.permissionDenied }
        guard let page = pdf.page(at: index) else { throw PreviewError.invalidPage }
        guard pdf.pageCount > 1 else { throw PreviewError.lastPage }
        pdf.removePage(at: index)
        return page
    }

    public func movePage(from source: Int, to destination: Int) throws {
        guard canAssemble else { throw PreviewError.permissionDenied }
        guard let page = pdf.page(at: source), (0..<pdf.pageCount).contains(destination) else {
            throw PreviewError.invalidPage
        }
        guard source != destination else { return }
        pdf.removePage(at: source)
        pdf.insert(page, at: destination)
    }

    public func extractPage(at index: Int, to url: URL) throws {
        try validateDestination(url)
        guard canCopy else { throw PreviewError.permissionDenied }
        guard let page = pdf.page(at: index)?.copy() as? PDFPage else { throw PreviewError.invalidPage }
        let extracted = PDFDocument()
        extracted.insert(page, at: 0)
        try PreviewDocument(pdf: extracted).exportPDF(to: url)
    }

    public func validateDestination(_ url: URL) throws {
        guard let sourceURL else { return }
        let source = sourceURL.resolvingSymlinksInPath().standardizedFileURL
        let destination = url.resolvingSymlinksInPath().standardizedFileURL
        guard source != destination else { throw PreviewError.exportFailed }
        if let sourceID = try? source.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
           let destinationID = try? destination.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
           (sourceID as? NSObject)?.isEqual(destinationID) == true { throw PreviewError.exportFailed }
    }

    public func exportPDF(to url: URL) throws {
        try validateDestination(url)
        guard canCopy else { throw PreviewError.permissionDenied }
        guard let data = pdf.dataRepresentation() else { throw PreviewError.exportFailed }
        try data.write(to: url, options: .atomic)
    }
}
