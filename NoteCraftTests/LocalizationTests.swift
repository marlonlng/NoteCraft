import Foundation
import NoteCraftKit
import Testing
@testable import NoteCraft

@MainActor
struct LocalizationTests {
    private func table(_ name: String, localization: String) throws -> [String: String] {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: "strings", subdirectory: nil, localization: localization))
        return try #require(NSDictionary(contentsOf: url) as? [String: String])
    }

    private func specifiers(in text: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(lld|@)"#)
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    @Test func usesEnglishAsDevelopmentLanguage() {
        #expect(Bundle.main.developmentLocalization == "en")
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String] == ["en", "de"])
        #expect(L10n.Menu.file == "File")
    }

    @Test func shipsLocalizationFolderForEveryLanguage() {
        for localization in ["en", "de"] {
            #expect(Bundle.main.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: nil, localization: localization) != nil, "\(localization)")
        }
    }

    @Test func translatesInterfaceToGerman() throws {
        let german = try table("Localizable", localization: "de")
        let samples = [
            L10n.App.settings, L10n.Menu.file, L10n.Menu.findAndReplace, L10n.Transformation.title(for: .formatJSON),
            L10n.Find.noMatches, L10n.Settings.restoresSessionHelp, L10n.Alert.reopenTitle, L10n.Help.intro,
            L10n.Accessibility.editor, L10n.ThemePreview.comment, TextEncoding.windows1252.displayName, Theme.paper.displayName
        ]
        for sample in samples {
            #expect(german[sample] != nil, "\(sample)")
        }
        #expect(german["Find"] == "Suchen")
        #expect(german["%lld of %lld"] == "%lld von %lld")
        #expect(german.count > 300)
    }

    @Test func keepsFormatSpecifiersInTranslations() throws {
        for (key, value) in try table("Localizable", localization: "de") {
            #expect(!value.isEmpty, "\(key)")
            #expect(specifiers(in: key).sorted() == specifiers(in: value).sorted(), "\(key)")
        }
    }

    @Test func translatesDocumentTypes() throws {
        let german = try table("InfoPlist", localization: "de")
        #expect(german["Text Document"] == "Textdokument")
        #expect(german["File"] == "Datei")
    }
}
