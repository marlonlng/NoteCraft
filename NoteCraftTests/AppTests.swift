import AppKit
import NoteCraftKit
import SwiftUI
import Testing
@testable import NoteCraft

@MainActor
struct MainMenuBuilderTests {
    private let menu = MainMenuBuilder(appDelegate: nil).build(for: NSApplication.shared)

    private func submenu(_ title: String, in menu: NSMenu? = nil) -> NSMenu? {
        (menu ?? self.menu).items.first { $0.title == title }?.submenu
    }

    @Test func followsStandardMenuOrder() {
        #expect(menu.items.map(\.title) == ["NoteCraft", "Ablage", "Bearbeiten", "Text", "Darstellung", "Fenster", "Hilfe"])
        #expect(submenu("Fenster")?.items.first?.action == #selector(NSWindow.performMiniaturize(_:)))
        #expect(submenu("Hilfe")?.items.first?.keyEquivalent == "?")
    }

    @Test func keepsStandardShortcuts() {
        func shortcut(_ action: Selector) -> (String, NSEvent.ModifierFlags)? {
            var stack = [menu]
            while let current = stack.popLast() {
                for item in current.items {
                    if let submenu = item.submenu {
                        stack.append(submenu)
                    } else if item.action == action, !item.isAlternate {
                        return (item.keyEquivalent, item.keyEquivalentModifierMask)
                    }
                }
            }
            return nil
        }
        #expect(shortcut(#selector(NSDocument.save(_:)))?.0 == "s")
        #expect(shortcut(#selector(NSDocument.runPageLayout(_:)))?.1 == [.command, .shift])
        #expect(shortcut(#selector(EditorWindowController.showCommandPalette(_:)))?.0 == "a")
        #expect(shortcut(#selector(EditorViewController.goToLine(_:)))?.0 == "l")
        #expect(shortcut(#selector(NSSplitViewController.toggleSidebar(_:)))?.1 == [.command, .control])
    }

    @Test func listsAllEncodingsAndLanguages() throws {
        let file = try #require(submenu("Ablage"))
        let encoding = try #require(submenu(L10n.Menu.encoding, in: file))
        let convert = try #require(submenu(L10n.Menu.convertToEncoding, in: encoding))
        #expect(convert.items.filter { !$0.isSeparatorItem }.count == TextEncoding.allCases.count)
        let text = try #require(submenu("Text"))
        let language = try #require(submenu(L10n.Menu.language, in: text))
        #expect(language.items.filter { !$0.isSeparatorItem }.count == LanguageCatalog.all.count + 1)
    }

    @Test func usesValidTransformationIdentifiers() throws {
        let text = try #require(submenu("Text"))
        var identifiers: [String] = []
        for item in text.items {
            for child in item.submenu?.items ?? [] where child.action == #selector(EditorTextView.performTextTransformation(_:)) {
                identifiers.append(child.representedObject as? String ?? "")
            }
        }
        #expect(Set(identifiers) == Set(TextTransformation.allCases.map(\.rawValue)))
    }

    @Test func usesEllipsisOnlyForCommandsNeedingInput() {
        var titles: [String] = []
        var stack = [menu]
        while let current = stack.popLast() {
            for item in current.items {
                if let submenu = item.submenu {
                    stack.append(submenu)
                } else {
                    titles.append(item.title)
                }
            }
        }
        #expect(titles.contains("Öffnen …"))
        #expect(titles.contains("Gehe zu Zeile …"))
        #expect(!titles.contains { $0.hasSuffix("...") })
    }
}

@MainActor
struct DisplayNameTests {
    @Test func namesEveryEncodingInGerman() {
        for encoding in TextEncoding.allCases {
            #expect(!encoding.displayName.isEmpty)
            #expect(!encoding.shortName.isEmpty)
        }
        #expect(TextEncoding.menuGroups.flatMap { $0 }.count == TextEncoding.allCases.count)
        #expect(TextEncoding.windows1252.displayName == "Westeuropäisch (Windows-1252)")
    }

    @Test func namesLineEndingsLanguagesAndThemes() {
        #expect(LineEnding.crlf.displayName == "CRLF – Windows")
        #expect(LineEnding.cr.shortName == "CR")
        #expect(Language.plainText.displayName == "Normaler Text")
        #expect(LanguageCatalog.swift.displayName == "Swift")
        #expect(Set(Theme.all.map(\.displayName)).count == Theme.all.count)
        #expect(Theme(id: "custom", isDark: false, background: "#FFFFFF", text: "#000000", selection: "#CCCCCC", currentLine: "#EEEEEE", lineNumber: "#777777", currentLineNumber: "#000000", invisibles: "#CCCCCC", matchHighlight: "#FFFF00", tokens: [:]).displayName == "custom")
    }

    @Test func describesErrorsInGerman() {
        let lossy = TextEncodingError.unrepresentableCharacter(character: "€", line: 2, column: 5, encoding: .isoLatin1)
        #expect(lossy.errorDescription == "Das Zeichen „€“ in Zeile 2, Spalte 5 kann in der Kodierung ISO 8859-1 nicht gesichert werden.")
        #expect(lossy.recoverySuggestion == L10n.Alert.unrepresentableRecovery)
        #expect(TextEncodingError.unrepresentableCharacter(character: nil, line: 1, column: 1, encoding: .macRoman).errorDescription?.contains("Mac OS Roman") == true)
        #expect(TextEncodingError.undecodable(encoding: .utf8).errorDescription == L10n.Alert.undecodable(encoding: "UTF-8"))
        #expect(TextEncodingError.undecodable(encoding: .utf8).recoverySuggestion == L10n.Alert.undecodableRecovery)
        #expect(TextEncodingError.binaryContent.errorDescription == L10n.Alert.binaryFileTitle)
        #expect(TextEncodingError.binaryContent.recoverySuggestion == L10n.Alert.binaryFileMessage)
        #expect(TextTransformationError.invalidBase64.errorDescription == L10n.Alert.invalidBase64)
        #expect(TextTransformationError.invalidPercentEncoding.errorDescription == L10n.Alert.invalidPercentEncoding)
        #expect(TextTransformationError.invalidJSON(line: 3, column: 4).errorDescription == "Ungültiges JSON in Zeile 3, Spalte 4.")
        #expect(SearchQueryError.emptyQuery.errorDescription == nil)
        #expect(SearchQueryError.invalidRegularExpression(pattern: "(").errorDescription == L10n.Find.invalidRegularExpression)
    }

    @Test func formatsPluralsInGerman() {
        #expect(L10n.Find.matchStatus(current: nil, total: 1) == "1 Treffer")
        #expect(L10n.Find.matchStatus(current: 2, total: 5) == "2 von 5")
        #expect(L10n.Find.replacedStatus(1) == "1 Treffer ersetzt")
        #expect(L10n.FileSearch.summary(matches: 1, files: 1) == "1 Treffer in 1 Datei")
        #expect(L10n.FileSearch.summary(matches: 4, files: 2) == "4 Treffer in 2 Dateien")
        #expect(L10n.StatusBar.indentation(Indentation(usesTabs: true, width: 4)) == "Tabulatoren: 4")
        #expect(L10n.Settings.megabytes(5) == "5 MB")
        #expect(L10n.Settings.points(13) == "13 pt")
        #expect(L10n.GoToLine.hint(lineCount: 3) == "Das Dokument hat 3 Zeilen.")
        #expect(L10n.FileSearch.lineLabel(7) == "Zeile 7")
        #expect(L10n.Transformation.title(for: .camelCase) == "camelCase")
    }
}

@MainActor
struct SupportTests {
    @Test func persistsSettingsAndPostsNotifications() async throws {
        let defaults = TestSupport.makeDefaults()
        let store = SettingsStore(defaults: defaults)
        #expect(defaults.bool(forKey: SettingsStore.quitAlwaysKeepsWindowsKey))
        var notified = 0
        let observer = NotificationCenter.default.addObserver(forName: .editorSettingsDidChange, object: store, queue: nil) { _ in
            notified += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        store.update(\.fontSize, to: 99)
        store.update(\.restoresSession, to: false)
        store.update(\.restoresSession, to: false)
        #expect(store.settings.fontSize == EditorSettings.fontSizeRange.upperBound)
        #expect(notified == 2)
        #expect(!defaults.bool(forKey: SettingsStore.quitAlwaysKeepsWindowsKey))
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.settings == store.settings)
    }

    @Test func convertsColorsAndFonts() {
        let color = HexColor(red: 1, green: 0, blue: 0).nsColor.usingColorSpace(.sRGB)
        #expect(color?.redComponent == 1)
        _ = HexColor(red: 0, green: 0, blue: 1).color
        var settings = EditorSettings()
        #expect(settings.editorFont().isFixedPitch)
        settings.fontName = "Menlo"
        #expect(settings.editorFont(scale: 2).pointSize == 26)
        settings.fontName = "Font That Does Not Exist"
        #expect(settings.editorFont().isFixedPitch)
        let dark = NSAppearance(named: .darkAqua)!
        #expect(dark.isDark)
        #expect(!NSAppearance(named: .aqua)!.isDark)
        #expect(settings.resolvedTheme(for: dark, increasesContrast: false) == .graphite)
        #expect(settings.resolvedTheme(for: dark, increasesContrast: true) == .highContrastDark)
        #expect(settings.resolvedTheme(for: NSAppearance(named: .aqua)!, increasesContrast: true) == .highContrastLight)
        #expect(MonospacedFonts.familyNames.contains("Menlo"))
    }

    @Test func readsAndWritesFindPasteboard() {
        let pasteboard = FindPasteboard(pasteboard: TestSupport.makePasteboard())
        #expect(pasteboard.string == nil)
        pasteboard.string = "needle"
        #expect(pasteboard.string == "needle")
        pasteboard.string = nil
        #expect(pasteboard.string == nil)
    }

    @Test func holdsWeakReferences() {
        var object: NSObject? = NSObject()
        let reference = WeakReference(object!)
        #expect(reference.object != nil)
        object = nil
        #expect(reference.object == nil)
    }
}

@MainActor
struct WindowTests {
    @Test func configuresToolbarAndSubtitle() throws {
        let fixture = try TestSupport.makeEditor("x")
        defer { fixture.close() }
        let controller = fixture.windowController
        let toolbar = try #require(controller.window?.toolbar)
        #expect(controller.toolbarDefaultItemIdentifiers(toolbar).contains(.find))
        #expect(controller.toolbarAllowedItemIdentifiers(toolbar).contains(.print))
        let find = controller.toolbar(toolbar, itemForItemIdentifier: .find, willBeInsertedIntoToolbar: true)
        #expect(find?.label == L10n.Accessibility.toolbarFind)
        let palette = controller.toolbar(toolbar, itemForItemIdentifier: .commandPalette, willBeInsertedIntoToolbar: true)
        #expect(palette?.action == #selector(EditorWindowController.showCommandPalette(_:)))
        let share = try #require(controller.toolbar(toolbar, itemForItemIdentifier: .share, willBeInsertedIntoToolbar: true) as? NSSharingServicePickerToolbarItem)
        #expect(controller.items(for: share).first as? String == "x")
        #expect(controller.toolbar(toolbar, itemForItemIdentifier: .space, willBeInsertedIntoToolbar: true) == nil)

        #expect(controller.window?.subtitle == "")
        fixture.document.fileURL = URL(fileURLWithPath: "/tmp/project/file.txt")
        #expect(controller.window?.subtitle == "/tmp/project")
        #expect((controller.items(for: share).first as? URL)?.lastPathComponent == "file.txt")
    }

    @Test func showsSidebarSectionsAndSyncsVisibility() throws {
        let first = try TestSupport.makeEditor("a")
        let second = try TestSupport.makeEditor("b")
        defer {
            first.close()
            second.close()
        }
        let split = first.windowController.splitController
        let wasVisible = split.isSidebarVisible
        split.showSidebar(section: .search)
        #expect(first.workspace.selectedSection == .search)
        #expect(split.isSidebarVisible)
        TestSupport.spinRunLoop()
        #expect(second.windowController.splitController.isSidebarVisible)
        split.toggleSidebar(nil)
        TestSupport.spinRunLoop(0.5)
        UserDefaults.standard.set(wasVisible, forKey: EditorSplitViewController.sidebarVisibilityKey)
    }

    @Test func prefillsFileSearchFromSelection() throws {
        let fixture = try TestSupport.makeEditor("needle in haystack")
        defer { fixture.close() }
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 6))
        fixture.windowController.showFileSearch(nil)
        #expect(fixture.workspace.fileSearch.queryText == "needle")
        #expect(fixture.workspace.fileSearch.focusRequest == 1)
        #expect(fixture.workspace.selectedSection == .search)
    }

    @Test func presentsPalettesOverWindow() throws {
        let fixture = try TestSupport.makeEditor("x")
        defer { fixture.close() }
        let window = try #require(fixture.windowController.window)
        window.orderFront(nil)
        fixture.windowController.showCommandPalette(nil)
        #expect(window.childWindows?.isEmpty == false)
        window.childWindows?.forEach { ($0 as? CommandPalettePanel)?.dismiss() }

        fixture.windowController.openQuickly(nil)
        TestSupport.spinRunLoop()
        window.attachedSheet.map { window.endSheet($0) }

        let folder = try TestSupport.makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        fixture.workspace.openFolder(folder, storesBookmark: false)
        fixture.windowController.openQuickly(nil)
        #expect(window.childWindows?.contains { $0 is CommandPalettePanel } == true)
        window.childWindows?.forEach { ($0 as? CommandPalettePanel)?.dismiss() }
    }

    @Test func createsSettingsWindowWithRememberedPane() {
        let defaults = TestSupport.makeDefaults()
        defaults.set(2, forKey: SettingsWindowController.selectedPaneKey)
        let settings = SettingsWindowController(store: TestSupport.makeSettingsStore(), defaults: defaults)
        #expect(settings.tabViewController.tabViewItems.map(\.label) == [L10n.Settings.general, L10n.Settings.editor, L10n.Settings.themes, L10n.Settings.files])
        #expect(settings.tabViewController.selectedTabViewItemIndex == 2)
        settings.tabViewController.selectedTabViewItemIndex = 1
        #expect(defaults.integer(forKey: SettingsWindowController.selectedPaneKey) == 1)
    }

    @Test func providesShareItemsAndAppActions() throws {
        let delegate = AppDelegate()
        #expect(delegate.isRunningTests)
        #expect(!delegate.applicationShouldOpenUntitledFile(NSApp))
        #expect(delegate.applicationSupportsSecureRestorableState(NSApp))
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Teilen", action: nil, keyEquivalent: ""))
        menu.items[0].identifier = MainMenuBuilder.shareItemIdentifier
        delegate.menuNeedsUpdate(menu)
        #expect(menu.items.first?.title == L10n.Menu.share)
        delegate.menuNeedsUpdate(NSMenu())
        _ = delegate.currentShareItems()
    }
}
