import AppKit
import NoteCraftKit
import Testing
@testable import NoteCraft

@MainActor
struct TextDocumentTests {
    @Test func loadsTextAndDetectsAttributes() throws {
        let document = TextDocument(settingsStore: TestSupport.makeSettingsStore())
        let data = "def main():\r\n    print('hi')\r\n".data(using: .windowsCP1252)!
        try document.load(data: data, fileName: "script.py")
        #expect(document.textStorage.string == "def main():\n    print('hi')\n")
        #expect(document.attributes.encoding == .utf8)
        #expect(document.attributes.lineEnding == .crlf)
        #expect(!document.attributes.hasMixedLineEndings)
        #expect(document.attributes.language.id == "python")
        #expect(document.attributes.indentation == Indentation(usesTabs: false, width: 4))
    }

    @Test func usesFallbackEncodingAndDetectsMixedLineEndings() throws {
        let store = TestSupport.makeSettingsStore { $0.fallbackEncoding = .isoLatin1 }
        let document = TextDocument(settingsStore: store)
        try document.load(data: "Größe\r\nä\nb".data(using: .isoLatin1)!, fileName: nil)
        #expect(document.attributes.encoding == .isoLatin1)
        #expect(document.attributes.hasMixedLineEndings)
        #expect(document.textStorage.string == "Größe\nä\nb")
    }

    @Test func usesDefaultsForNewDocuments() {
        let store = TestSupport.makeSettingsStore {
            $0.defaultEncoding = .utf16LittleEndian
            $0.defaultLineEnding = .cr
        }
        let document = TextDocument(settingsStore: store)
        #expect(document.attributes.encoding == .utf16LittleEndian)
        #expect(document.attributes.lineEnding == .cr)
        #expect(TextDocument.autosavesInPlace)
        #expect(!TextDocument.canConcurrentlyReadDocuments(ofType: "public.plain-text"))
    }

    @Test func marksLargeFilesAndKeepsDefaultIndentation() throws {
        let store = TestSupport.makeSettingsStore {
            $0.largeFileThreshold = 100_000
            $0.detectsIndentation = false
            $0.indentsWithTabs = true
        }
        let document = try TestSupport.makeDocument(String(repeating: "abc\n", count: 30_000), settingsStore: store)
        #expect(document.attributes.isLargeFile)
        #expect(document.attributes.indentation.usesTabs)
    }

    @Test func rejectsBinaryFiles() {
        let document = TextDocument(settingsStore: TestSupport.makeSettingsStore())
        #expect(throws: TextEncodingError.binaryContent) {
            try document.load(data: Data([0x00, 0x01, 0x02, 0x03]), fileName: "image.png")
        }
    }

    @Test func encodesWithLineEndingAndEncoding() throws {
        let document = try TestSupport.makeDocument("a\nb")
        document.convert(to: .crlf)
        try document.convert(to: .utf8WithBOM)
        #expect(try document.encodedContents() == Data([0xEF, 0xBB, 0xBF, 0x61, 0x0D, 0x0A, 0x62]))
        #expect(try document.data(ofType: "public.plain-text") == document.encodedContents())
    }

    @Test func refusesLossyEncodingConversion() throws {
        let document = try TestSupport.makeDocument("Preis: 5 €")
        #expect(throws: TextEncodingError.unrepresentableCharacter(character: "€", line: 1, column: 10, encoding: .isoLatin1)) {
            try document.convert(to: .isoLatin1)
        }
        #expect(document.attributes.encoding == .utf8)
    }

    @Test func undoesEncodingAndLineEndingChanges() throws {
        let document = try TestSupport.makeDocument("a\nb")
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        document.undoManager = undoManager

        undoManager.beginUndoGrouping()
        try document.convert(to: .utf16BigEndian)
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()
        document.convert(to: .cr)
        undoManager.endUndoGrouping()
        #expect(document.attributes.lineEnding == .cr)

        undoManager.undo()
        #expect(document.attributes.lineEnding == .lf)
        undoManager.undo()
        #expect(document.attributes.encoding == .utf8)
        undoManager.redo()
        #expect(document.attributes.encoding == .utf16BigEndian)
    }

    @Test func clearsMixedStateWhenConvertingToSameLineEnding() throws {
        let document = TextDocument(settingsStore: TestSupport.makeSettingsStore())
        try document.load(data: Data("a\nb\r\nc\n".utf8), fileName: nil)
        #expect(document.attributes.hasMixedLineEndings)
        document.convert(to: document.attributes.lineEnding)
        #expect(!document.attributes.hasMixedLineEndings)
    }

    @Test func overridesAndRestoresAutomaticLanguage() throws {
        let document = try TestSupport.makeDocument("{}", fileName: "data.json")
        #expect(document.attributes.language.id == "json")
        document.setLanguage(LanguageCatalog.yaml)
        #expect(document.attributes.language.id == "yaml")
        #expect(document.attributes.isLanguageOverridden)
        try document.load(data: Data("{}".utf8), fileName: "data.json")
        #expect(document.attributes.language.id == "yaml")
        document.setLanguage(nil)
        #expect(!document.attributes.isLanguageOverridden)
        #expect(document.attributes.language.id == "plaintext")
    }

    @Test func detectsAndSetsIndentation() throws {
        let document = try TestSupport.makeDocument("a\n\tb\n\tc\n")
        document.setIndentation(Indentation(usesTabs: false, width: 2))
        #expect(document.attributes.indentation == Indentation(usesTabs: false, width: 2))
        document.detectIndentation()
        #expect(document.attributes.indentation.usesTabs)
    }

    @Test func proposesFileNameExtensionFromLanguage() throws {
        let document = try TestSupport.makeDocument("", fileName: nil)
        #expect(document.fileNameExtension(forType: "public.plain-text", saveOperation: .saveAsOperation) == "txt")
        document.setLanguage(LanguageCatalog.swift)
        #expect(document.fileNameExtension(forType: "public.plain-text", saveOperation: .saveAsOperation) == "swift")
        document.fileURL = URL(fileURLWithPath: "/tmp/readme.md")
        #expect(document.fileNameExtension(forType: "public.plain-text", saveOperation: .saveAsOperation) == "md")
    }

    @Test func redetectsLanguageWhenFileURLChanges() throws {
        let document = try TestSupport.makeDocument("x", fileName: nil)
        document.fileURL = URL(fileURLWithPath: "/tmp/main.rs")
        #expect(document.attributes.language.id == "rust")
    }

    @Test func appliesSaveTransformationsToBuffer() throws {
        let store = TestSupport.makeSettingsStore {
            $0.trimsTrailingWhitespaceOnSave = true
            $0.ensuresTrailingNewlineOnSave = true
        }
        let document = try TestSupport.makeDocument("a  \nb", settingsStore: store)
        document.applySaveTransformations()
        #expect(document.textStorage.string == "a\nb\n")
        document.applySaveTransformations()
        #expect(document.textStorage.string == "a\nb\n")
    }

    @Test func savesAndReopensWithAnotherEncoding() async throws {
        let folder = try TestSupport.makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("latin.txt")
        try "Grüße".data(using: .isoLatin1)!.write(to: url)
        let store = TestSupport.makeSettingsStore { $0.fallbackEncoding = .macRoman }
        let document = TextDocument(settingsStore: store)
        try document.read(from: url, ofType: "public.plain-text")
        document.fileURL = url
        #expect(document.attributes.encoding == .macRoman)
        try document.reopen(with: .isoLatin1)
        #expect(document.textStorage.string == "Grüße")
        #expect(document.attributes.encoding == .isoLatin1)
        #expect(throws: TextEncodingError.undecodable(encoding: .utf8)) {
            try document.reopen(with: .utf8)
        }

        try await document.save(to: url, ofType: "public.plain-text", for: .saveOperation)
        #expect(try Data(contentsOf: url) == "Grüße".data(using: .isoLatin1))
    }

    @Test func readsDataWithoutFileName() throws {
        let document = TextDocument(settingsStore: TestSupport.makeSettingsStore())
        try document.read(from: Data("#!/bin/bash\necho hi".utf8), ofType: "public.plain-text")
        #expect(document.attributes.language.id == "shell")
    }

    @Test func handlesExternalChanges() throws {
        let folder = try TestSupport.makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("watched.txt")
        try "first".write(to: url, atomically: true, encoding: .utf8)
        let document = try TextDocument(contentsOf: url, ofType: "public.plain-text")
        #expect(document.textStorage.string == "first")

        document.handleExternalChange()
        #expect(document.attributes.externalChange == nil)

        try "second".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: url.path)
        document.handleExternalChange()
        #expect(document.textStorage.string == "second")
        #expect(document.attributes.externalChange == .reloaded)

        document.updateChangeCount(.changeDone)
        try "third".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(120)], ofItemAtPath: url.path)
        document.handleExternalChange()
        #expect(document.attributes.externalChange == .modified)
        document.keepCurrentVersion()
        #expect(document.attributes.externalChange == nil)
        #expect(document.textStorage.string == "second")

        document.attributes.externalChange = .modified
        document.reloadFromDisk()
        #expect(document.textStorage.string == "third")
        #expect(document.attributes.externalChange == nil)

        try FileManager.default.removeItem(at: url)
        document.handleExternalChange()
        #expect(document.attributes.externalChange == .deleted)
    }

    @Test func keepsModifiedStateWhenAutomaticReloadIsOff() throws {
        let folder = try TestSupport.makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("manual.txt")
        try "one".write(to: url, atomically: true, encoding: .utf8)
        let store = TestSupport.makeSettingsStore { $0.reloadsUnmodifiedDocuments = false }
        let document = TextDocument(settingsStore: store)
        try document.read(from: url, ofType: "public.plain-text")
        document.fileURL = url
        document.fileModificationDate = Date().addingTimeInterval(-60)
        document.handleExternalChange()
        #expect(document.attributes.externalChange == .modified)
        #expect(document.textStorage.string == "one")
    }

    @Test func createsPrintOperation() throws {
        let document = try TestSupport.makeDocument("line one\nline two")
        let operation = try document.printOperation(withSettings: [:])
        #expect((operation.view as? NSTextView)?.string == "line one\nline two")
        #expect(operation.showsPrintPanel)
    }

    @Test func preparesSavePanelWithAccessory() throws {
        let document = try TestSupport.makeDocument("x")
        let panel = NSSavePanel()
        #expect(document.prepareSavePanel(panel))
        #expect(panel.accessoryView != nil)
        #expect(panel.allowsOtherFileTypes)
        #expect(!document.shouldRunSavePanelWithAccessoryView)
    }

    @Test func proposesSaveNameWithLanguageExtension() throws {
        let document = try TestSupport.makeDocument("# Title", fileName: nil)
        document.setLanguage(LanguageCatalog.markdown)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Untitled.txt"
        #expect(document.prepareSavePanel(panel))
        #expect(panel.nameFieldStringValue == "Untitled.md")
        document.setLanguage(.plainText)
        panel.nameFieldStringValue = ""
        #expect(document.prepareSavePanel(panel))
        #expect(panel.nameFieldStringValue == "\(document.displayName!).txt")

        let saved = try TestSupport.makeDocument("x", fileName: "notes.txt")
        saved.fileURL = URL(fileURLWithPath: "/tmp/notes.txt")
        saved.setLanguage(LanguageCatalog.markdown)
        let savedPanel = NSSavePanel()
        savedPanel.nameFieldStringValue = "notes.txt"
        #expect(saved.prepareSavePanel(savedPanel))
        #expect(savedPanel.nameFieldStringValue == "notes.txt")
    }

    @Test func restoresLanguageAndSelectionFromState() throws {
        let document = try TestSupport.makeDocument("hello world", fileName: "a.txt")
        document.setLanguage(LanguageCatalog.markdown)
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        document.encodeRestorableState(with: archiver)
        archiver.encode(NSStringFromRange(NSRange(location: 6, length: 5)), forKey: TextDocument.selectionRestorationKey)
        archiver.finishEncoding()

        let restored = try TestSupport.makeDocument("hello world", fileName: "a.txt")
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        restored.restoreState(with: unarchiver)
        #expect(restored.attributes.language.id == "markdown")
        #expect(restored.pendingSelection == NSRange(location: 6, length: 5))
    }
}

@MainActor
struct TextDocumentActionTests {
    private func menuItem(_ action: Selector, represented: Any? = nil, tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
        item.representedObject = represented
        item.tag = tag
        return item
    }

    @Test func changesAttributesThroughMenuActions() throws {
        let document = try TestSupport.makeDocument("a\n\tb\n\tc")
        document.convertToEncoding(menuItem(#selector(TextDocument.convertToEncoding(_:)), represented: TextEncoding.utf16LittleEndian.rawValue))
        #expect(document.attributes.encoding == .utf16LittleEndian)
        document.changeLineEnding(menuItem(#selector(TextDocument.changeLineEnding(_:)), represented: LineEnding.crlf.rawValue))
        #expect(document.attributes.lineEnding == .crlf)
        document.changeLanguage(menuItem(#selector(TextDocument.changeLanguage(_:)), represented: "go"))
        #expect(document.attributes.language.id == "go")
        document.changeLanguage(menuItem(#selector(TextDocument.changeLanguage(_:)), represented: ""))
        #expect(!document.attributes.isLanguageOverridden)
        document.changeIndentationStyle(menuItem(#selector(TextDocument.changeIndentationStyle(_:)), tag: 0))
        #expect(!document.attributes.indentation.usesTabs)
        document.changeTabWidth(menuItem(#selector(TextDocument.changeTabWidth(_:)), tag: 8))
        #expect(document.attributes.indentation.width == 8)
        document.detectIndentationFromText(nil)
        #expect(document.attributes.indentation.usesTabs)
        document.convertToEncoding(nil)
        document.changeLineEnding(nil)
        document.changeTabWidth(nil)
    }

    @Test func reopensUneditedDocumentWithoutAsking() throws {
        let folder = try TestSupport.makeTemporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("plain.txt")
        try "Größe".data(using: .isoLatin1)!.write(to: url)
        let document = try TextDocument(contentsOf: url, ofType: "public.plain-text")
        document.reopenWithEncoding(menuItem(#selector(TextDocument.reopenWithEncoding(_:)), represented: TextEncoding.isoLatin1.rawValue))
        #expect(document.attributes.encoding == .isoLatin1)
        #expect(document.textStorage.string == "Größe")
    }

    @Test func validatesMenuItemsWithCheckmarks() throws {
        let document = try TestSupport.makeDocument("x", fileName: "x.swift")
        let encodingItem = menuItem(#selector(TextDocument.convertToEncoding(_:)), represented: TextEncoding.utf8.rawValue)
        #expect(document.validateMenuItem(encodingItem))
        #expect(encodingItem.state == .on)

        let reopenItem = menuItem(#selector(TextDocument.reopenWithEncoding(_:)), represented: TextEncoding.utf8.rawValue)
        #expect(!document.validateMenuItem(reopenItem))

        let lineEndingItem = menuItem(#selector(TextDocument.changeLineEnding(_:)), represented: LineEnding.lf.rawValue)
        #expect(document.validateMenuItem(lineEndingItem))
        #expect(lineEndingItem.state == .on)
        document.attributes.hasMixedLineEndings = true
        _ = document.validateMenuItem(lineEndingItem)
        #expect(lineEndingItem.state == .mixed)

        let automaticItem = menuItem(#selector(TextDocument.changeLanguage(_:)), represented: "")
        _ = document.validateMenuItem(automaticItem)
        #expect(automaticItem.state == .on)
        document.setLanguage(LanguageCatalog.swift)
        let swiftItem = menuItem(#selector(TextDocument.changeLanguage(_:)), represented: "swift")
        _ = document.validateMenuItem(swiftItem)
        #expect(swiftItem.state == .on)

        let tabsItem = menuItem(#selector(TextDocument.changeIndentationStyle(_:)), tag: 1)
        _ = document.validateMenuItem(tabsItem)
        #expect(tabsItem.state == .off)
        let widthItem = menuItem(#selector(TextDocument.changeTabWidth(_:)), tag: 4)
        _ = document.validateMenuItem(widthItem)
        #expect(widthItem.state == .on)

        #expect(!document.validateMenuItem(menuItem(#selector(TextDocument.revealInFinder(_:)))))
        document.fileURL = URL(fileURLWithPath: "/tmp/x.swift")
        #expect(document.validateMenuItem(menuItem(#selector(TextDocument.copyFilePath(_:)))))
    }

    @Test func copiesFilePath() throws {
        let document = try TestSupport.makeDocument("x")
        let pasteboard = TestSupport.makePasteboard()
        document.copyFilePath(to: pasteboard)
        #expect(pasteboard.string(forType: .string) == nil)
        document.fileURL = URL(fileURLWithPath: "/tmp/copied.txt")
        document.copyFilePath(to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "/tmp/copied.txt")
    }
}
