import AppKit
import NoteCraftKit

struct MarkdownTool {
    let label: String
    let action: Selector
    var tag = 0
    let image: NSImage
    let activeImage: NSImage

    /// A tool drawn with an SF Symbol; the active variant uses the accent color.
    static func symbol(_ name: String, label: String, action: Selector) -> MarkdownTool {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label) ?? NSImage()
        let active = image.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.controlAccentColor])) ?? image
        return MarkdownTool(label: label, action: action, image: image, activeImage: active)
    }

    /// A tool drawn with a short text such as "H1"; the active variant uses the accent color.
    static func text(_ text: String, label: String, action: Selector, tag: Int) -> MarkdownTool {
        MarkdownTool(label: label, action: action, tag: tag, image: textImage(text, label: label, color: nil), activeImage: textImage(text, label: label, color: .controlAccentColor))
    }

    private static func textImage(_ text: String, label: String, color: NSColor?) -> NSImage {
        let font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let size = (text as NSString).size(withAttributes: [.font: font])
        let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)), flipped: false) { _ in
            (text as NSString).draw(at: .zero, withAttributes: [.font: font, .foregroundColor: color ?? NSColor.black])
            return true
        }
        image.isTemplate = color == nil
        image.accessibilityDescription = label
        return image
    }
}

extension EditorWindowController {
    /// The tools of every Markdown group, in the order they appear.
    static let markdownToolsByGroup: [NSToolbarItem.Identifier: [MarkdownTool]] = [
        .markdownIndentation: [
            .symbol("decrease.indent", label: L10n.Menu.shiftLeft, action: #selector(EditorTextView.shiftLeft(_:))),
            .symbol("increase.indent", label: L10n.Menu.shiftRight, action: #selector(EditorTextView.shiftRight(_:)))
        ],
        .markdownTextStyle: [
            .symbol("bold", label: L10n.Menu.bold, action: #selector(EditorTextView.formatBold(_:))),
            .symbol("italic", label: L10n.Menu.italic, action: #selector(EditorTextView.formatItalic(_:))),
            .symbol("strikethrough", label: L10n.Menu.strikethrough, action: #selector(EditorTextView.formatStrikethrough(_:)))
        ],
        .markdownHeadings: (1...3).map { .text("H\($0)", label: L10n.Menu.headingLevel($0), action: #selector(EditorTextView.formatHeading(_:)), tag: $0) },
        .markdownLists: [
            .symbol("list.bullet", label: L10n.Menu.bulletedList, action: #selector(EditorTextView.toggleBulletedList(_:))),
            .symbol("list.number", label: L10n.Menu.numberedList, action: #selector(EditorTextView.toggleNumberedList(_:)))
        ],
        .markdownQuoteAndCode: [
            .symbol("text.quote", label: L10n.Menu.quote, action: #selector(EditorTextView.formatQuote(_:))),
            .symbol("chevron.left.forwardslash.chevron.right", label: L10n.Menu.code, action: #selector(EditorTextView.formatCode(_:)))
        ],
        .markdownLinkAndImage: [
            .symbol("link", label: L10n.MarkdownToolbar.link, action: #selector(EditorTextView.insertMarkdownLink(_:))),
            .symbol("photo", label: L10n.MarkdownToolbar.image, action: #selector(EditorTextView.insertMarkdownImage(_:)))
        ]
    ]

    private static let markdownGroupLabels: [NSToolbarItem.Identifier: String] = [
        .markdownIndentation: L10n.MarkdownToolbar.indentation,
        .markdownTextStyle: L10n.MarkdownToolbar.textStyle,
        .markdownHeadings: L10n.MarkdownToolbar.headings,
        .markdownLists: L10n.MarkdownToolbar.lists,
        .markdownQuoteAndCode: L10n.MarkdownToolbar.quoteAndCode,
        .markdownLinkAndImage: L10n.MarkdownToolbar.linkAndImage
    ]

    /// Builds a Markdown tool group or the menu with the remaining formats; returns `nil` for other identifiers.
    ///
    /// The tools send their commands to the first responder, so they work on the focused editor.
    func makeMarkdownTool(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        if identifier == .markdownMore {
            let label = L10n.MarkdownToolbar.moreFormats
            let item = NSMenuToolbarItem(itemIdentifier: identifier)
            item.label = label
            item.paletteLabel = label
            item.toolTip = label
            item.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: label)
            item.menu = MainMenuBuilder(appDelegate: nil).makeMoreFormatsMenu()
            item.showsIndicator = false
            return item
        }
        guard let tools = Self.markdownToolsByGroup[identifier], let label = Self.markdownGroupLabels[identifier] else { return nil }
        let group = NSToolbarItemGroup(itemIdentifier: identifier)
        group.label = label
        group.paletteLabel = label
        group.controlRepresentation = .expanded
        group.subitems = tools.enumerated().map { index, tool in
            let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("\(identifier.rawValue).\(index)"))
            item.label = tool.label
            item.paletteLabel = tool.label
            item.toolTip = tool.label
            item.image = tool.image
            item.action = tool.action
            item.tag = tool.tag
            return item
        }
        return group
    }

    /// Shows the tools whose format applies at the selection in the accent color; large files show no formats.
    func updateMarkdownToolStates() {
        let showsState = editorViewController.isMarkdownDocument && !editorViewController.document.attributes.isLargeFile
        let state = showsState ? editorViewController.textView.markdownFormatState : MarkdownFormatState()
        let states: [NSToolbarItem.Identifier: [Bool]] = [
            .markdownTextStyle: [MarkdownInlineStyle.bold, .italic, .strikethrough].map(state.inlineStyles.contains),
            .markdownHeadings: (1...3).map { state.headingLevel == $0 },
            .markdownLists: [state.listKind == .bullet, state.listKind == .numbered],
            .markdownQuoteAndCode: [state.isQuote, state.inlineStyles.contains(.code)]
        ]
        guard states != markdownToolStates else { return }
        markdownToolStates = states
        for case let group as NSToolbarItemGroup in window?.toolbar?.items ?? [] {
            applyMarkdownToolStates(to: group)
        }
    }

    /// Gives every tool of `group` the image for its current state.
    func applyMarkdownToolStates(to group: NSToolbarItemGroup) {
        guard let tools = Self.markdownToolsByGroup[group.itemIdentifier] else { return }
        let active = markdownToolStates[group.itemIdentifier] ?? []
        for (index, (subitem, tool)) in zip(group.subitems, tools).enumerated() {
            subitem.image = index < active.count && active[index] ? tool.activeImage : tool.image
        }
    }
}
