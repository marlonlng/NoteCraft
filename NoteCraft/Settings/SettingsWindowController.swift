import AppKit
import SwiftUI

final class SettingsTabViewController: NSTabViewController {
    var onSelectionChange: ((Int) -> Void)?

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        onSelectionChange?(selectedTabViewItemIndex)
    }
}

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController(store: .shared)
    static let selectedPaneKey = "SettingsSelectedPane"

    let tabViewController = SettingsTabViewController()

    init(store: SettingsStore, defaults: UserDefaults = .standard) {
        tabViewController.tabStyle = .toolbar
        tabViewController.canPropagateSelectedChildViewControllerTitle = true
        let panes: [(String, String, NSViewController)] = [
            (L10n.Settings.general, "gearshape", Self.host(GeneralSettingsView(store: store))),
            (L10n.Settings.editor, "character.cursor.ibeam", Self.host(EditorSettingsView(store: store))),
            (L10n.Settings.themes, "paintpalette", Self.host(ThemeSettingsView(store: store))),
            (L10n.Settings.files, "doc.text", Self.host(FilesSettingsView(store: store))),
            (L10n.Settings.markdown, "doc.richtext", Self.host(MarkdownSettingsView(store: store)))
        ]
        for (title, symbol, controller) in panes {
            controller.title = title
            let item = NSTabViewItem(viewController: controller)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabViewController.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabViewController)
        window.styleMask = [.titled, .closable]
        window.identifier = NSUserInterfaceItemIdentifier("SettingsWindow")
        window.isRestorable = false
        super.init(window: window)
        let storedIndex = defaults.integer(forKey: Self.selectedPaneKey)
        tabViewController.selectedTabViewItemIndex = min(max(storedIndex, 0), panes.count - 1)
        tabViewController.onSelectionChange = { index in
            defaults.set(index, forKey: Self.selectedPaneKey)
        }
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private static func host<Content: View>(_ view: Content) -> NSViewController {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = [.preferredContentSize]
        return controller
    }
}
