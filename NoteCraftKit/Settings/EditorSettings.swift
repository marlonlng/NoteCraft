import Foundation

public enum MarkdownScrollSync: String, CaseIterable, Codable, Sendable {
    case both
    case previewFollowsEditor
    case independent
}

public struct EditorSettings: Equatable, Codable, Sendable {
    public static let fontSizeRange: ClosedRange<Double> = 8...72
    public static let tabWidthRange: ClosedRange<Int> = 1...16
    public static let systemFontName = ""

    public var fontName: String = EditorSettings.systemFontName
    public var fontSize: Double = 13
    public var lineHeightMultiple: Double = 1.2
    public var tabWidth: Int = 4
    public var indentsWithTabs: Bool = false
    public var detectsIndentation: Bool = true
    public var showsLineNumbers: Bool = true
    public var highlightsCurrentLine: Bool = true
    public var showsInvisibleCharacters: Bool = false
    public var wrapsLines: Bool = true
    public var autoIndents: Bool = true
    public var closesBrackets: Bool = true
    public var highlightsMatchingBrackets: Bool = true
    public var checksSpelling: Bool = false
    public var lightThemeID: String = Theme.paper.id
    public var darkThemeID: String = Theme.graphite.id
    public var defaultEncoding: TextEncoding = .utf8
    public var fallbackEncoding: TextEncoding = .windows1252
    public var defaultLineEnding: LineEnding = .lf
    public var reloadsUnmodifiedDocuments: Bool = true
    public var opensDocumentsInTabs: Bool = true
    public var restoresSession: Bool = true
    public var trimsTrailingWhitespaceOnSave: Bool = false
    public var ensuresTrailingNewlineOnSave: Bool = false
    public var largeFileThreshold: Int = 5_000_000
    public var opensMarkdownPreview: Bool = true
    public var markdownScrollSync: MarkdownScrollSync = .both
    public var loadsExternalContent: Bool = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = EditorSettings()
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? defaults.fontName
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? defaults.fontSize
        lineHeightMultiple = try container.decodeIfPresent(Double.self, forKey: .lineHeightMultiple) ?? defaults.lineHeightMultiple
        tabWidth = try container.decodeIfPresent(Int.self, forKey: .tabWidth) ?? defaults.tabWidth
        indentsWithTabs = try container.decodeIfPresent(Bool.self, forKey: .indentsWithTabs) ?? defaults.indentsWithTabs
        detectsIndentation = try container.decodeIfPresent(Bool.self, forKey: .detectsIndentation) ?? defaults.detectsIndentation
        showsLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .showsLineNumbers) ?? defaults.showsLineNumbers
        highlightsCurrentLine = try container.decodeIfPresent(Bool.self, forKey: .highlightsCurrentLine) ?? defaults.highlightsCurrentLine
        showsInvisibleCharacters = try container.decodeIfPresent(Bool.self, forKey: .showsInvisibleCharacters)
            ?? defaults.showsInvisibleCharacters
        wrapsLines = try container.decodeIfPresent(Bool.self, forKey: .wrapsLines) ?? defaults.wrapsLines
        autoIndents = try container.decodeIfPresent(Bool.self, forKey: .autoIndents) ?? defaults.autoIndents
        closesBrackets = try container.decodeIfPresent(Bool.self, forKey: .closesBrackets) ?? defaults.closesBrackets
        highlightsMatchingBrackets = try container.decodeIfPresent(Bool.self, forKey: .highlightsMatchingBrackets)
            ?? defaults.highlightsMatchingBrackets
        checksSpelling = try container.decodeIfPresent(Bool.self, forKey: .checksSpelling) ?? defaults.checksSpelling
        lightThemeID = try container.decodeIfPresent(String.self, forKey: .lightThemeID) ?? defaults.lightThemeID
        darkThemeID = try container.decodeIfPresent(String.self, forKey: .darkThemeID) ?? defaults.darkThemeID
        defaultEncoding = (try? container.decodeIfPresent(TextEncoding.self, forKey: .defaultEncoding)) ?? defaults.defaultEncoding
        fallbackEncoding = (try? container.decodeIfPresent(TextEncoding.self, forKey: .fallbackEncoding)) ?? defaults.fallbackEncoding
        defaultLineEnding = (try? container.decodeIfPresent(LineEnding.self, forKey: .defaultLineEnding)) ?? defaults.defaultLineEnding
        reloadsUnmodifiedDocuments = try container.decodeIfPresent(Bool.self, forKey: .reloadsUnmodifiedDocuments)
            ?? defaults.reloadsUnmodifiedDocuments
        opensDocumentsInTabs = try container.decodeIfPresent(Bool.self, forKey: .opensDocumentsInTabs) ?? defaults.opensDocumentsInTabs
        restoresSession = try container.decodeIfPresent(Bool.self, forKey: .restoresSession) ?? defaults.restoresSession
        trimsTrailingWhitespaceOnSave = try container.decodeIfPresent(Bool.self, forKey: .trimsTrailingWhitespaceOnSave)
            ?? defaults.trimsTrailingWhitespaceOnSave
        ensuresTrailingNewlineOnSave = try container.decodeIfPresent(Bool.self, forKey: .ensuresTrailingNewlineOnSave)
            ?? defaults.ensuresTrailingNewlineOnSave
        largeFileThreshold = try container.decodeIfPresent(Int.self, forKey: .largeFileThreshold) ?? defaults.largeFileThreshold
        opensMarkdownPreview = try container.decodeIfPresent(Bool.self, forKey: .opensMarkdownPreview) ?? defaults.opensMarkdownPreview
        markdownScrollSync = (try? container.decodeIfPresent(MarkdownScrollSync.self, forKey: .markdownScrollSync)) ?? defaults.markdownScrollSync
        loadsExternalContent = try container.decodeIfPresent(Bool.self, forKey: .loadsExternalContent) ?? defaults.loadsExternalContent
        clamp()
    }

    /// Restricts numeric values to their supported ranges.
    public mutating func clamp() {
        fontSize = min(max(fontSize, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        tabWidth = min(max(tabWidth, Self.tabWidthRange.lowerBound), Self.tabWidthRange.upperBound)
        lineHeightMultiple = min(max(lineHeightMultiple, 1), 2)
        largeFileThreshold = max(100_000, largeFileThreshold)
    }

    public var indentation: Indentation {
        Indentation(usesTabs: indentsWithTabs, width: tabWidth)
    }

    /// The theme for the given appearance, falling back to the built-in default.
    public func theme(isDark: Bool) -> Theme {
        if isDark {
            return Theme.theme(withID: darkThemeID) ?? .graphite
        }
        return Theme.theme(withID: lightThemeID) ?? .paper
    }

    /// Prepares `text` for saving according to the save options.
    public func preparedForSaving(_ text: String) -> String {
        var result = text
        if trimsTrailingWhitespaceOnSave {
            result = (try? TextTransformation.trimTrailingWhitespace.apply(to: result)) ?? result
        }
        if ensuresTrailingNewlineOnSave, !result.isEmpty, !result.hasSuffix("\n") {
            result += "\n"
        }
        return result
    }
}
