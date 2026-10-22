import AppKit
import NoteCraftKit
import Testing
@testable import NoteCraft

@MainActor
struct EditorViewControllerTests {
    @Test func buildsEditorAndRegistersWithDocument() throws {
        let fixture = try TestSupport.makeEditor("hello\nworld")
        defer { fixture.close() }
        #expect(fixture.document.editor === fixture.editor)
        #expect(fixture.editor.scrollView.verticalRulerView === fixture.editor.rulerView)
        #expect(fixture.editor.lineIndex.lineCount == 2)
        #expect(fixture.editor.statusBarModel.lineCount == 2)
        #expect(fixture.windowController.window?.tabbingIdentifier == EditorWindowController.tabbingIdentifier)
    }

    @Test func updatesLineIndexAndStatusWhileTyping() throws {
        let fixture = try TestSupport.makeEditor("a")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.insertText("\nbc", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(fixture.editor.lineIndex == LineIndex(text: fixture.text))
        #expect(fixture.editor.statusBarModel.position == TextPosition(line: 2, column: 3))
        textView.setSelectedRange(NSRange(location: 0, length: 3))
        #expect(fixture.editor.statusBarModel.selectedLength == 3)
        #expect(fixture.editor.statusBarModel.selectionText == L10n.StatusBar.selection(characters: 3, ranges: 1))
    }

    @Test func appliesSettingsChanges() throws {
        let store = TestSupport.makeSettingsStore()
        let fixture = try TestSupport.makeEditor("x", settingsStore: store)
        defer { fixture.close() }
        store.settings.showsLineNumbers = false
        store.settings.autoIndents = false
        store.settings.closesBrackets = false
        store.settings.showsInvisibleCharacters = true
        store.settings.fontSize = 20
        #expect(!fixture.editor.scrollView.rulersVisible)
        #expect(!fixture.textView.autoIndents)
        #expect(!fixture.textView.closesBrackets)
        #expect((fixture.textView.layoutManager as? EditorLayoutManager)?.drawsInvisibleCharacters == true)
        #expect((fixture.textView.typingAttributes[.font] as? NSFont)?.pointSize == 20)
    }

    @Test func togglesViewOptionsFromMenu() throws {
        let store = TestSupport.makeSettingsStore()
        let fixture = try TestSupport.makeEditor("x", settingsStore: store)
        defer { fixture.close() }
        let editor = fixture.editor
        editor.toggleLineNumbers(nil)
        editor.toggleInvisibleCharacters(nil)
        editor.toggleLineWrapping(nil)
        editor.toggleCurrentLineHighlight(nil)
        #expect(!store.settings.showsLineNumbers)
        #expect(store.settings.showsInvisibleCharacters)
        #expect(!store.settings.wrapsLines)
        #expect(!store.settings.highlightsCurrentLine)

        let lineNumbers = NSMenuItem(title: "", action: #selector(EditorViewController.toggleLineNumbers(_:)), keyEquivalent: "")
        #expect(editor.validateMenuItem(lineNumbers))
        #expect(lineNumbers.title == L10n.Menu.showLineNumbers)
        let invisibles = NSMenuItem(title: "", action: #selector(EditorViewController.toggleInvisibleCharacters(_:)), keyEquivalent: "")
        _ = editor.validateMenuItem(invisibles)
        #expect(invisibles.title == L10n.Menu.hideInvisibles)
        let wrapping = NSMenuItem(title: "", action: #selector(EditorViewController.toggleLineWrapping(_:)), keyEquivalent: "")
        _ = editor.validateMenuItem(wrapping)
        #expect(wrapping.state == .off)
        let highlight = NSMenuItem(title: "", action: #selector(EditorViewController.toggleCurrentLineHighlight(_:)), keyEquivalent: "")
        _ = editor.validateMenuItem(highlight)
        #expect(highlight.state == .off)

        let wasVisible = editor.showsStatusBar
        editor.toggleStatusBar(nil)
        let statusItem = NSMenuItem(title: "", action: #selector(EditorViewController.toggleStatusBar(_:)), keyEquivalent: "")
        _ = editor.validateMenuItem(statusItem)
        #expect(statusItem.title == (wasVisible ? L10n.Menu.showStatusBar : L10n.Menu.hideStatusBar))
        editor.showsStatusBar = wasVisible
    }

    @Test func zoomsInStepsAndResets() throws {
        let fixture = try TestSupport.makeEditor("x")
        defer { fixture.close() }
        let editor = fixture.editor
        let zoomIn = NSMenuItem(title: "", action: #selector(EditorViewController.zoomIn(_:)), keyEquivalent: "")
        let zoomOut = NSMenuItem(title: "", action: #selector(EditorViewController.zoomOut(_:)), keyEquivalent: "")
        let reset = NSMenuItem(title: "", action: #selector(EditorViewController.resetZoom(_:)), keyEquivalent: "")
        #expect(!editor.validateMenuItem(reset))
        editor.zoomIn(nil)
        #expect(editor.zoomScale == 1.1)
        #expect(editor.validateMenuItem(reset))
        for _ in 0..<20 { editor.zoomIn(nil) }
        #expect(editor.zoomScale == 3)
        #expect(!editor.validateMenuItem(zoomIn))
        editor.resetZoom(nil)
        #expect(editor.zoomScale == 1)
        for _ in 0..<20 { editor.zoomOut(nil) }
        #expect(editor.zoomScale == 0.5)
        #expect(!editor.validateMenuItem(zoomOut))
    }

    @Test func navigatesToLinesAndSelectsThem() throws {
        let fixture = try TestSupport.makeEditor("one\ntwo\nthree")
        defer { fixture.close() }
        let editor = fixture.editor
        editor.goTo(line: 3, column: 2)
        #expect(fixture.textView.selectedRange() == NSRange(location: 9, length: 0))
        editor.goTo(line: 99, column: 1)
        #expect(fixture.textView.selectedRange() == NSRange(location: 9, length: 0))
        editor.selectLine(2)
        #expect(fixture.textView.selectedRange() == NSRange(location: 4, length: 4))
        editor.select(NSRange(location: 50, length: 10))
        #expect(fixture.textView.selectedRange() == NSRange(location: 13, length: 0))
    }

    @Test func findsAndReplacesThroughMenuActions() throws {
        let fixture = try TestSupport.makeEditor("cat dog cat")
        defer { fixture.close() }
        let editor = fixture.editor
        let model = editor.findBarModel
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 3))
        editor.showFindBar(nil)
        #expect(model.isVisible)
        #expect(model.searchText == "cat")
        #expect(model.matches.count == 2)
        editor.findNextMatch(nil)
        #expect(fixture.textView.selectedRange() == NSRange(location: 8, length: 3))
        editor.findPreviousMatch(nil)
        #expect(fixture.textView.selectedRange() == NSRange(location: 0, length: 3))
        editor.showFindAndReplaceBar(nil)
        #expect(model.isReplaceVisible)
        model.replacementText = "cow"
        model.replace()
        #expect(fixture.text == "cow dog cat")
        model.replaceAll()
        #expect(fixture.text == "cow dog cow")
        #expect(model.statusMessage == L10n.Find.replacedStatus(1))

        fixture.textView.setSelectedRange(NSRange(location: 4, length: 3))
        editor.useSelectionForFind(nil)
        #expect(model.searchText == "dog")
        editor.useSelectionForReplace(nil)
        #expect(model.replacementText == "dog")

        let next = NSMenuItem(title: "", action: #selector(EditorViewController.findNextMatch(_:)), keyEquivalent: "")
        #expect(editor.validateMenuItem(next))
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 0))
        let useSelection = NSMenuItem(title: "", action: #selector(EditorViewController.useSelectionForFind(_:)), keyEquivalent: "")
        #expect(!editor.validateMenuItem(useSelection))
    }

    @Test func refreshesMatchesAfterEditing() async throws {
        let fixture = try TestSupport.makeEditor("a a")
        defer { fixture.close() }
        let model = fixture.editor.findBarModel
        model.show(replacing: false)
        model.searchText = "a"
        #expect(model.matches.count == 2)
        fixture.textView.setSelectedRange(NSRange(location: 3, length: 0))
        fixture.textView.insertText(" a", replacementRange: NSRange(location: NSNotFound, length: 0))
        try await Task.sleep(for: .milliseconds(400))
        #expect(model.matches.count == 3)
    }

    @Test func highlightsSyntaxInBackground() async throws {
        let fixture = try TestSupport.makeEditor("let value = 1", fileName: "main.swift")
        defer { fixture.close() }
        let controller = fixture.editor.highlightController!
        controller.schedule(after: .zero)
        await controller.waitUntilFinished()
        #expect(controller.appliedTokens.contains { $0.kind == .keyword })
        let color = fixture.textView.layoutManager?.temporaryAttribute(.foregroundColor, atCharacterIndex: 0, effectiveRange: nil) as? NSColor
        #expect(color != nil)

        fixture.document.setLanguage(.plainText)
        #expect(controller.appliedTokens.isEmpty)
        fixture.document.setLanguage(LanguageCatalog.swift)
        controller.isEnabled = false
        #expect(controller.appliedTokens.isEmpty)
    }

    @Test func preservesSelectionWhenDocumentReloads() throws {
        let fixture = try TestSupport.makeEditor("0123456789")
        defer { fixture.close() }
        fixture.textView.setSelectedRange(NSRange(location: 4, length: 2))
        try fixture.document.load(data: Data("0123".utf8), fileName: "notes.txt")
        #expect(fixture.textView.selectedRange() == NSRange(location: 4, length: 0))
        #expect(fixture.editor.lineIndex.length == 4)
    }

    @Test func replacesWholeTextForSaveTransformations() throws {
        let store = TestSupport.makeSettingsStore { $0.trimsTrailingWhitespaceOnSave = true }
        let fixture = try TestSupport.makeEditor("a  \nb", settingsStore: store)
        defer { fixture.close() }
        fixture.textView.setSelectedRange(NSRange(location: 5, length: 0))
        fixture.document.applySaveTransformations()
        #expect(fixture.text == "a\nb")
        #expect(fixture.textView.selectedRange().location <= 3)
    }

    @Test func forwardsStatusBarActionsToDocument() throws {
        let fixture = try TestSupport.makeEditor("a\n\tb\n\tc")
        defer { fixture.close() }
        let editor = fixture.editor
        editor.selectLanguage(LanguageCatalog.css)
        #expect(fixture.document.attributes.language.id == "css")
        editor.convert(to: .utf16BigEndian)
        #expect(fixture.document.attributes.encoding == .utf16BigEndian)
        editor.convert(to: .crlf)
        #expect(fixture.document.attributes.lineEnding == .crlf)
        editor.setIndentation(Indentation(usesTabs: false, width: 3))
        #expect(fixture.textView.indentation == Indentation(usesTabs: false, width: 3))
        editor.detectIndentation()
        #expect(fixture.document.attributes.indentation.usesTabs)
        fixture.textView.insertText("€", replacementRange: NSRange(location: 0, length: 0))
        editor.convert(to: .isoLatin1)
        #expect(fixture.document.attributes.encoding == .utf16BigEndian)
        editor.reopen(with: .utf8)
    }

    @Test func presentsSheetsForGoToLineAndStatistics() throws {
        let fixture = try TestSupport.makeEditor("one two\nthree")
        defer { fixture.close() }
        let editor = fixture.editor
        editor.goToLine(nil)
        #expect(editor.presentedViewControllers?.count == 1)
        editor.presentedViewControllers?.forEach { editor.dismiss($0) }
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 3))
        editor.showDocumentStatistics(nil)
        #expect(editor.presentedViewControllers?.count == 1)
        editor.presentedViewControllers?.forEach { editor.dismiss($0) }
    }

    @Test func reactsToAppearanceChanges() throws {
        let store = TestSupport.makeSettingsStore { $0.darkThemeID = Theme.midnight.id }
        let fixture = try TestSupport.makeEditor("x", settingsStore: store)
        defer { fixture.close() }
        fixture.editor.view.appearance = NSAppearance(named: .darkAqua)
        fixture.editor.applyAppearance()
        let expected = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? Theme.highContrastDark : Theme.midnight
        #expect(fixture.editor.theme == expected)
        fixture.editor.view.appearance = NSAppearance(named: .aqua)
        fixture.editor.applyAppearance()
        #expect(!fixture.editor.theme.isDark)
    }

    @Test func drawsRulerWithLineNumbers() throws {
        let fixture = try TestSupport.makeEditor("one\n\ntwo\n")
        defer { fixture.close() }
        let ruler = fixture.editor.rulerView!
        fixture.textView.layoutManager?.ensureLayout(for: fixture.textView.textContainer!)
        let numbers = ruler.visibleLineNumbers().map(\.number)
        #expect(numbers == [1, 2, 3, 4])
        let baselines = ruler.visibleLineNumbers().map(\.baseline)
        #expect(zip(baselines, baselines.dropFirst()).allSatisfy { $0 < $1 })
        #expect(TestSupport.draw(ruler) != nil)
        var selected: Int?
        ruler.onSelectLine = { selected = $0 }
        let window = try #require(fixture.windowController.window)
        let point = ruler.convert(NSPoint(x: 5, y: baselines[2] - 4), to: nil)
        let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        ruler.mouseDown(with: event)
        #expect(selected == 3)
    }

    @Test func drawsWholeWindow() throws {
        let fixture = try TestSupport.makeEditor("struct A {}\n", fileName: "a.swift")
        defer { fixture.close() }
        fixture.editor.findBarModel.show(replacing: true)
        fixture.document.attributes.externalChange = .modified
        fixture.document.attributes.hasMixedLineEndings = true
        let contentView = try #require(fixture.windowController.window?.contentView)
        #expect(TestSupport.draw(contentView) != nil)
    }
}
