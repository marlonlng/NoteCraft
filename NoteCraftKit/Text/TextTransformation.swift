import Foundation

public enum TextTransformation: String, CaseIterable, Sendable {
    case sortLinesAscending
    case sortLinesDescending
    case sortLinesByLength
    case reverseLines
    case shuffleLines
    case removeDuplicateLines
    case removeEmptyLines
    case trimTrailingWhitespace
    case trimLeadingWhitespace
    case joinLines
    case uppercase
    case lowercase
    case capitalize
    case invertCase
    case camelCase
    case snakeCase
    case kebabCase
    case base64Encode
    case base64Decode
    case urlEncode
    case urlDecode
    case htmlEscape
    case htmlUnescape
    case formatJSON
    case minifyJSON

    /// Whether the transformation works on whole lines and needs the selection extended to line boundaries.
    public var operatesOnLines: Bool {
        switch self {
        case .sortLinesAscending, .sortLinesDescending, .sortLinesByLength, .reverseLines, .shuffleLines,
             .removeDuplicateLines, .removeEmptyLines, .trimTrailingWhitespace, .trimLeadingWhitespace, .joinLines:
            true
        default:
            false
        }
    }

    /// Applies the transformation to `text`.
    ///
    /// - Throws: `TextTransformationError` when the input cannot be decoded or parsed.
    public func apply(to text: String, indentation: String = "  ") throws -> String {
        switch self {
        case .sortLinesAscending:
            return Self.mapLines(text) { $0.sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
        case .sortLinesDescending:
            return Self.mapLines(text) { $0.sorted { $0.localizedStandardCompare($1) == .orderedDescending } }
        case .sortLinesByLength:
            return Self.mapLines(text) { lines in
                lines.enumerated()
                    .sorted { $0.element.count == $1.element.count ? $0.offset < $1.offset : $0.element.count < $1.element.count }
                    .map(\.element)
            }
        case .reverseLines:
            return Self.mapLines(text) { $0.reversed() }
        case .shuffleLines:
            return Self.mapLines(text) { $0.shuffled() }
        case .removeDuplicateLines:
            return Self.mapLines(text) { lines in
                var seen = Set<String>()
                return lines.filter { seen.insert($0).inserted }
            }
        case .removeEmptyLines:
            return Self.mapLines(text) { $0.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
        case .trimTrailingWhitespace:
            return Self.mapLines(text) { $0.map(Self.trimmingTrailingWhitespace) }
        case .trimLeadingWhitespace:
            return Self.mapLines(text) { $0.map { String($0.drop { $0 == " " || $0 == "\t" }) } }
        case .joinLines:
            return Self.mapLines(text) { lines in
                [lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")]
            }
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .capitalize:
            return text.capitalized
        case .invertCase:
            return text.map { character in
                let upper = character.uppercased()
                return String(character) == upper ? character.lowercased() : upper
            }.joined()
        case .camelCase:
            return Self.mapWordGroups(text) { words in
                guard let first = words.first else { return "" }
                return first.lowercased() + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
            }
        case .snakeCase:
            return Self.mapWordGroups(text) { $0.map { $0.lowercased() }.joined(separator: "_") }
        case .kebabCase:
            return Self.mapWordGroups(text) { $0.map { $0.lowercased() }.joined(separator: "-") }
        case .base64Encode:
            return Data(text.utf8).base64EncodedString()
        case .base64Decode:
            let compact = text.filter { !$0.isWhitespace }
            guard let data = Data(base64Encoded: compact), let decoded = String(data: data, encoding: .utf8) else {
                throw TextTransformationError.invalidBase64
            }
            return decoded
        case .urlEncode:
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&=+?#/:")
            return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
        case .urlDecode:
            guard let decoded = text.replacingOccurrences(of: "+", with: " ").removingPercentEncoding else {
                throw TextTransformationError.invalidPercentEncoding
            }
            return decoded
        case .htmlEscape:
            return HTMLEntities.escape(text)
        case .htmlUnescape:
            return HTMLEntities.unescape(text)
        case .formatJSON:
            return try JSONFormatter(indentation: indentation).format(text)
        case .minifyJSON:
            return try JSONFormatter(indentation: indentation).minify(text)
        }
    }

    private static func mapLines(_ text: String, _ transform: ([String]) -> [String]) -> String {
        var lines = text.components(separatedBy: "\n")
        let hasTrailingNewline = text.hasSuffix("\n")
        if hasTrailingNewline {
            lines.removeLast()
        }
        let result = transform(lines).joined(separator: "\n")
        return hasTrailingNewline ? result + "\n" : result
    }

    private static func trimmingTrailingWhitespace(_ line: String) -> String {
        var result = line
        while let last = result.last, last == " " || last == "\t" {
            result.removeLast()
        }
        return result
    }

    private static func mapWordGroups(_ text: String, _ transform: ([String]) -> String) -> String {
        mapLines(text) { lines in
            lines.map { line in
                let leading = String(line.prefix { $0 == " " || $0 == "\t" })
                let words = splitIntoWords(line)
                return words.isEmpty ? line : leading + transform(words)
            }
        }
    }

    /// Splits identifiers and phrases such as `fooBar baz_qux-HTTPServer` into words.
    static func splitIntoWords(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            guard character.isLetter || character.isNumber else {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                continue
            }
            if let previous = current.last {
                let next = index + 1 < characters.count ? characters[index + 1] : nil
                let startsNewWord = ((previous.isLowercase || previous.isNumber) && character.isUppercase)
                    || (previous.isUppercase && character.isUppercase && (next?.isLowercase ?? false))
                if startsNewWord {
                    words.append(current)
                    current = ""
                }
            }
            current.append(character)
        }
        if !current.isEmpty {
            words.append(current)
        }
        return words
    }
}

public enum TextTransformationError: Error, Equatable, Sendable {
    case invalidBase64
    case invalidPercentEncoding
    case invalidJSON(line: Int, column: Int)
}
