import Foundation

public struct SearchQuery: Equatable, Codable, Sendable {
    public var text: String
    public var isCaseSensitive: Bool
    public var matchesWholeWord: Bool
    public var usesRegularExpression: Bool

    public init(
        text: String,
        isCaseSensitive: Bool = false,
        matchesWholeWord: Bool = false,
        usesRegularExpression: Bool = false
    ) {
        self.text = text
        self.isCaseSensitive = isCaseSensitive
        self.matchesWholeWord = matchesWholeWord
        self.usesRegularExpression = usesRegularExpression
    }

    /// Compiles the query into a regular expression.
    ///
    /// - Throws: `SearchQueryError.emptyQuery` or `SearchQueryError.invalidRegularExpression`.
    public func makeRegularExpression() throws -> NSRegularExpression {
        guard !text.isEmpty else { throw SearchQueryError.emptyQuery }
        var pattern = usesRegularExpression ? text : NSRegularExpression.escapedPattern(for: text)
        if matchesWholeWord {
            pattern = #"(?<![\p{L}\p{N}_])(?:"# + pattern + #")(?![\p{L}\p{N}_])"#
        }
        var options: NSRegularExpression.Options = [.anchorsMatchLines]
        if !isCaseSensitive {
            options.insert(.caseInsensitive)
        }
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            throw SearchQueryError.invalidRegularExpression(pattern: text)
        }
    }
}

public enum SearchQueryError: Error, Equatable, Sendable {
    case emptyQuery
    case invalidRegularExpression(pattern: String)
}
