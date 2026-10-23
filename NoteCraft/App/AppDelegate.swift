import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = SettingsStore.shared
        NSWindow.allowsAutomaticWindowTabbing = true
        NSApp.mainMenu = MainMenuBuilder(appDelegate: self).build()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !isRunningTests {
            WorkspaceModel.shared.restore()
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        !isRunningTests
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc func showAboutPanel(_ sender: Any?) {
        let credits = NSAttributedString(
            string: L10n.App.credits,
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc func showSettings(_ sender: Any?) {
        SettingsWindowController.shared.showWindow(sender)
        SettingsWindowController.shared.window?.makeKeyAndOrderFront(sender)
    }

    @objc func showHelp(_ sender: Any?) {
        HelpWindowController.shared.showWindow(sender)
    }

    @objc func showAcknowledgements(_ sender: Any?) {
        AcknowledgementsWindowController.shared.showWindow(sender)
    }

    @objc func openFolder(_ sender: Any?) {
        WorkspaceModel.shared.chooseFolder(for: nil)
        if NSDocumentController.shared.documents.isEmpty {
            NSDocumentController.shared.newDocument(sender)
        }
    }

    @objc func newWindowForTab(_ sender: Any?) {
        NSDocumentController.shared.newDocument(sender)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let index = menu.items.firstIndex(where: { $0.identifier == MainMenuBuilder.shareItemIdentifier }) else { return }
        let items = currentShareItems()
        let shareItem = NSSharingServicePicker(items: items).standardShareMenuItem
        shareItem.identifier = MainMenuBuilder.shareItemIdentifier
        shareItem.title = L10n.Menu.share
        menu.removeItem(at: index)
        menu.insertItem(shareItem, at: index)
    }

    /// The file or text of the frontmost document for sharing.
    func currentShareItems() -> [Any] {
        guard let document = NSDocumentController.shared.currentDocument as? TextDocument else { return [] }
        if let fileURL = document.fileURL {
            return [fileURL]
        }
        return [document.textStorage.string]
    }
}
