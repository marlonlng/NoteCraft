import Foundation
import Testing
@testable import NoteCraftKit

struct MarkdownEditingTests {
    private func apply(_ edit: TextEdit?, to text: String) -> String? {
        edit?.applied(to: text)
    }

    @Test func wrapsAndUnwrapsInlineStyles() {
        let text = "say hello now"
        let bold = MarkdownEditing.toggle(.bold, in: text as NSString, selection: NSRange(location: 4, length: 5))
        #expect(apply(bold, to: text) == "say **hello** now")
        #expect(bold.selectedRange == NSRange(location: 6, length: 5))
        let wrapped = "say **hello** now"
        let unwrapped = MarkdownEditing.toggle(.bold, in: wrapped as NSString, selection: NSRange(location: 6, length: 5))
        #expect(apply(unwrapped, to: wrapped) == text)
        #expect(unwrapped.selectedRange == NSRange(location: 4, length: 5))
        let inner = MarkdownEditing.toggle(.bold, in: wrapped as NSString, selection: NSRange(location: 4, length: 9))
        #expect(apply(inner, to: wrapped) == text)
        let trailingSpace = MarkdownEditing.toggle(.code, in: text as NSString, selection: NSRange(location: 4, length: 6))
        #expect(apply(trailingSpace, to: text) == "say `hello` now")
    }

    @Test func distinguishesItalicFromBold() {
        let text = "**word**"
        let italic = MarkdownEditing.toggle(.italic, in: text as NSString, selection: NSRange(location: 2, length: 4))
        #expect(apply(italic, to: text) == "***word***")
        let both = "***word***"
        let removeItalic = MarkdownEditing.toggle(.italic, in: both as NSString, selection: NSRange(location: 3, length: 4))
        #expect(apply(removeItalic, to: both) == "**word**")
        let removeBold = MarkdownEditing.toggle(.bold, in: both as NSString, selection: NSRange(location: 3, length: 4))
        #expect(apply(removeBold, to: both) == "*word*")
        let strike = MarkdownEditing.toggle(.strikethrough, in: "~~x~~" as NSString, selection: NSRange(location: 0, length: 5))
        #expect(apply(strike, to: "~~x~~") == "x")
    }

    @Test func insertsAndRemovesEmptyMarkers() {
        let insert = MarkdownEditing.toggle(.bold, in: "ab" as NSString, selection: NSRange(location: 1, length: 0))
        #expect(apply(insert, to: "ab") == "a****b")
        #expect(insert.selectedRange == NSRange(location: 3, length: 0))
        let remove = MarkdownEditing.toggle(.bold, in: "a****b" as NSString, selection: NSRange(location: 3, length: 0))
        #expect(apply(remove, to: "a****b") == "ab")
        #expect(remove.selectedRange == NSRange(location: 1, length: 0))
    }

    @Test func insertsLinks() {
        let text = "see docs"
        let empty = MarkdownEditing.insertLink(in: text as NSString, selection: NSRange(location: 8, length: 0), suggestedAddress: nil)
        #expect(apply(empty, to: text) == "see docs[]()")
        #expect(empty.selectedRange == NSRange(location: 9, length: 0))
        let labeled = MarkdownEditing.insertLink(in: text as NSString, selection: NSRange(location: 4, length: 4), suggestedAddress: nil)
        #expect(apply(labeled, to: text) == "see [docs]()")
        #expect(labeled.selectedRange == NSRange(location: 11, length: 0))
        let suggested = MarkdownEditing.insertLink(in: text as NSString, selection: NSRange(location: 4, length: 4), suggestedAddress: " https://a.org ")
        #expect(apply(suggested, to: text) == "see [docs](https://a.org)")
        let emptySuggested = MarkdownEditing.insertLink(in: text as NSString, selection: NSRange(location: 0, length: 0), suggestedAddress: "https://a.org")
        #expect(apply(emptySuggested, to: text) == "[](https://a.org)see docs")
        #expect(emptySuggested.selectedRange == NSRange(location: 1, length: 0))
        let address = "go https://a.org"
        let fromAddress = MarkdownEditing.insertLink(in: address as NSString, selection: NSRange(location: 3, length: 13), suggestedAddress: nil)
        #expect(apply(fromAddress, to: address) == "go [](https://a.org)")
        #expect(fromAddress.selectedRange == NSRange(location: 4, length: 0))
    }

    @Test func turnsPastedAddressIntoLink() {
        let text = "read this"
        let edit = MarkdownEditing.link(pasting: "https://a.org", in: text as NSString, selection: NSRange(location: 5, length: 4))
        #expect(apply(edit, to: text) == "read [this](https://a.org)")
        #expect(MarkdownEditing.link(pasting: "plain words", in: text as NSString, selection: NSRange(location: 5, length: 4)) == nil)
        #expect(MarkdownEditing.link(pasting: "https://a.org", in: text as NSString, selection: NSRange(location: 5, length: 0)) == nil)
        #expect(MarkdownEditing.link(pasting: "https://a.org", in: "a\nb" as NSString, selection: NSRange(location: 0, length: 3)) == nil)
        #expect(MarkdownEditing.isAddress("www.example.com"))
        #expect(!MarkdownEditing.isAddress("https://"))
    }

    @Test func setsAndTogglesHeadings() {
        let text = "Title\nbody"
        let heading = MarkdownEditing.setHeading(level: 2, in: text as NSString, selection: NSRange(location: 3, length: 0))
        #expect(apply(heading, to: text) == "## Title\nbody")
        #expect(heading.selectedRange == NSRange(location: 6, length: 0))
        let changed = MarkdownEditing.setHeading(level: 1, in: "## Title" as NSString, selection: NSRange(location: 8, length: 0))
        #expect(apply(changed, to: "## Title") == "# Title")
        let toggled = MarkdownEditing.setHeading(level: 2, in: "## Title" as NSString, selection: NSRange(location: 0, length: 0))
        #expect(apply(toggled, to: "## Title") == "Title")
        #expect(toggled.selectedRange == NSRange(location: 0, length: 0))
        let block = MarkdownEditing.setHeading(level: 3, in: text as NSString, selection: NSRange(location: 0, length: 10))
        #expect(apply(block, to: text) == "### Title\n### body")
        #expect(block.selectedRange == NSRange(location: 0, length: 18))
        #expect(MarkdownEditing.headingLevel(of: "#hashtag").level == 0)
    }

    @Test func togglesQuotes() {
        let text = "one\n\ntwo"
        let quoted = MarkdownEditing.toggleQuote(in: text as NSString, selection: NSRange(location: 0, length: 8))
        #expect(apply(quoted, to: text) == "> one\n>\n> two")
        let unquoted = MarkdownEditing.toggleQuote(in: "> one\n>\n> two" as NSString, selection: NSRange(location: 0, length: 13))
        #expect(apply(unquoted, to: "> one\n>\n> two") == text)
        let nested = MarkdownEditing.toggleQuote(in: "> > deep" as NSString, selection: NSRange(location: 6, length: 0))
        #expect(apply(nested, to: "> > deep") == "> deep")
    }

    @Test func togglesTasksOnLines() {
        let text = "buy milk\n- eggs\n1. bread"
        let tasks = MarkdownEditing.toggleTask(in: text as NSString, selection: NSRange(location: 0, length: (text as NSString).length))
        #expect(apply(tasks, to: text) == "- [ ] buy milk\n- [ ] eggs\n1. [ ] bread")
        let open = "- [ ] a\n- [x] b"
        let checked = MarkdownEditing.toggleTask(in: open as NSString, selection: NSRange(location: 0, length: 15))
        #expect(apply(checked, to: open) == "- [x] a\n- [x] b")
        let done = "- [x] a\n- [X] b"
        let unchecked = MarkdownEditing.toggleTask(in: done as NSString, selection: NSRange(location: 0, length: 15))
        #expect(apply(unchecked, to: done) == "- [ ] a\n- [ ] b")
        let single = MarkdownEditing.toggleTask(in: "  note" as NSString, selection: NSRange(location: 4, length: 0))
        #expect(apply(single, to: "  note") == "  - [ ] note")
        #expect(single.selectedRange == NSRange(location: 10, length: 0))
    }

    @Test func togglesTaskByLineNumber() {
        let text = "# List\n- [ ] a\n- [x] b\nplain"
        #expect(apply(MarkdownEditing.toggleTask(atLine: 2, in: text as NSString), to: text) == "# List\n- [x] a\n- [x] b\nplain")
        #expect(apply(MarkdownEditing.toggleTask(atLine: 3, in: text as NSString), to: text) == "# List\n- [ ] a\n- [ ] b\nplain")
        #expect(MarkdownEditing.toggleTask(atLine: 4, in: text as NSString) == nil)
        #expect(MarkdownEditing.toggleTask(atLine: 9, in: text as NSString) == nil)
    }

    @Test func continuesBulletAndTaskLists() {
        let text = "- one"
        let bullet = MarkdownEditing.continueList(in: text as NSString, selection: NSRange(location: 5, length: 0))
        #expect(apply(bullet, to: text) == "- one\n- ")
        #expect(bullet?.selectedRange == NSRange(location: 8, length: 0))
        let task = "  * [x] done"
        let next = MarkdownEditing.continueList(in: task as NSString, selection: NSRange(location: 12, length: 0))
        #expect(apply(next, to: task) == "  * [x] done\n  * [ ] ")
        let split = MarkdownEditing.continueList(in: "- ab" as NSString, selection: NSRange(location: 3, length: 0))
        #expect(apply(split, to: "- ab") == "- a\n- b")
        #expect(MarkdownEditing.continueList(in: "- ab" as NSString, selection: NSRange(location: 1, length: 0)) == nil)
        #expect(MarkdownEditing.continueList(in: "plain" as NSString, selection: NSRange(location: 5, length: 0)) == nil)
        #expect(MarkdownEditing.continueList(in: "- ab" as NSString, selection: NSRange(location: 2, length: 2)) == nil)
    }

    @Test func endsListOnEmptyItem() {
        let text = "- one\n- "
        let edit = MarkdownEditing.continueList(in: text as NSString, selection: NSRange(location: 8, length: 0))
        #expect(apply(edit, to: text) == "- one\n")
        #expect(edit?.selectedRange == NSRange(location: 6, length: 0))
        let quote = MarkdownEditing.continueList(in: "> hi\n> " as NSString, selection: NSRange(location: 7, length: 0))
        #expect(apply(quote, to: "> hi\n> ") == "> hi\n")
    }

    @Test func continuesQuotes() {
        let edit = MarkdownEditing.continueList(in: "> hi" as NSString, selection: NSRange(location: 4, length: 0))
        #expect(apply(edit, to: "> hi") == "> hi\n> ")
        let nested = MarkdownEditing.continueList(in: ">> hi" as NSString, selection: NSRange(location: 5, length: 0))
        #expect(apply(nested, to: ">> hi") == ">> hi\n>> ")
    }

    @Test func renumbersOrderedLists() {
        let text = "1. a\n2. b\n   nested\n\n3. c\n- other"
        let edit = MarkdownEditing.continueList(in: text as NSString, selection: NSRange(location: 4, length: 0))
        #expect(apply(edit, to: text) == "1. a\n2. \n3. b\n   nested\n\n4. c\n- other")
        #expect(edit?.selectedRange == NSRange(location: 8, length: 0))
        let parenthesis = MarkdownEditing.continueList(in: "9) x" as NSString, selection: NSRange(location: 4, length: 0))
        #expect(apply(parenthesis, to: "9) x") == "9) x\n10) ")
        let gap = "1. a\n\n\n2. b"
        let stopped = MarkdownEditing.continueList(in: gap as NSString, selection: NSRange(location: 4, length: 0))
        #expect(apply(stopped, to: gap) == "1. a\n2. \n\n\n2. b")
    }

    @Test func detectsListItems() {
        let text = "- a\nb\n1) c"
        #expect(MarkdownEditing.isListItem(at: 1, in: text as NSString))
        #expect(!MarkdownEditing.isListItem(at: 4, in: text as NSString))
        #expect(MarkdownEditing.isListItem(at: 8, in: text as NSString))
        #expect(MarkdownListPrefix.parse("-no") == nil)
        #expect(MarkdownListPrefix.parse("-")?.length == 1)
    }

    @Test func createsImageMarkdown() {
        let folder = URL(fileURLWithPath: "/Users/me/notes")
        #expect(MarkdownEditing.imageMarkdown(for: URL(fileURLWithPath: "/Users/me/notes/img/a b.png"), relativeTo: folder) == "![a b](img/a%20b.png)")
        #expect(MarkdownEditing.imageMarkdown(for: URL(fileURLWithPath: "/Users/me/pics/c(1).jpg"), relativeTo: folder) == "![c(1)](../pics/c%281%29.jpg)")
        #expect(MarkdownEditing.imageMarkdown(for: URL(fileURLWithPath: "/Volumes/x/d.png"), relativeTo: folder) == "![d](/Volumes/x/d.png)")
        #expect(MarkdownEditing.imageMarkdown(for: URL(fileURLWithPath: "/tmp/e.png"), relativeTo: nil) == "![e](/tmp/e.png)")
    }
}
