import Foundation

/// Re-indents or minifies JSON while keeping the original key order and number notation.
public struct JSONFormatter: Sendable {
    public let indentation: String

    public init(indentation: String = "  ") {
        self.indentation = indentation
    }

    /// Returns `text` pretty printed with one value per line.
    ///
    /// - Throws: `TextTransformationError.invalidJSON` with the position of the first syntax error.
    public func format(_ text: String) throws -> String {
        try validate(text)
        let scalars = Array(text.unicodeScalars)
        var output = String.UnicodeScalarView()
        var level = 0
        var index = 0
        var isInString = false
        var isEscaped = false

        func appendNewline() {
            output.append("\n")
            for _ in 0..<level {
                output.append(contentsOf: indentation.unicodeScalars)
            }
        }

        func nextSignificantScalar(after position: Int) -> Unicode.Scalar? {
            var cursor = position + 1
            while cursor < scalars.count {
                if !Self.isWhitespace(scalars[cursor]) {
                    return scalars[cursor]
                }
                cursor += 1
            }
            return nil
        }

        while index < scalars.count {
            let scalar = scalars[index]
            if isInString {
                output.append(scalar)
                if isEscaped {
                    isEscaped = false
                } else if scalar == "\\" {
                    isEscaped = true
                } else if scalar == "\"" {
                    isInString = false
                }
                index += 1
                continue
            }
            switch scalar {
            case "\"":
                isInString = true
                output.append(scalar)
            case "{", "[":
                output.append(scalar)
                let closing: Unicode.Scalar = scalar == "{" ? "}" : "]"
                if nextSignificantScalar(after: index) == closing {
                    output.append(closing)
                    while index + 1 < scalars.count, scalars[index + 1] != closing {
                        index += 1
                    }
                    index += 1
                } else {
                    level += 1
                    appendNewline()
                }
            case "}", "]":
                level -= 1
                appendNewline()
                output.append(scalar)
            case ",":
                output.append(scalar)
                appendNewline()
            case ":":
                output.append(contentsOf: ": ".unicodeScalars)
            default:
                if !Self.isWhitespace(scalar) {
                    output.append(scalar)
                }
            }
            index += 1
        }
        return String(output)
    }

    /// Returns `text` without any whitespace outside of strings.
    ///
    /// - Throws: `TextTransformationError.invalidJSON` with the position of the first syntax error.
    public func minify(_ text: String) throws -> String {
        try validate(text)
        var output = String.UnicodeScalarView()
        var isInString = false
        var isEscaped = false
        for scalar in text.unicodeScalars {
            if isInString {
                output.append(scalar)
                if isEscaped {
                    isEscaped = false
                } else if scalar == "\\" {
                    isEscaped = true
                } else if scalar == "\"" {
                    isInString = false
                }
            } else if scalar == "\"" {
                isInString = true
                output.append(scalar)
            } else if !Self.isWhitespace(scalar) {
                output.append(scalar)
            }
        }
        return String(output)
    }

    /// Checks that `text` is valid JSON.
    ///
    /// - Throws: `TextTransformationError.invalidJSON` with the position of the first syntax error.
    public func validate(_ text: String) throws {
        do {
            _ = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])
        } catch {
            throw Self.positionedError(from: error as NSError, in: text)
        }
    }

    private static func positionedError(from error: NSError, in text: String) -> TextTransformationError {
        let description = (error.userInfo[NSDebugDescriptionErrorKey] as? String) ?? error.localizedDescription
        if let regex = try? NSRegularExpression(pattern: #"line (\d+), column (\d+)"#),
           let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
           let lineRange = Range(match.range(at: 1), in: description),
           let columnRange = Range(match.range(at: 2), in: description),
           let line = Int(description[lineRange]),
           let column = Int(description[columnRange]) {
            return .invalidJSON(line: line, column: column)
        }
        if let regex = try? NSRegularExpression(pattern: #"character (\d+)"#),
           let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
           let offsetRange = Range(match.range(at: 1), in: description),
           let offset = Int(description[offsetRange]) {
            let position = LineIndex(text: text).position(at: offset)
            return .invalidJSON(line: position.line, column: position.column)
        }
        return .invalidJSON(line: 1, column: 1)
    }

    private static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\n" || scalar == "\r" || scalar == "\t"
    }
}
