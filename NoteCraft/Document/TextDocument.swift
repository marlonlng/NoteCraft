import AppKit
import NoteCraftKit
import SwiftUI
import UniformTypeIdentifiers

final class TextDocument: NSDocument {
    static let selectionRestorationKey = "NoteCraftSelection"
    static let languageRestorationKey = "NoteCraftLanguage"

    let textStorage = NSTextStorage()
    let attributes: DocumentAttributes
    let settingsStore: SettingsStore
    weak var editor: DocumentEditor?
    var pendingSelection: NSRange?
    private var pendingSaveOptions: SaveOptions?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        attributes = DocumentAttributes(settings: settingsStore.settings)
        super.init()
    }

    override convenience init() {
        self.init(settingsStore: .shared)
    }

    override class var autosavesInPlace: Bool {
        true
    }

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        false
    }

    var settings: EditorSettings {
        settingsStore.settings
    }

    override func makeWindowControllers() {
        addWindowController(EditorWindowController(document: self))
    }

    // MARK: Reading and writing

    nonisolated override func read(from url: URL, ofType typeName: String) throws {
        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        try Self.onMainActor {
            try self.load(data: data, fileName: fileName)
        }
    }

    nonisolated override func read(from data: Data, ofType typeName: String) throws {
        try Self.onMainActor {
            try self.load(data: data, fileName: self.fileURL?.lastPathComponent)
        }
    }

    nonisolated override func data(ofType typeName: String) throws -> Data {
        try Self.onMainActor {
            try self.encodedContents()
        }
    }

    /// Decodes `data`, detects line endings, language and indentation, and replaces the text.
    func load(data: Data, fileName: String?) throws {
        let decoded = try EncodingDetector(fallbackEncoding: settings.fallbackEncoding).decode(data)
        apply(decoded, fileName: fileName)
    }

    /// Returns the bytes written to disk: the text with the document's line ending in the document's encoding.
    func encodedContents() throws -> Data {
        let text = LineEnding.normalize(textStorage.string, to: attributes.lineEnding)
        return try attributes.encoding.encode(text)
    }

    private func apply(_ decoded: DecodedText, fileName: String?) {
        let detection = LineEnding.detect(in: decoded.text)
        let normalized = LineEnding.normalize(decoded.text, to: .lf)
        attributes.encoding = decoded.encoding
        attributes.lineEnding = detection.dominant ?? settings.defaultLineEnding
        attributes.hasMixedLineEndings = detection.isMixed
        attributes.isLargeFile = (normalized as NSString).length > settings.largeFileThreshold
        if !attributes.isLanguageOverridden {
            attributes.language = Language.detect(fileName: fileName, content: normalized)
        }
        if settings.detectsIndentation, let detected = Indentation.detect(in: normalized) {
            attributes.indentation = detected
        } else {
            attributes.indentation = settings.indentation
        }
        editor?.documentWillReplaceContents()
        textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: normalized)
        editor?.documentDidReplaceContents()
    }

    nonisolated override var fileURL: URL? {
        didSet {
            guard oldValue != fileURL else { return }
            let reference = WeakReference(self)
            Self.performOnMainActor {
                reference.object?.fileURLDidChange()
            }
        }
    }

    private func fileURLDidChange() {
        if !attributes.isLanguageOverridden, let fileURL {
            attributes.language = Language.detect(fileName: fileURL.lastPathComponent, content: textStorage.string)
        }
        for case let controller as EditorWindowController in windowControllers {
            controller.updateSubtitle()
        }
    }

    // MARK: Saving

    override func save(
        to url: URL,
        ofType typeName: String,
        for saveOperation: NSDocument.SaveOperationType,
        completionHandler: @escaping (Error?) -> Void
    ) {
        if saveOperation == .saveOperation || saveOperation == .saveAsOperation {
            applyPendingSaveOptions()
            applySaveTransformations()
            attributes.hasMixedLineEndings = false
        }
        super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
    }

    /// Rewrites the text according to the save options of the settings before an explicit save.
    func applySaveTransformations() {
        let original = textStorage.string
        let prepared = settings.preparedForSaving(original)
        guard prepared != original else { return }
        if let editor {
            editor.replaceAllText(with: prepared, actionName: L10n.Menu.save)
        } else {
            textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: prepared)
        }
    }

    override var shouldRunSavePanelWithAccessoryView: Bool {
        false
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowedContentTypes = []
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        let options = SaveOptions(encoding: attributes.encoding, lineEnding: attributes.lineEnding)
        pendingSaveOptions = options
        let hostingView = NSHostingView(rootView: SavePanelAccessoryView(options: options))
        hostingView.frame.size = hostingView.fittingSize
        savePanel.accessoryView = hostingView
        return true
    }

    private func applyPendingSaveOptions() {
        guard let options = pendingSaveOptions else { return }
        pendingSaveOptions = nil
        attributes.encoding = options.encoding
        attributes.lineEnding = options.lineEnding
    }

    nonisolated override func fileNameExtension(forType typeName: String, saveOperation: NSDocument.SaveOperationType) -> String? {
        if let fileURL, !fileURL.pathExtension.isEmpty {
            return fileURL.pathExtension
        }
        guard Thread.isMainThread else { return "txt" }
        return MainActor.assumeIsolated {
            attributes.language.fileExtensions.first ?? "txt"
        }
    }

    // MARK: Encoding, line endings, language, indentation

    /// Uses `encoding` for the next save after checking that every character can be represented.
    ///
    /// - Throws: `TextEncodingError.unrepresentableCharacter` naming the first offending character.
    func convert(to encoding: TextEncoding) throws {
        guard encoding != attributes.encoding else { return }
        _ = try encoding.encode(textStorage.string)
        setEncoding(encoding)
    }

    private func setEncoding(_ encoding: TextEncoding) {
        let previous = attributes.encoding
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.setEncoding(previous)
            }
        }
        undoManager?.setActionName(L10n.Undo.encoding)
        attributes.encoding = encoding
    }

    /// Reads the file again and decodes it with `encoding`, discarding unsaved changes.
    ///
    /// - Throws: `TextEncodingError.undecodable` when the bytes are invalid in that encoding.
    func reopen(with encoding: TextEncoding) throws {
        guard let fileURL else { return }
        let data = try Data(contentsOf: fileURL)
        let decoded = try EncodingDetector().decode(data, as: encoding)
        apply(decoded, fileName: fileURL.lastPathComponent)
        undoManager?.removeAllActions()
        updateChangeCount(.changeCleared)
    }

    /// Uses `lineEnding` for every line when the document is saved next.
    func convert(to lineEnding: LineEnding) {
        guard lineEnding != attributes.lineEnding || attributes.hasMixedLineEndings else { return }
        setLineEnding(lineEnding, isMixed: false)
    }

    private func setLineEnding(_ lineEnding: LineEnding, isMixed: Bool) {
        let previous = attributes.lineEnding
        let wasMixed = attributes.hasMixedLineEndings
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.setLineEnding(previous, isMixed: wasMixed)
            }
        }
        undoManager?.setActionName(L10n.Undo.lineEnding)
        attributes.lineEnding = lineEnding
        attributes.hasMixedLineEndings = isMixed
    }

    /// Sets the syntax language; `nil` returns to automatic detection.
    func setLanguage(_ language: Language?) {
        if let language {
            attributes.language = language
            attributes.isLanguageOverridden = true
        } else {
            attributes.isLanguageOverridden = false
            attributes.language = Language.detect(fileName: fileURL?.lastPathComponent, content: textStorage.string)
        }
        invalidateRestorableState()
    }

    func setIndentation(_ indentation: Indentation) {
        attributes.indentation = indentation
    }

    /// Replaces the indentation with the one detected in the text, or the default from the settings.
    func detectIndentation() {
        attributes.indentation = Indentation.detect(in: textStorage.string) ?? settings.indentation
    }

    // MARK: External changes

    nonisolated override func presentedItemDidChange() {
        super.presentedItemDidChange()
        let reference = WeakReference(self)
        Self.performOnMainActor {
            reference.object?.handleExternalChange()
        }
    }

    /// Reloads an unmodified document silently or reports the change to the editor.
    func handleExternalChange() {
        guard let fileURL else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            attributes.externalChange = .deleted
            return
        }
        let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
        guard let diskDate = values?.contentModificationDate else { return }
        if let known = fileModificationDate, diskDate <= known {
            return
        }
        if !isDocumentEdited, settings.reloadsUnmodifiedDocuments {
            reloadFromDisk()
            attributes.externalChange = .reloaded
        } else {
            attributes.externalChange = .modified
        }
    }

    /// Replaces the text with the current file contents, discarding unsaved changes.
    func reloadFromDisk() {
        guard let fileURL, let fileType else { return }
        do {
            try revert(toContentsOf: fileURL, ofType: fileType)
            attributes.externalChange = nil
        } catch {
            presentError(error)
        }
    }

    /// Keeps the text in the editor and accepts the file on disk as the new baseline.
    func keepCurrentVersion() {
        if let fileURL, let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]) {
            fileModificationDate = values.contentModificationDate
        }
        attributes.externalChange = nil
    }

    // MARK: Restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        if let editor {
            coder.encode(NSStringFromRange(editor.selectedRange), forKey: Self.selectionRestorationKey)
        }
        if attributes.isLanguageOverridden {
            coder.encode(attributes.language.id, forKey: Self.languageRestorationKey)
        }
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let languageID = coder.decodeObject(of: NSString.self, forKey: Self.languageRestorationKey) as String?,
           let language = Language.language(withID: languageID) {
            setLanguage(language)
        }
        if let rangeString = coder.decodeObject(of: NSString.self, forKey: Self.selectionRestorationKey) as String? {
            let range = NSRangeFromString(rangeString)
            if let editor {
                editor.select(range)
            } else {
                pendingSelection = range
            }
        }
    }

    // MARK: Printing

    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        let info = printInfo.copy() as? NSPrintInfo ?? NSPrintInfo.shared
        info.dictionary().addEntries(from: printSettings)
        info.horizontalPagination = .fit
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] = true
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        textView.isRichText = false
        textView.font = settings.editorFont(scale: min(1, 10 / CGFloat(settings.fontSize)))
        textView.textColor = .black
        textView.backgroundColor = .white
        textView.string = textStorage.string
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.sizeToFit()
        let operation = NSPrintOperation(view: textView, printInfo: info)
        operation.jobTitle = displayName
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        return operation
    }

    // MARK: Helpers

    private nonisolated static func onMainActor<T: Sendable>(_ body: @MainActor () throws -> T) throws -> T {
        if Thread.isMainThread {
            return try MainActor.assumeIsolated(body)
        }
        return try DispatchQueue.main.sync {
            try MainActor.assumeIsolated(body)
        }
    }

    private nonisolated static func performOnMainActor(_ body: @escaping @MainActor @Sendable () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(body)
        } else {
            Task { @MainActor in body() }
        }
    }
}

@MainActor
@Observable
final class SaveOptions {
    var encoding: TextEncoding
    var lineEnding: LineEnding

    init(encoding: TextEncoding, lineEnding: LineEnding) {
        self.encoding = encoding
        self.lineEnding = lineEnding
    }
}

struct SavePanelAccessoryView: View {
    @Bindable var options: SaveOptions

    var body: some View {
        Form {
            Picker(L10n.Menu.encoding, selection: $options.encoding) {
                ForEach(Array(TextEncoding.menuGroups.enumerated()), id: \.offset) { index, group in
                    if index > 0 {
                        Divider()
                    }
                    ForEach(group, id: \.self) { encoding in
                        Text(encoding.displayName).tag(encoding)
                    }
                }
            }
            Picker(L10n.Menu.lineEnding, selection: $options.lineEnding) {
                ForEach(LineEnding.allCases, id: \.self) { lineEnding in
                    Text(lineEnding.displayName).tag(lineEnding)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(width: 380)
    }
}
