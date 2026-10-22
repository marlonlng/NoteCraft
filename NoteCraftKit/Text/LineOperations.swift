import Foundation

public enum LineOperations {
    /// Returns the range of all lines touched by `selection`, including the final line ending.
    ///
    /// A non-empty selection that ends at the very start of a line does not include that line.
    public static func lineRange(for selection: NSRange, in text: NSString) -> NSRange {
        var effective = selection
        if effective.length > 0, NSMaxRange(effective) <= text.length, NSMaxRange(effective) > 0,
           text.character(at: NSMaxRange(effective) - 1) == 0x0A {
            effective.length -= 1
        }
        return text.lineRange(for: effective)
    }

    /// Inserts a copy of the touched lines below them and moves the selection into the copy.
    public static func duplicateLines(in text: NSString, selection: NSRange) -> TextEdit {
        let lines = lineRange(for: selection, in: text)
        let content = text.substring(with: lines)
        if content.hasSuffix("\n") {
            let insertion = NSRange(location: NSMaxRange(lines), length: 0)
            let shifted = NSRange(location: selection.location + lines.length, length: selection.length)
            return TextEdit(range: insertion, replacement: content, selectedRange: shifted)
        }
        let insertion = NSRange(location: NSMaxRange(lines), length: 0)
        let shifted = NSRange(location: selection.location + lines.length + 1, length: selection.length)
        return TextEdit(range: insertion, replacement: "\n" + content, selectedRange: shifted)
    }

    /// Swaps the touched lines with the line above or below, keeping them selected.
    public static func moveLines(in text: NSString, selection: NSRange, direction: LineMoveDirection) -> TextEdit? {
        let lines = lineRange(for: selection, in: text)
        let block = text.substring(with: lines)
        switch direction {
        case .up:
            guard lines.location > 0 else { return nil }
            let previous = text.lineRange(for: NSRange(location: lines.location - 1, length: 0))
            let previousText = text.substring(with: previous)
            let replacement: String
            if block.hasSuffix("\n") {
                replacement = block + previousText
            } else {
                replacement = block + "\n" + String(previousText.dropLast())
            }
            let combined = NSUnionRange(previous, lines)
            let selected = NSRange(location: selection.location - previous.length, length: selection.length)
            return TextEdit(range: combined, replacement: replacement, selectedRange: selected)
        case .down:
            guard NSMaxRange(lines) < text.length else { return nil }
            let next = text.lineRange(for: NSRange(location: NSMaxRange(lines), length: 0))
            let nextText = text.substring(with: next)
            let replacement: String
            let offset: Int
            if nextText.hasSuffix("\n") {
                replacement = nextText + block
                offset = next.length
            } else {
                replacement = nextText + "\n" + String(block.dropLast())
                offset = next.length + 1
            }
            let combined = NSUnionRange(lines, next)
            let selected = NSRange(location: selection.location + offset, length: selection.length)
            return TextEdit(range: combined, replacement: replacement, selectedRange: selected)
        }
    }

    /// Removes the touched lines and places the caret at the start of the following line.
    public static func deleteLines(in text: NSString, selection: NSRange) -> TextEdit {
        var lines = lineRange(for: selection, in: text)
        let content = text.substring(with: lines)
        if !content.hasSuffix("\n"), lines.location > 0 {
            lines = NSRange(location: lines.location - 1, length: lines.length + 1)
        }
        let caret = lines.location
        return TextEdit(range: lines, replacement: "", selectedRange: NSRange(location: caret, length: 0))
    }

    /// Adds one indentation `unit` in front of every non-empty touched line.
    public static func indent(in text: NSString, selection: NSRange, unit: String) -> TextEdit {
        let lines = contentLineRange(for: selection, in: text)
        let content = text.substring(with: lines)
        let rewritten = content.components(separatedBy: "\n")
            .map { $0.isEmpty ? $0 : unit + $0 }
            .joined(separator: "\n")
        return edit(replacing: lines, with: rewritten, selection: selection, caretDelta: unit.utf16.count)
    }

    /// Removes one indentation level (a tab or up to `tabWidth` spaces) from every touched line.
    public static func outdent(in text: NSString, selection: NSRange, tabWidth: Int) -> TextEdit? {
        let lines = contentLineRange(for: selection, in: text)
        let content = text.substring(with: lines)
        var firstLineRemoval = 0
        let rewritten = content.components(separatedBy: "\n").enumerated().map { index, line -> String in
            let removal: Int
            if line.hasPrefix("\t") {
                removal = 1
            } else {
                removal = min(tabWidth, line.prefix { $0 == " " }.count)
            }
            if index == 0 {
                firstLineRemoval = removal
            }
            return String(line.dropFirst(removal))
        }.joined(separator: "\n")
        guard rewritten != content else { return nil }
        return edit(replacing: lines, with: rewritten, selection: selection, caretDelta: -firstLineRemoval)
    }

    /// Comments or uncomments the touched lines using the language's comment syntax.
    ///
    /// Line comments are preferred; block comments wrap the touched lines when no line comment exists.
    public static func toggleComment(in text: NSString, selection: NSRange, syntax: CommentSyntax) -> TextEdit? {
        let lines = contentLineRange(for: selection, in: text)
        let content = text.substring(with: lines)
        if let token = syntax.lineComment {
            let rows = content.components(separatedBy: "\n")
            let nonEmpty = rows.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !nonEmpty.isEmpty else { return nil }
            let isCommented = nonEmpty.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix(token) }
            let rewritten: String
            if isCommented {
                rewritten = rows.map { uncomment($0, token: token) }.joined(separator: "\n")
            } else {
                let column = nonEmpty.map { $0.prefix { $0 == " " || $0 == "\t" }.count }.min() ?? 0
                rewritten = rows.map { row in
                    guard !row.trimmingCharacters(in: .whitespaces).isEmpty else { return row }
                    let index = row.index(row.startIndex, offsetBy: column)
                    return String(row[..<index]) + token + " " + String(row[index...])
                }.joined(separator: "\n")
            }
            let delta = (rewritten as NSString).length - lines.length
            return edit(replacing: lines, with: rewritten, selection: selection, caretDelta: delta)
        }
        guard let block = syntax.blockComment else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        let rewritten: String
        if trimmed.hasPrefix(block.start), trimmed.hasSuffix(block.end), trimmed.count >= block.start.count + block.end.count {
            var inner = String(trimmed.dropFirst(block.start.count).dropLast(block.end.count))
            if inner.hasPrefix(" ") { inner.removeFirst() }
            if inner.hasSuffix(" ") { inner.removeLast() }
            let leading = String(content.prefix { $0 == " " || $0 == "\t" })
            rewritten = leading + inner
        } else {
            let leading = String(content.prefix { $0 == " " || $0 == "\t" })
            rewritten = leading + block.start + " " + content.dropFirst(leading.count) + " " + block.end
        }
        let delta = (rewritten as NSString).length - lines.length
        return edit(replacing: lines, with: rewritten, selection: selection, caretDelta: delta)
    }

    /// Applies `transformation` to the selection, or to the whole text when nothing is selected.
    ///
    /// Line-based transformations extend the selection to full lines.
    /// - Throws: `TextTransformationError` from the transformation.
    public static func transform(
        _ transformation: TextTransformation,
        in text: NSString,
        selection: NSRange,
        indentation: String = "  "
    ) throws -> TextEdit {
        let range: NSRange
        if selection.length == 0 {
            range = NSRange(location: 0, length: text.length)
        } else if transformation.operatesOnLines {
            range = contentLineRange(for: selection, in: text)
        } else {
            range = selection
        }
        let original = text.substring(with: range)
        let replacement = try transformation.apply(to: original, indentation: indentation)
        let selected = NSRange(location: range.location, length: (replacement as NSString).length)
        return TextEdit(range: range, replacement: replacement, selectedRange: selected)
    }

    /// Returns the touched lines without the line ending of the last line.
    public static func contentLineRange(for selection: NSRange, in text: NSString) -> NSRange {
        var lines = lineRange(for: selection, in: text)
        if lines.length > 0, text.character(at: NSMaxRange(lines) - 1) == 0x0A {
            lines.length -= 1
        }
        return lines
    }

    private static func uncomment(_ row: String, token: String) -> String {
        guard let tokenRange = row.range(of: token),
              row[row.startIndex..<tokenRange.lowerBound].allSatisfy({ $0 == " " || $0 == "\t" }) else {
            return row
        }
        var remainder = row[tokenRange.upperBound...]
        if remainder.hasPrefix(" ") {
            remainder = remainder.dropFirst()
        }
        return String(row[..<tokenRange.lowerBound]) + remainder
    }

    private static func edit(replacing lines: NSRange, with rewritten: String, selection: NSRange, caretDelta: Int) -> TextEdit {
        let newLength = (rewritten as NSString).length
        let selected: NSRange
        if selection.length == 0 {
            let location = min(max(selection.location + caretDelta, lines.location), lines.location + newLength)
            selected = NSRange(location: location, length: 0)
        } else {
            selected = NSRange(location: lines.location, length: newLength)
        }
        return TextEdit(range: lines, replacement: rewritten, selectedRange: selected)
    }
}

public struct CommentSyntax: Equatable, Sendable {
    public struct BlockComment: Equatable, Sendable {
        public let start: String
        public let end: String

        public init(start: String, end: String) {
            self.start = start
            self.end = end
        }
    }

    public let lineComment: String?
    public let blockComment: BlockComment?

    public init(lineComment: String? = nil, blockComment: BlockComment? = nil) {
        self.lineComment = lineComment
        self.blockComment = blockComment
    }
}
