import Foundation

public struct SyntaxToken: Equatable, Sendable {
    public let range: NSRange
    public let kind: TokenKind

    public init(range: NSRange, kind: TokenKind) {
        self.range = range
        self.kind = kind
    }
}

public final class SyntaxHighlighter: @unchecked Sendable {
    public let language: Language
    private let regularExpression: NSRegularExpression?
    private let groupNames: [(name: String, kind: TokenKind)]

    /// Creates a highlighter for `language`.
    ///
    /// - Throws: An error when a rule of the language is not a valid regular expression.
    public init(language: Language) throws {
        self.language = language
        guard !language.rules.isEmpty else {
            regularExpression = nil
            groupNames = []
            return
        }
        var names: [(String, TokenKind)] = []
        var alternatives: [String] = []
        for (index, rule) in language.rules.enumerated() {
            let name = "r\(index)"
            names.append((name, rule.kind))
            alternatives.append("(?<\(name)>\(rule.pattern))")
        }
        regularExpression = try NSRegularExpression(
            pattern: alternatives.joined(separator: "|"),
            options: [.anchorsMatchLines]
        )
        groupNames = names
    }

    /// Returns the tokens of `text`, limited to matches that intersect `range` when given.
    public func tokens(in text: String, range: NSRange? = nil) -> [SyntaxToken] {
        guard let regularExpression else { return [] }
        let nsText = text as NSString
        let searchRange = range ?? NSRange(location: 0, length: nsText.length)
        var tokens: [SyntaxToken] = []
        regularExpression.enumerateMatches(in: text, options: [], range: searchRange) { match, _, _ in
            guard let match, match.range.length > 0 else { return }
            for group in groupNames {
                let groupRange = match.range(withName: group.name)
                if groupRange.location != NSNotFound {
                    tokens.append(SyntaxToken(range: groupRange, kind: group.kind))
                    break
                }
            }
        }
        return tokens
    }
}

public final class SyntaxHighlighterCache: @unchecked Sendable {
    public static let shared = SyntaxHighlighterCache()
    private let lock = NSLock()
    private var highlighters: [String: SyntaxHighlighter] = [:]

    /// Returns a cached highlighter for `language`, compiling it on first use.
    public func highlighter(for language: Language) -> SyntaxHighlighter? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = highlighters[language.id] {
            return cached
        }
        guard let highlighter = try? SyntaxHighlighter(language: language) else { return nil }
        highlighters[language.id] = highlighter
        return highlighter
    }
}
