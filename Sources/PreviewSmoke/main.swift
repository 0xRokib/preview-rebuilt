import AppKit
import PDFKit
import PreviewCore
import UniformTypeIdentifiers
import ImageIO
import Vision

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw NSError(domain: "PreviewSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

let history = EditHistory()
var value = 0
history.append { value = 0 }; value = 1
try require(history.isDirty, "History failed to mark edit dirty")
history.markSaved()
try require(!history.isDirty, "Saved history still dirty")
history.popLast()?()
try require(history.isDirty && value == 0, "Undo after save must be dirty")
history.append { value = 0 }; value = 2
try require(history.isDirty, "Same-depth branch falsely marked saved")
history.removeAll()
history.append { value = 0 }; history.popLast()?()
try require(!history.isDirty, "Undo to initial state still dirty")
print("PASS: edit history clean/dirty, saved-state undo, branch identity, reset")
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PreviewSmoke-" + UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let image = NSImage(size: NSSize(width: 400, height: 500))
image.lockFocus()
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 400, height: 500).fill()
("Preview smoke fixture" as NSString).draw(at: NSPoint(x: 40, y: 250), withAttributes: [.font: NSFont.systemFont(ofSize: 20)])
image.unlockFocus()
let pdf = PDFDocument()
pdf.insert(PDFPage(image: image)!, at: 0)
let source = directory.appendingPathComponent("source.pdf")
try PreviewDocument(pdf: pdf).exportPDF(to: source)
let original = try Data(contentsOf: source)
let loaded = try PreviewDocument(url: source)
var overwriteDenied = false
do { try loaded.exportPDF(to: source) } catch PreviewError.exportFailed { overwriteDenied = true }
try require(overwriteDenied, "Core allowed source overwrite")
let alias = directory.appendingPathComponent("alias.pdf")
try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: source)
var aliasDenied = false
do { try loaded.exportPDF(to: alias) } catch PreviewError.exportFailed { aliasDenied = true }
try require(aliasDenied, "Core allowed symlink source overwrite")
let page = loaded.pdf.page(at: 0)!
for _ in 0..<4 { try loaded.rotate(page) }
try require(page.rotation == 0, "Rotation did not wrap")
try loaded.addNote(to: page, text: "Persistent note")
let copy = directory.appendingPathComponent("copy.pdf")
try loaded.exportPDF(to: copy)
let unchanged = try Data(contentsOf: source)
try require(unchanged == original, "Original file changed")
let exported = try PreviewDocument(url: copy)
try require(exported.pdf.page(at: 0)!.annotations.contains { $0.contents == "Persistent note" }, "Note did not survive export")
let tiff = directory.appendingPathComponent("image.tiff")
try image.tiffRepresentation!.write(to: tiff)
let imageDocument = try PreviewDocument(url: tiff)
try require(imageDocument.isImage && imageDocument.pdf.pageCount == 1, "Image import failed")
let raster = try RasterImage(url: tiff)
let resized = try raster.resize(width: 120, height: 90)
try require(resized.image.width == 120 && resized.image.height == 90, "Resize dimensions wrong")
let cropped = try raster.crop(CGRect(x: 10, y: 20, width: 80, height: 70))
try require(cropped.image.width == 80 && cropped.image.height == 70, "Crop dimensions wrong")
let flipped = try cropped.flip(horizontal: true).flip(horizontal: true)
try require(flipped.image.width == 80 && flipped.image.height == 70, "Flip changed dimensions")
_ = try raster.adjust(exposure: 0.5, contrast: 1.2, saturation: 0.8)
for type in [UTType.png, .jpeg, .tiff, .heic] {
    let destination = directory.appendingPathComponent("raster." + type.preferredFilenameExtension!)
    try resized.export(to: destination, type: type)
    let decoded = try RasterImage(url: destination)
    try require(decoded.image.width == 120 && decoded.image.height == 90, "Raster export dimensions lost")
    let source = CGImageSourceCreateWithURL(destination as CFURL, nil)!
    try require(CGImageSourceGetType(source) as String? == type.identifier, "Raster export type wrong")
}
var badSize = false
do { _ = try raster.resize(width: 0, height: 10) } catch { badSize = true }
try require(badSize, "Invalid image size allowed")
let rasterOriginal = try Data(contentsOf: tiff)
try require(rasterOriginal == image.tiffRepresentation!, "Raster source changed")
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage: raster.image).perform([request])
let recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
try require(recognized.localizedCaseInsensitiveContains("Preview"), "OCR fixture text not recognized")
print("PASS: raster crop/resize/flip/color adjustment, PNG/JPEG/TIFF/HEIC export/reload, size guard, source preservation, Vision OCR fixture")
let oversized = directory.appendingPathComponent("oversized.pdf")
FileManager.default.createFile(atPath: oversized.path, contents: nil)
let handle = try FileHandle(forWritingTo: oversized)
try handle.truncate(atOffset: 256 * 1024 * 1024 + 1)
try handle.close()
var oversizedDenied = false
do { _ = try PreviewDocument(url: oversized) } catch PreviewError.tooLarge { oversizedDenied = true }
try require(oversizedDenied, "Oversized document accepted")
var directoryDenied = false
do { _ = try PreviewDocument(url: directory) } catch { directoryDenied = true }
try require(directoryDenied, "Directory accepted as document")
let hardlink = directory.appendingPathComponent("hardlink.pdf")
try FileManager.default.linkItem(at: source, to: hardlink)
var hardlinkDenied = false
do { try loaded.exportPDF(to: hardlink) } catch PreviewError.exportFailed { hardlinkDenied = true }
try require(hardlinkDenied, "Hardlink overwrite accepted")
print("PASS: file size/type limits, source symlink/hardlink export denial")
let invalid = directory.appendingPathComponent("invalid.txt")
try Data("invalid document".utf8).write(to: invalid)
var rejected = false
do { _ = try PreviewDocument(url: invalid) } catch { rejected = true }
try require(rejected, "Invalid file was accepted")
let managed = try PreviewDocument(url: source)
let first = managed.pdf.page(at: 0)!
let blank = try managed.insertBlank(at: 1)
try require(managed.pdf.pageCount == 2, "Blank insertion failed")
try managed.movePage(from: 1, to: 0)
try require(managed.pdf.page(at: 0) === blank && managed.pdf.page(at: 1) === first, "Move order wrong")
try managed.movePage(from: 0, to: 1)
let removed = try managed.removePage(at: 1)
try require(removed === blank && managed.pdf.pageCount == 1, "Delete identity wrong")
var finalRejected = false
do { _ = try managed.removePage(at: 0) } catch PreviewError.lastPage { finalRejected = true }
try require(finalRejected, "Final page deletion allowed")
let inserted = try managed.insertPages(from: loaded, at: 1)
try require(inserted == 1 && loaded.pdf.pageCount == 1, "Merge mutated source")
try require(managed.pdf.page(at: 1) !== loaded.pdf.page(at: 0), "Merge did not clone page")
let extractedURL = directory.appendingPathComponent("extracted.pdf")
try managed.extractPage(at: 1, to: extractedURL)
let extractedDocument = try PreviewDocument(url: extractedURL)
try require(extractedDocument.pdf.pageCount == 1, "Extraction page count wrong")
try require(extractedDocument.pdf.page(at: 0)!.annotations.contains { $0.contents == "Persistent note" }, "Extract lost note")
var invalidIndexRejected = false
do { try managed.movePage(from: 0, to: 9) } catch PreviewError.invalidPage { invalidIndexRejected = true }
try require(invalidIndexRejected && managed.pdf.pageCount == 2, "Invalid move changed document")
print("PASS: blank insertion, page move/reverse, deletion/final-page guard, merge cloning, extraction persistence, invalid index")
let encryptedURL = directory.appendingPathComponent("encrypted.pdf")
let encrypted = pdf.dataRepresentation(options: [PDFDocumentWriteOption.userPasswordOption: "fixture-user", PDFDocumentWriteOption.ownerPasswordOption: "fixture-owner"] )!
try encrypted.write(to: encryptedURL)
for password in [nil, "wrong"] as [String?] {
    var locked = false
    do { _ = try PreviewDocument(url: encryptedURL, password: password) } catch PreviewError.locked { locked = true }
    try require(locked, "Locked PDF accepted missing/wrong password")
}
let unlocked = try PreviewDocument(url: encryptedURL, password: "fixture-owner")
try require(unlocked.pdf.pageCount == 1 && !unlocked.pdf.isLocked && unlocked.canAssemble, "Password unlock failed")
let restrictedURL = directory.appendingPathComponent("restricted.pdf")
let restrictedData = pdf.dataRepresentation(options: [
    PDFDocumentWriteOption.userPasswordOption: "fixture-reader",
    PDFDocumentWriteOption.ownerPasswordOption: "fixture-admin",
    PDFDocumentWriteOption.accessPermissionsOption: NSNumber(value: 0)
])!
try restrictedData.write(to: restrictedURL)
let restricted = try PreviewDocument(url: restrictedURL, password: "fixture-reader")
try require(!restricted.canAssemble && !restricted.canAnnotate && !restricted.canCopy, "Reader permissions bypassed")
var forbidden = 0
for operation in [
    { _ = try restricted.insertBlank(at: 1) },
    { try restricted.rotate(restricted.pdf.page(at: 0)!) },
    { _ = try restricted.addNote(to: restricted.pdf.page(at: 0)!, text: "blocked") },
    { try restricted.exportPDF(to: directory.appendingPathComponent("forbidden.pdf")) }
] {
    do { try operation() } catch PreviewError.permissionDenied { forbidden += 1 }
}
try require(forbidden == 4 && restricted.pdf.pageCount == 1, "Forbidden mutation/export allowed")
print("PASS: encrypted PDF missing/wrong password rejection, owner unlock, restricted-reader mutation/export guards")
if let destination = ProcessInfo.processInfo.environment["PREVIEW_FIXTURE_DIR"] {
    let url = URL(fileURLWithPath: destination, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    try PreviewDocument(pdf: pdf).exportPDF(to: url.appendingPathComponent("sample.pdf"))
    try image.tiffRepresentation!.write(to: url.appendingPathComponent("sample.tiff"))
}
print("PASS: rotation, PDF load/export, note persistence, original preservation, image import, invalid-file rejection")
