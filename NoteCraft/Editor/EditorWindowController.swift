import AppKit
import SwiftUI

extension Notification.Name {
    static let sidebarVisibilityDidChange = Notification.Name("NoteCraftSidebarVisibilityDidChange")
}

extension NSToolbarItem.Identifier {
    static let find = NSToolbarItem.Identifier("NoteCraftFind")
    static let commandPalette = NSToolbarItem.Identifier("NoteCraftCommandPalette")
    static let share = NSToolbarItem.Identifier("NoteCraftShare")
    static let preview = NSToolbarItem.Identifier("NoteCraftPreview")
    static let format = NSToolbarItem.Identifier("NoteCraftFormat")
    static let markdownItems: [NSToolbarItem.Identifier] = [.preview, .format]
}

final class EditorSplitViewController: NSSplitViewController {
    static let sidebarVisibilityKey = "ShowsSidebar"

    let sidebarItem: NSSplitViewItem
    let editorViewController: EditorViewController
    let workspace: WorkspaceModel
    private var observer: NSObjectProtocol?

    init(editor: EditorViewController, workspace: WorkspaceModel) {
        editorViewController = editor
        self.workspace = workspace
        let sidebarController = NSHostingController(rootView: SidebarView(workspace: workspace))
        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 420
        sidebarItem.canCollapse = true
        let storedVisibility = UserDefaults.standard.object(forKey: Self.sidebarVisibilityKey) as? Bool
        sidebarItem.isCollapsed = !(storedVisibility ?? (workspace.folderURL != nil))
        super.init(nibName: nil, bundle: nil)
        let contentItem = NSSplitViewItem(viewController: editor)
        contentItem.minimumThickness = 320
        addSplitViewItem(sidebarItem)
        addSplitViewItem(contentItem)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        observer = NotificationCenter.default.addObserver(forName: .sidebarVisibilityDidChange, object: nil, queue: .main) { [weak self] notification in
            let isVisible = notification.userInfo?["isVisible"] as? Bool
            let senderID = (notification.object as AnyObject?).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                guard let self, senderID != ObjectIdentifier(self), let isVisible else { return }
                self.sidebarItem.isCollapsed = !isVisible
            }
        }
    }

    isolated deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var isSidebarVisible: Bool {
        !sidebarItem.isCollapsed
    }

    override func toggleSidebar(_ sender: Any?) {
        let willBeVisible = sidebarItem.isCollapsed
        super.toggleSidebar(sender)
        publishSidebarVisibility(willBeVisible)
    }

    /// Shows the sidebar with the given section selected.
    func showSidebar(section: SidebarSection) {
        workspace.selectedSection = section
        if sidebarItem.isCollapsed {
            sidebarItem.animator().isCollapsed = false
            publishSidebarVisibility(true)
        }
    }

    private func publishSidebarVisibility(_ isVisible: Bool) {
        UserDefaults.standard.set(isVisible, forKey: Self.sidebarVisibilityKey)
        NotificationCenter.default.post(name: .sidebarVisibilityDidChange, object: self, userInfo: ["isVisible": isVisible])
    }
}

final class EditorWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSSharingServicePickerToolbarItemDelegate {
    static let tabbingIdentifier = "NoteCraftEditor"
    static let toolbarIdentifier = "NoteCraftEditorToolbar"
    static let markdownToolbarItemsKey = "AddedMarkdownToolbarItems"

    let editorViewController: EditorViewController
    let splitController: EditorSplitViewController
    private var palettePanel: CommandPalettePanel?

    init(
        document: TextDocument,
        workspace: WorkspaceModel = .shared,
        findPasteboard: FindPasteboard = FindPasteboard(),
        defaults: UserDefaults = .standard
    ) {
        editorViewController = EditorViewController(document: document, settingsStore: document.settingsStore, findPasteboard: findPasteboard)
        splitController = EditorSplitViewController(editor: editorViewController, workspace: workspace)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.identifier = NSUserInterfaceItemIdentifier("EditorWindow")
        window.minSize = NSSize(width: 480, height: 320)
        window.tabbingIdentifier = Self.tabbingIdentifier
        window.tabbingMode = document.settings.opensDocumentsInTabs ? .preferred : .automatic
        window.toolbarStyle = .unified
        window.titleVisibility = .visible
        super.init(window: window)
        window.contentViewController = splitController
        window.setContentSize(NSSize(width: 980, height: 700))
        window.delegate = self
        shouldCascadeWindows = true
        configureToolbar(defaults: defaults)
        updateSubtitle()
        editorViewController.onDocumentAttributesChange = { [weak self] in
            self?.updateMarkdownToolbarItems()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var textDocument: TextDocument? {
        document as? TextDocument
    }

    /// Shows the enclosing folder of the file below the window title.
    func updateSubtitle() {
        guard let url = textDocument?.fileURL else {
            window?.subtitle = ""
            return
        }
        window?.subtitle = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
    }

    /// Opens a new untitled document as a tab of this window, regardless of the system tab preference.
    override func newWindowForTab(_ sender: Any?) {
        guard let window,
              let document = try? NSDocumentController.shared.openUntitledDocumentAndDisplay(false) else { return }
        document.makeWindowControllers()
        guard let newWindow = document.windowControllers.first?.window else { return }
        window.addTabbedWindow(newWindow, ordered: .above)
        newWindow.makeKeyAndOrderFront(sender)
    }

    @objc func showFileSearch(_ sender: Any?) {
        splitController.showSidebar(section: .search)
        let fileSearch = splitController.workspace.fileSearch
        let selection = editorViewController.textView.selectedRange()
        if selection.length > 0, selection.length < 200 {
            fileSearch.queryText = editorViewController.textView.nsString.substring(with: selection)
        }
        fileSearch.focusRequest += 1
    }

    @objc func showCommandPalette(_ sender: Any?) {
        presentPalette(CommandPaletteModel.commands(for: self))
    }

    @objc func openQuickly(_ sender: Any?) {
        guard splitController.workspace.folderURL != nil else {
            let alert = NSAlert()
            alert.messageText = L10n.Palette.noFolderForQuickOpen
            alert.addButton(withTitle: L10n.Sidebar.openFolder)
            alert.addButton(withTitle: L10n.Alert.cancel)
            guard let window else { return }
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                MainActor.assumeIsolated {
                    self?.splitController.workspace.chooseFolder(for: self?.window)
                }
            }
            return
        }
        presentPalette(CommandPaletteModel.files(in: splitController.workspace))
    }

    @objc func openFolder(_ sender: Any?) {
        splitController.workspace.chooseFolder(for: window)
        splitController.showSidebar(section: .files)
    }

    private func presentPalette(_ model: CommandPaletteModel) {
        guard let window else { return }
        palettePanel?.close()
        let panel = CommandPalettePanel(model: model)
        palettePanel = panel
        panel.present(over: window)
    }

    private func configureToolbar(defaults: UserDefaults) {
        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        window?.toolbar = toolbar
        Self.addMarkdownItems(to: toolbar, defaults: defaults)
    }

    /// Adds the Markdown items once to toolbars whose configuration was saved before the items existed.
    static func addMarkdownItems(to toolbar: NSToolbar, defaults: UserDefaults) {
        guard !defaults.bool(forKey: markdownToolbarItemsKey) else { return }
        defaults.set(true, forKey: markdownToolbarItemsKey)
        let identifiers = toolbar.items.map(\.itemIdentifier)
        var index = identifiers.firstIndex(of: .commandPalette) ?? identifiers.count
        for identifier in NSToolbarItem.Identifier.markdownItems where !identifiers.contains(identifier) {
            toolbar.insertItem(withItemIdentifier: identifier, at: index)
            index += 1
        }
    }

    /// Shows the preview and format items only while the document is Markdown.
    func updateMarkdownToolbarItems() {
        let isHidden = !editorViewController.isMarkdownDocument
        for item in window?.toolbar?.items ?? [] where NSToolbarItem.Identifier.markdownItems.contains(item.itemIdentifier) {
            item.isHidden = isHidden
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, .preview, .format, .commandPalette, .find, .share]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, .space, .preview, .format, .commandPalette, .find, .share, .print]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .find:
            return makeItem(itemIdentifier, label: L10n.Accessibility.toolbarFind, symbol: "magnifyingglass", action: #selector(EditorViewController.showFindBar(_:)))
        case .commandPalette:
            return makeItem(itemIdentifier, label: L10n.Accessibility.toolbarPalette, symbol: "command", action: #selector(showCommandPalette(_:)))
        case .share:
            let item = NSSharingServicePickerToolbarItem(itemIdentifier: itemIdentifier)
            item.label = L10n.Accessibility.toolbarShare
            item.delegate = self
            return item
        case .preview:
            let item = makeItem(itemIdentifier, label: L10n.Accessibility.preview, symbol: "eye", action: #selector(EditorViewController.togglePreview(_:)))
            item.isHidden = !editorViewController.isMarkdownDocument
            return item
        case .format:
            let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
            item.label = L10n.Menu.format
            item.paletteLabel = L10n.Menu.format
            item.toolTip = L10n.Menu.format
            item.image = NSImage(systemSymbolName: "textformat", accessibilityDescription: L10n.Menu.format)
            item.menu = MainMenuBuilder(appDelegate: nil).makeFormatMenu(includesShortcuts: false)
            item.showsIndicator = true
            item.isHidden = !editorViewController.isMarkdownDocument
            return item
        default:
            return nil
        }
    }

    private func makeItem(_ identifier: NSToolbarItem.Identifier, label: String, symbol: String, action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.action = action
        item.isBordered = true
        return item
    }

    func items(for pickerToolbarItem: NSSharingServicePickerToolbarItem) -> [Any] {
        if let url = textDocument?.fileURL {
            return [url]
        }
        return [editorViewController.textView.string]
    }
}
