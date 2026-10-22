import Foundation
import Testing
@testable import NoteCraftKit

struct TextStatisticsTests {
    @Test func countsCharactersWordsAndLines() {
        let statistics = TextStatistics.compute(for: "Hallo Welt 👋\nZweite Zeile\n")
        #expect(statistics == TextStatistics(characters: 26, words: 4, lines: 3))
    }

    @Test func treatsEmptyTextAsOneLine() {
        #expect(TextStatistics.compute(for: "") == TextStatistics(characters: 0, words: 0, lines: 1))
    }
}

struct OccurrenceSelectionTests {
    @Test func findsWordAroundCaret() {
        let text = "let foo_bar = 1" as NSString
        #expect(OccurrenceSelection.wordRange(at: 6, in: text) == NSRange(location: 4, length: 7))
        #expect(OccurrenceSelection.wordRange(at: 12, in: text) == nil)
        #expect(OccurrenceSelection.wordRange(at: 0, in: "" as NSString) == nil)
    }

    @Test func expandsEmptySelectionToWordFirst() {
        let text = "foo bar foo" as NSString
        #expect(OccurrenceSelection.addingNextOccurrence(to: [NSRange(location: 1, length: 0)], in: text) == [NSRange(location: 0, length: 3)])
    }

    @Test func addsNextOccurrenceAndWraps() {
        let text = "foo bar foo foo" as NSString
        var selections = [NSRange(location: 8, length: 3)]
        selections = OccurrenceSelection.addingNextOccurrence(to: selections, in: text)
        #expect(selections == [NSRange(location: 8, length: 3), NSRange(location: 12, length: 3)])
        selections = OccurrenceSelection.addingNextOccurrence(to: selections, in: text)
        #expect(selections == [NSRange(location: 0, length: 3), NSRange(location: 8, length: 3), NSRange(location: 12, length: 3)])
    }

    @Test func keepsSelectionsWhenNothingElseMatches() {
        let text = "foo bar" as NSString
        let selections = [NSRange(location: 0, length: 3)]
        #expect(OccurrenceSelection.addingNextOccurrence(to: selections, in: text) == selections)
        #expect(OccurrenceSelection.addingNextOccurrence(to: [], in: text) == [])
        #expect(OccurrenceSelection.addingNextOccurrence(to: [NSRange(location: 2, length: 0)], in: "a  b" as NSString) == [NSRange(location: 2, length: 0)])
    }

    @Test func selectsAllOccurrences() {
        let text = "ab ab abc" as NSString
        #expect(OccurrenceSelection.allOccurrences(of: NSRange(location: 0, length: 2), in: text).count == 3)
        #expect(OccurrenceSelection.allOccurrences(of: NSRange(location: 1, length: 0), in: text).count == 3)
        #expect(OccurrenceSelection.allOccurrences(of: NSRange(location: 1, length: 0), in: "a b" as NSString) == [NSRange(location: 0, length: 1)])
        #expect(OccurrenceSelection.allOccurrences(of: NSRange(location: 1, length: 0), in: " " as NSString) == [NSRange(location: 1, length: 0)])
    }
}
