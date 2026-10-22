import Foundation

public struct TextStatistics: Equatable, Sendable {
    public let characters: Int
    public let words: Int
    public let lines: Int

    public init(characters: Int, words: Int, lines: Int) {
        self.characters = characters
        self.words = words
        self.lines = lines
    }

    /// Counts characters (grapheme clusters), words and lines of `text`.
    public static func compute(for text: String) -> TextStatistics {
        var words = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            words += 1
        }
        let lines = text.isEmpty ? 1 : text.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
        return TextStatistics(characters: text.count, words: words, lines: lines)
    }
}

public enum OccurrenceSelection {
    /// Returns the word surrounding `location`, or `nil` when the caret is not inside a word.
    public static func wordRange(at location: Int, in text: NSString) -> NSRange? {
        guard text.length > 0 else { return nil }
        let isWordCharacter: (unichar) -> Bool = { character in
            guard let scalar = Unicode.Scalar(character) else { return false }
            return CharacterSet.alphanumerics.contains(scalar) || character == 0x5F
        }
        var start = min(location, text.length)
        var end = start
        while start > 0, isWordCharacter(text.character(at: start - 1)) {
            start -= 1
        }
        while end < text.length, isWordCharacter(text.character(at: end)) {
            end += 1
        }
        return end > start ? NSRange(location: start, length: end - start) : nil
    }

    /// Returns the selection extended by the next occurrence of the selected text.
    ///
    /// An empty selection is first expanded to the word at the caret.
    public static func addingNextOccurrence(to selections: [NSRange], in text: NSString) -> [NSRange] {
        guard let last = selections.last else { return selections }
        if selections.count == 1, last.length == 0 {
            return wordRange(at: last.location, in: text).map { [$0] } ?? selections
        }
        let needle = text.substring(with: last)
        guard !needle.isEmpty else { return selections }
        let after = NSRange(location: NSMaxRange(last), length: text.length - NSMaxRange(last))
        var candidate = text.range(of: needle, options: .literal, range: after)
        if candidate.location == NSNotFound {
            candidate = text.range(of: needle, options: .literal, range: NSRange(location: 0, length: last.location))
        }
        guard candidate.location != NSNotFound, !selections.contains(candidate) else { return selections }
        return (selections + [candidate]).sorted { $0.location < $1.location }
    }

    /// Returns every occurrence of the selected text, or of the word at the caret.
    public static func allOccurrences(of selection: NSRange, in text: NSString) -> [NSRange] {
        let target = selection.length == 0 ? wordRange(at: selection.location, in: text) : selection
        guard let target else { return [selection] }
        let needle = text.substring(with: target)
        var result: [NSRange] = []
        var searchRange = NSRange(location: 0, length: text.length)
        while true {
            let found = text.range(of: needle, options: .literal, range: searchRange)
            guard found.location != NSNotFound else { break }
            result.append(found)
            let next = NSMaxRange(found)
            searchRange = NSRange(location: next, length: text.length - next)
        }
        return result.isEmpty ? [selection] : result
    }
}
