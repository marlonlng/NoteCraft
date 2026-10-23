import Foundation
import Testing
@testable import NoteCraftKit

struct MarkdownTableTests {
    private func apply(_ edit: TextEdit?, to text: String) -> String? {
        edit?.applied(to: text)
    }

    @Test func parsesCellsAndAlignments() {
        #expect(MarkdownTable.cells(of: "| a | `b|c` | d\\|e |") == ["a", "`b|c`", "d\\|e"])
        #expect(MarkdownTable.cells(of: "a|b") == ["a", "b"])
        #expect(MarkdownTable.delimiterAlignments("|:--|:-:|--:|---|") == [.left, .center, .right, .none])
        #expect(MarkdownTable.delimiterAlignments("| a | b |") == nil)
        #expect(MarkdownTable.delimiterAlignments("| -:- |") == nil)
        #expect(MarkdownTable.parse(["| a |"]) == nil)
    }

    @Test func formatsColumns() {
        let table = MarkdownTable.parse(["|Name|Größe|", "|:-|-:|", "|Apfel|3|", "|Kiwi"])
        #expect(table?.formattedLines() == [
            "| Name  | Größe |",
            "| :---- | ----: |",
            "| Apfel | 3     |",
            "| Kiwi  |       |"
        ])
        let centered = MarkdownTable(header: ["x"], alignments: [.center], rows: [])
        #expect(centered.formattedLines() == ["| x   |", "| :-: |"])
    }

    @Test func formatsTableAroundCaret() {
        let text = "Intro\n|a|bb|\n|-|-|\n|ccc|d|\nOutro"
        let edit = MarkdownTableEditing.format(in: text as NSString, selection: NSRange(location: 25, length: 0))
        #expect(apply(edit, to: text) == "Intro\n| a   | bb  |\n| --- | --- |\n| ccc | d   |\nOutro")
        #expect(edit?.selectedRange == NSRange(location: 43, length: 0))
        #expect(MarkdownTableEditing.format(in: text as NSString, selection: NSRange(location: 2, length: 0)) == nil)
        #expect(MarkdownTableEditing.containsTable(at: 25, in: text as NSString))
        #expect(!MarkdownTableEditing.containsTable(at: 30, in: text as NSString))
        #expect(MarkdownTableEditing.format(in: "| a |\n| b |" as NSString, selection: NSRange(location: 1, length: 0)) == nil)
    }

    @Test func addsRowsAndColumns() {
        let text = "| a | b |\n| - | - |\n| 1 | 2 |"
        let row = MarkdownTableEditing.addRow(in: text as NSString, selection: NSRange(location: 22, length: 0))
        #expect(apply(row, to: text) == "| a   | b   |\n| --- | --- |\n| 1   | 2   |\n|     |     |")
        #expect(row?.selectedRange == NSRange(location: 44, length: 0))
        let headerRow = MarkdownTableEditing.addRow(in: text as NSString, selection: NSRange(location: 2, length: 0))
        #expect(apply(headerRow, to: text) == "| a   | b   |\n| --- | --- |\n|     |     |\n| 1   | 2   |")
        let column = MarkdownTableEditing.addColumn(in: text as NSString, selection: NSRange(location: 2, length: 0))
        #expect(apply(column, to: text) == "| a   |     | b   |\n| --- | --- | --- |\n| 1   |     | 2   |")
        #expect(column?.selectedRange == NSRange(location: 8, length: 0))
    }

    @Test func insertsTableTemplate() {
        let headers = ["Column 1", "Column 2"]
        let empty = MarkdownTableEditing.insertTable(in: "" as NSString, selection: NSRange(location: 0, length: 0), headers: headers)
        #expect(apply(empty, to: "") == "| Column 1 | Column 2 |\n| -------- | -------- |\n|          |          |\n|          |          |")
        #expect(empty.selectedRange == NSRange(location: 2, length: 8))
        let afterText = MarkdownTableEditing.insertTable(in: "Text" as NSString, selection: NSRange(location: 2, length: 0), headers: ["A"])
        #expect(apply(afterText, to: "Text") == "Text\n\n| A   |\n| --- |\n|     |\n|     |")
        let middle = MarkdownTableEditing.insertTable(in: "Text\nMore" as NSString, selection: NSRange(location: 1, length: 0), headers: ["A"])
        #expect(apply(middle, to: "Text\nMore") == "Text\n\n| A   |\n| --- |\n|     |\n|     |\nMore")
        let emptyLine = MarkdownTableEditing.insertTable(in: "Text\n" as NSString, selection: NSRange(location: 5, length: 0), headers: ["A"])
        #expect(apply(emptyLine, to: "Text\n") == "Text\n\n| A   |\n| --- |\n|     |\n|     |")
    }
}

struct MarkdownTableOfContentsTests {
    @Test func collectsHeadingsOutsideCode() {
        let text = "---\ntitle: x\n---\n# Intro\n\n```\n# not a heading\n```\n## Use **Bold** `code`\nSetext\n======\nSub\n---\n- item\n---\n### [Link](https://a.org) snake_case\n"
        let entries = MarkdownTableOfContents.entries(in: text)
        #expect(entries.map(\.level) == [1, 2, 1, 2, 3])
        #expect(entries.map(\.title) == ["Intro", "Use Bold code", "Setext", "Sub", "Link snake_case"])
        #expect(entries.map(\.slug) == ["intro", "use-bold-code", "setext", "sub", "link-snake_case"])
    }

    @Test func buildsNestedList() {
        let entries = MarkdownTableOfContents.entries(in: "## A\n### B\n## A")
        #expect(MarkdownTableOfContents.block(for: entries) == "<!-- toc -->\n- [A](#a)\n  - [B](#b)\n- [A](#a-1)\n<!-- tocstop -->")
        #expect(MarkdownTableOfContents.block(for: []) == "<!-- toc -->\n<!-- tocstop -->")
    }

    @Test func insertsAndUpdatesTableOfContents() {
        let text = "\n# One"
        let inserted = MarkdownTableOfContents.update(in: text as NSString, selection: NSRange(location: 0, length: 0))
        let withTOC = inserted.applied(to: text)
        #expect(withTOC == "<!-- toc -->\n- [One](#one)\n<!-- tocstop -->\n\n# One")
        let extended = withTOC + "\n## Two"
        let caret = (extended as NSString).length
        let updated = MarkdownTableOfContents.update(in: extended as NSString, selection: NSRange(location: caret, length: 0))
        #expect(updated.applied(to: extended) == "<!-- toc -->\n- [One](#one)\n  - [Two](#two)\n<!-- tocstop -->\n\n# One\n## Two")
        #expect(updated.selectedRange.location == caret + 16)
        let onText = MarkdownTableOfContents.update(in: "# A\nText" as NSString, selection: NSRange(location: 5, length: 0))
        #expect(onText.applied(to: "# A\nText") == "# A\n<!-- toc -->\n- [A](#a)\n<!-- tocstop -->\n\nText")
    }
}
