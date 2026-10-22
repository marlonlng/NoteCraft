import AppKit
import NoteCraftKit
import Testing
@testable import NoteCraft

@MainActor
struct EditorTextViewTests {
    @Test func configuresPlainTextEditing() throws {
        let fixture = try TestSupport.makeEditor("x")
        defer { fixture.close() }
        let textView = fixture.textView
        #expect(!textView.isRichText)
        #expect(!textView.isAutomaticQuoteSubstitutionEnabled)
        #expect(!textView.isAutomaticDashSubstitutionEnabled)
        #expect(!textView.isAutomaticSpellingCorrectionEnabled)
        #expect(textView.allowsUndo)
        #expect(textView.accessibilityLabel() == L10n.Accessibility.editor)
    }

    @Test func pairsBracketsAndSkipsOverClosingCharacter() throws {
        let fixture = try TestSupport.makeEditor("")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.insertText("f", replacementRange: NSRange(location: NSNotFound, length: 0))
        textView.insertText("(", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(fixture.text == "f()")
        #expect(textView.selectedRange() == NSRange(location: 2, length: 0))
        textView.insertText(")", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(fixture.text == "f()")
        #expect(textView.selectedRange() == NSRange(location: 3, length: 0))
    }

    @Test func wrapsSelectionInPair() throws {
        let fixture = try TestSupport.makeEditor("value")
        defer { fixture.close() }
        fixture.textView.setSelectedRange(NSRange(location: 0, length: 5))
        fixture.textView.insertText("\"", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(fixture.text == "\"value\"")
        #expect(fixture.textView.selectedRange() == NSRange(location: 1, length: 5))
    }

    @Test func deletesEmptyPairAndSoftTabs() throws {
        let fixture = try TestSupport.makeEditor("()\n        x")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.deleteBackward(nil)
        #expect(fixture.text == "\n        x")
        textView.indentation = Indentation(usesTabs: false, width: 4)
        textView.setSelectedRange(NSRange(location: 9, length: 0))
        textView.deleteBackward(nil)
        #expect(fixture.text == "\n    x")
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        textView.deleteBackward(nil)
        #expect(fixture.text == "\n    ")
    }

    @Test func returnsSoftTabRangeOnlyForLeadingSpaces() throws {
        let fixture = try TestSupport.makeEditor("ab  x\n    y")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.indentation = Indentation(usesTabs: false, width: 4)
        #expect(textView.softTabDeletionRange(at: 4) == nil)
        #expect(textView.softTabDeletionRange(at: 10) == NSRange(location: 6, length: 4))
        #expect(textView.softTabDeletionRange(at: 6) == nil)
    }

    @Test func indentsNewLinesAutomatically() throws {
        let fixture = try TestSupport.makeEditor("    if x {}")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.indentation = Indentation(usesTabs: false, width: 4)
        textView.setSelectedRange(NSRange(location: 10, length: 0))
        textView.insertNewline(nil)
        #expect(fixture.text == "    if x {\n        \n    }")
        #expect(textView.selectedRange() == NSRange(location: 19, length: 0))
        textView.autoIndents = false
        textView.insertNewline(nil)
        #expect(fixture.text == "    if x {\n        \n\n    }")
    }

    @Test func insertsSpacesForTabAndIndentsSelections() throws {
        let fixture = try TestSupport.makeEditor("ab\ncd")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.indentation = Indentation(usesTabs: false, width: 4)
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.insertTab(nil)
        #expect(fixture.text == "a   b\ncd")
        textView.setSelectedRange(NSRange(location: 0, length: 8))
        textView.insertTab(nil)
        #expect(fixture.text == "    a   b\n    cd")
        textView.insertBacktab(nil)
        #expect(fixture.text == "a   b\ncd")
        textView.indentation = Indentation(usesTabs: true, width: 4)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.insertTab(nil)
        #expect(fixture.text == "\ta   b\ncd")
    }

    @Test func runsLineCommands() throws {
        let fixture = try TestSupport.makeEditor("one\ntwo\nthree", fileName: "a.swift")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 5, length: 0))
        textView.duplicateLine(nil)
        #expect(fixture.text == "one\ntwo\ntwo\nthree")
        textView.moveLineUp(nil)
        #expect(fixture.text == "one\ntwo\ntwo\nthree")
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.moveLineDown(nil)
        #expect(fixture.text == "two\none\ntwo\nthree")
        textView.deleteLine(nil)
        #expect(fixture.text == "two\ntwo\nthree")
        textView.toggleComment(nil)
        #expect(fixture.text == "two\n// two\nthree")
        textView.shiftRight(nil)
        #expect(fixture.text.contains("    // two"))
        textView.shiftLeft(nil)
        #expect(fixture.text == "two\n// two\nthree")
    }

    @Test func undoesEditsStepByStep() throws {
        let fixture = try TestSupport.makeEditor("one\ntwo")
        defer { fixture.close() }
        let textView = fixture.textView
        let undoManager = try #require(textView.undoManager)
        undoManager.groupsByEvent = false
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        undoManager.beginUndoGrouping()
        textView.duplicateLine(nil)
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.selectNextOccurrence(nil)
        textView.selectNextOccurrence(nil)
        textView.insertText("1", replacementRange: NSRange(location: NSNotFound, length: 0))
        undoManager.endUndoGrouping()
        #expect(fixture.text == "1\n1\ntwo")
        undoManager.undo()
        #expect(fixture.text == "one\none\ntwo")
        undoManager.undo()
        #expect(fixture.text == "one\ntwo")
        undoManager.groupsByEvent = true
    }

    @Test func beepsForImpossibleLineMove() throws {
        let fixture = try TestSupport.makeEditor("only")
        defer { fixture.close() }
        fixture.textView.moveLineUp(nil)
        #expect(fixture.text == "only")
    }

    @Test func transformsSelectionAndDocument() throws {
        let fixture = try TestSupport.makeEditor("b\na\n")
        defer { fixture.close() }
        let textView = fixture.textView
        let item = NSMenuItem(title: "", action: #selector(EditorTextView.performTextTransformation(_:)), keyEquivalent: "")
        item.representedObject = TextTransformation.sortLinesAscending.rawValue
        textView.performTextTransformation(item)
        #expect(fixture.text == "a\nb\n")
        textView.setSelectedRange(NSRange(location: 0, length: 1))
        textView.transform(with: .uppercase)
        #expect(fixture.text == "A\nb\n")
        textView.performTextTransformation(nil)
        textView.setSelectedRange(NSRange(location: 0, length: 1))
        textView.transform(with: .base64Decode)
        #expect(fixture.text == "A\nb\n")
        fixture.windowController.window?.attachedSheet.map { fixture.windowController.window?.endSheet($0) }
    }

    @Test func convertsBetweenTabsAndSpaces() throws {
        let fixture = try TestSupport.makeEditor("\ta\n\t\tb")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.indentation = Indentation(usesTabs: false, width: 2)
        textView.convertTabsToSpaces(nil)
        #expect(fixture.text == "  a\n    b")
        textView.setSelectedRange(NSRange(location: 4, length: 5))
        textView.convertSpacesToTabs(nil)
        #expect(fixture.text == "  a\n\t\tb")
        textView.convertSpacesToTabs(nil)
        #expect(fixture.text == "  a\n\t\tb")
    }

    @Test func editsMultipleSelectionsTogether() throws {
        let fixture = try TestSupport.makeEditor("foo bar foo")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.selectNextOccurrence(nil)
        textView.selectNextOccurrence(nil)
        #expect(textView.selectedRanges.count == 2)
        textView.insertText("x", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(fixture.text == "x bar x")
        #expect(textView.insertionLocations == [1, 7])
        textView.insertText("y", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(fixture.text == "xy bar xy")
        textView.deleteBackward(nil)
        #expect(fixture.text == "x bar x")
        textView.insertTab(nil)
        textView.insertNewline(nil)
        #expect(fixture.text == "x    \n bar x    \n")
        textView.cancelOperation(nil)
        #expect(textView.insertionLocations.isEmpty)
    }

    @Test func selectsAllOccurrencesAndCollapsesWithEscape() throws {
        let fixture = try TestSupport.makeEditor("a b a b a")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 0, length: 1))
        textView.selectAllOccurrences(nil)
        #expect(textView.selectedRanges.count == 3)
        textView.deleteBackward(nil)
        #expect(fixture.text == " b  b ")
        textView.setSelectedRanges([NSValue(range: NSRange(location: 0, length: 1)), NSValue(range: NSRange(location: 2, length: 1))], affinity: .downstream, stillSelecting: false)
        textView.cancelOperation(nil)
        #expect(textView.selectedRanges.count == 1)
    }

    @Test func pastesNormalizedTextAndDistributesLines() throws {
        let fixture = try TestSupport.makeEditor("a\nb")
        defer { fixture.close() }
        let textView = fixture.textView
        let pasteboard = TestSupport.makePasteboard()
        pasteboard.clearContents()
        pasteboard.setString("1\r\n2", forType: .string)
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        #expect(textView.readSelection(from: pasteboard, type: .string))
        #expect(fixture.text == "a\nb1\n2")

        textView.setSelectedRanges([NSValue(range: NSRange(location: 0, length: 1)), NSValue(range: NSRange(location: 2, length: 1))], affinity: .downstream, stillSelecting: false)
        #expect(textView.readSelection(from: pasteboard, type: .string))
        #expect(fixture.text == "1\n21\n2")
    }

    @Test func tracksMatchingBrackets() throws {
        let fixture = try TestSupport.makeEditor("f(a[1])")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        #expect(textView.highlightedBracketRanges == [NSRange(location: 1, length: 1), NSRange(location: 6, length: 1)])
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        #expect(textView.highlightedBracketRanges.isEmpty)
        textView.highlightsMatchingBrackets = false
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        #expect(textView.highlightedBracketRanges.isEmpty)
    }

    @Test func computesLineAndCaretRectangles() throws {
        let fixture = try TestSupport.makeEditor("abc\n\nxyz\n")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let first = try #require(textView.lineRect(forCharacterAt: 0))
        let second = try #require(textView.lineRect(forCharacterAt: 4))
        #expect(second.minY > first.minY)
        #expect(textView.lineRect(forCharacterAt: 9) != nil)
        let caret = try #require(textView.caretRect(at: 2))
        let start = try #require(textView.caretRect(at: 0))
        #expect(caret.minX > start.minX)
        #expect(textView.caretRect(at: 9) != nil)
    }

    @Test func drawsWithHighlightsAndInvisibles() throws {
        let fixture = try TestSupport.makeEditor("f(a)\t \nx")
        defer { fixture.close() }
        let textView = fixture.textView
        (textView.layoutManager as? EditorLayoutManager)?.drawsInvisibleCharacters = true
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        #expect(TestSupport.draw(textView) != nil)
        textView.setSelectedRange(NSRange(location: 0, length: 1))
        textView.selectNextOccurrence(nil)
        textView.setInsertionLocations([0, 3])
        #expect(TestSupport.draw(textView) != nil)
        #expect(EditorLayoutManager.symbol(for: 0x20) == "·")
        #expect(EditorLayoutManager.symbol(for: 0x41) == nil)
    }

    @Test func togglesLineWrapping() throws {
        let fixture = try TestSupport.makeEditor("long line")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setWrapsLines(false)
        #expect(textView.enclosingScrollView?.hasHorizontalScroller == true)
        #expect(textView.textContainer?.widthTracksTextView == false)
        textView.setWrapsLines(true)
        #expect(textView.textContainer?.widthTracksTextView == true)
    }

    @Test func validatesTextCommands() throws {
        let fixture = try TestSupport.makeEditor("x", fileName: "plain.txt")
        defer { fixture.close() }
        let textView = fixture.textView
        let comment = NSMenuItem(title: "", action: #selector(EditorTextView.toggleComment(_:)), keyEquivalent: "")
        textView.commentSyntax = CommentSyntax()
        #expect(!textView.validateMenuItem(comment))
        textView.commentSyntax = CommentSyntax(lineComment: "#")
        #expect(textView.validateMenuItem(comment))
        let duplicate = NSMenuItem(title: "", action: #selector(EditorTextView.duplicateLine(_:)), keyEquivalent: "")
        #expect(textView.validateMenuItem(duplicate))
        let copy = NSMenuItem(title: "", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        _ = textView.validateMenuItem(copy)
    }

    @Test func forwardsEscapeToFindBar() throws {
        let fixture = try TestSupport.makeEditor("x")
        defer { fixture.close() }
        fixture.editor.findBarModel.show(replacing: false)
        fixture.textView.cancelOperation(nil)
        #expect(!fixture.editor.findBarModel.isVisible)
    }
}
