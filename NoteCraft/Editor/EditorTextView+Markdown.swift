import AppKit
import NoteCraftKit
import UniformTypeIdentifiers

extension EditorTextView: NSToolbarItemValidation {
    /// Enables the Markdown tools of the toolbar while the editor shows an editable Markdown document.
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        isEditable && isMarkdown
    }

    @objc func formatBold(_ sender: Any?) {
        toggleInlineStyle(.bold)
    }

    @objc func formatItalic(_ sender: Any?) {
        toggleInlineStyle(.italic)
    }

    @objc func formatStrikethrough(_ sender: Any?) {
        toggleInlineStyle(.strikethrough)
    }

    @objc func formatCode(_ sender: Any?) {
        apply(MarkdownEditing.toggleCode(in: nsString, selection: selectedRange()), actionName: L10n.Undo.formatting)
    }

    private func toggleInlineStyle(_ style: MarkdownInlineStyle) {
        apply(MarkdownEditing.toggle(style, in: nsString, selection: selectedRange()), actionName: L10n.Undo.formatting)
    }

    @objc func insertMarkdownLink(_ sender: Any?) {
        insertLink(suggestedAddress: NSPasteboard.general.string(forType: .string))
    }

    /// Inserts link syntax around the selection, using `suggestedAddress` when it is a web or mail address.
    func insertLink(suggestedAddress: String?) {
        apply(MarkdownEditing.insertLink(in: nsString, selection: selectedRange(), suggestedAddress: suggestedAddress), actionName: L10n.Undo.link)
    }

    @objc func formatHeading(_ sender: Any?) {
        applyHeading(level: (sender as? NSMenuItem)?.tag ?? (sender as? NSToolbarItem)?.tag ?? 0)
    }

    /// Turns the selected lines into headings of `level`, or into body text when they already have that level.
    func applyHeading(level: Int) {
        apply(MarkdownEditing.setHeading(level: level, in: nsString, selection: selectedRange()), actionName: L10n.Undo.formatting)
    }

    @objc func formatQuote(_ sender: Any?) {
        apply(MarkdownEditing.toggleQuote(in: nsString, selection: selectedRange()), actionName: L10n.Undo.formatting)
    }

    @objc func toggleBulletedList(_ sender: Any?) {
        apply(MarkdownEditing.toggleList(.bullet, in: nsString, selection: selectedRange()), actionName: L10n.Undo.list)
    }

    @objc func toggleNumberedList(_ sender: Any?) {
        apply(MarkdownEditing.toggleList(.numbered, in: nsString, selection: selectedRange()), actionName: L10n.Undo.list)
    }

    @objc func toggleTask(_ sender: Any?) {
        apply(MarkdownEditing.toggleTask(in: nsString, selection: selectedRange()), actionName: L10n.Undo.task)
    }

    @objc func insertMarkdownTable(_ sender: Any?) {
        let headers = (1...3).map(L10n.Markdown.column)
        apply(MarkdownTableEditing.insertTable(in: nsString, selection: selectedRange(), headers: headers), actionName: L10n.Undo.table)
    }

    @objc func formatMarkdownTable(_ sender: Any?) {
        apply(MarkdownTableEditing.format(in: nsString, selection: selectedRange()), actionName: L10n.Undo.table)
    }

    @objc func addMarkdownTableRow(_ sender: Any?) {
        apply(MarkdownTableEditing.addRow(in: nsString, selection: selectedRange()), actionName: L10n.Undo.table)
    }

    @objc func addMarkdownTableColumn(_ sender: Any?) {
        apply(MarkdownTableEditing.addColumn(in: nsString, selection: selectedRange()), actionName: L10n.Undo.table)
    }

    @objc func updateTableOfContents(_ sender: Any?) {
        apply(MarkdownTableOfContents.update(in: nsString, selection: selectedRange()), actionName: L10n.Undo.tableOfContents)
    }

    /// Whether `url` is an image file that Markdown can reference.
    static func isImageFile(_ url: URL) -> Bool {
        url.isFileURL && UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }

    /// Lets the user choose image files and inserts a reference to each of them in place of the selection.
    @objc func insertMarkdownImage(_ sender: Any?) {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = documentFolderURL
        panel.prompt = L10n.Menu.insertImagePrompt
        let range = selectedRange()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            MainActor.assumeIsolated {
                self?.insertImages(urls, replacing: range)
            }
        }
    }

    /// Inserts an image reference for every file in place of `range`, relative to the folder of the document.
    @discardableResult
    func insertImages(_ urls: [URL], replacing range: NSRange) -> Bool {
        let markdown = urls.map { MarkdownEditing.imageMarkdown(for: $0, relativeTo: documentFolderURL) }.joined(separator: "\n")
        let location = min(max(range.location, 0), nsString.length)
        let target = NSRange(location: location, length: min(max(range.length, 0), nsString.length - location))
        let caret = NSRange(location: location + (markdown as NSString).length, length: 0)
        return applyEdit(range: target, replacement: markdown, selectedRange: caret, actionName: L10n.Undo.insertImage)
    }

    /// The Markdown formatting at the selection, as shown by the Format menu and the toolbar.
    var markdownFormatState: MarkdownFormatState {
        MarkdownFormatState.at(selectedRange(), in: nsString)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let menu = super.menu(for: event)?.copy() as? NSMenu else { return nil }
        guard isMarkdown else { return menu }
        let format = NSMenuItem(title: L10n.Menu.format, action: nil, keyEquivalent: "")
        format.submenu = MainMenuBuilder(appDelegate: nil).makeFormatMenu(includesShortcuts: false)
        let index = menu.items.firstIndex { $0.action == #selector(paste(_:)) }.map { $0 + 1 } ?? menu.items.count
        menu.insertItem(.separator(), at: index)
        menu.insertItem(format, at: index + 1)
        return menu
    }

    /// Enables the Markdown commands only for Markdown documents and checks the formats at the selection;
    /// returns `nil` for other actions.
    func validateMarkdownMenuItem(_ menuItem: NSMenuItem) -> Bool? {
        switch menuItem.action {
        case #selector(formatBold(_:)), #selector(formatItalic(_:)), #selector(formatStrikethrough(_:)), #selector(formatCode(_:)),
             #selector(formatHeading(_:)), #selector(formatQuote(_:)), #selector(toggleBulletedList(_:)), #selector(toggleNumberedList(_:)):
            if isMarkdown {
                menuItem.state = isActive(menuItem.action, tag: menuItem.tag, in: markdownFormatState) ? .on : .off
            }
            return isEditable && isMarkdown
        case #selector(insertMarkdownLink(_:)), #selector(insertMarkdownImage(_:)), #selector(toggleTask(_:)),
             #selector(insertMarkdownTable(_:)), #selector(updateTableOfContents(_:)):
            return isEditable && isMarkdown
        case #selector(formatMarkdownTable(_:)), #selector(addMarkdownTableRow(_:)), #selector(addMarkdownTableColumn(_:)):
            return isEditable && isMarkdown && MarkdownTableEditing.containsTable(at: selectedRange().location, in: nsString)
        default:
            return nil
        }
    }

    private func isActive(_ action: Selector?, tag: Int, in state: MarkdownFormatState) -> Bool {
        switch action {
        case #selector(formatBold(_:)): state.inlineStyles.contains(.bold)
        case #selector(formatItalic(_:)): state.inlineStyles.contains(.italic)
        case #selector(formatStrikethrough(_:)): state.inlineStyles.contains(.strikethrough)
        case #selector(formatCode(_:)): state.inlineStyles.contains(.code)
        case #selector(formatHeading(_:)): state.headingLevel == tag && !state.inlineStyles.contains(.code)
        case #selector(formatQuote(_:)): state.isQuote
        case #selector(toggleBulletedList(_:)): state.listKind == .bullet
        case #selector(toggleNumberedList(_:)): state.listKind == .numbered
        default: false
        }
    }
}
