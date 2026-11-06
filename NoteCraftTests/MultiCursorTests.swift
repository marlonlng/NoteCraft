import AppKit
import NoteCraftKit
import Testing
@testable import NoteCraft

@MainActor
struct MultiCursorTests {
    private func makeEditor(_ text: String) throws -> EditorFixture {
        let fixture = try TestSupport.makeEditor(text)
        if let container = fixture.textView.textContainer {
            fixture.textView.layoutManager?.ensureLayout(for: container)
        }
        return fixture
    }

    private func type(_ text: String, in textView: EditorTextView) {
        textView.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    @Test func movesEveryCaretToLineStartAndEnd() throws {
        let fixture = try makeEditor("one\ntwo words\nx")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setInsertionLocations([1, 5, 15])
        textView.doCommand(by: #selector(NSResponder.moveToRightEndOfLine(_:)))
        #expect(textView.insertionLocations == [3, 13, 15])
        type(";", in: textView)
        #expect(fixture.text == "one;\ntwo words;\nx;")
        textView.doCommand(by: #selector(NSResponder.moveToLeftEndOfLine(_:)))
        #expect(textView.insertionLocations == [0, 5, 16])
    }

    @Test func extendsAndCollapsesEverySelection() throws {
        let fixture = try makeEditor("alpha\nbeta\ngamma")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setInsertionLocations([0, 6, 11])
        textView.doCommand(by: #selector(NSResponder.moveWordRightAndModifySelection(_:)))
        #expect(textView.cursors.map(\.range) == [NSRange(location: 0, length: 5), NSRange(location: 6, length: 4), NSRange(location: 11, length: 5)])
        #expect(textView.selectedRanges.count == 3)
        textView.doCommand(by: #selector(NSResponder.moveLeftAndModifySelection(_:)))
        #expect(textView.cursors.map(\.range) == [NSRange(location: 0, length: 4), NSRange(location: 6, length: 3), NSRange(location: 11, length: 4)])
        textView.doCommand(by: #selector(NSResponder.moveRight(_:)))
        #expect(textView.insertionLocations == [4, 9, 15])
        textView.doCommand(by: #selector(NSResponder.moveToLeftEndOfLineAndModifySelection(_:)))
        #expect(textView.cursors.map(\.head) == [0, 6, 11])
        textView.doCommand(by: #selector(NSResponder.moveLeft(_:)))
        #expect(textView.insertionLocations == [0, 6, 11])
        textView.doCommand(by: #selector(NSResponder.moveToEndOfParagraphAndModifySelection(_:)))
        textView.doCommand(by: #selector(NSResponder.moveWordLeft(_:)))
        #expect(textView.insertionLocations == [0, 6, 11])
    }

    @Test func keepsColumnWhenMovingUpAndDown() throws {
        let fixture = try makeEditor("abcdef\nab\nabcdef\nabcdef")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setInsertionLocations([5, 15])
        textView.doCommand(by: #selector(NSResponder.moveDown(_:)))
        #expect(textView.insertionLocations == [9, 22])
        textView.doCommand(by: #selector(NSResponder.moveDown(_:)))
        #expect(textView.insertionLocations == [15, 23])
        textView.doCommand(by: #selector(NSResponder.moveUp(_:)))
        #expect(textView.insertionLocations == [9, 15])
        textView.doCommand(by: #selector(NSResponder.moveDownAndModifySelection(_:)))
        #expect(textView.cursors.map(\.range) == [NSRange(location: 9, length: 6), NSRange(location: 15, length: 7)])
    }

    @Test func mergesCursorsThatMeet() throws {
        let fixture = try makeEditor("ab\ncd")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setInsertionLocations([1, 4])
        textView.doCommand(by: #selector(NSResponder.moveToBeginningOfDocument(_:)))
        #expect(textView.cursors.isEmpty)
        #expect(textView.selectedRange() == NSRange(location: 0, length: 0))
        textView.setInsertionLocations([1, 4])
        textView.doCommand(by: #selector(NSResponder.moveToEndOfDocumentAndModifySelection(_:)))
        #expect(textView.selectedRange() == NSRange(location: 1, length: 4))
        textView.setInsertionLocations([0, 3])
        textView.doCommand(by: #selector(NSResponder.moveParagraphForwardAndModifySelection(_:)))
        textView.doCommand(by: #selector(NSResponder.moveParagraphForwardAndModifySelection(_:)))
        #expect(textView.selectedRange() == NSRange(location: 0, length: 5))
        textView.setInsertionLocations([2, 5])
        textView.doCommand(by: #selector(NSResponder.moveParagraphBackwardAndModifySelection(_:)))
        #expect(textView.cursors.map(\.head) == [0, 3])
        textView.doCommand(by: #selector(NSResponder.moveParagraphBackwardAndModifySelection(_:)))
        #expect(textView.selectedRange() == NSRange(location: 0, length: 5))
    }

    @Test func deletesAtEveryCaret() throws {
        let fixture = try makeEditor("one two\nthree four")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setInsertionLocations([7, 18])
        textView.doCommand(by: #selector(NSResponder.deleteWordBackward(_:)))
        #expect(fixture.text == "one \nthree ")
        #expect(textView.insertionLocations == [4, 11])
        textView.doCommand(by: #selector(NSResponder.deleteToBeginningOfLine(_:)))
        #expect(fixture.text == "\n")
        #expect(textView.insertionLocations == [0, 1])
        textView.doCommand(by: #selector(NSResponder.deleteToBeginningOfLine(_:)))
        #expect(fixture.text == "\n")
        textView.doCommand(by: #selector(NSResponder.deleteForward(_:)))
        #expect(fixture.text == "")
        #expect(textView.cursors.isEmpty)
    }

    @Test func deletesSelectionsAndWordsForward() throws {
        let fixture = try makeEditor("ab cd\nab cd")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setCursors([TextCursor(anchor: 0, head: 2), TextCursor(caret: 6)])
        textView.doCommand(by: #selector(NSResponder.deleteWordForward(_:)))
        #expect(fixture.text == " cd\n cd")
        textView.doCommand(by: #selector(NSResponder.deleteToEndOfParagraph(_:)))
        #expect(fixture.text == "\n")
    }

    @Test func movesRangesOfNativeMultipleSelection() throws {
        let fixture = try makeEditor("foo\nfoo")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRanges([NSValue(range: NSRange(location: 0, length: 3)), NSValue(range: NSRange(location: 4, length: 3))], affinity: .downstream, stillSelecting: false)
        #expect(textView.cursors.isEmpty)
        textView.doCommand(by: #selector(NSResponder.moveToRightEndOfLine(_:)))
        #expect(textView.insertionLocations == [3, 7])
    }

    @Test func leavesSingleCursorToTextView() throws {
        let fixture = try makeEditor("abc")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        textView.doCommand(by: #selector(NSResponder.moveRight(_:)))
        #expect(textView.selectedRange() == NSRange(location: 2, length: 0))
        #expect(textView.activeCursors == nil)
    }

    @Test func showsSystemCaretsForAdditionalCursors() throws {
        let fixture = try makeEditor("a\nb\nc")
        defer { fixture.close() }
        let textView = fixture.textView
        textView.setInsertionLocations([0, 2, 4])
        #expect(textView.caretIndicators.count == 2)
        #expect(textView.caretIndicators.allSatisfy { $0.superview === textView })
        let expected = try #require(textView.caretRect(at: 2))
        #expect(abs(textView.caretIndicators[0].frame.minY - expected.minY) < 0.5)
        #expect(textView.caretIndicators.allSatisfy { $0.displayMode == .hidden })
        textView.insertionPointColor = .systemRed
        #expect(textView.caretIndicators.allSatisfy { $0.color == .systemRed })
        textView.setFrameSize(NSSize(width: textView.frame.width - 10, height: textView.frame.height))
        #expect(textView.caretIndicators.count == 2)
        textView.setCursors([TextCursor(anchor: 0, head: 1), TextCursor(caret: 4)])
        #expect(textView.caretIndicators.count == 1)
        #expect(textView.selectedRanges.map(\.rangeValue) == [NSRange(location: 0, length: 1)])
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        #expect(textView.cursors.isEmpty)
        #expect(textView.caretIndicators.isEmpty)
        textView.window?.makeFirstResponder(nil)
        textView.window?.makeFirstResponder(textView)
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: textView.window)
        #expect(textView.windowObservers.count == 2)
    }
}
