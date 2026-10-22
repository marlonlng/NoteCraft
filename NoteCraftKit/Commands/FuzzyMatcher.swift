import Foundation

public struct FuzzyMatch: Equatable, Sendable {
    public let score: Int
    public let matchedOffsets: [Int]

    public init(score: Int, matchedOffsets: [Int]) {
        self.score = score
        self.matchedOffsets = matchedOffsets
    }
}

public enum FuzzyMatcher {
    /// Matches the characters of `query` in order inside `candidate`, ignoring case and diacritics.
    ///
    /// Consecutive characters, word starts and camel case boundaries raise the score, gaps and a late start lower it.
    /// Every occurrence of the first query character is tried as a starting point and the best result wins.
    /// - Returns: `nil` when not every query character occurs in order.
    public static func match(_ query: String, in candidate: String) -> FuzzyMatch? {
        let needle = Array(fold(query).filter { !$0.isWhitespace })
        guard !needle.isEmpty else { return FuzzyMatch(score: 0, matchedOffsets: []) }
        let original = Array(candidate)
        let haystack = original.map { fold(String($0)).first ?? $0 }
        var best: FuzzyMatch?
        for start in haystack.indices where haystack[start] == needle[0] {
            guard let candidateMatch = greedyMatch(needle, haystack: haystack, original: original, start: start) else { break }
            if best == nil || candidateMatch.score > best!.score {
                best = candidateMatch
            }
        }
        return best
    }

    /// Returns the candidates that match `query`, best match first.
    public static func rank<Item>(_ items: [Item], query: String, text: (Item) -> String) -> [(item: Item, match: FuzzyMatch)] {
        items.compactMap { item -> (Item, FuzzyMatch)? in
            guard let match = match(query, in: text(item)) else { return nil }
            return (item, match)
        }
        .enumerated()
        .sorted { lhs, rhs in
            lhs.element.1.score == rhs.element.1.score ? lhs.offset < rhs.offset : lhs.element.1.score > rhs.element.1.score
        }
        .map { (item: $0.element.0, match: $0.element.1) }
    }

    private static func greedyMatch(_ needle: [Character], haystack: [Character], original: [Character], start: Int) -> FuzzyMatch? {
        var offsets: [Int] = []
        var score = 0
        var needleIndex = 0
        var offset = start
        while offset < haystack.count, needleIndex < needle.count {
            if haystack[offset] == needle[needleIndex] {
                score += 1
                if let previous = offsets.last {
                    let gap = offset - previous - 1
                    score += gap == 0 ? 6 : -min(gap, 3)
                }
                if offset == 0 || !(original[offset - 1].isLetter || original[offset - 1].isNumber) {
                    score += 5
                } else if original[offset].isUppercase, original[offset - 1].isLowercase {
                    score += 4
                }
                offsets.append(offset)
                needleIndex += 1
            }
            offset += 1
        }
        guard needleIndex == needle.count else { return nil }
        score -= min(start, 5)
        score -= max(0, haystack.count - needle.count) / 8
        return FuzzyMatch(score: score, matchedOffsets: offsets)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
