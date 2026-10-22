import Foundation

public enum SearchDirection: Sendable {
    case forward
    case backward
}

public struct ReplaceAllResult: Equatable, Sendable {
    public let text: String
    public let replacementCount: Int

    public init(text: String, replacementCount: Int) {
        self.text = text
        self.replacementCount = replacementCount
    }
}

public struct TextSearcher: @unchecked Sendable {
    public let query: SearchQuery
    private let regularExpression: NSRegularExpression

    /// Creates a searcher for `query`.
    ///
    /// - Throws: `SearchQueryError` when the query is empty or not a valid regular expression.
    public init(query: SearchQuery) throws {
        self.query = query
        regularExpression = try query.makeRegularExpression()
    }

    /// Returns all non-empty matches in `text`, optionally limited to `range`.
    public func matches(in text: String, range: NSRange? = nil, limit: Int = .max) -> [NSRange] {
        matches(in: text as NSString, range: range, limit: limit)
    }

    /// Returns all non-empty matches in `text`, optionally limited to `range`.
    public func matches(in text: NSString, range: NSRange? = nil, limit: Int = .max) -> [NSRange] {
        let searchRange = range ?? NSRange(location: 0, length: text.length)
        var result: [NSRange] = []
        regularExpression.enumerateMatches(in: text as String, options: [], range: searchRange) { match, _, stop in
            guard let match, match.range.length > 0 else { return }
            result.append(match.range)
            if result.count >= limit {
                stop.pointee = true
            }
        }
        return result
    }

    /// Returns the next match starting the search at `location` in `direction`.
    ///
    /// When `wrapsAround` is true the search continues at the other end of the text.
    public func nextMatch(
        in text: NSString,
        from location: Int,
        direction: SearchDirection,
        wrapsAround: Bool,
        within range: NSRange? = nil
    ) -> NSRange? {
        let scope = range ?? NSRange(location: 0, length: text.length)
        let clamped = min(max(location, scope.location), NSMaxRange(scope))
        switch direction {
        case .forward:
            let tail = NSRange(location: clamped, length: NSMaxRange(scope) - clamped)
            if let match = matches(in: text, range: tail, limit: 1).first {
                return match
            }
            return wrapsAround ? matches(in: text, range: scope, limit: 1).first : nil
        case .backward:
            let head = NSRange(location: scope.location, length: clamped - scope.location)
            if let match = matches(in: text, range: head).last {
                return match
            }
            return wrapsAround ? matches(in: text, range: scope).last : nil
        }
    }

    /// Returns the text that replaces `match`, expanding `$1`-style references in regular expression mode.
    public func replacementText(for match: NSRange, in text: NSString, template: String) -> String {
        guard query.usesRegularExpression,
              let result = regularExpression.firstMatch(in: text as String, options: [], range: match) else {
            return template
        }
        return regularExpression.replacementString(for: result, in: text as String, offset: 0, template: template)
    }

    /// Replaces every match in `text`, optionally limited to `range`.
    public func replaceAll(in text: String, with template: String, within range: NSRange? = nil) -> ReplaceAllResult {
        let nsText = text as NSString
        let searchRange = range ?? NSRange(location: 0, length: nsText.length)
        let effectiveTemplate = query.usesRegularExpression ? template : NSRegularExpression.escapedTemplate(for: template)
        let mutable = NSMutableString(string: nsText)
        let count = regularExpression.replaceMatches(
            in: mutable,
            options: [],
            range: searchRange,
            withTemplate: effectiveTemplate
        )
        return ReplaceAllResult(text: mutable as String, replacementCount: count)
    }
}
