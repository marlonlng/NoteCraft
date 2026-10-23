import AppKit
import NoteCraftKit
import Observation

struct PaletteItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let shortcut: String?
    let symbolName: String
    let perform: @MainActor () -> Void
}

@MainActor
enum MenuCommandCatalog {
    /// Collects every enabled command of `menu` and its submenus with the path of parent menu titles.
    static func commands(in menu: NSMenu, path: [String] = [], excluding excludedActions: Set<Selector> = []) -> [(item: NSMenuItem, path: [String])] {
        menu.update()
        var result: [(NSMenuItem, [String])] = []
        for item in menu.items where !item.isSeparatorItem && !item.isHidden {
            if let submenu = item.submenu {
                guard submenu !== NSApp.servicesMenu else { continue }
                result += commands(in: submenu, path: path + [item.title], excluding: excludedActions)
            } else if let action = item.action, item.isEnabled, !item.title.isEmpty, !excludedActions.contains(action) {
                result.append((item, path))
            }
        }
        return result
    }

    /// The shortcut of `item` in menu notation, e.g. `⇧⌘A`.
    static func shortcut(for item: NSMenuItem) -> String? {
        guard !item.keyEquivalent.isEmpty else { return nil }
        var symbols = ""
        let modifiers = item.keyEquivalentModifierMask
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        let key = item.keyEquivalent
        let isUppercaseLetter = key.count == 1 && key.uppercased() == key && key.lowercased() != key
        if modifiers.contains(.shift) || isUppercaseLetter { symbols += "⇧" }
        if modifiers.contains(.command) { symbols += "⌘" }
        let special: [String: String] = ["\r": "↩", "\u{1B}": "⎋", "\t": "⇥", "\u{8}": "⌫", " ": "␣"]
        return symbols + (special[key] ?? key.uppercased())
    }
}

@MainActor
@Observable
final class CommandPaletteModel {
    enum Mode {
        case commands
        case files
    }

    static let resultLimit = 200

    let mode: Mode
    let items: [PaletteItem]
    var selectedIndex = 0

    var query = "" {
        didSet {
            selectedIndex = 0
        }
    }

    init(mode: Mode, items: [PaletteItem]) {
        self.mode = mode
        self.items = items
    }

    var placeholder: String {
        mode == .commands ? L10n.Palette.commandsPlaceholder : L10n.Palette.filesPlaceholder
    }

    var results: [PaletteItem] {
        let ranked = FuzzyMatcher.rank(items, query: query) { item in
            mode == .files ? (item.subtitle ?? item.title) : item.title + " " + (item.subtitle ?? "")
        }
        return ranked.prefix(Self.resultLimit).map(\.item)
    }

    func moveSelection(by delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    var selectedItem: PaletteItem? {
        let results = results
        return results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    /// Builds the command list from the main menu and the open documents of the app.
    static func commands(for windowController: EditorWindowController?, mainMenu: NSMenu? = NSApp.mainMenu) -> CommandPaletteModel {
        var items: [PaletteItem] = []
        if let mainMenu {
            let excluded: Set<Selector> = [
                #selector(EditorWindowController.showCommandPalette(_:)),
                #selector(NSWindow.makeKeyAndOrderFront(_:))
            ]
            for (index, entry) in MenuCommandCatalog.commands(in: mainMenu, excluding: excluded).enumerated() {
                let menuItem = entry.item
                items.append(PaletteItem(
                    id: "command-\(index)",
                    title: menuItem.title.replacingOccurrences(of: #"\s*…$"#, with: "", options: .regularExpression),
                    subtitle: entry.path.joined(separator: " › "),
                    shortcut: MenuCommandCatalog.shortcut(for: menuItem),
                    symbolName: "command",
                    perform: {
                        NSApp.sendAction(menuItem.action!, to: menuItem.target, from: menuItem)
                    }
                ))
            }
        }
        for case let document as TextDocument in NSDocumentController.shared.documents where document !== windowController?.document {
            items.append(PaletteItem(
                id: "document-\(ObjectIdentifier(document).hashValue)",
                title: document.displayName,
                subtitle: L10n.Palette.documents,
                shortcut: nil,
                symbolName: "doc.text",
                perform: {
                    document.showWindows()
                }
            ))
        }
        return CommandPaletteModel(mode: .commands, items: items)
    }

    /// Builds the file list of the workspace folder.
    static func files(in workspace: WorkspaceModel) -> CommandPaletteModel {
        let items = workspace.allFiles.map { file in
            PaletteItem(
                id: file.url.path,
                title: file.url.lastPathComponent,
                subtitle: file.relativePath,
                shortcut: nil,
                symbolName: "doc",
                perform: {
                    DocumentOpener.open(file.url)
                }
            )
        }
        return CommandPaletteModel(mode: .files, items: items)
    }
}
