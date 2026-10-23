import AppKit
import NoteCraftKit
import UniformTypeIdentifiers

extension EditorViewController {
    var isMarkdownDocument: Bool {
        document.attributes.language == LanguageCatalog.markdown
    }

    var isPreviewVisible: Bool {
        previewController?.view.superview === contentSplitView
    }

    var allowsExternalContent: Bool {
        settings.loadsExternalContent || document.attributes.allowsExternalContent || externalContentStore.isAllowed(for: document.fileURL)
    }

    var previewContent: MarkdownPreviewContent {
        MarkdownPreviewContent(
            text: document.textStorage.string,
            folderURL: document.fileURL?.deletingLastPathComponent(),
            allowsExternalImages: allowsExternalContent,
            styleSheet: MarkdownStyleSheet(theme: theme, printTheme: settings.theme(isDark: false), codeFontName: settings.fontName)
        )
    }

    @objc func togglePreview(_ sender: Any?) {
        setPreviewVisible(!isPreviewVisible)
    }

    /// Shows or hides the preview next to the editor; only Markdown documents have a preview.
    func setPreviewVisible(_ isVisible: Bool) {
        guard isVisible != isPreviewVisible else { return }
        guard isVisible else {
            previewController?.view.removeFromSuperview()
            scrollView.frame = contentSplitView.bounds
            previewUpdateTask?.cancel()
            return
        }
        guard isMarkdownDocument else { return }
        let preview = previewController ?? makePreviewController()
        contentSplitView.addSubview(preview.view)
        splitEvenly(contentSplitView)
        preview.scroll(toLine: editorTopLine())
        preview.display(previewContent)
    }

    private func makePreviewController() -> MarkdownPreviewController {
        let preview = MarkdownPreviewController(folderAccess: folderAccessStore)
        preview.delegate = self
        addChild(preview)
        previewController = preview
        return preview
    }

    /// Opens the preview for a Markdown document once, as the settings ask, and closes it for other languages.
    func updatePreviewAvailability() {
        guard isMarkdownDocument else {
            setPreviewVisible(false)
            hasDecidedPreviewVisibility = false
            return
        }
        guard !hasDecidedPreviewVisibility else { return }
        hasDecidedPreviewVisibility = true
        if settings.opensMarkdownPreview {
            setPreviewVisible(true)
        }
    }

    /// Renders the preview again shortly after the last change.
    func schedulePreviewUpdate() {
        guard isPreviewVisible else { return }
        previewUpdateTask?.cancel()
        previewUpdateTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.refreshPreview()
        }
    }

    /// Renders the preview immediately with the current text, theme and permissions.
    func refreshPreview() {
        guard isPreviewVisible, let previewController else { return }
        previewUpdateTask?.cancel()
        previewController.display(previewContent)
    }

    /// The one-based, fractional source line at the top of the editor.
    func editorTopLine() -> Double {
        guard let layoutManager = textView.layoutManager, let container = textView.textContainer, textView.nsString.length > 0 else { return 1 }
        let top = scrollView.contentView.bounds.minY
        let point = NSPoint(x: 0, y: max(0, top - textView.textContainerOrigin.y))
        layoutManager.ensureLayout(forBoundingRect: NSRect(x: 0, y: point.y, width: container.size.width, height: 1), in: container)
        let glyph = layoutManager.glyphIndex(for: point, in: container)
        let character = min(layoutManager.characterIndexForGlyph(at: glyph), textView.nsString.length - 1)
        let line = lineIndex.position(at: character).line
        guard let start = lineIndex.offset(line: line, column: 1), let rect = textView.lineRect(forCharacterAt: start), rect.height > 0 else {
            return Double(line)
        }
        return Double(line) + min(max((top - rect.minY) / rect.height, 0), 0.999)
    }

    /// Scrolls the editor so that the fractional one-based `line` is at the top.
    func scrollEditor(toLine line: Double) {
        let whole = min(max(1, Int(line.rounded(.down))), lineIndex.lineCount)
        guard let start = lineIndex.offset(line: whole, column: 1), let first = textView.lineRect(forCharacterAt: start) else { return }
        let visibleLines = Int(scrollView.contentView.bounds.height / max(first.height, 1)) + 2
        let lastLine = min(whole + visibleLines, lineIndex.lineCount)
        let end = lineIndex.range(ofLine: lastLine).map(NSMaxRange) ?? textView.nsString.length
        textView.layoutManager?.ensureLayout(forCharacterRange: NSRange(location: 0, length: min(end, textView.nsString.length)))
        guard let rect = textView.lineRect(forCharacterAt: start) else { return }
        let fraction = min(max(line - Double(whole), 0), 1)
        ignoresEditorScrollUntil = Date().addingTimeInterval(0.25)
        textView.scroll(NSPoint(x: scrollView.contentView.bounds.minX, y: rect.minY + fraction * rect.height))
    }

    func editorDidScroll() {
        guard isPreviewVisible, settings.markdownScrollSync != .independent, Date() >= ignoresEditorScrollUntil else { return }
        ignoresPreviewScrollUntil = Date().addingTimeInterval(0.25)
        previewController?.scroll(toLine: editorTopLine())
    }

    @objc func exportAsHTML(_ sender: Any?) {
        guard let window = view.window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = exportTitle + ".html"
        panel.directoryURL = document.fileURL?.deletingLastPathComponent()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                self?.writeHTML(to: url)
            }
        }
    }

    /// Writes the document as a self-contained HTML file to `url`.
    func writeHTML(to url: URL) {
        do {
            try exportedHTML(for: document.textStorage.string, includesDarkAppearance: true).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            document.presentErrorAsSheet(error)
        }
    }

    var exportTitle: String {
        let name = document.fileURL?.lastPathComponent ?? document.displayName ?? ""
        return (name as NSString).deletingPathExtension
    }

    /// The Markdown `text` as an HTML document with embedded style and local images.
    func exportedHTML(for text: String, includesDarkAppearance: Bool) -> String {
        let renderer = MarkdownRenderer(
            folderURL: document.fileURL?.deletingLastPathComponent(),
            loadsExternalImages: true,
            allowsTaskToggling: false,
            localImageSource: Self.dataAddress(for:)
        )
        let light = settings.theme(isDark: false)
        let styleSheet = MarkdownStyleSheet(
            theme: light,
            printTheme: light,
            darkTheme: includesDarkAppearance ? settings.theme(isDark: true) : nil,
            codeFontName: settings.fontName
        )
        return MarkdownPage.exportHTML(title: exportTitle, body: renderer.render(text).html, css: styleSheet.css)
    }

    /// A `data:` address with the contents of the image at `url`, or the file address when it can't be read.
    static func dataAddress(for url: URL) -> String {
        guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
              let data = try? Data(contentsOf: url) else { return url.absoluteString }
        return "data:\(type.preferredMIMEType ?? "application/octet-stream");base64,\(data.base64EncodedString())"
    }

    @objc func copyAsFormattedText(_ sender: Any?) {
        copyFormattedText(to: .general)
    }

    /// Writes the selection, or the whole document, as HTML, rich text and Markdown source to `pasteboard`.
    func copyFormattedText(to pasteboard: NSPasteboard) {
        let selection = textView.selectedRange()
        let source = selection.length > 0 ? textView.nsString.substring(with: selection) : textView.string
        let html = exportedHTML(for: source, includesDarkAppearance: false)
        pasteboard.clearContents()
        pasteboard.setString(html, forType: .html)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributed = try? NSAttributedString(data: Data(html.utf8), options: options, documentAttributes: nil),
           let rtf = try? attributed.data(from: NSRange(location: 0, length: attributed.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pasteboard.setData(rtf, forType: .rtf)
        }
        pasteboard.setString(source, forType: .string)
    }

    /// Opens a link of the preview: web and mail addresses in their app, other documents in NoteCraft.
    func openPreviewLink(_ address: String, workspace: NSWorkspace = .shared) {
        if let url = URL(string: address), let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) {
            workspace.open(url)
            return
        }
        if address.lowercased().hasPrefix("www."), let url = URL(string: "http://" + address) {
            workspace.open(url)
            return
        }
        guard case .local(let fileURL) = MarkdownResourceLocation.resolve(address, relativeTo: document.fileURL?.deletingLastPathComponent()) else {
            NSSound.beep()
            return
        }
        let type = UTType(filenameExtension: fileURL.pathExtension)
        guard type == nil || type?.conforms(to: .text) == true else {
            workspace.open(fileURL)
            return
        }
        NSDocumentController.shared.openDocument(withContentsOf: fileURL, display: true) { _, _, error in
            if let error {
                MainActor.assumeIsolated {
                    _ = NSApp.presentError(error)
                }
            }
        }
    }
}

extension EditorViewController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        if splitView.subviews.count == 2, splitView.subviews.contains(where: { $0.frame.width < 1 }) {
            splitEvenly(splitView)
        } else {
            splitView.adjustSubviews()
        }
    }

    /// Gives editor and preview the same width.
    func splitEvenly(_ splitView: NSSplitView) {
        let bounds = splitView.bounds
        let width = max(0, (bounds.width - splitView.dividerThickness) / 2)
        for (index, subview) in splitView.subviews.enumerated() {
            subview.frame = NSRect(x: CGFloat(index) * (width + splitView.dividerThickness), y: 0, width: width, height: bounds.height)
        }
    }
}

extension EditorViewController: MarkdownPreviewDelegate {
    func preview(_ preview: MarkdownPreviewController, didScrollToLine line: Double) {
        guard settings.markdownScrollSync == .both, Date() >= ignoresPreviewScrollUntil else { return }
        scrollEditor(toLine: line)
    }

    func preview(_ preview: MarkdownPreviewController, didRequestLine line: Int) {
        goTo(line: line, column: 1)
    }

    func preview(_ preview: MarkdownPreviewController, didToggleTaskAtLine line: Int) {
        guard textView.isEditable, let edit = MarkdownEditing.toggleTask(atLine: line, in: textView.nsString) else { return }
        textView.applyEdit(range: edit.range, replacement: edit.replacement, selectedRange: nil, actionName: L10n.Undo.task)
    }

    func preview(_ preview: MarkdownPreviewController, didActivateLink address: String) {
        openPreviewLink(address)
    }

    func previewDidRequestExternalContent(_ preview: MarkdownPreviewController) {
        if let fileURL = document.fileURL {
            externalContentStore.allow(for: fileURL)
        } else {
            document.attributes.allowsExternalContent = true
        }
        refreshPreview()
    }

    func preview(_ preview: MarkdownPreviewController, didRequestAccessTo folderURL: URL) {
        folderAccessStore.requestAccess(to: folderURL, for: view.window) { [weak self] in
            self?.refreshPreview()
        }
    }
}
