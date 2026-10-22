import Foundation

public struct Indentation: Equatable, Codable, Sendable {
    public var usesTabs: Bool
    public var width: Int

    public init(usesTabs: Bool, width: Int) {
        self.usesTabs = usesTabs
        self.width = max(1, width)
    }

    public var unit: String {
        usesTabs ? "\t" : String(repeating: " ", count: width)
    }

    /// Guesses the indentation style of `text` from its indented lines.
    ///
    /// Returns `nil` when the text contains too few indented lines to decide.
    public static func detect(in text: String, sampleLimit: Int = 2_000) -> Indentation? {
        var tabLines = 0
        var spaceLines = 0
        var widthVotes: [Int: Int] = [:]
        var previousSpaces = 0
        var inspected = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard inspected < sampleLimit else { break }
            inspected += 1
            guard let first = line.first, first == " " || first == "\t" else {
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    previousSpaces = 0
                }
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            if first == "\t" {
                tabLines += 1
                continue
            }
            let spaces = line.prefix { $0 == " " }.count
            spaceLines += 1
            let delta = abs(spaces - previousSpaces)
            if delta >= 2, delta <= 8 {
                widthVotes[delta, default: 0] += 1
            }
            previousSpaces = spaces
        }
        guard tabLines + spaceLines >= 2 else { return nil }
        if tabLines > spaceLines {
            return Indentation(usesTabs: true, width: 4)
        }
        let width = widthVotes.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }?.key ?? 4
        return Indentation(usesTabs: false, width: width)
    }

    /// Returns the leading tabs and spaces of the line containing `location`, up to `location`.
    public static func leadingWhitespace(ofLineContaining location: Int, in text: NSString) -> String {
        let line = text.lineRange(for: NSRange(location: location, length: 0))
        var end = line.location
        while end < min(NSMaxRange(line), location) {
            let character = text.character(at: end)
            guard character == 0x20 || character == 0x09 else { break }
            end += 1
        }
        return text.substring(with: NSRange(location: line.location, length: end - line.location))
    }

    /// Computes the text inserted for a line break at `location`, keeping or increasing the indentation.
    ///
    /// Between an opening and its closing bracket the closing bracket moves to its own line.
    /// - Returns: The text to insert and the caret offset inside that text.
    public func lineBreak(at location: Int, in text: NSString) -> (text: String, caretOffset: Int) {
        let base = Self.leadingWhitespace(ofLineContaining: location, in: text)
        let previous = Self.previousSignificantCharacter(before: location, in: text)
        let next = location < text.length ? text.character(at: location) : nil
        let opensBlock = previous.map { [0x7B, 0x5B, 0x28].contains($0) } ?? false
        let opensPythonBlock = previous == 0x3A
        if opensBlock, let next, let previous, Brackets.closing(forOpening: previous) == next {
            let inner = "\n" + base + unit
            return (inner + "\n" + base, (inner as NSString).length)
        }
        let insertion = "\n" + base + (opensBlock || opensPythonBlock ? unit : "")
        return (insertion, (insertion as NSString).length)
    }

    /// Replaces every tab with spaces up to the next tab stop of `width` columns.
    public static func expandTabs(in text: String, width: Int) -> String {
        let width = max(1, width)
        var result = ""
        result.reserveCapacity(text.count)
        var column = 0
        for character in text {
            switch character {
            case "\t":
                let count = width - column % width
                result += String(repeating: " ", count: count)
                column += count
            case "\n":
                result.append(character)
                column = 0
            default:
                result.append(character)
                column += 1
            }
        }
        return result
    }

    /// Replaces leading runs of `width` spaces with tabs; spaces inside lines are kept.
    public static func collapseLeadingSpaces(in text: String, width: Int) -> String {
        let width = max(1, width)
        return text.components(separatedBy: "\n").map { line in
            let leading = line.prefix { $0 == " " || $0 == "\t" }
            var columns = 0
            for character in leading {
                columns = character == "\t" ? columns + width - columns % width : columns + 1
            }
            let tabs = String(repeating: "\t", count: columns / width)
            let spaces = String(repeating: " ", count: columns % width)
            return tabs + spaces + line.dropFirst(leading.count)
        }.joined(separator: "\n")
    }

    private static func previousSignificantCharacter(before location: Int, in text: NSString) -> unichar? {
        var index = location - 1
        let lineStart = text.lineRange(for: NSRange(location: location, length: 0)).location
        while index >= lineStart {
            let character = text.character(at: index)
            if character != 0x20, character != 0x09 {
                return character
            }
            index -= 1
        }
        return nil
    }
}

public enum Brackets {
    private static let pairs: [unichar: unichar] = [0x28: 0x29, 0x5B: 0x5D, 0x7B: 0x7D]

    /// Returns the closing bracket for an opening bracket.
    public static func closing(forOpening character: unichar) -> unichar? {
        pairs[character]
    }

    /// Returns the opening bracket for a closing bracket.
    public static func opening(forClosing character: unichar) -> unichar? {
        pairs.first { $0.value == character }?.key
    }

    /// Finds the bracket matching the one at `index`, scanning at most `limit` characters.
    public static func matchingBracket(at index: Int, in text: NSString, limit: Int = 100_000) -> Int? {
        guard index >= 0, index < text.length else { return nil }
        let character = text.character(at: index)
        if let closing = closing(forOpening: character) {
            var depth = 0
            var cursor = index
            let end = min(text.length, index + limit)
            while cursor < end {
                let current = text.character(at: cursor)
                if current == character {
                    depth += 1
                } else if current == closing {
                    depth -= 1
                    if depth == 0 { return cursor }
                }
                cursor += 1
            }
            return nil
        }
        if let opening = opening(forClosing: character) {
            var depth = 0
            var cursor = index
            let end = max(0, index - limit)
            while cursor >= end {
                let current = text.character(at: cursor)
                if current == character {
                    depth += 1
                } else if current == opening {
                    depth -= 1
                    if depth == 0 { return cursor }
                }
                cursor -= 1
            }
        }
        return nil
    }
}

public enum AutoPairing {
    private static let pairs: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'", "`": "`"]

    /// Returns the closing counterpart that should be inserted after typing `input`, if any.
    ///
    /// Pairs are only inserted when the caret is followed by whitespace, a closing bracket or the end of text.
    /// Quotes are not paired directly after a letter or digit.
    public static func closingCounterpart(for input: String, before nextCharacter: Character?, after previousCharacter: Character?) -> String? {
        guard let closing = pairs[input] else { return nil }
        if let nextCharacter, !(nextCharacter.isWhitespace || ")]}".contains(nextCharacter)) {
            return nil
        }
        let isQuote = input == closing
        if isQuote, let previousCharacter, previousCharacter.isLetter || previousCharacter.isNumber || String(previousCharacter) == input {
            return nil
        }
        return closing
    }

    /// Whether typing `input` should only move the caret over an identical, already present closing character.
    public static func shouldSkipOver(_ input: String, nextCharacter: Character?) -> Bool {
        guard let nextCharacter, String(nextCharacter) == input else { return false }
        return pairs.values.contains(input)
    }

    /// Whether deleting backward at the caret should remove both characters of an empty pair.
    public static func shouldDeletePair(previousCharacter: Character?, nextCharacter: Character?) -> Bool {
        guard let previousCharacter, let nextCharacter else { return false }
        return pairs[String(previousCharacter)] == String(nextCharacter)
    }
}
