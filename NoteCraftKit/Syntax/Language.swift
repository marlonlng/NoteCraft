import Foundation

public enum TokenKind: String, CaseIterable, Codable, Sendable {
    case keyword
    case type
    case string
    case number
    case comment
    case constant
    case function
    case attribute
    case tag
    case variable
    case directive
    case heading
    case emphasis
    case link
    case inserted
    case deleted
}

public struct HighlightRule: Equatable, Sendable {
    public let pattern: String
    public let kind: TokenKind

    public init(_ pattern: String, _ kind: TokenKind) {
        self.pattern = pattern
        self.kind = kind
    }

    /// A rule matching any of `words` as a whole word.
    public static func words(_ words: [String], _ kind: TokenKind, caseInsensitive: Bool = false) -> HighlightRule {
        let alternatives = words.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let pattern = #"\b(?:"# + alternatives + #")\b"#
        return HighlightRule(caseInsensitive ? "(?i:" + pattern + ")" : pattern, kind)
    }
}

public struct Language: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let fileExtensions: [String]
    public let fileNames: [String]
    public let interpreters: [String]
    public let commentSyntax: CommentSyntax
    public let rules: [HighlightRule]

    public init(
        id: String,
        name: String,
        fileExtensions: [String] = [],
        fileNames: [String] = [],
        interpreters: [String] = [],
        commentSyntax: CommentSyntax = CommentSyntax(),
        rules: [HighlightRule] = []
    ) {
        self.id = id
        self.name = name
        self.fileExtensions = fileExtensions
        self.fileNames = fileNames
        self.interpreters = interpreters
        self.commentSyntax = commentSyntax
        self.rules = rules
    }

    public static func == (lhs: Language, rhs: Language) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static let plainText = Language(id: "plaintext", name: "Plain Text", fileExtensions: ["txt", "text", "log"])

    /// Returns the language with the given identifier.
    public static func language(withID id: String) -> Language? {
        LanguageCatalog.all.first { $0.id == id }
    }

    /// Picks the language for a file from its name, extension or shebang line.
    public static func detect(fileName: String?, content: String) -> Language {
        if let fileName {
            let lowercasedName = fileName.lowercased()
            if let match = LanguageCatalog.all.first(where: { $0.fileNames.contains { $0.lowercased() == lowercasedName } }) {
                return match
            }
            let fileExtension = (lowercasedName as NSString).pathExtension
            if !fileExtension.isEmpty,
               let match = LanguageCatalog.all.first(where: { $0.fileExtensions.contains(fileExtension) }) {
                return match
            }
        }
        if let interpreter = shebangInterpreter(in: content),
           let match = LanguageCatalog.all.first(where: { $0.interpreters.contains(interpreter) }) {
            return match
        }
        let head = content.prefix(256).trimmingCharacters(in: .whitespacesAndNewlines)
        if head.hasPrefix("<?xml") {
            return LanguageCatalog.xml
        }
        if head.lowercased().hasPrefix("<!doctype html") || head.lowercased().hasPrefix("<html") {
            return LanguageCatalog.html
        }
        return .plainText
    }

    /// Extracts the interpreter name from a `#!` line, e.g. `python3` → `python`.
    static func shebangInterpreter(in content: String) -> String? {
        guard content.hasPrefix("#!") else { return nil }
        let firstLine = content.prefix { $0 != "\n" }
        var components = firstLine.dropFirst(2).split(separator: " ").map(String.init)
        guard var program = components.first.map({ ($0 as NSString).lastPathComponent }) else { return nil }
        if program == "env" {
            components.removeFirst()
            guard let next = components.first(where: { !$0.hasPrefix("-") }) else { return nil }
            program = next
        }
        return program.trimmingCharacters(in: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")))
    }
}
