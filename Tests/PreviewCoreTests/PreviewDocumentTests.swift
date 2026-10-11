import XCTest
import AppKit
import PDFKit
@testable import PreviewCore

final class PreviewDocumentTests: XCTestCase {
    private func document() -> PreviewDocument {
        let image = NSImage(size: NSSize(width: 400, height: 500))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 400, height: 500).fill()
        image.unlockFocus()
        let pdf = PDFDocument()
        pdf.insert(PDFPage(image: image)!, at: 0)
        return PreviewDocument(pdf: pdf)
    }

    func testRotationWraps() throws {
        let model = document()
        let page = model.pdf.page(at: 0)!
        for _ in 0..<4 { try model.rotate(page) }
        XCTAssertEqual(page.rotation, 0)
    }

    func testNoteSurvivesExportWithoutChangingOriginal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.pdf")
        let copy = directory.appendingPathComponent("copy.pdf")
        try document().exportPDF(to: source)
        let original = try Data(contentsOf: source)
        let loaded = try PreviewDocument(url: source)
        let page = loaded.pdf.page(at: 0)!
        try loaded.addNote(to: page, text: "Review this page")
        try loaded.exportPDF(to: copy)
        XCTAssertEqual(try Data(contentsOf: source), original)
        let reloaded = try PreviewDocument(url: copy)
        XCTAssertTrue(reloaded.pdf.page(at: 0)!.annotations.contains { $0.contents == "Review this page" })
    }

    func testInvalidFileIsRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a document".utf8).write(to: url)
        XCTAssertThrowsError(try PreviewDocument(url: url))
    }

    func testImageLoadsAsSinglePage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
        defer { try? FileManager.default.removeItem(at: url) }
        let image = document().pdf.page(at: 0)!.thumbnail(of: NSSize(width: 100, height: 100), for: .mediaBox)
        try image.tiffRepresentation!.write(to: url)
        let loaded = try PreviewDocument(url: url)
        XCTAssertTrue(loaded.isImage)
        XCTAssertEqual(loaded.pdf.pageCount, 1)
    }
}
