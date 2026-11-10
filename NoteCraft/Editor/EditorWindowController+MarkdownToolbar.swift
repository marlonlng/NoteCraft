import AppKit
import NoteCraftKit

struct MarkdownTool {
    let label: String
    let action: Selector
    var makeSubmenu: (@MainActor () -> NSMenu)?
    let image: NSImage
    let activeImage: NSImage
    var isActive: (MarkdownFormatState) -> Bool = { _ in false }

    /// A tool drawn with an SF Symbol; the active variant uses the accent color.
    static func symbol(
        _ name: String,
        label: String,
        action: Selector,
        isActive: @escaping (MarkdownFormatState) -> Bool = { _ in false }
    ) -> MarkdownTool {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label) ?? NSImage()
        let active = image.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.controlAccentColor])) ?? image
        return MarkdownTool(label: label, action: action, image: image, activeImage: active, isActive: isActive)
    }

    /// The heading tool, drawn as "Aa", that opens body text and the heading levels in a popover; it is active on headings.
    ///
    /// It is a plain button rather than a menu item, because a menu item would split the capsule. The overflow menu
    /// shows the heading levels as a submenu.
    static var heading: MarkdownTool {
        var tool = symbol("textformat", label: L10n.Menu.heading, action: #selector(EditorTextView.showHeadingStyles(_:))) { $0.headingLevel > 0 }
        tool.makeSubmenu = { MainMenuBuilder(appDelegate: nil).makeHeadingMenu(includesShortcuts: false) }
        return tool
    }
}

extension EditorWindowController {
    /// The tools of the Markdown capsule, in the order they appear.
    static let markdownTools: [MarkdownTool] = [
        .symbol("bold", label: L10n.Menu.bold, action: #selector(EditorTextView.formatBold(_:))) { $0.inlineStyles.contains(.bold) },
        .symbol("italic", label: L10n.Menu.italic, action: #selector(EditorTextView.formatItalic(_:))) { $0.inlineStyles.contains(.italic) },
        .symbol("strikethrough", label: L10n.Menu.strikethrough, action: #selector(EditorTextView.formatStrikethrough(_:))) {
            $0.inlineStyles.contains(.strikethrough)
        },
        .heading,
        .symbol("list.bullet", label: L10n.Menu.bulletedList, action: #selector(EditorTextView.toggleBulletedList(_:))) { $0.listKind == .bullet },
        .symbol("list.number", label: L10n.Menu.numberedList, action: #selector(EditorTextView.toggleNumberedList(_:))) { $0.listKind == .numbered },
        .symbol("text.quote", label: L10n.Menu.quote, action: #selector(EditorTextView.formatQuote(_:))) { $0.isQuote },
        .symbol("chevron.left.forwardslash.chevron.right", label: L10n.Menu.code, action: #selector(EditorTextView.formatCode(_:))) {
            $0.inlineStyles.contains(.code)
        },
        .symbol("link", label: L10n.MarkdownToolbar.link, action: #selector(EditorTextView.insertMarkdownLink(_:))),
        .symbol("photo", label: L10n.MarkdownToolbar.image, action: #selector(EditorTextView.insertMarkdownImage(_:)))
    ]

    /// Builds the Markdown capsule or the menu with the remaining formats; returns `nil` for other identifiers.
    ///
    /// The tools send their commands to the first responder, so they work on the focused editor. A tool with a submenu
    /// shows that submenu in the overflow menu.
    func makeMarkdownTool(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        switch identifier {
        case .markdownTools:
            let label = L10n.MarkdownToolbar.tools
            let group = NSToolbarItemGroup(itemIdentifier: identifier)
            group.label = label
            group.paletteLabel = label
            group.controlRepresentation = .expanded
            group.subitems = Self.markdownTools.enumerated().map { index, tool in
                let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("\(identifier.rawValue).\(index)"))
                item.label = tool.label
                item.paletteLabel = tool.label
                item.toolTip = tool.label
                item.image = tool.image
                item.action = tool.action
                if let makeSubmenu = tool.makeSubmenu {
                    let menuItem = NSMenuItem(title: tool.label, action: nil, keyEquivalent: "")
                    menuItem.submenu = makeSubmenu()
                    item.menuFormRepresentation = menuItem
                }
                return item
            }
            return group
        case .markdownMore:
            let label = L10n.MarkdownToolbar.moreFormats
            let item = NSMenuToolbarItem(itemIdentifier: identifier)
            item.label = label
            item.paletteLabel = label
            item.toolTip = label
            item.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: label)
            item.menu = MainMenuBuilder(appDelegate: nil).makeMoreFormatsMenu()
            item.showsIndicator = false
            return item
        default:
            return nil
        }
    }

    /// Shows the tools whose format applies at the selection in the accent color; large files show no formats.
    func updateMarkdownToolStates() {
        let showsState = editorViewController.isMarkdownDocument && !editorViewController.document.attributes.isLargeFile
        let state = showsState ? editorViewController.textView.markdownFormatState : MarkdownFormatState()
        let states = Self.markdownTools.map { $0.isActive(state) }
        guard states != markdownToolStates else { return }
        markdownToolStates = states
        for case let group as NSToolbarItemGroup in window?.toolbar?.items ?? [] {
            applyMarkdownToolStates(to: group)
        }
    }

    /// Gives every tool of the Markdown capsule the image for its current state.
    func applyMarkdownToolStates(to group: NSToolbarItemGroup) {
        guard group.itemIdentifier == .markdownTools else { return }
        for (index, (subitem, tool)) in zip(group.subitems, Self.markdownTools).enumerated() {
            subitem.image = markdownToolStates.indices.contains(index) && markdownToolStates[index] ? tool.activeImage : tool.image
        }
    }
}
