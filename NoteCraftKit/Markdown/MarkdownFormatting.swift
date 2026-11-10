import Foundation
import Markdown

public enum MarkdownListKind: Sendable {
    case bullet
    case numbered
}

struct MarkdownInlineSpan: Equatable {
    let style: MarkdownInlineStyle
    let range: NSRange
    let markerLength: Int

    /// Whether the span covers `selection`; an empty selection must lie strictly between the span's edges.
    func contains(_ selection: NSRange) -> Bool {
        if selection.length == 0 {
            return range.location < selection.location && selection.location < NSMaxRange(range)
        }
        return range.location <= selection.location && NSMaxRange(selection) <= NSMaxRange(range)
    }
}

struct MarkdownFencedBlock: Equatable {
    let opening: NSRange
    let closing: NSRange?

    /// Whether `location` lies between the start of the opening fence and the end of the closing fence.
    func contains(_ location: Int, in text: NSString) -> Bool {
        location >= opening.location && location <= (closing.map(NSMaxRange) ?? text.length)
    }
}

public struct MarkdownFormatState: Equatable, Sendable {
    public var inlineStyles: Set<MarkdownInlineStyle>
    public var headingLevel: Int
    public var listKind: MarkdownListKind?
    public var isQuote: Bool

    public init(inlineStyles: Set<MarkdownInlineStyle> = [], headingLevel: Int = 0, listKind: MarkdownListKind? = nil, isQuote: Bool = false) {
        self.inlineStyles = inlineStyles
        self.headingLevel = headingLevel
        self.listKind = listKind
        self.isQuote = isQuote
    }

    /// The formatting that applies to `selection`.
    ///
    /// Line formats count when every non-empty line of the selection has them. Inline styles count when the selection
    /// stays on one line inside a span of that style. Inside a fenced code block only code applies.
    public static func at(_ selection: NSRange, in text: NSString) -> MarkdownFormatState {
        let location = min(max(selection.location, 0), text.length)
        let selection = NSRange(location: location, length: min(max(selection.length, 0), text.length - location))
        if let block = MarkdownEditing.fencedBlock(containing: selection.location, in: text), block.contains(NSMaxRange(selection), in: text) {
            return MarkdownFormatState(inlineStyles: [.code])
        }
        var state = MarkdownFormatState()
        let lines = MarkdownEditing.lineSlices(for: selection, in: text)
        let nonEmpty = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        if let first = nonEmpty.first {
            let level = MarkdownEditing.headingLevel(of: first.text).level
            state.headingLevel = nonEmpty.allSatisfy { MarkdownEditing.headingLevel(of: $0.text).level == level } ? level : 0
            let kind = MarkdownEditing.listKind(of: first.text)
            state.listKind = nonEmpty.allSatisfy { MarkdownEditing.listKind(of: $0.text) == kind } ? kind : nil
            state.isQuote = nonEmpty.allSatisfy { MarkdownEditing.quotePrefixLength(of: $0.text) > 0 }
        }
        if lines.count == 1 {
            let spans = MarkdownEditing.inlineSpans(inLineAt: selection.location, in: text).filter { $0.contains(selection) }
            state.inlineStyles = Set(spans.map(\.style))
        }
        return state
    }
}

extension MarkdownEditing {
    private static let fenceExpression = try? NSRegularExpression(pattern: #"^ {0,3}(`{3,}|~{3,})(.*)$"#)

    static func listKind(of line: String) -> MarkdownListKind? {
        MarkdownListPrefix.parse(line).map { $0.isOrdered ? .numbered : .bullet }
    }

    /// Turns the touched lines into list items of `kind`, or back into plain lines when they all are items of that kind.
    ///
    /// Items of the other kind are converted. Numbered items count up per indentation and continue a numbered item
    /// right above the selection.
    public static func toggleList(_ kind: MarkdownListKind, in text: NSString, selection: NSRange) -> TextEdit {
        let lines = lineSlices(for: selection, in: text)
        let nonEmpty = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let removes = !nonEmpty.isEmpty && nonEmpty.allSatisfy { listKind(of: $0.text) == kind }
        var counters: [String: Int] = [:]
        if kind == .numbered, let first = lines.first, first.range.location > 0 {
            let previous = contentRange(of: text.lineRange(for: NSRange(location: first.range.location - 1, length: 0)), in: text)
            if let prefix = MarkdownListPrefix.parse(text.substring(with: previous)), let number = prefix.number {
                counters[prefix.indentation] = number + 1
            }
        }
        return rewriteLines(lines, in: text, selection: selection) { line in
            let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
            guard nonEmpty.isEmpty || !isBlank else { return (line, 0, 0) }
            let nsLine = line as NSString
            let prefix = MarkdownListPrefix.parse(line)
            if removes, let prefix {
                return (prefix.indentation + nsLine.substring(from: prefix.length), prefix.length, (prefix.indentation as NSString).length)
            }
            if kind == .bullet, let prefix, !prefix.isOrdered {
                return (line, prefix.length, prefix.length)
            }
            let indentation = prefix?.indentation ?? String(line.prefix { $0 == " " || $0 == "\t" })
            let oldPrefixLength = prefix?.length ?? (indentation as NSString).length
            let checkbox = prefix?.checkbox.map { "[\($0)] " } ?? ""
            var marker = "- "
            if kind == .numbered {
                counters = counters.filter { $0.key.count <= indentation.count }
                let number = counters[indentation] ?? 1
                counters[indentation] = number + 1
                marker = "\(number). "
            }
            let newPrefix = indentation + marker + checkbox
            return (newPrefix + nsLine.substring(from: oldPrefixLength), oldPrefixLength, (newPrefix as NSString).length)
        }
    }

    /// Formats the selection as code: a fenced block across several lines, inline code within one line.
    ///
    /// Without a selection the word at the caret becomes code. Inside existing code the code formatting is removed.
    public static func toggleCode(in text: NSString, selection: NSRange) -> TextEdit {
        if let block = fencedBlock(containing: selection.location, in: text), block.contains(NSMaxRange(selection), in: text) {
            return removingFences(of: block, in: text, selection: selection)
        }
        if text.substring(with: selection).trimmingCharacters(in: .newlines).contains("\n") {
            return wrappingInFence(lineSlices(for: selection, in: text), in: text, selection: selection)
        }
        if selection.length == 0, enclosingSpan(.code, of: selection, in: text) == nil, let word = wordRange(at: selection.location, in: text) {
            return TextEdit(range: word, replacement: "`" + text.substring(with: word) + "`", selectedRange: NSRange(location: selection.location + 1, length: 0))
        }
        return toggle(.code, in: text, selection: selection)
    }

    /// The innermost span of `style` that covers `selection`, if the selection stays on one line.
    static func enclosingSpan(_ style: MarkdownInlineStyle, of selection: NSRange, in text: NSString) -> MarkdownInlineSpan? {
        guard NSMaxRange(selection) <= text.length, !text.substring(with: selection).contains("\n") else { return nil }
        return inlineSpans(inLineAt: selection.location, in: text)
            .filter { $0.style == style && $0.contains(selection) }
            .min { $0.range.length < $1.range.length }
    }

    /// Removes the markers of `span` and keeps the selection on the same text.
    static func removingSpan(_ span: MarkdownInlineSpan, in text: NSString, selection: NSRange) -> TextEdit {
        let marker = span.markerLength
        let start = span.range.location
        let end = NSMaxRange(span.range)
        let inner = text.substring(with: NSRange(location: start + marker, length: span.range.length - marker * 2))
        func map(_ position: Int) -> Int {
            if position <= start {
                return position
            }
            if position <= start + marker {
                return start
            }
            if position <= end - marker {
                return position - marker
            }
            return end - marker * 2
        }
        let newStart = map(selection.location)
        let newEnd = map(NSMaxRange(selection))
        return TextEdit(range: span.range, replacement: inner, selectedRange: NSRange(location: newStart, length: newEnd - newStart))
    }

    /// The emphasis, strikethrough and code spans of the line that contains `location`, in document coordinates.
    static func inlineSpans(inLineAt location: Int, in text: NSString) -> [MarkdownInlineSpan] {
        let lineRange = contentRange(of: text.lineRange(for: NSRange(location: min(location, text.length), length: 0)), in: text)
        let line = text.substring(with: lineRange)
        let indentation = (String(line.prefix { $0 == " " || $0 == "\t" }) as NSString).length
        let body = (line as NSString).substring(from: indentation)
        guard body.contains(where: { "*_~`".contains($0) }) else { return [] }
        var spans: [MarkdownInlineSpan] = []
        collectSpans(in: Document(parsing: body, options: [.disableSmartOpts]), body: body, offset: lineRange.location + indentation, into: &spans)
        return spans
    }

    private static func collectSpans(in markup: any Markup, body: String, offset: Int, into spans: inout [MarkdownInlineSpan]) {
        for child in markup.children {
            if let style = inlineStyle(of: child), let range = child.range.flatMap({ utf16Range(of: $0, in: body) }) {
                let content = (body as NSString).substring(with: range)
                let markerLength: Int
                switch style {
                case .bold: markerLength = 2
                case .italic: markerLength = 1
                case .strikethrough: markerLength = content.prefix { $0 == "~" }.count
                case .code: markerLength = content.prefix { $0 == "`" }.count
                }
                if markerLength > 0, range.length >= markerLength * 2 {
                    spans.append(MarkdownInlineSpan(style: style, range: NSRange(location: range.location + offset, length: range.length), markerLength: markerLength))
                }
            }
            collectSpans(in: child, body: body, offset: offset, into: &spans)
        }
    }

    private static func inlineStyle(of markup: any Markup) -> MarkdownInlineStyle? {
        switch markup {
        case is Strong: .bold
        case is Emphasis: .italic
        case is Strikethrough: .strikethrough
        case is InlineCode: .code
        default: nil
        }
    }

    private static func utf16Range(of range: SourceRange, in line: String) -> NSRange? {
        guard range.lowerBound.line == 1, range.upperBound.line == 1 else { return nil }
        let utf8 = line.utf8
        guard let start = utf8.index(utf8.startIndex, offsetBy: range.lowerBound.column - 1, limitedBy: utf8.endIndex),
              let end = utf8.index(utf8.startIndex, offsetBy: range.upperBound.column - 1, limitedBy: utf8.endIndex) else {
            return nil
        }
        let location = line.utf16.distance(from: line.utf16.startIndex, to: start)
        return NSRange(location: location, length: line.utf16.distance(from: start, to: end))
    }

    /// The fenced code block whose lines include the line of `location`, fences included.
    static func fencedBlock(containing location: Int, in text: NSString) -> MarkdownFencedBlock? {
        let target = text.lineRange(for: NSRange(location: min(max(location, 0), text.length), length: 0)).location
        var open: (range: NSRange, character: Character, length: Int)?
        var lineStart = 0
        while lineStart <= text.length {
            if open == nil, lineStart > target {
                return nil
            }
            let lineRange = text.lineRange(for: NSRange(location: lineStart, length: 0))
            let content = contentRange(of: lineRange, in: text)
            if let fence = fence(in: text.substring(with: content)) {
                if let current = open {
                    if fence.character == current.character, fence.length >= current.length, fence.info.trimmingCharacters(in: .whitespaces).isEmpty {
                        if target <= content.location {
                            return MarkdownFencedBlock(opening: current.range, closing: content)
                        }
                        open = nil
                    }
                } else if fence.character == "~" || !fence.info.contains("`") {
                    open = (content, fence.character, fence.length)
                }
            }
            guard NSMaxRange(lineRange) > lineStart else { break }
            lineStart = NSMaxRange(lineRange)
        }
        if let current = open, target >= current.range.location {
            return MarkdownFencedBlock(opening: current.range, closing: nil)
        }
        return nil
    }

    private static func fence(in line: String) -> (character: Character, length: Int, info: String)? {
        let nsLine = line as NSString
        guard let match = fenceExpression?.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)),
              let character = nsLine.substring(with: match.range(at: 1)).first else {
            return nil
        }
        return (character, match.range(at: 1).length, nsLine.substring(with: match.range(at: 2)))
    }

    private static func removingFences(of block: MarkdownFencedBlock, in text: NSString, selection: NSRange) -> TextEdit {
        let start = block.opening.location
        let innerStart = min(NSMaxRange(block.opening) + 1, text.length)
        guard let closing = block.closing else {
            let removed = innerStart - start
            let mapped = { (position: Int) in position < innerStart ? start : position - removed }
            let newStart = mapped(selection.location)
            return TextEdit(
                range: NSRange(location: start, length: removed),
                replacement: "",
                selectedRange: NSRange(location: newStart, length: mapped(NSMaxRange(selection)) - newStart)
            )
        }
        let innerEnd = max(innerStart, closing.location - 1)
        let inner = text.substring(with: NSRange(location: innerStart, length: innerEnd - innerStart))
        func map(_ position: Int) -> Int {
            if position < innerStart {
                return start
            }
            return start + min(position, innerEnd) - innerStart
        }
        let newStart = map(selection.location)
        return TextEdit(
            range: NSRange(location: start, length: NSMaxRange(closing) - start),
            replacement: inner,
            selectedRange: NSRange(location: newStart, length: map(NSMaxRange(selection)) - newStart)
        )
    }

    private static func wrappingInFence(_ lines: [LineSlice], in text: NSString, selection: NSRange) -> TextEdit {
        guard let first = lines.first, let last = lines.last else {
            return TextEdit(range: selection, replacement: text.substring(with: selection), selectedRange: selection)
        }
        let block = NSRange(location: first.range.location, length: NSMaxRange(last.range) - first.range.location)
        let replacement = "```\n" + text.substring(with: block) + "\n```"
        return TextEdit(range: block, replacement: replacement, selectedRange: NSRange(location: block.location + 4, length: block.length))
    }

    /// The letters, digits and underscores around `location`, or `nil` when there are none.
    static func wordRange(at location: Int, in text: NSString) -> NSRange? {
        func isWordCharacter(_ index: Int) -> Bool {
            guard index >= 0, index < text.length, let scalar = Unicode.Scalar(text.character(at: index)) else { return false }
            return scalar == "_" || CharacterSet.alphanumerics.contains(scalar)
        }
        var start = location
        var end = location
        while isWordCharacter(start - 1) {
            start -= 1
        }
        while isWordCharacter(end) {
            end += 1
        }
        return end > start ? NSRange(location: start, length: end - start) : nil
    }
}
