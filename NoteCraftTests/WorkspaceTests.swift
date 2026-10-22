import AppKit
import NoteCraftKit
import Testing
@testable import NoteCraft

@MainActor
struct WorkspaceModelTests {
    private func makeFolder() throws -> URL {
        let folder = try TestSupport.makeTemporaryFolder()
        let manager = FileManager.default
        try manager.createDirectory(at: folder.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try manager.createDirectory(at: folder.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try "let a = 1\n".write(to: folder.appendingPathComponent("Sources/App.swift"), atomically: true, encoding: .utf8)
        try "# Readme\nneedle\n".write(to: folder.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "b".write(to: folder.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        try "hidden".write(to: folder.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        return folder
    }

    @Test func listsFoldersFirstAndSkipsIgnoredEntries() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let nodes = FileNode.children(of: folder)
        #expect(nodes.map(\.name) == ["Sources", "b.txt", "README.md"])
        #expect(nodes[0].isDirectory)
        #expect(nodes[0].children?.map(\.name) == ["App.swift"])
        #expect(nodes[0].children?.first?.children == nil)
        #expect(nodes[1] == FileNode(url: nodes[1].url, isDirectory: false))
        #expect(Set(nodes).count == 3)
    }

    @Test func opensReloadsFiltersAndClosesFolder() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let defaults = TestSupport.makeDefaults()
        let workspace = WorkspaceModel(defaults: defaults)
        workspace.openFolder(folder)
        #expect(workspace.folderURL == folder)
        #expect(workspace.rootNodes.count == 3)
        #expect(workspace.fileSearch.folderURL == folder)
        #expect(defaults.data(forKey: WorkspaceModel.bookmarkKey) != nil)
        #expect(workspace.allFiles.map(\.relativePath) == ["b.txt", "README.md", "Sources/App.swift"])

        workspace.filterText = "app"
        #expect(workspace.filteredFiles.map(\.relativePath) == ["Sources/App.swift"])

        try "c".write(to: folder.appendingPathComponent("c.txt"), atomically: true, encoding: .utf8)
        workspace.reload()
        #expect(workspace.rootNodes.count == 4)
        #expect(workspace.allFiles.count == 4)

        let restored = WorkspaceModel(defaults: defaults)
        restored.restore()
        #expect(restored.folderURL?.standardizedFileURL.path == folder.standardizedFileURL.path)

        workspace.closeFolder()
        #expect(workspace.folderURL == nil)
        #expect(workspace.rootNodes.isEmpty)
        #expect(workspace.allFiles.isEmpty)
        #expect(defaults.data(forKey: WorkspaceModel.bookmarkKey) == nil)
    }

    @Test func ignoresInvalidBookmarks() {
        let defaults = TestSupport.makeDefaults()
        defaults.set(Data([1, 2, 3]), forKey: WorkspaceModel.bookmarkKey)
        let workspace = WorkspaceModel(defaults: defaults)
        workspace.restore()
        #expect(workspace.folderURL == nil)
        #expect(defaults.data(forKey: WorkspaceModel.bookmarkKey) == nil)
        WorkspaceModel(defaults: TestSupport.makeDefaults()).restore()
    }

    @Test func searchesFilesInFolder() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = FileSearchModel()
        model.search()
        #expect(!model.hasSearched)
        model.folderURL = folder
        model.queryText = "needle"
        model.search()
        await model.waitUntilFinished()
        #expect(model.results.map(\.relativePath) == ["README.md"])
        #expect(model.totalMatches == 1)
        #expect(model.summary == L10n.FileSearch.summary(matches: 1, files: 1))
        #expect(!model.isSearching)

        model.filePatternText = "*.swift"
        model.search()
        await model.waitUntilFinished()
        #expect(model.results.isEmpty)
        #expect(model.summary == L10n.FileSearch.summary(matches: 0, files: 0))

        model.usesRegularExpression = true
        model.queryText = "("
        model.search()
        #expect(model.validationMessage == L10n.Find.invalidRegularExpression)

        model.clear()
        #expect(model.summary == nil)
        #expect(model.results.isEmpty)
        #expect(model.query.usesRegularExpression)
    }

    @Test func cancelsRunningSearch() throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = FileSearchModel()
        model.folderURL = folder
        model.queryText = "a"
        model.search()
        #expect(model.summary != nil)
        model.cancel()
        #expect(!model.isSearching)
    }
}

@MainActor
struct CommandPaletteTests {
    private func makeMenu() -> (NSMenu, ActionSink) {
        let sink = ActionSink()
        let menu = NSMenu(title: "Main")
        let fileItem = NSMenuItem(title: "Ablage", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "Ablage")
        let sort = NSMenuItem(title: "Aufsteigend sortieren", action: #selector(ActionSink.run(_:)), keyEquivalent: "s")
        sort.keyEquivalentModifierMask = [.command, .option, .control]
        sort.target = sink
        let duplicate = NSMenuItem(title: "Zeile duplizieren …", action: #selector(ActionSink.run(_:)), keyEquivalent: "D")
        duplicate.target = sink
        let disabled = NSMenuItem(title: "Deaktiviert", action: #selector(ActionSink.disabled(_:)), keyEquivalent: "")
        disabled.target = sink
        let hidden = NSMenuItem(title: "Versteckt", action: #selector(ActionSink.run(_:)), keyEquivalent: "")
        hidden.target = sink
        hidden.isHidden = true
        fileMenu.addItem(sort)
        fileMenu.addItem(.separator())
        fileMenu.addItem(duplicate)
        fileMenu.addItem(disabled)
        fileMenu.addItem(hidden)
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)
        return (menu, sink)
    }

    @Test func collectsEnabledCommandsWithPaths() {
        let (menu, sink) = makeMenu()
        defer { withExtendedLifetime(sink) {} }
        let commands = MenuCommandCatalog.commands(in: menu)
        #expect(commands.map(\.item.title) == ["Aufsteigend sortieren", "Zeile duplizieren …"])
        #expect(commands.first?.path == ["Ablage"])
    }

    @Test func formatsShortcuts() throws {
        let (menu, sink) = makeMenu()
        defer { withExtendedLifetime(sink) {} }
        let items = MenuCommandCatalog.commands(in: menu).map(\.item)
        try #require(items.count == 2)
        #expect(MenuCommandCatalog.shortcut(for: items[0]) == "⌃⌥⌘S")
        #expect(MenuCommandCatalog.shortcut(for: items[1]) == "⇧⌘D")
        let returnItem = NSMenuItem(title: "", action: nil, keyEquivalent: "\r")
        #expect(MenuCommandCatalog.shortcut(for: returnItem) == "⌘↩")
        #expect(MenuCommandCatalog.shortcut(for: NSMenuItem()) == nil)
    }

    @Test func ranksAndPerformsCommands() {
        let (menu, sink) = makeMenu()
        let model = CommandPaletteModel.commands(for: nil, mainMenu: menu)
        #expect(model.mode == .commands)
        #expect(model.placeholder == L10n.Palette.commandsPlaceholder)
        model.query = "dupl"
        #expect(model.results.first?.title == "Zeile duplizieren")
        #expect(model.results.first?.subtitle == "Ablage")
        model.selectedItem?.perform()
        #expect(sink.count == 1)
        model.query = ""
        model.moveSelection(by: 5)
        #expect(model.selectedIndex == model.results.count - 1)
        model.moveSelection(by: -10)
        #expect(model.selectedIndex == 0)
        model.query = "zzzz"
        model.moveSelection(by: 1)
        #expect(model.selectedItem == nil)
    }

    @Test func listsOpenDocumentsAndWorkspaceFiles() throws {
        let folder = try TestSupport.makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try "x".write(to: folder.appendingPathComponent("alpha.txt"), atomically: true, encoding: .utf8)
        let workspace = WorkspaceModel(defaults: TestSupport.makeDefaults())
        workspace.openFolder(folder, storesBookmark: false)
        let model = CommandPaletteModel.files(in: workspace)
        #expect(model.mode == .files)
        #expect(model.placeholder == L10n.Palette.filesPlaceholder)
        #expect(model.items.map(\.title) == ["alpha.txt"])
        model.query = "alp"
        #expect(model.results.count == 1)
    }

    @Test func rendersPaletteViewAndPanel() throws {
        let (menu, sink) = makeMenu()
        defer { withExtendedLifetime(sink) {} }
        let model = CommandPaletteModel.commands(for: nil, mainMenu: menu)
        TestSupport.render(CommandPaletteView(model: model, onPerform: { _ in }, onClose: {}))
        model.query = "nothing matches"
        TestSupport.render(CommandPaletteView(model: model, onPerform: { _ in }, onClose: {}))

        let fixture = try TestSupport.makeEditor("x")
        defer { fixture.close() }
        let window = try #require(fixture.windowController.window)
        let panel = CommandPalettePanel(model: CommandPaletteModel.commands(for: nil, mainMenu: menu))
        #expect(panel.canBecomeKey)
        panel.present(over: window)
        #expect(window.childWindows?.contains(panel) == true)
        panel.dismiss()
        #expect(window.childWindows?.contains(panel) != true)
    }
}

@MainActor
final class ActionSink: NSObject, NSMenuItemValidation {
    var count = 0

    @objc func run(_ sender: Any?) {
        count += 1
    }

    @objc func disabled(_ sender: Any?) {}

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.action != #selector(disabled(_:))
    }
}
