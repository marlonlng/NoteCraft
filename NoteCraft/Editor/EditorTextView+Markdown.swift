import AppKit
import NoteCraftKit
import SwiftUI
import UniformTypeIdentifiers

extension EditorTextView: NSToolbarItemValidation, NSPopoverDelegate {
    private static var headingPopoverClosingClick: Int?
    /// The heading styles popover while it is open.
    static var headingPopover: NSPopover?

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

    /// Opens the heading styles in a popover below the clicked toolbar button, or below the caret without a click.
    ///
    /// A click on the button that closes the open popover does not open it again.
    @objc func showHeadingStyles(_ sender: Any?) {
        let event = NSApp.currentEvent
        let click = event?.type == .leftMouseUp ? event : nil
        if let click, click.eventNumber == Self.headingPopoverClosingClick {
            Self.headingPopoverClosingClick = nil
            return
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        let content = NSHostingController(rootView: HeadingStylesView(currentLevel: markdownFormatState.headingLevel) { [weak self, weak popover] level in
            popover?.performClose(nil)
            self?.applyHeading(level: level)
        })
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        if let click, let root = click.window?.contentView?.superview, let button = Self.innermostButton(at: click.locationInWindow, in: root) {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: button.isFlipped ? .maxY : .minY)
        } else {
            popover.show(relativeTo: caretRect, of: self, preferredEdge: .maxY)
        }
        Self.headingPopover = popover
    }

    /// Remembers the click that closes the heading styles, so that a click on their button only closes them.
    func popoverWillClose(_ notification: Notification) {
        let event = NSApp.currentEvent
        Self.headingPopoverClosingClick = event?.type == .leftMouseDown ? event?.eventNumber : nil
    }

    func popoverDidClose(_ notification: Notification) {
        Self.headingPopover = nil
    }

    private var caretRect: NSRect {
        guard let window else { return bounds }
        let rect = convert(window.convertFromScreen(firstRect(forCharacterRange: selectedRange(), actualRange: nil)), from: nil)
        return rect.insetBy(dx: -1, dy: 0)
    }

    /// Finds the innermost visible button under `location`, given in window coordinates, among `root` and its subviews.
    ///
    /// Hit testing the toolbar returns the whole item group, and the glass of a capsule lies in a sibling above its
    /// buttons, so every view under the location is searched.
    static func innermostButton(at location: NSPoint, in root: NSView) -> NSButton? {
        var button: NSButton?
        func search(_ view: NSView) {
            guard !view.isHidden, view.bounds.contains(view.convert(location, from: nil)) else { return }
            if let found = view as? NSButton {
                button = found
            }
            view.subviews.forEach(search)
        }
        search(root)
        return button
    }

    @objc func formatHeading(_ sender: Any?) {
        applyHeading(level: (sender as? NSMenuItem)?.tag ?? 0)
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
