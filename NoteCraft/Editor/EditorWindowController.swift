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
    static let markdownTools = NSToolbarItem.Identifier("NoteCraftMarkdownTools")
    static let markdownMore = NSToolbarItem.Identifier("NoteCraftMarkdownMore")
    static let markdownToolItems: [NSToolbarItem.Identifier] = [.markdownTools, .markdownMore]
    static let markdownItems: [NSToolbarItem.Identifier] = markdownToolItems + [.preview]
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
        sidebarItem.isCollapsed = !Self.showsSidebar(in: .standard, hasFolder: workspace.folderURL != nil)
        super.init(nibName: nil, bundle: nil)
        let contentItem = NSSplitViewItem(viewController: editor)
        contentItem.minimumThickness = 320
        addSplitViewItem(sidebarItem)
        addSplitViewItem(contentItem)
    }

    /// Whether new windows show the sidebar: the stored choice, which a launch argument such as `-ShowsSidebar NO`
    /// gives as text, or else whether a folder is open.
    static func showsSidebar(in defaults: UserDefaults, hasFolder: Bool) -> Bool {
        defaults.object(forKey: sidebarVisibilityKey) == nil ? hasFolder : defaults.bool(forKey: sidebarVisibilityKey)
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
    static let markdownToolsKey = "AddedMarkdownToolCapsule"
    /// The size of new windows, wide enough for the Markdown tools next to the sidebar.
    static let defaultContentSize = NSSize(width: 1100, height: 700)

    let editorViewController: EditorViewController
    let splitController: EditorSplitViewController
    private var palettePanel: CommandPalettePanel?
    var markdownToolStates: [Bool] = []

    init(
        document: TextDocument,
        workspace: WorkspaceModel = .shared,
        findPasteboard: FindPasteboard = FindPasteboard(),
        defaults: UserDefaults = .standard
    ) {
        editorViewController = EditorViewController(document: document, settingsStore: document.settingsStore, findPasteboard: findPasteboard)
        splitController = EditorSplitViewController(editor: editorViewController, workspace: workspace)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
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
        window.setContentSize(Self.defaultContentSize)
        window.delegate = self
        shouldCascadeWindows = true
        configureToolbar(defaults: defaults)
        updateSubtitle()
        editorViewController.onDocumentAttributesChange = { [weak self] in
            self?.updateMarkdownToolbarItems()
        }
        editorViewController.onEditingStateChange = { [weak self] in
            self?.updateMarkdownToolStates()
        }
        updateMarkdownToolStates()
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
        toolbar.centeredItemIdentifiers = Set(NSToolbarItem.Identifier.markdownToolItems)
        window?.toolbar = toolbar
        Self.addMarkdownItems(to: toolbar, defaults: defaults)
    }

    /// Updates toolbars whose configuration was saved before the Markdown items existed, once per item set.
    ///
    /// The preview item goes in front of the command palette. The Markdown tools replace the former format menu
    /// and sit with the remaining formats between two flexible spaces after the sidebar items; where the toolbar
    /// already has the remaining formats, the tools go right in front of them.
    static func addMarkdownItems(to toolbar: NSToolbar, defaults: UserDefaults) {
        if !defaults.bool(forKey: markdownToolbarItemsKey) {
            defaults.set(true, forKey: markdownToolbarItemsKey)
            let identifiers = toolbar.items.map(\.itemIdentifier)
            if !identifiers.contains(.preview) {
                toolbar.insertItem(withItemIdentifier: .preview, at: identifiers.firstIndex(of: .commandPalette) ?? identifiers.count)
            }
        }
        guard !defaults.bool(forKey: markdownToolsKey) else { return }
        defaults.set(true, forKey: markdownToolsKey)
        if let index = toolbar.items.firstIndex(where: { $0.itemIdentifier == .format }) {
            toolbar.removeItem(at: index)
        }
        let identifiers = toolbar.items.map(\.itemIdentifier)
        guard !identifiers.contains(.markdownTools) else { return }
        if let index = identifiers.firstIndex(of: .markdownMore) {
            toolbar.insertItem(withItemIdentifier: .markdownTools, at: index)
            return
        }
        let index = (identifiers.firstIndex(of: .flexibleSpace) ?? identifiers.firstIndex(of: .sidebarTrackingSeparator) ?? -1) + 1
        for (offset, identifier) in (NSToolbarItem.Identifier.markdownToolItems + [.flexibleSpace]).enumerated() {
            toolbar.insertItem(withItemIdentifier: identifier, at: index + offset)
        }
    }

    /// Shows the Markdown tools and the preview item only while the document is Markdown.
    func updateMarkdownToolbarItems() {
        let isHidden = !editorViewController.isMarkdownDocument
        for item in window?.toolbar?.items ?? [] where NSToolbarItem.Identifier.markdownItems.contains(item.itemIdentifier) {
            item.isHidden = isHidden
        }
        updateMarkdownToolStates()
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace]
            + NSToolbarItem.Identifier.markdownToolItems
            + [.flexibleSpace, .preview, .commandPalette, .find, .share]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace, .space]
            + NSToolbarItem.Identifier.markdownToolItems
            + [.preview, .commandPalette, .find, .share, .print]
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
            item.visibilityPriority = Self.visibilityPriority(of: itemIdentifier)
            return item
        case .preview:
            let item = makeItem(itemIdentifier, label: L10n.Accessibility.preview, symbol: "eye", action: #selector(EditorViewController.togglePreview(_:)))
            item.isHidden = !editorViewController.isMarkdownDocument
            return item
        default:
            guard let item = makeMarkdownTool(itemIdentifier) else { return nil }
            item.isHidden = !editorViewController.isMarkdownDocument
            item.visibilityPriority = Self.visibilityPriority(of: itemIdentifier)
            if let group = item as? NSToolbarItemGroup {
                applyMarkdownToolStates(to: group)
            }
            return item
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
        item.visibilityPriority = Self.visibilityPriority(of: identifier)
        return item
    }

    /// Which items stay visible in narrow windows: the preview and the general commands before the Markdown tools,
    /// and the remaining formats go to the overflow menu first.
    static func visibilityPriority(of identifier: NSToolbarItem.Identifier) -> NSToolbarItem.VisibilityPriority {
        switch identifier {
        case .preview, .commandPalette, .find, .share: .high
        case .markdownMore: .low
        default: .standard
        }
    }

    func items(for pickerToolbarItem: NSSharingServicePickerToolbarItem) -> [Any] {
        if let url = textDocument?.fileURL {
            return [url]
        }
        return [editorViewController.textView.string]
    }
}
