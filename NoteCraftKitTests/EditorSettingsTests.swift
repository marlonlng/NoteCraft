import Foundation
import Testing
@testable import NoteCraftKit

struct EditorSettingsTests {
    @Test func roundTripsThroughJSON() throws {
        var settings = EditorSettings()
        settings.fontSize = 15
        settings.defaultEncoding = .utf16LittleEndian
        settings.defaultLineEnding = .crlf
        settings.darkThemeID = Theme.midnight.id
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(EditorSettings.self, from: data) == settings)
    }

    @Test func fillsMissingKeysWithDefaults() throws {
        let data = Data(#"{"fontSize": 18, "tabWidth": 2}"#.utf8)
        let settings = try JSONDecoder().decode(EditorSettings.self, from: data)
        #expect(settings.fontSize == 18)
        #expect(settings.tabWidth == 2)
        #expect(settings.showsLineNumbers)
        #expect(settings.defaultEncoding == .utf8)
    }

    @Test func ignoresUnknownEnumValues() throws {
        let data = Data(#"{"defaultEncoding": "ebcdic", "defaultLineEnding": "nel"}"#.utf8)
        let settings = try JSONDecoder().decode(EditorSettings.self, from: data)
        #expect(settings.defaultEncoding == .utf8)
        #expect(settings.defaultLineEnding == .lf)
    }

    @Test func clampsValuesToSupportedRanges() throws {
        let data = Data(#"{"fontSize": 400, "tabWidth": 0, "lineHeightMultiple": 9, "largeFileThreshold": 5}"#.utf8)
        let settings = try JSONDecoder().decode(EditorSettings.self, from: data)
        #expect(settings.fontSize == 72)
        #expect(settings.tabWidth == 1)
        #expect(settings.lineHeightMultiple == 2)
        #expect(settings.largeFileThreshold == 100_000)
    }

    @Test func selectsThemeForAppearance() {
        var settings = EditorSettings()
        #expect(settings.theme(isDark: false) == .paper)
        #expect(settings.theme(isDark: true) == .graphite)
        settings.lightThemeID = "missing"
        settings.darkThemeID = Theme.highContrastDark.id
        #expect(settings.theme(isDark: false) == .paper)
        #expect(settings.theme(isDark: true) == .highContrastDark)
    }

    @Test func derivesIndentation() {
        var settings = EditorSettings()
        settings.indentsWithTabs = true
        settings.tabWidth = 8
        #expect(settings.indentation == Indentation(usesTabs: true, width: 8))
    }

    @Test func preparesTextForSaving() {
        var settings = EditorSettings()
        #expect(settings.preparedForSaving("a  \nb") == "a  \nb")
        settings.trimsTrailingWhitespaceOnSave = true
        settings.ensuresTrailingNewlineOnSave = true
        #expect(settings.preparedForSaving("a  \nb") == "a\nb\n")
        #expect(settings.preparedForSaving("") == "")
    }
}

struct FuzzyMatcherTests {
    @Test func matchesCharactersInOrder() throws {
        let match = try #require(FuzzyMatcher.match("srt", in: "Sortieren"))
        #expect(match.matchedOffsets == [0, 2, 3])
        #expect(FuzzyMatcher.match("xyz", in: "Sortieren") == nil)
    }

    @Test func ignoresCaseDiacriticsAndSpaces() {
        #expect(FuzzyMatcher.match("zeilen ober", in: "Zeile nach oben verschieben") != nil)
        #expect(FuzzyMatcher.match("grosse", in: "Größe") == nil)
        #expect(FuzzyMatcher.match("grose", in: "Größe") != nil)
    }

    @Test func returnsZeroScoreForEmptyQuery() {
        #expect(FuzzyMatcher.match("  ", in: "Anything") == FuzzyMatch(score: 0, matchedOffsets: []))
    }

    @Test func prefersWordStartsAndConsecutiveMatches() throws {
        let wordStart = try #require(FuzzyMatcher.match("dup", in: "Zeile duplizieren"))
        let scattered = try #require(FuzzyMatcher.match("dup", in: "Dokument umbenennen per"))
        #expect(wordStart.score > scattered.score)
    }

    @Test func rewardsCamelCaseBoundaries() throws {
        let camel = try #require(FuzzyMatcher.match("fb", in: "fooBar"))
        let plain = try #require(FuzzyMatcher.match("fb", in: "foobar"))
        #expect(camel.score > plain.score)
    }

    @Test func ranksItemsByScoreKeepingOrderForTies() {
        let ranked = FuzzyMatcher.rank(["Kopieren", "Ersetzen", "In Dateien suchen", "Suchen"], query: "such") { $0 }
        #expect(ranked.map(\.item) == ["Suchen", "In Dateien suchen"])
        let all = FuzzyMatcher.rank(["b", "a"], query: "") { $0 }
        #expect(all.map(\.item) == ["b", "a"])
    }
}
