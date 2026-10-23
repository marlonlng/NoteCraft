import AppKit
import NoteCraftKit
import UniformTypeIdentifiers

extension EditorTextView {
    @objc func formatBold(_ sender: Any?) {
        toggleInlineStyle(.bold)
    }

    @objc func formatItalic(_ sender: Any?) {
        toggleInlineStyle(.italic)
    }

    @objc func formatStrikethrough(_ sender: Any?) {
        toggleInlineStyle(.strikethrough)
    }

    @objc func formatInlineCode(_ sender: Any?) {
        toggleInlineStyle(.code)
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
        let level = (sender as? NSMenuItem)?.tag ?? 0
        apply(MarkdownEditing.setHeading(level: level, in: nsString, selection: selectedRange()), actionName: L10n.Undo.formatting)
    }

    @objc func formatQuote(_ sender: Any?) {
        apply(MarkdownEditing.toggleQuote(in: nsString, selection: selectedRange()), actionName: L10n.Undo.formatting)
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

    /// Inserts an image reference for every file at `location`, relative to the folder of the document.
    @discardableResult
    func insertImages(_ urls: [URL], at location: Int) -> Bool {
        let markdown = urls.map { MarkdownEditing.imageMarkdown(for: $0, relativeTo: documentFolderURL) }.joined(separator: "\n")
        let range = NSRange(location: min(max(location, 0), nsString.length), length: 0)
        let caret = NSRange(location: range.location + (markdown as NSString).length, length: 0)
        return applyEdit(range: range, replacement: markdown, selectedRange: caret, actionName: L10n.Undo.insertImage)
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

    /// Enables the Markdown commands only for Markdown documents; returns `nil` for other actions.
    func validateMarkdownMenuItem(_ menuItem: NSMenuItem) -> Bool? {
        switch menuItem.action {
        case #selector(formatBold(_:)), #selector(formatItalic(_:)), #selector(formatStrikethrough(_:)), #selector(formatInlineCode(_:)),
             #selector(insertMarkdownLink(_:)), #selector(formatHeading(_:)), #selector(formatQuote(_:)), #selector(toggleTask(_:)),
             #selector(insertMarkdownTable(_:)), #selector(updateTableOfContents(_:)):
            return isEditable && isMarkdown
        case #selector(formatMarkdownTable(_:)), #selector(addMarkdownTableRow(_:)), #selector(addMarkdownTableColumn(_:)):
            return isEditable && isMarkdown && MarkdownTableEditing.containsTable(at: selectedRange().location, in: nsString)
        default:
            return nil
        }
    }
}
