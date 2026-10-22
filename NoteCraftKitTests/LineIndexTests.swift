import Foundation
import Testing
@testable import NoteCraftKit

struct LineIndexTests {
    @Test func indexesLineStarts() {
        let index = LineIndex(text: "ab\ncd\n\nef")
        #expect(index.lineStarts == [0, 3, 6, 7])
        #expect(index.lineCount == 4)
    }

    @Test func countsTrailingEmptyLine() {
        #expect(LineIndex(text: "a\n").lineCount == 2)
        #expect(LineIndex(text: "").lineCount == 1)
    }

    @Test func mapsOffsetsToPositions() {
        let index = LineIndex(text: "ab\ncd\nef")
        #expect(index.lineNumber(at: 0) == 1)
        #expect(index.lineNumber(at: 2) == 1)
        #expect(index.lineNumber(at: 3) == 2)
        #expect(index.position(at: 4) == TextPosition(line: 2, column: 2))
        #expect(index.position(at: 100) == TextPosition(line: 3, column: 3))
        #expect(index.position(at: -5) == TextPosition(line: 1, column: 1))
    }

    @Test func returnsLineRanges() {
        let index = LineIndex(text: "ab\ncd\nef")
        #expect(index.range(ofLine: 1) == NSRange(location: 0, length: 2))
        #expect(index.range(ofLine: 3) == NSRange(location: 6, length: 2))
        #expect(index.range(ofLine: 0) == nil)
        #expect(index.range(ofLine: 4) == nil)
    }

    @Test func convertsLineAndColumnToOffset() {
        let index = LineIndex(text: "ab\ncd\nef")
        #expect(index.offset(line: 2, column: 2) == 4)
        #expect(index.offset(line: 2, column: 99) == 5)
        #expect(index.offset(line: 9, column: 1) == nil)
    }

    @Test func handlesLongTextAcrossChunks() {
        let text = String(repeating: "x\n", count: 20_000)
        let index = LineIndex(text: text)
        #expect(index.lineCount == 20_001)
        #expect(index.lineNumber(at: 39_999) == 20_000)
    }

    @Test func updatesIncrementallyForInsertion() {
        let original = "ab\ncd\nef"
        var index = LineIndex(text: original)
        let updated = "ab\nc\nX\nd\nef"
        index.applyEdit(editedRange: NSRange(location: 4, length: 3), changeInLength: 3, in: updated as NSString)
        #expect(index == LineIndex(text: updated))
    }

    @Test func updatesIncrementallyForDeletion() {
        var index = LineIndex(text: "ab\ncd\nef\ngh")
        let updated = "ab\ngh"
        index.applyEdit(editedRange: NSRange(location: 3, length: 0), changeInLength: -6, in: updated as NSString)
        #expect(index == LineIndex(text: updated))
    }

    @Test func matchesFullRebuildForRandomEdits() {
        var generator = SystemRandomNumberGenerator()
        var text = "line one\nline two\n\nline four\n"
        var index = LineIndex(text: text)
        let fragments = ["", "a", "\n", "xy\nz", "\n\n", "longer fragment\nwith lines\n"]
        for _ in 0..<300 {
            let nsText = text as NSString
            let location = Int.random(in: 0...nsText.length, using: &generator)
            let length = Int.random(in: 0...min(6, nsText.length - location), using: &generator)
            let fragment = fragments.randomElement(using: &generator)!
            text = nsText.replacingCharacters(in: NSRange(location: location, length: length), with: fragment)
            let newLength = (fragment as NSString).length
            index.applyEdit(
                editedRange: NSRange(location: location, length: newLength),
                changeInLength: newLength - length,
                in: text as NSString
            )
            #expect(index == LineIndex(text: text))
        }
    }
}
