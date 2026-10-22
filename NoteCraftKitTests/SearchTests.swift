import Foundation
import Testing
@testable import NoteCraftKit

struct SearchQueryTests {
    @Test func rejectsEmptyQuery() {
        #expect(throws: SearchQueryError.emptyQuery) {
            try SearchQuery(text: "").makeRegularExpression()
        }
    }

    @Test func rejectsInvalidRegularExpression() {
        #expect(throws: SearchQueryError.invalidRegularExpression(pattern: "(a")) {
            try SearchQuery(text: "(a", usesRegularExpression: true).makeRegularExpression()
        }
    }

    @Test func escapesLiteralQueries() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "a.b"))
        #expect(searcher.matches(in: "a.b axb") == [NSRange(location: 0, length: 3)])
    }
}

struct TextSearcherTests {
    @Test func ignoresCaseByDefault() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "note"))
        #expect(searcher.matches(in: "Note NOTE note").count == 3)
    }

    @Test func respectsCaseSensitivity() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "Note", isCaseSensitive: true))
        #expect(searcher.matches(in: "Note NOTE note") == [NSRange(location: 0, length: 4)])
    }

    @Test func matchesWholeWordsIncludingUmlauts() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "für", matchesWholeWord: true))
        #expect(searcher.matches(in: "für fürs Gefühl für") == [NSRange(location: 0, length: 3), NSRange(location: 16, length: 3)])
    }

    @Test func anchorsMatchLines() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "^b", usesRegularExpression: true))
        #expect(searcher.matches(in: "a\nb\nb") == [NSRange(location: 2, length: 1), NSRange(location: 4, length: 1)])
    }

    @Test func limitsMatches() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "a"))
        #expect(searcher.matches(in: "aaaa", limit: 2).count == 2)
    }

    @Test func skipsEmptyMatches() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "x*", usesRegularExpression: true))
        #expect(searcher.matches(in: "ab xx") == [NSRange(location: 3, length: 2)])
    }

    @Test func findsNextMatchForwardWithWrapping() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "ab"))
        let text = "ab cd ab" as NSString
        #expect(searcher.nextMatch(in: text, from: 1, direction: .forward, wrapsAround: false) == NSRange(location: 6, length: 2))
        #expect(searcher.nextMatch(in: text, from: 7, direction: .forward, wrapsAround: true) == NSRange(location: 0, length: 2))
        #expect(searcher.nextMatch(in: text, from: 7, direction: .forward, wrapsAround: false) == nil)
    }

    @Test func findsPreviousMatchBackwardWithWrapping() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "ab"))
        let text = "ab cd ab" as NSString
        #expect(searcher.nextMatch(in: text, from: 6, direction: .backward, wrapsAround: false) == NSRange(location: 0, length: 2))
        #expect(searcher.nextMatch(in: text, from: 0, direction: .backward, wrapsAround: true) == NSRange(location: 6, length: 2))
        #expect(searcher.nextMatch(in: text, from: 0, direction: .backward, wrapsAround: false) == nil)
    }

    @Test func searchesWithinScope() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "a"))
        let text = "a a a a" as NSString
        let scope = NSRange(location: 2, length: 3)
        #expect(searcher.nextMatch(in: text, from: 5, direction: .forward, wrapsAround: true, within: scope) == NSRange(location: 2, length: 1))
    }

    @Test func expandsCaptureGroupsInReplacement() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: #"(\w+)@(\w+)"#, usesRegularExpression: true))
        let text = "mail: max@example" as NSString
        let match = try #require(searcher.matches(in: text).first)
        #expect(searcher.replacementText(for: match, in: text, template: "$2 at $1") == "example at max")
    }

    @Test func usesLiteralReplacementOutsideRegularExpressionMode() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "a"))
        let text = "a" as NSString
        #expect(searcher.replacementText(for: NSRange(location: 0, length: 1), in: text, template: "$1") == "$1")
        #expect(searcher.replaceAll(in: "a b a", with: "$0").text == "$0 b $0")
    }

    @Test func replacesAllMatches() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: #"\d+"#, usesRegularExpression: true))
        let result = searcher.replaceAll(in: "a1 b22 c333", with: "#")
        #expect(result == ReplaceAllResult(text: "a# b# c#", replacementCount: 3))
    }

    @Test func replacesAllWithinRange() throws {
        let searcher = try TextSearcher(query: SearchQuery(text: "x"))
        let result = searcher.replaceAll(in: "x x x", with: "y", within: NSRange(location: 1, length: 3))
        #expect(result == ReplaceAllResult(text: "x y x", replacementCount: 1))
    }
}
