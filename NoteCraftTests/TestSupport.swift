import AppKit
import NoteCraftKit
import SwiftUI
import WebKit
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
            findPasteboard: FindPasteboard(pasteboard: makePasteboard()),
            defaults: makeDefaults()
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

    /// Suspends until `condition` holds or `timeout` passes, letting the main queue run; returns whether it holds.
    @discardableResult
    static func wait(timeout: TimeInterval = 10, until condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return true
    }

    /// Evaluates `script` in `webView` and returns its result.
    static func evaluate(_ script: String, in webView: WKWebView) async -> Any? {
        let box = ResultBox()
        webView.evaluateJavaScript(script) { value, _ in
            let result = value
            MainActor.assumeIsolated {
                box.value = result
                box.isDone = true
            }
        }
        await wait { box.isDone }
        return box.value
    }

    /// The PNG data of a small opaque image.
    static func makePNG(width: Int = 2, height: Int = 2) -> Data {
        let image = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )
        return image?.representation(using: .png, properties: [:]) ?? Data()
    }
}

@MainActor
final class ResultBox {
    var value: Any?
    var isDone = false
}

@MainActor
final class RecordingWorkspace: NSWorkspace {
    var opened: [URL] = []

    override func open(_ url: URL) -> Bool {
        opened.append(url)
        return true
    }
}

@MainActor
final class RecordingPreviewDelegate: MarkdownPreviewDelegate {
    var scrolledLines: [Double] = []
    var requestedLines: [Int] = []
    var toggledLines: [Int] = []
    var links: [String] = []
    var externalContentRequests = 0
    var folderRequests: [URL] = []

    func preview(_ preview: MarkdownPreviewController, didScrollToLine line: Double) {
        scrolledLines.append(line)
    }

    func preview(_ preview: MarkdownPreviewController, didRequestLine line: Int) {
        requestedLines.append(line)
    }

    func preview(_ preview: MarkdownPreviewController, didToggleTaskAtLine line: Int) {
        toggledLines.append(line)
    }

    func preview(_ preview: MarkdownPreviewController, didActivateLink address: String) {
        links.append(address)
    }

    func previewDidRequestExternalContent(_ preview: MarkdownPreviewController) {
        externalContentRequests += 1
    }

    func preview(_ preview: MarkdownPreviewController, didRequestAccessTo folderURL: URL) {
        folderRequests.append(folderURL)
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
