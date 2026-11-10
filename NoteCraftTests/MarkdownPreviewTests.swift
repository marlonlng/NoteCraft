import AppKit
import NoteCraftKit
import SwiftUI
import Testing
import WebKit
@testable import NoteCraft

@MainActor
struct MarkdownPreviewTests {
    private func makeMarkdownEditor(_ text: String, configure: (inout EditorSettings) -> Void = { _ in }) throws -> EditorFixture {
        let fixture = try TestSupport.makeEditor(text, fileName: "notes.md", settingsStore: TestSupport.makeSettingsStore(configure))
        fixture.editor.externalContentStore = ExternalContentStore(defaults: TestSupport.makeDefaults())
        return fixture
    }

    @Test func opensPreviewForMarkdownAsConfigured() throws {
        let fixture = try makeMarkdownEditor("# Title")
        defer { fixture.close() }
        #expect(fixture.editor.isPreviewVisible)
        #expect(fixture.textView.isMarkdown)
        #expect(fixture.editor.previewController?.webView.accessibilityLabel() == L10n.Accessibility.preview)
        let plain = try TestSupport.makeEditor("# Title")
        defer { plain.close() }
        #expect(!plain.editor.isPreviewVisible)
        #expect(!plain.textView.isMarkdown)
        let off = try makeMarkdownEditor("x") { $0.opensMarkdownPreview = false }
        defer { off.close() }
        #expect(!off.editor.isPreviewVisible)
    }

    @Test func togglesPreviewAndClosesItForOtherLanguages() throws {
        let fixture = try makeMarkdownEditor("text")
        defer { fixture.close() }
        let editor = fixture.editor
        let item = NSMenuItem(title: "", action: #selector(EditorViewController.togglePreview(_:)), keyEquivalent: "")
        #expect(editor.validateMenuItem(item))
        #expect(item.title == L10n.Menu.hidePreview)
        editor.togglePreview(nil)
        #expect(!editor.isPreviewVisible)
        #expect(editor.validateMenuItem(item))
        #expect(item.title == L10n.Menu.showPreview)
        editor.togglePreview(nil)
        #expect(editor.isPreviewVisible)
        fixture.document.setLanguage(LanguageCatalog.swift)
        #expect(!editor.isPreviewVisible)
        #expect(!editor.validateMenuItem(item))
        editor.togglePreview(nil)
        #expect(!editor.isPreviewVisible)
        fixture.document.setLanguage(LanguageCatalog.markdown)
        #expect(editor.isPreviewVisible)
    }

    @Test func keepsShareOfEditorAndPreview() throws {
        let fixture = try makeMarkdownEditor("text")
        defer { fixture.close() }
        let window = try #require(fixture.windowController.window)
        window.layoutIfNeeded()
        let split = try #require(fixture.editor.contentSplitView)
        #expect(split.subviews.count == 2)
        #expect(abs(split.subviews[0].frame.width - split.subviews[1].frame.width) < 3)
        split.setPosition(split.bounds.width * 0.3, ofDividerAt: 0)
        window.setFrame(NSRect(x: 0, y: 0, width: 1300, height: 600), display: false)
        window.layoutIfNeeded()
        #expect(abs(split.subviews[0].frame.width / split.bounds.width - 0.3) < 0.02)
        fixture.editor.setPreviewVisible(false)
        #expect(split.subviews.count == 1)
        #expect(abs(split.subviews[0].frame.width - split.bounds.width) < 1)
    }

    @Test func rendersTextAndUpdatesWhileTyping() async throws {
        let fixture = try makeMarkdownEditor("# Title\n\nBody")
        defer { fixture.close() }
        let preview = try #require(fixture.editor.previewController)
        #expect(await TestSupport.wait { preview.isLoaded })
        #expect(await TestSupport.evaluate("document.querySelector('h1').textContent", in: preview.webView) as? String == "Title")
        fixture.textView.setSelectedRange(NSRange(location: (fixture.text as NSString).length, length: 0))
        fixture.textView.insertText(" more", replacementRange: NSRange(location: NSNotFound, length: 0))
        try await Task.sleep(for: .milliseconds(400))
        #expect(await TestSupport.evaluate("document.querySelector('p').textContent", in: preview.webView) as? String == "Body more")
        fixture.document.settingsStore.settings.lightThemeID = Theme.sage.id
        #expect(preview.content?.styleSheet.theme.id == fixture.editor.theme.id)
    }

    @Test func showsLocalImagesThroughResourceHandler() async throws {
        let folder = try TestSupport.makeTemporaryFolder()
        try TestSupport.makePNG(width: 3, height: 2).write(to: folder.appendingPathComponent("dot.png"))
        let fixture = try makeMarkdownEditor("![Dot](dot.png)")
        defer { fixture.close() }
        fixture.document.fileURL = folder.appendingPathComponent("notes.md")
        #expect(fixture.textView.documentFolderURL?.standardizedFileURL == folder.standardizedFileURL)
        fixture.editor.refreshPreview()
        let preview = try #require(fixture.editor.previewController)
        #expect(preview.state.inaccessibleFolder == nil)
        #expect(await TestSupport.wait { preview.isLoaded })
        var width = 0
        for _ in 0..<50 where width == 0 {
            width = (await TestSupport.evaluate("document.querySelector('img') ? document.querySelector('img').naturalWidth : 0", in: preview.webView) as? NSNumber)?.intValue ?? 0
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(width == 3)
    }

    @Test func blocksExternalImagesUntilAllowed() async throws {
        let fixture = try makeMarkdownEditor("![Logo](https://notecraft.invalid/logo.png)")
        defer { fixture.close() }
        fixture.editor.refreshPreview()
        let preview = try #require(fixture.editor.previewController)
        #expect(preview.state.blockedImageCount == 1)
        #expect(!fixture.editor.allowsExternalContent)
        fixture.editor.previewDidRequestExternalContent(preview)
        #expect(fixture.document.attributes.allowsExternalContent)
        #expect(preview.state.blockedImageCount == 0)
        #expect(preview.content?.allowsExternalImages == true)
        #expect(await TestSupport.wait { preview.isLoaded })
        #expect(await TestSupport.evaluate("document.querySelector('meta[http-equiv]').content.includes('https:')", in: preview.webView) as? Bool == true)
    }

    @Test func remembersExternalContentPerFile() throws {
        let folder = try TestSupport.makeTemporaryFolder()
        let fixture = try makeMarkdownEditor("![Logo](https://notecraft.invalid/logo.png)")
        defer { fixture.close() }
        fixture.document.fileURL = folder.appendingPathComponent("saved.md")
        let preview = try #require(fixture.editor.previewController)
        fixture.editor.previewDidRequestExternalContent(preview)
        #expect(fixture.editor.externalContentStore.isAllowed(for: fixture.document.fileURL))
        #expect(!fixture.document.attributes.allowsExternalContent)
        let always = try makeMarkdownEditor("x") { $0.loadsExternalContent = true }
        defer { always.close() }
        #expect(always.editor.allowsExternalContent)
    }

    @Test func storesPermissions() throws {
        let defaults = TestSupport.makeDefaults()
        let store = ExternalContentStore(defaults: defaults)
        let url = URL(fileURLWithPath: "/tmp/a.md")
        #expect(!store.isAllowed(for: url))
        #expect(!store.isAllowed(for: nil))
        store.allow(for: url)
        store.allow(for: url)
        #expect(store.isAllowed(for: URL(fileURLWithPath: "/tmp/../tmp/a.md")))
        #expect(defaults.stringArray(forKey: ExternalContentStore.documentsKey)?.count == 1)
        store.reset()
        #expect(!store.isAllowed(for: url))

        let folder = try TestSupport.makeTemporaryFolder()
        let access = FolderAccessStore(defaults: defaults)
        #expect(!access.covers(folder.appendingPathComponent("x.png")))
        access.grant(folder)
        access.grant(folder)
        #expect(access.folders.count == 1)
        #expect(access.covers(folder.appendingPathComponent("sub/x.png")))
        #expect(access.covers(folder))
        #expect(!access.covers(folder.deletingLastPathComponent()))
        let restored = FolderAccessStore(defaults: defaults)
        #expect(restored.covers(folder.appendingPathComponent("x.png")))
        access.reset()
        #expect(access.folders.isEmpty)
        #expect(defaults.array(forKey: FolderAccessStore.bookmarksKey) == nil)
    }

    @Test func reportsFoldersOfUnreadableImages() throws {
        let folder = try TestSupport.makeTemporaryFolder()
        let image = folder.appendingPathComponent("a.png")
        try TestSupport.makePNG().write(to: image)
        let access = FolderAccessStore(defaults: TestSupport.makeDefaults())
        #expect(MarkdownPreviewController.inaccessibleFolder(for: [image], documentFolder: folder, access: access) == nil)
        let documentFolder = URL(fileURLWithPath: "/private/var/root/notes")
        let hidden = documentFolder.appendingPathComponent("img/b.png")
        #expect(MarkdownPreviewController.inaccessibleFolder(for: [hidden], documentFolder: documentFolder, access: access)?.path == documentFolder.path)
        #expect(MarkdownPreviewController.inaccessibleFolder(for: [hidden], documentFolder: nil, access: access)?.path == "/private/var/root/notes/img")
        access.grant(documentFolder)
        #expect(MarkdownPreviewController.inaccessibleFolder(for: [hidden], documentFolder: documentFolder, access: access) == nil)
    }

    @Test func servesOnlyImageFiles() throws {
        let folder = try TestSupport.makeTemporaryFolder()
        let image = folder.appendingPathComponent("a b.png")
        try Data([1, 2, 3]).write(to: image)
        let text = folder.appendingPathComponent("a.txt")
        try Data("x".utf8).write(to: text)
        let result = PreviewResourceHandler.image(for: try #require(URL(string: MarkdownPage.resourceAddress(for: image))))
        #expect(result?.0 == Data([1, 2, 3]))
        #expect(result?.1 == "image/png")
        #expect(PreviewResourceHandler.image(for: try #require(URL(string: MarkdownPage.resourceAddress(for: text)))) == nil)
        #expect(PreviewResourceHandler.image(for: try #require(URL(string: "https://example.com/a.png"))) == nil)
    }

    @Test func handlesPreviewMessages() throws {
        let fixture = try makeMarkdownEditor("- [ ] task\n\nline 3")
        defer { fixture.close() }
        let preview = try #require(fixture.editor.previewController)
        preview.handleMessage(["type": "task", "line": 1])
        #expect(fixture.text == "- [x] task\n\nline 3")
        #expect(fixture.textView.undoManager?.undoActionName == L10n.Undo.task)
        preview.handleMessage(["type": "reveal", "line": 3])
        #expect(fixture.textView.selectedRange() == NSRange(location: 12, length: 0))
        preview.handleMessage(["type": "scroll", "line": 2.5])
        #expect(preview.lastLine == 2.5)
        let delegate = RecordingPreviewDelegate()
        preview.delegate = delegate
        preview.handleMessage(["type": "link", "href": "https://a.org"])
        preview.handleMessage(["type": "task", "line": 1])
        preview.handleMessage(["type": "reveal", "line": 2])
        preview.handleMessage(["type": "scroll", "line": 4])
        preview.handleMessage(["type": "unknown"])
        preview.handleMessage(["type": "task"])
        preview.handleMessage("garbage")
        #expect(delegate.links == ["https://a.org"])
        #expect(delegate.toggledLines == [1])
        #expect(delegate.requestedLines == [2])
        #expect(delegate.scrolledLines == [4])
    }

    @Test func opensLinksByKind() throws {
        let fixture = try makeMarkdownEditor("x")
        defer { fixture.close() }
        let workspace = RecordingWorkspace()
        fixture.editor.openPreviewLink("https://a.org/x", workspace: workspace)
        fixture.editor.openPreviewLink("www.b.org", workspace: workspace)
        fixture.editor.openPreviewLink("mailto:a@b.org", workspace: workspace)
        fixture.editor.openPreviewLink("/tmp/file.pdf", workspace: workspace)
        fixture.editor.openPreviewLink("javascript:alert(1)", workspace: workspace)
        #expect(workspace.opened.map(\.absoluteString) == ["https://a.org/x", "http://www.b.org", "mailto:a@b.org", "file:///tmp/file.pdf"])
    }

    @Test func syncsScrollingBetweenEditorAndPreview() throws {
        let text = (1...300).map { "Line \($0)\n" }.joined()
        let fixture = try makeMarkdownEditor(text)
        defer { fixture.close() }
        let editor = fixture.editor
        let preview = try #require(editor.previewController)
        #expect(editor.editorTopLine() < 2)
        editor.scrollEditor(toLine: 120.5)
        #expect(abs(editor.editorTopLine() - 120.5) < 1)
        editor.ignoresEditorScrollUntil = .distantPast
        editor.editorDidScroll()
        #expect(abs(preview.lastLine - 120.5) < 1)
        editor.ignoresPreviewScrollUntil = .distantPast
        editor.preview(preview, didScrollToLine: 40)
        #expect(abs(editor.editorTopLine() - 40) < 1)
        fixture.document.settingsStore.settings.markdownScrollSync = .previewFollowsEditor
        editor.ignoresPreviewScrollUntil = .distantPast
        editor.preview(preview, didScrollToLine: 200)
        #expect(abs(editor.editorTopLine() - 40) < 1)
        fixture.document.settingsStore.settings.markdownScrollSync = .independent
        editor.ignoresEditorScrollUntil = .distantPast
        editor.editorDidScroll()
        #expect(abs(preview.lastLine - 120.5) < 1)
    }

    @Test func exportsSelfContainedHTML() throws {
        let folder = try TestSupport.makeTemporaryFolder()
        try TestSupport.makePNG().write(to: folder.appendingPathComponent("dot.png"))
        let fixture = try makeMarkdownEditor("# Report\n\n![Dot](dot.png) ![Web](https://notecraft.invalid/a.png)")
        defer { fixture.close() }
        fixture.document.fileURL = folder.appendingPathComponent("Report.md")
        let output = folder.appendingPathComponent("Report.html")
        fixture.editor.writeHTML(to: output)
        let html = try String(contentsOf: output, encoding: .utf8)
        #expect(html.contains("<title>Report</title>"))
        #expect(html.contains("src=\"data:image/png;base64,"))
        #expect(html.contains("src=\"https://notecraft.invalid/a.png\""))
        #expect(html.contains("prefers-color-scheme: dark"))
        #expect(!html.contains("<script"))
        #expect(fixture.editor.exportTitle == "Report")
        #expect(EditorViewController.dataAddress(for: folder.appendingPathComponent("missing.png")).hasPrefix("file://"))
        let item = NSMenuItem(title: "", action: #selector(EditorViewController.exportAsHTML(_:)), keyEquivalent: "")
        #expect(fixture.editor.validateMenuItem(item))
        let plain = try TestSupport.makeEditor("x")
        defer { plain.close() }
        #expect(!plain.editor.validateMenuItem(item))
    }

    @Test func copiesFormattedText() throws {
        let fixture = try makeMarkdownEditor("**Bold** text")
        defer { fixture.close() }
        let pasteboard = TestSupport.makePasteboard()
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 8))
        fixture.editor.copyFormattedText(to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "**Bold**")
        #expect(pasteboard.string(forType: .html)?.contains("<strong>Bold</strong>") == true)
        #expect(pasteboard.string(forType: .html)?.contains("prefers-color-scheme") == false)
        #expect(pasteboard.data(forType: .rtf) != nil)
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 0))
        fixture.editor.copyFormattedText(to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "**Bold** text")
    }

    @Test func printsRenderedPreview() async throws {
        let fixture = try makeMarkdownEditor("# Print me")
        defer { fixture.close() }
        let preview = try #require(fixture.editor.previewController)
        #expect(await TestSupport.wait { preview.isLoaded })
        #expect(fixture.editor.markdownPrintOperation(printInfo: NSPrintInfo()) != nil)
        let operation = try fixture.document.printOperation(withSettings: [:])
        #expect(operation.jobTitle == fixture.document.displayName)
        #expect(!(operation.view is NSTextView))
        fixture.editor.setPreviewVisible(false)
        #expect(fixture.editor.markdownPrintOperation(printInfo: NSPrintInfo()) == nil)
        #expect(try fixture.document.printOperation(withSettings: [:]).view is NSTextView)
    }

    @Test func rendersSettingsAndBanner() {
        let store = TestSupport.makeSettingsStore()
        var resets = 0
        let view = MarkdownSettingsView(store: store, onResetPermissions: { resets += 1 })
        #expect(TestSupport.render(view) != nil)
        view.onResetPermissions()
        #expect(resets == 1)
        #expect(MarkdownScrollSync.allCases.map(\.displayName) == ["Both directions", "Preview follows editor", "Independent"])
        let state = MarkdownPreviewState()
        state.blockedImageCount = 2
        state.inaccessibleFolder = URL(fileURLWithPath: "/tmp")
        var actions: [String] = []
        let banner = PreviewBanner(state: state, onLoadExternalContent: { actions.append("external") }, onAllowFolderAccess: { actions.append($0.path) })
        #expect(TestSupport.render(banner) != nil)
        banner.onLoadExternalContent()
        banner.onAllowFolderAccess(URL(fileURLWithPath: "/tmp"))
        #expect(actions == ["external", "/tmp"])
    }
}

@MainActor
struct MarkdownEditorTests {
    @Test func continuesListsAndIndentsItems() throws {
        let fixture = try TestSupport.makeEditor("- one", fileName: "a.md")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.indentation = Indentation(usesTabs: false, width: 4)
        textView.setSelectedRange(NSRange(location: 5, length: 0))
        textView.insertNewline(nil)
        #expect(fixture.text == "- one\n- ")
        textView.insertTab(nil)
        #expect(fixture.text == "- one\n    - ")
        textView.setSelectedRange(NSRange(location: (fixture.text as NSString).length, length: 0))
        textView.insertNewline(nil)
        #expect(fixture.text == "- one\n")
        let plain = try TestSupport.makeEditor("- one")
        defer { plain.close() }
        plain.textView.setSelectedRange(NSRange(location: 5, length: 0))
        plain.textView.insertNewline(nil)
        #expect(plain.text == "- one\n")
    }

    @Test func turnsPastedAddressIntoLink() throws {
        let fixture = try TestSupport.makeEditor("read docs", fileName: "a.md")
        defer { fixture.close() }
        let pasteboard = TestSupport.makePasteboard()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("https://a.org", forType: .string)
        fixture.textView.setSelectedRange(NSRange(location: 5, length: 4))
        #expect(fixture.textView.readSelection(from: pasteboard, type: .string))
        #expect(fixture.text == "read [docs](https://a.org)")
    }

    @Test func runsFormattingCommands() throws {
        let fixture = try TestSupport.makeEditor("word", fileName: "a.md")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 0, length: 4))
        textView.formatBold(nil)
        #expect(fixture.text == "**word**")
        #expect(textView.undoManager?.undoActionName == L10n.Undo.formatting)
        textView.formatBold(nil)
        textView.formatItalic(nil)
        #expect(fixture.text == "*word*")
        textView.formatItalic(nil)
        textView.formatStrikethrough(nil)
        #expect(fixture.text == "~~word~~")
        textView.formatStrikethrough(nil)
        textView.formatCode(nil)
        #expect(fixture.text == "`word`")
        textView.formatCode(nil)
        textView.insertLink(suggestedAddress: "https://a.org")
        #expect(fixture.text == "[word](https://a.org)")
        let heading = NSMenuItem()
        heading.tag = 2
        textView.formatHeading(heading)
        #expect(fixture.text == "## [word](https://a.org)")
        textView.formatQuote(nil)
        #expect(fixture.text == "> ## [word](https://a.org)")
        textView.formatQuote(nil)
        textView.formatHeading(nil)
        textView.toggleTask(nil)
        #expect(fixture.text == "- [ ] [word](https://a.org)")
        #expect(textView.undoManager?.undoActionName == L10n.Undo.task)
        textView.insertMarkdownLink(nil)
    }

    @Test func runsListAndCodeCommands() throws {
        let fixture = try TestSupport.makeEditor("one\ntwo", fileName: "a.md")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 0, length: 7))
        textView.toggleBulletedList(nil)
        #expect(fixture.text == "- one\n- two")
        #expect(textView.undoManager?.undoActionName == L10n.Undo.list)
        textView.toggleNumberedList(nil)
        #expect(fixture.text == "1. one\n2. two")
        textView.toggleNumberedList(nil)
        #expect(fixture.text == "one\ntwo")
        textView.formatCode(nil)
        #expect(fixture.text == "```\none\ntwo\n```")
        textView.formatCode(nil)
        #expect(fixture.text == "one\ntwo")
        textView.setSelectedRange(NSRange(location: 5, length: 0))
        textView.applyHeading(level: 1)
        #expect(fixture.text == "one\n# two")
        #expect(textView.markdownFormatState.headingLevel == 1)
        textView.applyHeading(level: 1)
        #expect(fixture.text == "one\ntwo")
    }

    @Test func editsTablesAndTableOfContents() throws {
        let fixture = try TestSupport.makeEditor("# Notes\n", fileName: "a.md")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 8, length: 0))
        textView.insertMarkdownTable(nil)
        #expect(fixture.text.contains("| Column 1 | Column 2 | Column 3 |"))
        textView.addMarkdownTableRow(nil)
        textView.addMarkdownTableColumn(nil)
        textView.formatMarkdownTable(nil)
        let lines = fixture.text.components(separatedBy: "\n")
        #expect(lines.filter { $0.hasPrefix("|") }.count == 5)
        #expect(lines[3].filter { $0 == "|" }.count == 5)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.updateTableOfContents(nil)
        #expect(fixture.text.hasPrefix("<!-- toc -->\n- [Notes](#notes)\n<!-- tocstop -->\n"))
        #expect(textView.undoManager?.undoActionName == L10n.Undo.tableOfContents)
    }

    @Test func validatesMarkdownCommands() throws {
        let fixture = try TestSupport.makeEditor("| a |\n| - |\ntext", fileName: "a.md")
        defer { fixture.close() }
        let bold = NSMenuItem(title: "", action: #selector(EditorTextView.formatBold(_:)), keyEquivalent: "")
        let row = NSMenuItem(title: "", action: #selector(EditorTextView.addMarkdownTableRow(_:)), keyEquivalent: "")
        fixture.textView.setSelectedRange(NSRange(location: 1, length: 0))
        #expect(fixture.textView.validateMenuItem(bold))
        #expect(fixture.textView.validateMenuItem(row))
        fixture.textView.setSelectedRange(NSRange(location: 13, length: 0))
        #expect(!fixture.textView.validateMenuItem(row))
        let plain = try TestSupport.makeEditor("x")
        defer { plain.close() }
        #expect(!plain.textView.validateMenuItem(bold))
        let comment = NSMenuItem(title: "", action: #selector(EditorTextView.toggleComment(_:)), keyEquivalent: "")
        #expect(fixture.textView.validateMenuItem(comment))
    }

    @Test func checksActiveFormatsInMenus() throws {
        let fixture = try TestSupport.makeEditor("## **bold** text\n- item\n1. step\n> quote", fileName: "a.md")
        defer { fixture.close() }
        let textView = fixture.textView
        func state(_ action: Selector, tag: Int = 0) -> NSControl.StateValue {
            let item = NSMenuItem(title: "", action: action, keyEquivalent: "")
            item.tag = tag
            #expect(textView.validateMenuItem(item))
            return item.state
        }
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        #expect(state(#selector(EditorTextView.formatBold(_:))) == .on)
        #expect(state(#selector(EditorTextView.formatItalic(_:))) == .off)
        #expect(state(#selector(EditorTextView.formatHeading(_:)), tag: 2) == .on)
        #expect(state(#selector(EditorTextView.formatHeading(_:)), tag: 1) == .off)
        textView.setSelectedRange(NSRange(location: 19, length: 0))
        #expect(state(#selector(EditorTextView.toggleBulletedList(_:))) == .on)
        #expect(state(#selector(EditorTextView.toggleNumberedList(_:))) == .off)
        textView.setSelectedRange(NSRange(location: 27, length: 0))
        #expect(state(#selector(EditorTextView.toggleNumberedList(_:))) == .on)
        textView.setSelectedRange(NSRange(location: 34, length: 0))
        #expect(state(#selector(EditorTextView.formatQuote(_:))) == .on)
        #expect(state(#selector(EditorTextView.formatCode(_:))) == .off)
        #expect(state(#selector(EditorTextView.formatStrikethrough(_:))) == .off)
        let image = NSMenuItem(title: "", action: #selector(EditorTextView.insertMarkdownImage(_:)), keyEquivalent: "")
        #expect(textView.validateMenuItem(image))
    }

    @Test func insertsDroppedImages() throws {
        let fixture = try TestSupport.makeEditor("", fileName: "a.md")
        defer { fixture.close() }
        fixture.textView.documentFolderURL = URL(fileURLWithPath: "/notes")
        #expect(fixture.textView.insertImages([URL(fileURLWithPath: "/notes/img/a.png"), URL(fileURLWithPath: "/notes/b.jpg")], replacing: NSRange(location: 0, length: 0)))
        #expect(fixture.text == "![a](img/a.png)\n![b](b.jpg)")
        fixture.textView.insertImages([URL(fileURLWithPath: "/notes/c.gif")], replacing: NSRange(location: 0, length: 15))
        #expect(fixture.text == "![c](c.gif)\n![b](b.jpg)")
        #expect(fixture.textView.undoManager?.undoActionName == L10n.Undo.insertImage)
        #expect(EditorTextView.isImageFile(URL(fileURLWithPath: "/x/a.PNG")))
        #expect(!EditorTextView.isImageFile(URL(fileURLWithPath: "/x/a.txt")))
        #expect(!EditorTextView.isImageFile(try #require(URL(string: "https://x/a.png"))))
    }
}

@MainActor
struct AcknowledgementsTests {
    @Test func showsBundledLicenseTexts() {
        let text = AcknowledgementsView.bundledText()
        #expect(text.contains("Swift Markdown"))
        #expect(text.contains("Apache License"))
        #expect(text.contains("cmark-gfm"))
        #expect(AcknowledgementsView.bundledText(in: Bundle(for: NSObject.self)).isEmpty)
        #expect(TestSupport.render(AcknowledgementsView(text: "License")) != nil)
        #expect(AcknowledgementsWindowController.shared.window?.title == L10n.Menu.acknowledgements)
    }
}

@MainActor
struct MarkdownToolbarTests {
    private func markdownItems(of toolbar: NSToolbar) -> [NSToolbarItem] {
        toolbar.items.filter { NSToolbarItem.Identifier.markdownItems.contains($0.itemIdentifier) }
    }

    private func group(_ identifier: NSToolbarItem.Identifier, in toolbar: NSToolbar) throws -> NSToolbarItemGroup {
        try #require(toolbar.items.first { $0.itemIdentifier == identifier } as? NSToolbarItemGroup)
    }

    @Test func offersCenteredMarkdownTools() throws {
        let fixture = try TestSupport.makeEditor("x", fileName: "a.md")
        defer { fixture.close() }
        let controller = fixture.windowController
        let toolbar = try #require(controller.window?.toolbar)
        let tools = NSToolbarItem.Identifier.markdownTools
        let defaults = controller.toolbarDefaultItemIdentifiers(toolbar)
        #expect(Array(defaults.drop { $0 != tools[0] }.prefix(tools.count)) == tools)
        #expect(defaults.contains(.preview) && !defaults.contains(.format))
        #expect(!controller.toolbarAllowedItemIdentifiers(toolbar).contains(.format))
        #expect(toolbar.centeredItemIdentifiers == Set(tools))
        #expect(toolbar.items.first { $0.itemIdentifier == .preview }?.visibilityPriority == .high)
        #expect(toolbar.items.first { $0.itemIdentifier == .share }?.visibilityPriority == .high)
        #expect(toolbar.items.first { $0.itemIdentifier == .markdownMore }?.visibilityPriority == .low)
        #expect(toolbar.items.first { $0.itemIdentifier == .markdownTextStyle }?.visibilityPriority == .standard)
        for identifier in tools {
            let item = try #require(controller.toolbar(toolbar, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: true))
            #expect(!item.label.isEmpty)
        }
        let style = try #require(controller.makeMarkdownTool(.markdownTextStyle) as? NSToolbarItemGroup)
        #expect(style.label == L10n.MarkdownToolbar.textStyle)
        #expect(style.controlRepresentation == .expanded)
        #expect(style.subitems.map(\.toolTip) == [L10n.Menu.bold, L10n.Menu.italic, L10n.Menu.strikethrough])
        #expect(style.subitems.map(\.action) == [#selector(EditorTextView.formatBold(_:)), #selector(EditorTextView.formatItalic(_:)), #selector(EditorTextView.formatStrikethrough(_:))])
        #expect(style.subitems.allSatisfy { $0.image != nil && $0.target == nil })
        let headings = try #require(controller.makeMarkdownTool(.markdownHeadings) as? NSToolbarItemGroup)
        #expect(headings.subitems.map(\.toolTip) == (1...3).map(L10n.Menu.headingLevel))
        #expect(headings.subitems.map(\.tag) == [1, 2, 3])
        #expect(headings.subitems.allSatisfy { $0.image?.isTemplate == true && $0.image?.size.width ?? 0 > 0 })
        for (identifier, tools) in EditorWindowController.markdownToolsByGroup {
            #expect(tools.allSatisfy { $0.image !== $0.activeImage }, "\(identifier.rawValue)")
        }
        let more = try #require(controller.makeMarkdownTool(.markdownMore) as? NSMenuToolbarItem)
        #expect(more.menu.items.first?.action == #selector(EditorTextView.toggleTask(_:)))
        #expect(more.menu.items.last?.action == #selector(EditorTextView.updateTableOfContents(_:)))
        #expect(controller.makeMarkdownTool(.find) == nil)
        let preview = try #require(controller.toolbar(toolbar, itemForItemIdentifier: .preview, willBeInsertedIntoToolbar: true))
        #expect(preview.action == #selector(EditorViewController.togglePreview(_:)))
        #expect(!preview.isHidden)
        #expect(fixture.editor.validateToolbarItem(preview))
        #expect(preview.toolTip == L10n.Menu.hidePreview)
        let find = try #require(controller.toolbar(toolbar, itemForItemIdentifier: .find, willBeInsertedIntoToolbar: true))
        #expect(fixture.editor.validateToolbarItem(find))
        #expect(fixture.textView.validateToolbarItem(style.subitems[0]))
        fixture.textView.isEditable = false
        #expect(!fixture.textView.validateToolbarItem(style.subitems[0]))
    }

    @Test func runsToolsAndHighlightsFormats() throws {
        let fixture = try TestSupport.makeEditor("word", fileName: "a.md")
        defer { fixture.close() }
        let controller = fixture.windowController
        let toolbar = try #require(controller.window?.toolbar)
        let textView = fixture.textView
        fixture.windowController.window?.makeFirstResponder(textView)
        func click(_ identifier: NSToolbarItem.Identifier, _ index: Int) throws {
            let subitem = try group(identifier, in: toolbar).subitems[index]
            #expect(NSApp.sendAction(try #require(subitem.action), to: textView, from: subitem))
        }
        func isActive(_ identifier: NSToolbarItem.Identifier, _ index: Int) throws -> Bool {
            let subitem = try group(identifier, in: toolbar).subitems[index]
            let tool = try #require(EditorWindowController.markdownToolsByGroup[identifier]?[index])
            #expect(subitem.image === tool.activeImage || subitem.image === tool.image)
            return subitem.image === tool.activeImage
        }
        textView.setSelectedRange(NSRange(location: 0, length: 4))
        try click(.markdownTextStyle, 0)
        #expect(fixture.text == "**word**")
        #expect(try isActive(.markdownTextStyle, 0))
        #expect(try !isActive(.markdownTextStyle, 1))
        try click(.markdownTextStyle, 0)
        #expect(fixture.text == "word")
        #expect(try !isActive(.markdownTextStyle, 0))
        try click(.markdownHeadings, 1)
        #expect(fixture.text == "## word")
        #expect(try isActive(.markdownHeadings, 1))
        #expect(controller.markdownToolStates[.markdownHeadings] == [false, true, false])
        try click(.markdownHeadings, 1)
        try click(.markdownLists, 1)
        #expect(fixture.text == "1. word")
        #expect(try isActive(.markdownLists, 1))
        try click(.markdownLists, 0)
        #expect(fixture.text == "- word")
        try click(.markdownIndentation, 1)
        #expect(fixture.text.hasPrefix(" ") || fixture.text.hasPrefix("\t"))
        try click(.markdownIndentation, 0)
        #expect(fixture.text == "- word")
        try click(.markdownLists, 0)
        try click(.markdownQuoteAndCode, 0)
        #expect(fixture.text == "> word")
        #expect(try isActive(.markdownQuoteAndCode, 0))
        try click(.markdownQuoteAndCode, 0)
        try click(.markdownQuoteAndCode, 1)
        #expect(fixture.text == "`word`")
        #expect(try isActive(.markdownQuoteAndCode, 1))
        textView.string = "a **b** c"
        textView.setSelectedRange(NSRange(location: 5, length: 0))
        #expect(try isActive(.markdownTextStyle, 0))
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        #expect(try !isActive(.markdownTextStyle, 0))
    }

    @Test func hidesMarkdownItemsForOtherLanguages() throws {
        let fixture = try TestSupport.makeEditor("**x**", fileName: "a.md")
        defer { fixture.close() }
        let toolbar = try #require(fixture.windowController.window?.toolbar)
        #expect(markdownItems(of: toolbar).count == NSToolbarItem.Identifier.markdownItems.count)
        #expect(markdownItems(of: toolbar).allSatisfy { !$0.isHidden })
        fixture.textView.setSelectedRange(NSRange(location: 2, length: 0))
        #expect(fixture.windowController.markdownToolStates[.markdownTextStyle]?.first == true)
        fixture.document.setLanguage(LanguageCatalog.swift)
        #expect(markdownItems(of: toolbar).allSatisfy { $0.isHidden })
        #expect(fixture.windowController.markdownToolStates[.markdownTextStyle]?.first == false)
        let preview = try #require(markdownItems(of: toolbar).first { $0.itemIdentifier == .preview })
        #expect(!fixture.editor.validateToolbarItem(preview))
        #expect(!fixture.textView.validateToolbarItem(try group(.markdownLists, in: toolbar).subitems[0]))
        fixture.document.setLanguage(LanguageCatalog.markdown)
        #expect(markdownItems(of: toolbar).allSatisfy { !$0.isHidden })
        let plain = try TestSupport.makeEditor("x")
        defer { plain.close() }
        let plainToolbar = try #require(plain.windowController.window?.toolbar)
        #expect(plain.windowController.toolbar(plainToolbar, itemForItemIdentifier: .markdownLists, willBeInsertedIntoToolbar: true)?.isHidden == true)
    }

    @Test func addsMarkdownItemsOnceToSavedToolbars() throws {
        let fixture = try TestSupport.makeEditor("x", fileName: "a.md")
        defer { fixture.close() }
        let toolbar = NSToolbar(identifier: "NoteCraftTests-\(UUID().uuidString)")
        toolbar.delegate = fixture.windowController
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 300), styleMask: [.titled], backing: .buffered, defer: true)
        window.toolbar = toolbar
        func removeMarkdownItems() {
            while let index = toolbar.items.firstIndex(where: { NSToolbarItem.Identifier.markdownItems.contains($0.itemIdentifier) }) {
                toolbar.removeItem(at: index)
            }
            while toolbar.items.filter({ $0.itemIdentifier == .flexibleSpace }).count > 1,
                  let index = toolbar.items.lastIndex(where: { $0.itemIdentifier == .flexibleSpace }) {
                toolbar.removeItem(at: index)
            }
        }
        removeMarkdownItems()
        #expect(markdownItems(of: toolbar).isEmpty)
        let defaults = TestSupport.makeDefaults()
        EditorWindowController.addMarkdownItems(to: toolbar, defaults: defaults)
        let identifiers = toolbar.items.map(\.itemIdentifier)
        #expect(markdownItems(of: toolbar).count == NSToolbarItem.Identifier.markdownItems.count)
        #expect(identifiers.firstIndex(of: .preview).map { $0 + 1 } == identifiers.firstIndex(of: .commandPalette))
        let first = try #require(identifiers.firstIndex(of: .markdownIndentation))
        #expect(identifiers[first - 1] == .flexibleSpace)
        #expect(Array(identifiers[first..<first + 7]) == NSToolbarItem.Identifier.markdownTools)
        #expect(identifiers[first + 7] == .flexibleSpace)
        removeMarkdownItems()
        EditorWindowController.addMarkdownItems(to: toolbar, defaults: defaults)
        #expect(markdownItems(of: toolbar).isEmpty)
        let upgraded = TestSupport.makeDefaults()
        upgraded.set(true, forKey: EditorWindowController.markdownToolbarItemsKey)
        EditorWindowController.addMarkdownItems(to: toolbar, defaults: upgraded)
        #expect(markdownItems(of: toolbar).count == NSToolbarItem.Identifier.markdownTools.count)
    }

    @Test func addsFormatSubmenuToContextMenu() throws {
        let fixture = try TestSupport.makeEditor("x", fileName: "a.md")
        defer { fixture.close() }
        let event = try #require(NSEvent.mouseEvent(
            with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: fixture.windowController.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        let menu = try #require(fixture.textView.menu(for: event))
        let format = menu.items.first { $0.title == L10n.Menu.format }
        #expect(format?.submenu?.items.contains { $0.action == #selector(EditorTextView.toggleTask(_:)) } == true)
        let again = try #require(fixture.textView.menu(for: event))
        #expect(again.items.filter { $0.title == L10n.Menu.format }.count == 1)
        let plain = try TestSupport.makeEditor("x")
        defer { plain.close() }
        #expect(plain.textView.menu(for: event)?.items.contains { $0.title == L10n.Menu.format } == false)
    }
}
