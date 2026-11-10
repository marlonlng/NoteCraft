import Foundation
import Testing
@testable import NoteCraftKit

struct MarkdownFormattingTests {
    private func state(_ text: String, _ location: Int, _ length: Int = 0) -> MarkdownFormatState {
        MarkdownFormatState.at(NSRange(location: location, length: length), in: text as NSString)
    }

    @Test func findsInlineSpansWithTheirMarkers() {
        let text = "  - a **bold** and *ä* `x` ~~gone~~"
        let spans = MarkdownEditing.inlineSpans(inLineAt: 5, in: text as NSString)
        let ranges = spans.map { ($0.style, (text as NSString).substring(with: $0.range), $0.markerLength) }
        #expect(ranges.map(\.0) == [.bold, .italic, .code, .strikethrough])
        #expect(ranges.map(\.1) == ["**bold**", "*ä*", "`x`", "~~gone~~"])
        #expect(ranges.map(\.2) == [2, 1, 1, 2])
        #expect(MarkdownEditing.inlineSpans(inLineAt: 0, in: "plain" as NSString).isEmpty)
        let emoji = "😀 **b**"
        #expect(MarkdownEditing.inlineSpans(inLineAt: 0, in: emoji as NSString).first?.range == NSRange(location: 3, length: 5))
    }

    @Test func reportsInlineStylesAtTheCaret() {
        let text = "a **bold *both*** `code` ~~x~~"
        #expect(state(text, 5).inlineStyles == [.bold])
        #expect(state(text, 11).inlineStyles == [.bold, .italic])
        #expect(state(text, 2).inlineStyles.isEmpty)
        #expect(state(text, 17).inlineStyles.isEmpty)
        #expect(state(text, 20).inlineStyles == [.code])
        #expect(state(text, 27).inlineStyles == [.strikethrough])
        #expect(state(text, 2, 15).inlineStyles == [.bold])
        #expect(state("**a**\nb", 2, 4).inlineStyles.isEmpty)
    }

    @Test func reportsLineFormats() {
        #expect(state("## Title", 4).headingLevel == 2)
        #expect(state("# a\n## b", 0, 7).headingLevel == 0)
        #expect(state("- a\n\n* b", 0, 7).listKind == .bullet)
        #expect(state("1. a\n2. b", 0, 8).listKind == .numbered)
        #expect(state("- a\n1. b", 0, 7).listKind == nil)
        #expect(state("- [ ] task", 3).listKind == .bullet)
        #expect(state("> a\n> b", 0, 6).isQuote)
        #expect(!state("> a\nb", 0, 5).isQuote)
        #expect(state("> a\nb", 0, 4).isQuote)
        #expect(state("", 0) == MarkdownFormatState())
    }

    @Test func treatsFencedBlocksAsCode() {
        let text = "intro\n```swift\n# not a heading\n```\nafter"
        #expect(state(text, 20) == MarkdownFormatState(inlineStyles: [.code]))
        #expect(state(text, 7).inlineStyles == [.code])
        #expect(state(text, 33).inlineStyles == [.code])
        #expect(state(text, 38).inlineStyles.isEmpty)
        #expect(state(text, 2).inlineStyles.isEmpty)
        #expect(state(text, 2, 20).inlineStyles.isEmpty)
        let unclosed = "a\n~~~\ncode"
        #expect(state(unclosed, 8).inlineStyles == [.code])
        #expect(MarkdownEditing.fencedBlock(containing: 0, in: unclosed as NSString) == nil)
        let nested = "```\n~~~\n```\nb"
        #expect(MarkdownEditing.fencedBlock(containing: 5, in: nested as NSString)?.closing == NSRange(location: 8, length: 3))
        #expect(MarkdownEditing.fencedBlock(containing: 12, in: nested as NSString) == nil)
        #expect(MarkdownEditing.fencedBlock(containing: 0, in: "``` a`b\nx" as NSString) == nil)
    }

    @Test func removesTheSpanAroundTheCaret() {
        let text = "a **bold** b"
        let edit = MarkdownEditing.toggle(.bold, in: text as NSString, selection: NSRange(location: 6, length: 0))
        #expect(edit.applied(to: text) == "a bold b")
        #expect(edit.selectedRange == NSRange(location: 4, length: 0))
        let start = MarkdownEditing.toggle(.bold, in: text as NSString, selection: NSRange(location: 3, length: 0))
        #expect(start.applied(to: text) == "a bold b")
        #expect(start.selectedRange == NSRange(location: 2, length: 0))
        let nested = "**a *b* c**"
        let italic = MarkdownEditing.toggle(.italic, in: nested as NSString, selection: NSRange(location: 5, length: 0))
        #expect(italic.applied(to: nested) == "**a b c**")
        let outer = MarkdownEditing.toggle(.bold, in: nested as NSString, selection: NSRange(location: 5, length: 0))
        #expect(outer.applied(to: nested) == "a *b* c")
        #expect(outer.selectedRange == NSRange(location: 3, length: 0))
        let whole = MarkdownEditing.toggle(.strikethrough, in: "~x~ y" as NSString, selection: NSRange(location: 0, length: 3))
        #expect(whole.applied(to: "~x~ y") == "x y")
        #expect(whole.selectedRange == NSRange(location: 0, length: 1))
    }

    @Test func togglesBulletLists() {
        let text = "one\n\ntwo"
        let bullets = MarkdownEditing.toggleList(.bullet, in: text as NSString, selection: NSRange(location: 0, length: 8))
        #expect(bullets.applied(to: text) == "- one\n\n- two")
        let listed = "- one\n\n* two"
        let removed = MarkdownEditing.toggleList(.bullet, in: listed as NSString, selection: NSRange(location: 0, length: 12))
        #expect(removed.applied(to: listed) == "one\n\ntwo")
        let mixed = "* one\n1. [x] two"
        let converted = MarkdownEditing.toggleList(.bullet, in: mixed as NSString, selection: NSRange(location: 0, length: 16))
        #expect(converted.applied(to: mixed) == "* one\n- [x] two")
        let empty = MarkdownEditing.toggleList(.bullet, in: "" as NSString, selection: NSRange(location: 0, length: 0))
        #expect(empty.applied(to: "") == "- ")
        #expect(empty.selectedRange == NSRange(location: 2, length: 0))
        let caret = MarkdownEditing.toggleList(.bullet, in: "  word" as NSString, selection: NSRange(location: 4, length: 0))
        #expect(caret.applied(to: "  word") == "  - word")
        #expect(caret.selectedRange == NSRange(location: 6, length: 0))
    }

    @Test func togglesNumberedLists() {
        let text = "a\nb\n  c\n  d\ne"
        let numbered = MarkdownEditing.toggleList(.numbered, in: text as NSString, selection: NSRange(location: 0, length: 13))
        #expect(numbered.applied(to: text) == "1. a\n2. b\n  1. c\n  2. d\n3. e")
        let continued = "1. a\n2. b\nc\nd"
        let more = MarkdownEditing.toggleList(.numbered, in: continued as NSString, selection: NSRange(location: 10, length: 3))
        #expect(more.applied(to: continued) == "1. a\n2. b\n3. c\n4. d")
        let bullets = "- a\n- [ ] b"
        let converted = MarkdownEditing.toggleList(.numbered, in: bullets as NSString, selection: NSRange(location: 0, length: 11))
        #expect(converted.applied(to: bullets) == "1. a\n2. [ ] b")
        let back = MarkdownEditing.toggleList(.numbered, in: "1. a\n2. b" as NSString, selection: NSRange(location: 0, length: 9))
        #expect(back.applied(to: "1. a\n2. b") == "a\nb")
    }

    @Test func formatsCodeInlineOrAsBlock() {
        let word = MarkdownEditing.toggleCode(in: "call value now" as NSString, selection: NSRange(location: 7, length: 0))
        #expect(word.applied(to: "call value now") == "call `value` now")
        #expect(word.selectedRange == NSRange(location: 8, length: 0))
        let space = MarkdownEditing.toggleCode(in: "a  b" as NSString, selection: NSRange(location: 2, length: 0))
        #expect(space.applied(to: "a  b") == "a `` b")
        let inline = MarkdownEditing.toggleCode(in: "x `y` z" as NSString, selection: NSRange(location: 3, length: 0))
        #expect(inline.applied(to: "x `y` z") == "x y z")
        let selection = MarkdownEditing.toggleCode(in: "a b c" as NSString, selection: NSRange(location: 2, length: 1))
        #expect(selection.applied(to: "a b c") == "a `b` c")
        let lines = "one\ntwo\nthree"
        let block = MarkdownEditing.toggleCode(in: lines as NSString, selection: NSRange(location: 1, length: 5))
        #expect(block.applied(to: lines) == "```\none\ntwo\n```\nthree")
        #expect(block.selectedRange == NSRange(location: 4, length: 7))
    }

    @Test func removesFencedBlocks() throws {
        let text = "a\n```swift\nlet x\n```\nb"
        let edit = MarkdownEditing.toggleCode(in: text as NSString, selection: NSRange(location: 13, length: 0))
        #expect(edit.applied(to: text) == "a\nlet x\nb")
        #expect(edit.selectedRange == NSRange(location: 4, length: 0))
        let fromFence = MarkdownEditing.toggleCode(in: text as NSString, selection: NSRange(location: 3, length: 0))
        #expect(fromFence.selectedRange == NSRange(location: 2, length: 0))
        let whole = MarkdownEditing.toggleCode(in: text as NSString, selection: NSRange(location: 2, length: 18))
        #expect(whole.applied(to: text) == "a\nlet x\nb")
        #expect(whole.selectedRange == NSRange(location: 2, length: 5))
        let empty = "```\n```"
        #expect(MarkdownEditing.toggleCode(in: empty as NSString, selection: NSRange(location: 0, length: 0)).applied(to: empty) == "")
        let unclosed = "a\n```\nb"
        let opened = MarkdownEditing.toggleCode(in: unclosed as NSString, selection: NSRange(location: 6, length: 1))
        #expect(opened.applied(to: unclosed) == "a\nb")
        #expect(opened.selectedRange == NSRange(location: 2, length: 1))
        #expect(MarkdownEditing.wordRange(at: 0, in: "" as NSString) == nil)
        #expect(try #require(MarkdownEditing.wordRange(at: 2, in: "a_b1 c" as NSString)) == NSRange(location: 0, length: 4))
    }
}
