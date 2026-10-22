import AppKit
import SwiftUI

struct ShortcutEntry: Identifiable {
    let keys: String
    let title: String

    var id: String { keys + title }
}

struct HelpView: View {
    static let sections: [(title: String, entries: [ShortcutEntry])] = [
        (L10n.Help.documentsSection, [
            ShortcutEntry(keys: "⌘N", title: L10n.Menu.new),
            ShortcutEntry(keys: "⌘T", title: L10n.Menu.newTab),
            ShortcutEntry(keys: "⌘O", title: L10n.Menu.open),
            ShortcutEntry(keys: "⌥⌘O", title: L10n.Menu.openFolder),
            ShortcutEntry(keys: "⇧⌘O", title: L10n.Menu.openQuickly),
            ShortcutEntry(keys: "⌘S", title: L10n.Menu.save),
            ShortcutEntry(keys: "⇧⌘S", title: L10n.Menu.duplicate)
        ]),
        (L10n.Help.editingSection, [
            ShortcutEntry(keys: "⌘]", title: L10n.Menu.shiftRight),
            ShortcutEntry(keys: "⌘[", title: L10n.Menu.shiftLeft),
            ShortcutEntry(keys: "⌘/", title: L10n.Menu.toggleComment),
            ShortcutEntry(keys: "⌘D", title: L10n.Menu.duplicateLine),
            ShortcutEntry(keys: "⌥⌘[", title: L10n.Menu.moveLineUp),
            ShortcutEntry(keys: "⌥⌘]", title: L10n.Menu.moveLineDown),
            ShortcutEntry(keys: "⇧⌘K", title: L10n.Menu.deleteLine),
            ShortcutEntry(keys: "⌥⌘E", title: L10n.Menu.selectNextOccurrence),
            ShortcutEntry(keys: "⌃⌘G", title: L10n.Menu.selectAllOccurrences)
        ]),
        (L10n.Help.searchSection, [
            ShortcutEntry(keys: "⌘F", title: L10n.Menu.findEllipsis),
            ShortcutEntry(keys: "⌥⌘F", title: L10n.Menu.findAndReplace),
            ShortcutEntry(keys: "⌘G", title: L10n.Menu.findNext),
            ShortcutEntry(keys: "⇧⌘G", title: L10n.Menu.findPrevious),
            ShortcutEntry(keys: "⌘E", title: L10n.Menu.useSelectionForFind),
            ShortcutEntry(keys: "⇧⌘F", title: L10n.Menu.findInFiles),
            ShortcutEntry(keys: "⌘L", title: L10n.Menu.goToLine)
        ]),
        (L10n.Help.viewSection, [
            ShortcutEntry(keys: "⇧⌘A", title: L10n.Menu.commandPalette),
            ShortcutEntry(keys: "⌃⌘S", title: L10n.Menu.showSidebar),
            ShortcutEntry(keys: "⌘+", title: L10n.Menu.zoomIn),
            ShortcutEntry(keys: "⌘−", title: L10n.Menu.zoomOut),
            ShortcutEntry(keys: "⌘0", title: L10n.Menu.actualSize)
        ])
    ]

    static let tips = [L10n.Help.tipSession, L10n.Help.tipColumns, L10n.Help.tipEncoding, L10n.Help.tipVersions]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.Help.intro)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.Help.shortcutsTitle)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                ForEach(Self.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
                            ForEach(section.entries) { entry in
                                GridRow {
                                    Text(entry.keys)
                                        .font(.body.monospaced())
                                        .frame(minWidth: 56, alignment: .leading)
                                    Text(entry.title)
                                }
                            }
                        }
                    }
                }
                Text(L10n.Help.tipsTitle)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                ForEach(Self.tips, id: \.self) { tip in
                    Label(tip, systemImage: "lightbulb")
                        .fixedSize(horizontal: false, vertical: true)
                }
                RegexCheatSheetView()
                    .padding(-16)
            }
            .padding(24)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 480, idealHeight: 640)
    }
}

final class HelpWindowController: NSWindowController {
    static let shared = HelpWindowController()

    init() {
        let controller = NSHostingController(rootView: HelpView())
        let window = NSWindow(contentViewController: controller)
        window.title = L10n.Help.title
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 560, height: 640))
        window.identifier = NSUserInterfaceItemIdentifier("HelpWindow")
        window.isRestorable = false
        super.init(window: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
