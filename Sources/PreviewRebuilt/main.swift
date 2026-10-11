import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewers: [ViewerWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        if viewers.isEmpty { newViewer() }
        NSApp.activate(ignoringOtherApps: true)
        for path in CommandLine.arguments.dropFirst() where !path.hasPrefix("-") {
            open(URL(fileURLWithPath: path))
        }
        if CommandLine.arguments.contains("--ui-smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                guard let viewer = viewers.last, viewer.pdfView.document?.pageCount == 1,
                      viewer.pdfView.frame.width > 300, viewer.pdfView.frame.height > 200 else {
                    fputs("FAIL: document or viewer layout\n", stderr)
                    exit(1)
                }
                viewer.zoomIn()
                viewer.zoomOut()
                viewer.fitPage()
                viewer.rotatePage()
                viewer.undoEdit()
                viewer.toggleSidebar()
                viewer.toggleSidebar()
                guard viewer.pdfView.currentPage?.rotation == 0 else { exit(1) }
                viewer.insertBlankPage()
                guard viewer.pdfView.document?.pageCount == 2 else { exit(1) }
                viewer.movePageEarlier()
                viewer.undoEdit()
                viewer.undoEdit()
                guard viewer.pdfView.document?.pageCount == 1, !viewer.undoEdits.isDirty else { exit(1) }
                print("PASS: native window, PDF layout, zoom, rotation/undo, sidebar, blank insertion, page move/undo")
                exit(0)
            }
        }
    }

    @discardableResult
    private func newViewer() -> ViewerWindow {
        let viewer = ViewerWindow()
        viewers.append(viewer)
        viewer.onClose = { [weak self, weak viewer] in
            self?.viewers.removeAll { $0 === viewer }
        }
        viewer.showWindow(nil)
        return viewer
    }

    private var activeViewer: ViewerWindow? {
        viewers.first { $0.window === NSApp.keyWindow }
    }

    private func open(_ url: URL) {
        let viewer = newViewer()
        viewer.load(url)
    }

    func application(_ sender: NSApplication, open urls: [URL]) { urls.forEach(open) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        viewers.filter { $0.window?.isVisible == true }.allSatisfy { $0.prepareToQuit() } ? .terminateNow : .terminateCancel
    }

    @objc private func openDocument() { (activeViewer ?? newViewer()).openFile() }
    @objc private func exportDocument() { activeViewer?.exportCopy() }
    @objc private func undoEdit() { activeViewer?.undoEdit() }
    @objc private func newWindow() { newViewer() }

    private func item(_ title: String, _ action: Selector, _ key: String, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }

    private func buildMenu() {
        let menu = NSMenu()
        let app = NSMenu()
        app.addItem(item("About Preview Rebuilt", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), ""))
        app.addItem(.separator())
        app.addItem(item("Quit Preview Rebuilt", #selector(NSApplication.terminate(_:)), "q"))
        let file = NSMenu(title: "File")
        file.addItem(item("New Window", #selector(newWindow), "n", target: self))
        file.addItem(item("Open…", #selector(openDocument), "o", target: self))
        file.addItem(item("Export PDF Copy…", #selector(exportDocument), "s", target: self))
        file.addItem(item("Close", #selector(NSWindow.performClose(_:)), "w"))
        let edit = NSMenu(title: "Edit")
        edit.addItem(item("Undo Document Edit", #selector(undoEdit), "z", target: self))
        edit.addItem(.separator())
        edit.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        edit.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        edit.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        edit.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        let pages = NSMenu(title: "Pages")
        for (title, action) in [
            ("Insert Blank Page", #selector(ViewerWindow.insertBlankPage)),
            ("Insert Pages from File…", #selector(ViewerWindow.insertFilePages)),
            ("Move Page Earlier", #selector(ViewerWindow.movePageEarlier)),
            ("Move Page Later", #selector(ViewerWindow.movePageLater)),
            ("Delete Current Page…", #selector(ViewerWindow.deleteCurrentPage)),
            ("Extract Current Page…", #selector(ViewerWindow.extractCurrentPage))
        ] {
            pages.addItem(item(title, action, ""))
        }
        let tools = NSMenu(title: "Tools")
        for (title, action) in [
            ("Crop Image…", #selector(ViewerWindow.cropImage)),
            ("Resize Image…", #selector(ViewerWindow.resizeImage)),
            ("Flip Horizontal", #selector(ViewerWindow.flipHorizontal)),
            ("Flip Vertical", #selector(ViewerWindow.flipVertical)),
            ("Adjust Colors…", #selector(ViewerWindow.adjustColors)),
            ("Export Image…", #selector(ViewerWindow.exportImage)),
            ("Underline Selection", #selector(ViewerWindow.underlineText)),
            ("Strike Through Selection", #selector(ViewerWindow.strikeText)),
            ("Move/Resize Annotation…", #selector(ViewerWindow.moveAnnotation)),
            ("Delete Annotation…", #selector(ViewerWindow.deleteAnnotation)),
            ("Rectangle…", #selector(ViewerWindow.rectangleMarkup)),
            ("Ellipse…", #selector(ViewerWindow.ellipseMarkup)),
            ("Arrow…", #selector(ViewerWindow.lineMarkup)),
            ("Recognize Page Text…", #selector(ViewerWindow.recognizeText)),
            ("Document Information…", #selector(ViewerWindow.inspectDocument)),
            ("Go to Page…", #selector(ViewerWindow.goToPage)),
            ("Single Page", #selector(ViewerWindow.singlePage)),
            ("Continuous Pages", #selector(ViewerWindow.continuousPages)),
            ("Two Pages", #selector(ViewerWindow.twoPages)),
            ("Full Screen", #selector(ViewerWindow.fullScreen)),
            ("Export Protected PDF…", #selector(ViewerWindow.exportProtected)),
            ("Print…", #selector(ViewerWindow.printDocument)),
            ("Share PDF Copy…", #selector(ViewerWindow.shareDocument))
        ] { tools.addItem(item(title, action, "")) }
        let window = NSMenu(title: "Window")
        window.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"))
        window.addItem(item("Zoom", #selector(NSWindow.performZoom(_:)), ""))
        for (title, submenu) in [("Preview Rebuilt", app), ("File", file), ("Edit", edit), ("Pages", pages), ("Tools", tools), ("Window", window)] {
            let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            entry.submenu = submenu
            menu.addItem(entry)
        }
        NSApp.mainMenu = menu
        NSApp.windowsMenu = window
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
