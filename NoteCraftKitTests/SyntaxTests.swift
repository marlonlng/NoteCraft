import Foundation
import Testing
@testable import NoteCraftKit

struct LanguageTests {
    @Test(arguments: LanguageCatalog.all)
    func compilesHighlighter(language: Language) throws {
        let highlighter = try SyntaxHighlighter(language: language)
        _ = highlighter.tokens(in: "sample text 123 \"quoted\" // comment\n# heading\n")
    }

    @Test func hasUniqueIdentifiers() {
        let identifiers = LanguageCatalog.all.map(\.id)
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test func doesNotShareFileExtensions() {
        let extensions = LanguageCatalog.all.flatMap(\.fileExtensions)
        #expect(Set(extensions).count == extensions.count)
    }

    @Test(arguments: [
        ("main.swift", "swift"),
        ("index.HTML", "html"),
        ("Makefile", "makefile"),
        ("Dockerfile", "dockerfile"),
        (".zshrc", "shell"),
        ("Gemfile", "ruby"),
        ("data.json", "json"),
        ("notes.txt", "plaintext"),
        ("config.yml", "yaml"),
        ("run.bat", "batch")
    ])
    func detectsLanguageFromFileName(fileName: String, expected: String) {
        #expect(Language.detect(fileName: fileName, content: "").id == expected)
    }

    @Test func detectsLanguageFromShebang() {
        #expect(Language.detect(fileName: "script", content: "#!/usr/bin/env python3\nprint()").id == "python")
        #expect(Language.detect(fileName: nil, content: "#!/bin/zsh\necho").id == "shell")
        #expect(Language.detect(fileName: nil, content: "#!/usr/bin/env -S node --flag\n").id == "javascript")
        #expect(Language.detect(fileName: nil, content: "#!/usr/bin/env\n").id == "plaintext")
    }

    @Test func detectsMarkupFromContent() {
        #expect(Language.detect(fileName: nil, content: "<?xml version=\"1.0\"?>").id == "xml")
        #expect(Language.detect(fileName: nil, content: "<!DOCTYPE html>").id == "html")
        #expect(Language.detect(fileName: nil, content: "hello").id == "plaintext")
    }

    @Test func looksUpLanguageByIdentifier() {
        #expect(Language.language(withID: "rust")?.name == "Rust")
        #expect(Language.language(withID: "cobol") == nil)
    }

    @Test func comparesLanguagesByIdentifier() {
        #expect(LanguageCatalog.swift == Language.language(withID: "swift"))
        #expect(Set([LanguageCatalog.swift, LanguageCatalog.swift]).count == 1)
    }
}

struct SyntaxHighlighterTests {
    private func kinds(_ language: Language, _ text: String) throws -> [(String, TokenKind)] {
        let highlighter = try SyntaxHighlighter(language: language)
        let nsText = text as NSString
        return highlighter.tokens(in: text).map { (nsText.substring(with: $0.range), $0.kind) }
    }

    @Test func highlightsSwift() throws {
        let tokens = try kinds(LanguageCatalog.swift, "let x: Int = 42 // if\n\"func\" @MainActor")
        #expect(tokens.contains { $0 == ("let", .keyword) })
        #expect(tokens.contains { $0 == ("Int", .type) })
        #expect(tokens.contains { $0 == ("42", .number) })
        #expect(tokens.contains { $0 == ("// if", .comment) })
        #expect(tokens.contains { $0 == ("\"func\"", .string) })
        #expect(tokens.contains { $0 == ("@MainActor", .attribute) })
        #expect(!tokens.contains { $0.0 == "if" })
    }

    @Test func highlightsMultilineBlockComments() throws {
        let tokens = try kinds(LanguageCatalog.c, "/* a\nint b */ int c;")
        #expect(tokens.first! == ("/* a\nint b */", .comment))
        #expect(tokens.contains { $0 == ("int", .type) })
    }

    @Test func highlightsCaseInsensitiveKeywords() throws {
        let tokens = try kinds(LanguageCatalog.sql, "select * FROM users -- note")
        #expect(tokens.contains { $0 == ("select", .keyword) })
        #expect(tokens.contains { $0 == ("FROM", .keyword) })
        #expect(tokens.contains { $0 == ("-- note", .comment) })
    }

    @Test func highlightsMarkdown() throws {
        let tokens = try kinds(LanguageCatalog.markdown, "# Title\nSome **bold** and [link](https://x.y)\n- item")
        #expect(tokens.contains { $0 == ("# Title", .heading) })
        #expect(tokens.contains { $0 == ("**bold**", .emphasis) })
        #expect(tokens.contains { $0 == ("[link](https://x.y)", .link) })
        #expect(tokens.contains { $0 == ("-", .keyword) })
    }

    @Test func highlightsDiff() throws {
        let tokens = try kinds(LanguageCatalog.diff, "--- a\n+++ b\n@@ -1 +1 @@\n-old\n+new")
        #expect(tokens.map(\.1) == [.heading, .heading, .directive, .deleted, .inserted])
    }

    @Test func highlightsJSONKeysAndValues() throws {
        let tokens = try kinds(LanguageCatalog.json, #"{"key": "value", "n": -1.5e3, "b": true}"#)
        #expect(tokens.contains { $0 == ("\"key\"", .attribute) })
        #expect(tokens.contains { $0 == ("\"value\"", .string) })
        #expect(tokens.contains { $0 == ("true", .constant) })
    }

    @Test func limitsTokensToRange() throws {
        let highlighter = try SyntaxHighlighter(language: LanguageCatalog.swift)
        let tokens = highlighter.tokens(in: "let a\nlet b", range: NSRange(location: 6, length: 5))
        #expect(tokens.count == 1)
        #expect(tokens.first?.range == NSRange(location: 6, length: 3))
    }

    @Test func returnsNoTokensForPlainText() throws {
        let highlighter = try SyntaxHighlighter(language: .plainText)
        #expect(highlighter.tokens(in: "let x = 1").isEmpty)
    }

    @Test func cachesHighlighters() {
        let cache = SyntaxHighlighterCache()
        let first = cache.highlighter(for: LanguageCatalog.python)
        let second = cache.highlighter(for: LanguageCatalog.python)
        #expect(first != nil)
        #expect(first === second)
        let broken = Language(id: "broken", name: "Broken", rules: [HighlightRule("(", .keyword)])
        #expect(cache.highlighter(for: broken) == nil)
    }
}

struct ThemeTests {
    @Test func parsesAndFormatsHexColors() throws {
        let color = try #require(HexColor(hex: "#336699"))
        #expect(color.hexString == "#336699")
        let translucent = try #require(HexColor(hex: "33669980"))
        #expect(translucent.hexString == "#33669980")
        #expect(HexColor(hex: "#12") == nil)
        #expect(HexColor(hex: "#GGGGGG") == nil)
    }

    @Test func computesContrastRatio() {
        let black = HexColor(red: 0, green: 0, blue: 0)
        let white = HexColor(red: 1, green: 1, blue: 1)
        #expect(abs(black.contrastRatio(with: white) - 21) < 0.01)
        #expect(abs(white.contrastRatio(with: white) - 1) < 0.01)
    }

    @Test(arguments: Theme.all)
    func meetsTextContrastRequirements(theme: Theme) {
        let minimum = theme.id.hasPrefix("highContrast") ? 7.0 : 4.5
        #expect(theme.text.contrastRatio(with: theme.background) >= minimum)
        for kind in TokenKind.allCases {
            let ratio = theme.color(for: kind).contrastRatio(with: theme.background)
            #expect(ratio >= minimum, "\(theme.id) \(kind) \(ratio)")
        }
        #expect(theme.lineNumber.contrastRatio(with: theme.background) >= 3)
    }

    @Test func providesLightAndDarkThemes() {
        #expect(Theme.all.contains { $0.isDark })
        #expect(Theme.all.contains { !$0.isDark })
        #expect(Theme.theme(withID: "graphite")?.isDark == true)
        #expect(Theme.theme(withID: "missing") == nil)
    }

    @Test func fallsBackForInvalidColors() {
        let theme = Theme(
            id: "test", isDark: false, background: "x", text: "y", selection: "z", currentLine: "", lineNumber: "",
            currentLineNumber: "", invisibles: "", matchHighlight: "", tokens: [.keyword: "nope"]
        )
        #expect(theme.background == HexColor(red: 1, green: 1, blue: 1))
        #expect(theme.color(for: .keyword) == theme.text)
    }
}
