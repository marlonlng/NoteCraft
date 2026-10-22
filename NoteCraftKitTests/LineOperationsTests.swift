import Foundation
import Testing
@testable import NoteCraftKit

struct LineOperationsTests {
    private func apply(_ edit: TextEdit?, to text: String) -> String? {
        edit?.applied(to: text)
    }

    @Test func computesLineRangeExcludingLineAfterSelectionEnd() {
        let text = "ab\ncd\nef" as NSString
        #expect(LineOperations.lineRange(for: NSRange(location: 0, length: 3), in: text) == NSRange(location: 0, length: 3))
        #expect(LineOperations.lineRange(for: NSRange(location: 4, length: 0), in: text) == NSRange(location: 3, length: 3))
        #expect(LineOperations.contentLineRange(for: NSRange(location: 4, length: 0), in: text) == NSRange(location: 3, length: 2))
    }

    @Test func duplicatesLine() {
        let text = "ab\ncd\nef"
        let edit = LineOperations.duplicateLines(in: text as NSString, selection: NSRange(location: 4, length: 0))
        #expect(apply(edit, to: text) == "ab\ncd\ncd\nef")
        #expect(edit.selectedRange == NSRange(location: 7, length: 0))
    }

    @Test func duplicatesLastLineWithoutLineEnding() {
        let text = "ab\ncd"
        let edit = LineOperations.duplicateLines(in: text as NSString, selection: NSRange(location: 4, length: 1))
        #expect(apply(edit, to: text) == "ab\ncd\ncd")
        #expect(edit.selectedRange == NSRange(location: 7, length: 1))
    }

    @Test func movesLinesUp() {
        let text = "ab\ncd\nef"
        let edit = LineOperations.moveLines(in: text as NSString, selection: NSRange(location: 4, length: 0), direction: .up)
        #expect(apply(edit, to: text) == "cd\nab\nef")
        #expect(edit?.selectedRange == NSRange(location: 1, length: 0))
    }

    @Test func movesLastLineUp() {
        let text = "ab\ncd"
        let edit = LineOperations.moveLines(in: text as NSString, selection: NSRange(location: 3, length: 0), direction: .up)
        #expect(apply(edit, to: text) == "cd\nab")
    }

    @Test func movesLinesDown() {
        let text = "ab\ncd\nef"
        let edit = LineOperations.moveLines(in: text as NSString, selection: NSRange(location: 0, length: 0), direction: .down)
        #expect(apply(edit, to: text) == "cd\nab\nef")
        #expect(edit?.selectedRange == NSRange(location: 3, length: 0))
    }

    @Test func movesLineDownOverLastLine() {
        let text = "ab\ncd"
        let edit = LineOperations.moveLines(in: text as NSString, selection: NSRange(location: 1, length: 0), direction: .down)
        #expect(apply(edit, to: text) == "cd\nab")
        #expect(edit?.selectedRange == NSRange(location: 4, length: 0))
    }

    @Test func refusesToMoveBeyondBounds() {
        let text = "ab\ncd" as NSString
        #expect(LineOperations.moveLines(in: text, selection: NSRange(location: 0, length: 0), direction: .up) == nil)
        #expect(LineOperations.moveLines(in: text, selection: NSRange(location: 4, length: 0), direction: .down) == nil)
    }

    @Test func deletesLines() {
        let text = "ab\ncd\nef"
        let middle = LineOperations.deleteLines(in: text as NSString, selection: NSRange(location: 4, length: 0))
        #expect(apply(middle, to: text) == "ab\nef")
        let last = LineOperations.deleteLines(in: text as NSString, selection: NSRange(location: 7, length: 0))
        #expect(apply(last, to: text) == "ab\ncd")
    }

    @Test func indentsAndOutdentsLines() {
        let text = "a\n\nb"
        let indent = LineOperations.indent(in: text as NSString, selection: NSRange(location: 0, length: 4), unit: "    ")
        #expect(apply(indent, to: text) == "    a\n\n    b")
        #expect(indent.selectedRange == NSRange(location: 0, length: 12))

        let indented = "    a\n\t b\n  c"
        let outdent = LineOperations.outdent(in: indented as NSString, selection: NSRange(location: 0, length: 13), tabWidth: 4)
        #expect(apply(outdent, to: indented) == "a\n b\nc")
        #expect(LineOperations.outdent(in: "a" as NSString, selection: NSRange(location: 0, length: 0), tabWidth: 4) == nil)
    }

    @Test func movesCaretWhenIndentingSingleLine() {
        let indent = LineOperations.indent(in: "ab" as NSString, selection: NSRange(location: 1, length: 0), unit: "\t")
        #expect(indent.selectedRange == NSRange(location: 2, length: 0))
        let outdent = LineOperations.outdent(in: "\tab" as NSString, selection: NSRange(location: 2, length: 0), tabWidth: 4)
        #expect(outdent?.selectedRange == NSRange(location: 1, length: 0))
    }

    @Test func togglesLineComments() {
        let syntax = CommentSyntax(lineComment: "//")
        let text = "  a\n\n    b"
        let comment = LineOperations.toggleComment(in: text as NSString, selection: NSRange(location: 0, length: 10), syntax: syntax)
        let commented = apply(comment, to: text)
        #expect(commented == "  // a\n\n  //   b")
        let uncomment = LineOperations.toggleComment(in: commented! as NSString, selection: NSRange(location: 0, length: 16), syntax: syntax)
        #expect(apply(uncomment, to: commented!) == text)
    }

    @Test func togglesBlockComments() {
        let syntax = CommentSyntax(blockComment: .init(start: "<!--", end: "-->"))
        let text = "  <p>Hi</p>"
        let comment = LineOperations.toggleComment(in: text as NSString, selection: NSRange(location: 3, length: 0), syntax: syntax)
        let commented = apply(comment, to: text)
        #expect(commented == "  <!-- <p>Hi</p> -->")
        let uncomment = LineOperations.toggleComment(in: commented! as NSString, selection: NSRange(location: 3, length: 0), syntax: syntax)
        #expect(apply(uncomment, to: commented!) == text)
    }

    @Test func refusesToCommentWithoutSyntaxOrContent() {
        #expect(LineOperations.toggleComment(in: "a" as NSString, selection: NSRange(location: 0, length: 0), syntax: CommentSyntax()) == nil)
        #expect(LineOperations.toggleComment(in: "  " as NSString, selection: NSRange(location: 0, length: 0), syntax: CommentSyntax(lineComment: "#")) == nil)
    }

    @Test func transformsWholeDocumentWithoutSelection() throws {
        let text = "b\na\n"
        let edit = try LineOperations.transform(.sortLinesAscending, in: text as NSString, selection: NSRange(location: 0, length: 0))
        #expect(edit.applied(to: text) == "a\nb\n")
    }

    @Test func transformsSelectedLinesOnly() throws {
        let text = "z\nb\na\n"
        let edit = try LineOperations.transform(.sortLinesAscending, in: text as NSString, selection: NSRange(location: 3, length: 2))
        #expect(edit.applied(to: text) == "z\na\nb\n")
        #expect(edit.selectedRange == NSRange(location: 2, length: 3))
    }

    @Test func transformsExactSelectionForCharacterTransformations() throws {
        let text = "abc def"
        let edit = try LineOperations.transform(.uppercase, in: text as NSString, selection: NSRange(location: 4, length: 3))
        #expect(edit.applied(to: text) == "abc DEF")
    }
}
