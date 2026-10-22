import AppKit
import NoteCraftKit
import SwiftUI
@testable import NoteCraft

@MainActor
enum TestSupport {
    /// A settings store backed by a fresh, empty defaults suite.
    static func makeSettingsStore(_ configure: (inout EditorSettings) -> Void = { _ in }) -> SettingsStore {
        let store = SettingsStore(defaults: makeDefaults())
        configure(&store.settings)
        return store
    }

    static func makeDefaults() -> UserDefaults {
        let name = "NoteCraftTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    static func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("NoteCraftTests-\(UUID().uuidString)"))
    }

    /// A document whose text was loaded as if read from a file named `fileName`.
    static func makeDocument(
        _ text: String = "",
        fileName: String? = "notes.txt",
        settingsStore: SettingsStore? = nil
    ) throws -> TextDocument {
        let document = TextDocument(settingsStore: settingsStore ?? makeSettingsStore())
        try document.load(data: Data(text.utf8), fileName: fileName)
        return document
    }

    /// A complete editor window for `text` with isolated settings, workspace and find pasteboard.
    static func makeEditor(
        _ text: String = "",
        fileName: String? = "notes.txt",
        settingsStore: SettingsStore? = nil
    ) throws -> EditorFixture {
        let document = try makeDocument(text, fileName: fileName, settingsStore: settingsStore)
        let workspace = WorkspaceModel(defaults: makeDefaults())
        let controller = EditorWindowController(
            document: document,
            workspace: workspace,
            findPasteboard: FindPasteboard(pasteboard: makePasteboard())
        )
        document.addWindowController(controller)
        controller.window?.setFrame(NSRect(x: 0, y: 0, width: 900, height: 600), display: false)
        controller.window?.layoutIfNeeded()
        return EditorFixture(document: document, windowController: controller, workspace: workspace)
    }

    /// A new, empty folder inside the sandbox container.
    static func makeTemporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NoteCraftTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Lays out and draws `view` offscreen so that its body and drawing code run.
    @discardableResult
    static func render<Content: View>(_ view: Content, size: NSSize = NSSize(width: 600, height: 400)) -> NSBitmapImageRep? {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        return draw(hostingView)
    }

    /// Draws `view` into a bitmap.
    @discardableResult
    static func draw(_ view: NSView) -> NSBitmapImageRep? {
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    /// Runs the main run loop briefly so that scheduled main-actor work can execute.
    static func spinRunLoop(_ seconds: TimeInterval = 0.05) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
}

@MainActor
struct EditorFixture {
    let document: TextDocument
    let windowController: EditorWindowController
    let workspace: WorkspaceModel

    var editor: EditorViewController {
        windowController.editorViewController
    }

    var textView: EditorTextView {
        editor.textView
    }

    var text: String {
        document.textStorage.string
    }

    func close() {
        windowController.window?.orderOut(nil)
        document.removeWindowController(windowController)
        windowController.close()
    }
}

@MainActor
final class FakeSearchTarget: SearchTarget {
    var text: NSMutableString
    var selection = NSRange(location: 0, length: 0)
    var highlighted: [NSRange] = []
    var focused = false
    var lastActionName: String?

    init(_ text: String) {
        self.text = NSMutableString(string: text)
    }

    var searchableText: NSString { text }
    var searchSelection: NSRange { selection }

    func showMatch(_ range: NSRange) {
        selection = range
    }

    func replaceMatch(_ range: NSRange, with replacement: String) -> Bool {
        text.replaceCharacters(in: range, with: replacement)
        selection = NSRange(location: range.location + (replacement as NSString).length, length: 0)
        return true
    }

    func replaceText(in range: NSRange, with replacement: String, actionName: String) {
        text.replaceCharacters(in: range, with: replacement)
        lastActionName = actionName
    }

    func highlightMatches(_ ranges: [NSRange]) {
        highlighted = ranges
    }

    func focusEditor() {
        focused = true
    }
}
