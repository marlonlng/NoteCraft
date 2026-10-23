import AppKit
import NoteCraftKit
import SwiftUI

final class EditorContainerView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

final class EditorViewController: NSViewController {
    static let statusBarVisibilityKey = "ShowsStatusBar"
    static let zoomSteps: [CGFloat] = [0.5, 0.67, 0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    let document: TextDocument
    let settingsStore: SettingsStore
    let findBarModel: FindBarModel
    let statusBarModel = StatusBarModel()
    private(set) var textView: EditorTextView!
    private(set) var scrollView: NSScrollView!
    private(set) var contentSplitView: NSSplitView!
    var previewController: MarkdownPreviewController?
    var externalContentStore = ExternalContentStore.shared
    var folderAccessStore = FolderAccessStore.shared
    var hasDecidedPreviewVisibility = false
    var previewUpdateTask: Task<Void, Never>?
    var ignoresEditorScrollUntil = Date.distantPast
    var ignoresPreviewScrollUntil = Date.distantPast
    var onDocumentAttributesChange: (() -> Void)?
    private(set) var rulerView: LineNumberRulerView!
    private(set) var highlightController: SyntaxHighlightController!
    private(set) var lineIndex = LineIndex(text: "")
    private(set) var zoomScale: CGFloat = 1
    private(set) var theme: Theme = .paper
    private var statusBarHost: NSView!
    private(set) var findBarHost: NSView!
    private var findRefreshTask: Task<Void, Never>?
    private var storedSelectionBeforeReload: NSRange?
    private var observers: [NSObjectProtocol] = []

    var showsStatusBar: Bool {
        get { UserDefaults.standard.object(forKey: Self.statusBarVisibilityKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.statusBarVisibilityKey)
            statusBarHost?.isHidden = !newValue
        }
    }

    init(document: TextDocument, settingsStore: SettingsStore = .shared, findPasteboard: FindPasteboard = FindPasteboard()) {
        self.document = document
        self.settingsStore = settingsStore
        findBarModel = FindBarModel(findPasteboard: findPasteboard)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var settings: EditorSettings {
        settingsStore.settings
    }

    override func loadView() {
        let container = EditorContainerView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.onAppearanceChange = { [weak self] in
            self?.applyAppearance()
        }
        view = container

        let editor = EditorTextView.makeScrollableEditor(textStorage: document.textStorage)
        textView = editor.textView
        scrollView = editor.scrollView
        textView.delegate = self
        textView.onCancel = { [weak self] in
            guard let self, self.findBarModel.isVisible else { return false }
            self.findBarModel.hide()
            return true
        }
        textView.onOpenFiles = { urls in
            for url in urls {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
            }
        }

        rulerView = LineNumberRulerView(textView: textView, scrollView: scrollView)
        rulerView.onSelectLine = { [weak self] line in
            self?.selectLine(line)
        }
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true

        guard let layoutManager = textView.layoutManager else { return }
        highlightController = SyntaxHighlightController(textStorage: document.textStorage, layoutManager: layoutManager)

        let bannerHost = NSHostingView(rootView: BannerContainer(attributes: document.attributes, controller: self))
        let findBarHost = NSHostingView(rootView: FindBarContainer(model: findBarModel))
        let statusHost = NSHostingView(rootView: StatusBarContainer(
            model: statusBarModel,
            attributes: document.attributes,
            document: document,
            actions: self
        ))
        statusBarHost = statusHost
        self.findBarHost = findBarHost
        bannerHost.sizingOptions = [.intrinsicContentSize]
        findBarHost.sizingOptions = [.intrinsicContentSize]
        statusHost.sizingOptions = [.intrinsicContentSize]
        for host in [bannerHost, findBarHost, statusHost] as [NSView] {
            host.setContentHuggingPriority(.required, for: .vertical)
            host.setContentCompressionResistancePriority(.required, for: .vertical)
            host.setContentHuggingPriority(.defaultLow, for: .horizontal)
            host.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.addSubview(scrollView)
        contentSplitView = splitView
        scrollView.contentView.postsBoundsChangedNotifications = true

        let stack = NSStackView(views: [bannerHost, findBarHost, splitView, statusHost])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        for subview in stack.arrangedSubviews {
            subview.translatesAutoresizingMaskIntoConstraints = false
            subview.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        splitView.setContentHuggingPriority(.defaultLow, for: .vertical)
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        statusHost.isHidden = !showsStatusBar

        findBarModel.target = self
        document.textStorage.delegate = self
        document.editor = self
        rebuildLineIndex()
        applySettings()
        observeNotifications()
        if let pending = document.pendingSelection {
            document.pendingSelection = nil
            select(pending)
        } else {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(textView)
    }

    isolated deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func observeNotifications() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .editorSettingsDidChange,
            object: settingsStore,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applySettings()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.editorDidScroll()
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applyAppearance()
            }
        })
    }

    /// Applies editor settings such as font, wrapping and visibility toggles to this editor.
    func applySettings() {
        let settings = settings
        textView.autoIndents = settings.autoIndents
        textView.closesBrackets = settings.closesBrackets
        textView.highlightsMatchingBrackets = settings.highlightsMatchingBrackets
        textView.highlightsCurrentLine = settings.highlightsCurrentLine
        textView.isContinuousSpellCheckingEnabled = settings.checksSpelling
        textView.setWrapsLines(settings.wrapsLines)
        scrollView.rulersVisible = settings.showsLineNumbers
        (textView.layoutManager as? EditorLayoutManager)?.drawsInvisibleCharacters = settings.showsInvisibleCharacters
        applyDocumentAttributes()
        applyAppearance()
    }

    /// Applies language, indentation and large-file mode of the document.
    func applyDocumentAttributes() {
        let attributes = document.attributes
        textView.indentation = attributes.indentation
        textView.commentSyntax = attributes.language.commentSyntax
        highlightController.isEnabled = !attributes.isLargeFile
        highlightController.language = attributes.language
        textView.isMarkdown = isMarkdownDocument
        textView.documentFolderURL = document.fileURL?.deletingLastPathComponent()
        applyTextAttributes()
        updatePreviewAvailability()
        onDocumentAttributesChange?()
    }

    /// Applies the theme matching the current appearance.
    func applyAppearance() {
        theme = settings.resolvedTheme(for: view.effectiveAppearance)
        let background = theme.background.nsColor
        textView.backgroundColor = background
        textView.insertionPointColor = theme.text.nsColor
        textView.selectedTextAttributes = [.backgroundColor: theme.selection.nsColor]
        textView.currentLineColor = theme.currentLine.nsColor
        textView.bracketHighlightColor = theme.selection.nsColor.withAlphaComponent(0.8)
        scrollView.backgroundColor = background
        rulerView.backgroundColor = background
        rulerView.numberColor = theme.lineNumber.nsColor
        rulerView.currentNumberColor = theme.currentLineNumber.nsColor
        (textView.layoutManager as? EditorLayoutManager)?.invisiblesColor = theme.invisibles.nsColor
        highlightController.theme = theme
        applyTextAttributes()
        highlightMatches(Array(findBarModel.matches.prefix(FindBarModel.highlightLimit)))
        rulerView.needsDisplay = true
        textView.needsDisplay = true
        refreshPreview()
    }

    var baseTextAttributes: [NSAttributedString.Key: Any] {
        let font = settings.editorFont(scale: zoomScale)
        let paragraph = NSMutableParagraphStyle()
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        paragraph.tabStops = []
        paragraph.defaultTabInterval = spaceWidth * CGFloat(document.attributes.indentation.width)
        paragraph.lineHeightMultiple = CGFloat(settings.lineHeightMultiple)
        return [.font: font, .foregroundColor: theme.text.nsColor, .paragraphStyle: paragraph]
    }

    private func applyTextAttributes() {
        let attributes = baseTextAttributes
        textView.typingAttributes = attributes
        let storage = document.textStorage
        storage.beginEditing()
        storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
        storage.endEditing()
        if let font = attributes[.font] as? NSFont {
            rulerView.numberFont = .monospacedDigitSystemFont(ofSize: max(9, font.pointSize - 1), weight: .regular)
            (textView.layoutManager as? EditorLayoutManager)?.invisiblesFont = font
        }
    }

    private func rebuildLineIndex() {
        lineIndex = LineIndex(text: document.textStorage.string as NSString)
        rulerView.lineIndex = lineIndex
        updateStatus()
    }

    /// Updates position, selection and line count in the status bar.
    func updateStatus() {
        let ranges = textView.editingRanges ?? [textView.selectedRange()]
        let primary = textView.selectedRange()
        statusBarModel.position = lineIndex.position(at: primary.location)
        statusBarModel.selectedLength = ranges.reduce(0) { $0 + $1.length }
        statusBarModel.selectionCount = ranges.count
        statusBarModel.lineCount = lineIndex.lineCount
    }

    private func scheduleFindRefresh() {
        guard findBarModel.isVisible else { return }
        findRefreshTask?.cancel()
        findRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.findBarModel.refresh()
        }
    }

    /// Selects the full line with the given one-based number.
    func selectLine(_ line: Int) {
        guard let range = lineIndex.range(ofLine: line) else { return }
        let lineRange = LineOperations.lineRange(for: range, in: textView.nsString)
        textView.setSelectedRange(lineRange)
        view.window?.makeFirstResponder(textView)
    }

    /// Moves the caret to a one-based line and column and scrolls it into view.
    func goTo(line: Int, column: Int) {
        guard let offset = lineIndex.offset(line: line, column: column) else { return }
        select(NSRange(location: offset, length: 0))
        view.window?.makeFirstResponder(textView)
    }

    /// Changes the zoom by one step or resets it when `direction` is zero.
    func zoom(by direction: Int) {
        if direction == 0 {
            zoomScale = 1
        } else {
            let steps = Self.zoomSteps
            let index = steps.firstIndex { $0 >= zoomScale - 0.001 } ?? steps.count - 1
            let next = min(max(index + direction, 0), steps.count - 1)
            zoomScale = steps[next]
        }
        applyTextAttributes()
        rulerView.needsDisplay = true
    }
}

extension EditorViewController: NSTextStorageDelegate, NSTextViewDelegate {
    nonisolated func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        MainActor.assumeIsolated {
            lineIndex.applyEdit(editedRange: editedRange, changeInLength: delta, in: document.textStorage.string as NSString)
            rulerView?.lineIndex = lineIndex
            highlightController?.textDidChange()
            scheduleFindRefresh()
            schedulePreviewUpdate()
            updateStatus()
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateStatus()
        rulerView.needsDisplay = true
        findBarModel.updateCurrentMatch()
        document.invalidateRestorableState()
    }
}

extension EditorViewController: DocumentEditor {
    var selectedRange: NSRange {
        textView.selectedRange()
    }

    func documentWillReplaceContents() {
        storedSelectionBeforeReload = textView?.selectedRange()
    }

    func documentDidReplaceContents() {
        rebuildLineIndex()
        applyTextAttributes()
        highlightController.schedule(after: .zero)
        if let stored = storedSelectionBeforeReload {
            let length = document.textStorage.length
            let location = min(stored.location, length)
            textView.setSelectedRange(NSRange(location: location, length: min(stored.length, length - location)))
        }
        storedSelectionBeforeReload = nil
        findBarModel.refresh()
        refreshPreview()
    }

    func documentAttributesDidChange() {
        applyDocumentAttributes()
    }

    func select(_ range: NSRange) {
        let length = document.textStorage.length
        let location = min(max(range.location, 0), length)
        let clamped = NSRange(location: location, length: min(max(range.length, 0), length - location))
        textView.setSelectedRange(clamped)
        textView.scrollRangeToVisible(clamped)
    }

    func replaceAllText(with text: String, actionName: String) {
        let selection = textView.selectedRange()
        let fullRange = NSRange(location: 0, length: document.textStorage.length)
        textView.applyEdit(range: fullRange, replacement: text, selectedRange: nil, actionName: actionName)
        select(NSRange(location: selection.location, length: 0))
    }

    func markdownPrintOperation(printInfo: NSPrintInfo) -> NSPrintOperation? {
        guard isMarkdownDocument, isPreviewVisible, let previewController, previewController.isLoaded else { return nil }
        let operation = previewController.webView.printOperation(with: printInfo)
        operation.view?.frame = previewController.webView.bounds
        return operation
    }
}

extension EditorViewController: SearchTarget {
    var searchableText: NSString {
        textView.nsString
    }

    var searchSelection: NSRange {
        textView.selectedRange()
    }

    func showMatch(_ range: NSRange) {
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.showFindIndicator(for: range)
    }

    func replaceMatch(_ range: NSRange, with replacement: String) -> Bool {
        let caret = NSRange(location: range.location + (replacement as NSString).length, length: 0)
        return textView.applyEdit(range: range, replacement: replacement, selectedRange: caret, actionName: L10n.Find.replaceActionName)
    }

    func replaceText(in range: NSRange, with replacement: String, actionName: String) {
        let selection = textView.selectedRange()
        textView.applyEdit(range: range, replacement: replacement, selectedRange: nil, actionName: actionName)
        select(NSRange(location: min(selection.location, document.textStorage.length), length: 0))
    }

    func highlightMatches(_ ranges: [NSRange]) {
        guard let layoutManager = textView?.layoutManager else { return }
        let fullRange = NSRange(location: 0, length: document.textStorage.length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
        let color = theme.matchHighlight.nsColor
        for range in ranges where NSMaxRange(range) <= fullRange.length {
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        }
    }

    func focusEditor() {
        view.window?.makeFirstResponder(textView)
    }
}

private struct BannerContainer: View {
    let attributes: DocumentAttributes
    weak var controller: EditorViewController?

    var body: some View {
        if let change = attributes.externalChange {
            VStack(spacing: 0) {
                ExternalChangeBanner(
                    change: change,
                    onReload: { controller?.document.reloadFromDisk() },
                    onKeep: { controller?.document.keepCurrentVersion() },
                    onDismiss: { attributes.externalChange = nil }
                )
                Divider()
            }
            .background(.bar)
        }
    }
}

private struct FindBarContainer: View {
    let model: FindBarModel

    var body: some View {
        if model.isVisible {
            VStack(spacing: 0) {
                FindBarView(model: model)
                Divider()
            }
            .background(.bar)
        }
    }
}

private struct StatusBarContainer: View {
    let model: StatusBarModel
    let attributes: DocumentAttributes
    let document: TextDocument
    weak var actions: StatusBarActions?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            StatusBarView(model: model, attributes: attributes, canReopen: document.fileURL != nil, actions: actions)
        }
        .background(.bar)
    }
}
