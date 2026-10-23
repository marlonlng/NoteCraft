import Foundation

public enum MarkdownInlineStyle: String, CaseIterable, Sendable {
    case bold
    case italic
    case strikethrough
    case code

    public var marker: String {
        switch self {
        case .bold: "**"
        case .italic: "*"
        case .strikethrough: "~~"
        case .code: "`"
        }
    }
}

struct MarkdownListPrefix: Equatable {
    let indentation: String
    let bullet: String?
    let number: Int?
    let delimiter: String
    let checkbox: Character?
    let length: Int
    let checkboxLocation: Int?

    var isOrdered: Bool {
        number != nil
    }

    /// Parses the list marker at the start of `line`, e.g. `  - [ ] `, `3. ` or `* `.
    static func parse(_ line: String) -> MarkdownListPrefix? {
        guard let regex = MarkdownEditing.listItemExpression else { return nil }
        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else { return nil }
        let indentation = nsLine.substring(with: match.range(at: 1))
        let marker = nsLine.substring(with: match.range(at: 2))
        let numberRange = match.range(at: 3)
        let number = numberRange.location == NSNotFound ? nil : Int(nsLine.substring(with: numberRange))
        let delimiter = match.range(at: 4).location == NSNotFound ? "" : nsLine.substring(with: match.range(at: 4))
        let checkboxRange = match.range(at: 6)
        var checkbox: Character?
        var checkboxLocation: Int?
        if checkboxRange.location != NSNotFound {
            checkbox = Character(nsLine.substring(with: NSRange(location: checkboxRange.location + 1, length: 1)))
            checkboxLocation = checkboxRange.location + 1
        }
        return MarkdownListPrefix(
            indentation: indentation,
            bullet: number == nil ? marker : nil,
            number: number,
            delimiter: delimiter,
            checkbox: checkbox,
            length: NSMaxRange(match.range),
            checkboxLocation: checkboxLocation
        )
    }
}

public enum MarkdownEditing {
    static let listItemExpression = try? NSRegularExpression(pattern: #"^([ \t]*)([-*+]|(\d{1,9})([.)]))([ \t]+|$)(\[[ xX]\](?:[ \t]+|$))?"#)
    private static let headingExpression = try? NSRegularExpression(pattern: #"^ {0,3}(#{1,6})(?:[ \t]+|$)"#)
    private static let quoteExpression = try? NSRegularExpression(pattern: #"^[ \t]*(?:>[ \t]?)+"#)

    /// Wraps the selection in the marker of `style`, or removes the marker when it is already there.
    public static func toggle(_ style: MarkdownInlineStyle, in text: NSString, selection: NSRange) -> TextEdit {
        let marker = style.marker
        let markerLength = (marker as NSString).length
        if selection.length == 0 {
            let before = NSRange(location: selection.location - markerLength, length: markerLength)
            if before.location >= 0, NSMaxRange(selection) + markerLength <= text.length,
               text.substring(with: before) == marker,
               text.substring(with: NSRange(location: selection.location, length: markerLength)) == marker {
                return TextEdit(
                    range: NSRange(location: before.location, length: markerLength * 2),
                    replacement: "",
                    selectedRange: NSRange(location: before.location, length: 0)
                )
            }
            return TextEdit(range: selection, replacement: marker + marker, selectedRange: NSRange(location: selection.location + markerLength, length: 0))
        }
        let core = trimmedRange(selection, in: text)
        let selected = text.substring(with: core)
        if hasMarker(style, atStartOf: selected), hasMarker(style, atEndOf: selected), (selected as NSString).length > markerLength * 2 {
            let inner = (selected as NSString).substring(with: NSRange(location: markerLength, length: (selected as NSString).length - markerLength * 2))
            return TextEdit(range: core, replacement: inner, selectedRange: NSRange(location: core.location, length: (inner as NSString).length))
        }
        if core.location >= markerLength, NSMaxRange(core) + markerLength <= text.length {
            let before = text.substring(to: core.location)
            let after = text.substring(from: NSMaxRange(core))
            if hasMarker(style, atEndOf: before), hasMarker(style, atStartOf: after) {
                let range = NSRange(location: core.location - markerLength, length: core.length + markerLength * 2)
                return TextEdit(range: range, replacement: selected, selectedRange: NSRange(location: range.location, length: core.length))
            }
        }
        return TextEdit(
            range: core,
            replacement: marker + selected + marker,
            selectedRange: NSRange(location: core.location + markerLength, length: core.length)
        )
    }

    private static func trimmedRange(_ range: NSRange, in text: NSString) -> NSRange {
        var start = range.location
        var end = NSMaxRange(range)
        let whitespace = CharacterSet.whitespacesAndNewlines
        while start < end, let scalar = Unicode.Scalar(text.character(at: start)), whitespace.contains(scalar) {
            start += 1
        }
        while end > start, let scalar = Unicode.Scalar(text.character(at: end - 1)), whitespace.contains(scalar) {
            end -= 1
        }
        return start == end ? range : NSRange(location: start, length: end - start)
    }

    private static func hasMarker(_ style: MarkdownInlineStyle, atStartOf text: String) -> Bool {
        switch style {
        case .bold, .italic:
            let run = text.prefix { $0 == "*" }.count
            return style == .bold ? run == 2 || run == 3 : run == 1 || run == 3
        case .strikethrough, .code:
            return text.hasPrefix(style.marker) && !text.hasPrefix(style.marker + style.marker.prefix(1))
        }
    }

    private static func hasMarker(_ style: MarkdownInlineStyle, atEndOf text: String) -> Bool {
        switch style {
        case .bold, .italic:
            let run = text.reversed().prefix { $0 == "*" }.count
            return style == .bold ? run == 2 || run == 3 : run == 1 || run == 3
        case .strikethrough, .code:
            return text.hasSuffix(style.marker) && !text.hasSuffix(style.marker.suffix(1) + style.marker)
        }
    }

    /// Whether `text` is a single web or mail address.
    public static func isAddress(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else { return false }
        let lowercased = trimmed.lowercased()
        return ["http://", "https://", "mailto:", "ftp://", "www."].contains { lowercased.hasPrefix($0) && lowercased.count > $0.count }
    }

    /// Inserts link syntax around the selection; `suggestedAddress` fills in an address, e.g. from the pasteboard.
    public static func insertLink(in text: NSString, selection: NSRange, suggestedAddress: String?) -> TextEdit {
        let selected = text.substring(with: selection)
        let address = suggestedAddress.flatMap { isAddress($0) ? $0.trimmingCharacters(in: .whitespacesAndNewlines) : nil }
        if !selected.isEmpty, isAddress(selected) {
            return TextEdit(range: selection, replacement: "[](\(selected))", selectedRange: NSRange(location: selection.location + 1, length: 0))
        }
        let label = selected as NSString
        if let address {
            let replacement = "[\(selected)](\(address))"
            let caret = selected.isEmpty ? selection.location + 1 : selection.location + (replacement as NSString).length
            return TextEdit(range: selection, replacement: replacement, selectedRange: NSRange(location: caret, length: 0))
        }
        let caret = selected.isEmpty ? selection.location + 1 : selection.location + label.length + 3
        return TextEdit(range: selection, replacement: "[\(selected)]()", selectedRange: NSRange(location: caret, length: 0))
    }

    /// Turns the selection into a link when an address is pasted over text that isn't an address itself.
    public static func link(pasting pasted: String, in text: NSString, selection: NSRange) -> TextEdit? {
        guard selection.length > 0, isAddress(pasted) else { return nil }
        let selected = text.substring(with: selection)
        guard !selected.contains("\n"), !isAddress(selected) else { return nil }
        let replacement = "[\(selected)](\(pasted.trimmingCharacters(in: .whitespacesAndNewlines)))"
        return TextEdit(range: selection, replacement: replacement, selectedRange: NSRange(location: selection.location + (replacement as NSString).length, length: 0))
    }

    /// Turns the touched lines into headings of `level`, or into body text when `level` is 0 or the lines already have that level.
    public static func setHeading(level: Int, in text: NSString, selection: NSRange) -> TextEdit {
        let target = min(max(level, 0), 6)
        let lines = lineSlices(for: selection, in: text)
        let currentLevels = lines.map { headingLevel(of: $0.text) }
        let nonEmpty = zip(lines, currentLevels).filter { !$0.0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let effective = !nonEmpty.isEmpty && nonEmpty.allSatisfy({ $0.1.level == target }) ? 0 : target
        let prefix = effective > 0 ? String(repeating: "#", count: effective) + " " : ""
        return rewriteLines(lines, in: text, selection: selection) { line in
            let current = headingLevel(of: line)
            let body = (line as NSString).substring(from: current.prefixLength)
            return (prefix + body, current.prefixLength, (prefix as NSString).length)
        }
    }

    static func headingLevel(of line: String) -> (level: Int, prefixLength: Int) {
        guard let regex = headingExpression,
              let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
            return (0, 0)
        }
        return (match.range(at: 1).length, match.range.length)
    }

    /// Adds `> ` in front of the touched lines, or removes it when every non-empty line is already quoted.
    public static func toggleQuote(in text: NSString, selection: NSRange) -> TextEdit {
        let lines = lineSlices(for: selection, in: text)
        let nonEmpty = lines.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let removes = !nonEmpty.isEmpty && nonEmpty.allSatisfy { quotePrefixLength(of: $0.text) > 0 }
        return rewriteLines(lines, in: text, selection: selection) { line in
            if removes {
                let length = quotePrefixLength(of: line)
                guard length > 0 else { return (line, 0, 0) }
                var prefix = (line as NSString).substring(to: length)
                if let index = prefix.lastIndex(of: ">") {
                    prefix = String(prefix[..<index])
                }
                let rest = (line as NSString).substring(from: length)
                let trimmedPrefix = prefix.hasSuffix(" ") ? String(prefix.dropLast()) : prefix
                let kept = trimmedPrefix.trimmingCharacters(in: .whitespaces).isEmpty ? "" : trimmedPrefix + " "
                return (kept + rest, length, (kept as NSString).length)
            }
            return (line.isEmpty ? ">" : "> " + line, 0, line.isEmpty ? 1 : 2)
        }
    }

    static func quotePrefixLength(of line: String) -> Int {
        guard let regex = quoteExpression,
              let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else {
            return 0
        }
        return match.range.length
    }

    /// Turns the touched lines into tasks or checks and unchecks them.
    ///
    /// Lines that aren't tasks yet become unchecked tasks. When every line is a task, all of them are checked,
    /// or unchecked if they were all checked before.
    public static func toggleTask(in text: NSString, selection: NSRange) -> TextEdit {
        let lines = lineSlices(for: selection, in: text)
        let prefixes = lines.map { MarkdownListPrefix.parse($0.text) }
        let allTasks = prefixes.allSatisfy { $0?.checkbox != nil }
        let allChecked = prefixes.allSatisfy { $0?.checkbox == "x" || $0?.checkbox == "X" }
        return rewriteLines(lines, in: text, selection: selection) { line in
            let prefix = MarkdownListPrefix.parse(line)
            let nsLine = line as NSString
            if allTasks, let prefix, let location = prefix.checkboxLocation {
                let mark = allChecked ? " " : "x"
                let rewritten = nsLine.replacingCharacters(in: NSRange(location: location, length: 1), with: mark)
                return (rewritten, prefix.length, prefix.length)
            }
            if let prefix {
                guard prefix.checkbox == nil else { return (line, prefix.length, prefix.length) }
                let marker = nsLine.substring(to: prefix.length)
                let separator = marker.hasSuffix(" ") || marker.hasSuffix("\t") ? "" : " "
                let newPrefix = marker + separator + "[ ] "
                return (newPrefix + nsLine.substring(from: prefix.length), prefix.length, (newPrefix as NSString).length)
            }
            let indentation = String(line.prefix { $0 == " " || $0 == "\t" })
            let indentationLength = (indentation as NSString).length
            let newPrefix = indentation + "- [ ] "
            return (newPrefix + nsLine.substring(from: indentationLength), indentationLength, (newPrefix as NSString).length)
        }
    }

    /// Checks or unchecks the task in the one-based `line`; returns `nil` when that line isn't a task.
    public static func toggleTask(atLine line: Int, in text: NSString) -> TextEdit? {
        guard let range = LineIndex(text: text).range(ofLine: line) else { return nil }
        let content = text.substring(with: range).trimmingCharacters(in: .newlines)
        guard let prefix = MarkdownListPrefix.parse(content), let checkbox = prefix.checkbox, let location = prefix.checkboxLocation else {
            return nil
        }
        let mark = checkbox == " " ? "x" : " "
        let target = NSRange(location: range.location + location, length: 1)
        return TextEdit(range: target, replacement: mark, selectedRange: NSRange(location: NSMaxRange(target), length: 0))
    }

    /// Whether the line containing `location` is a list item.
    public static func isListItem(at location: Int, in text: NSString) -> Bool {
        let lineRange = text.lineRange(for: NSRange(location: min(location, text.length), length: 0))
        return MarkdownListPrefix.parse(text.substring(with: lineRange).trimmingCharacters(in: .newlines)) != nil
    }

    /// Continues a list or quote at the caret with the next marker, or ends it when the current item is empty.
    ///
    /// Following items of an ordered list are renumbered.
    public static func continueList(in text: NSString, selection: NSRange) -> TextEdit? {
        guard selection.length == 0 else { return nil }
        let caret = selection.location
        let lineRange = text.lineRange(for: NSRange(location: caret, length: 0))
        let contentRange = contentRange(of: lineRange, in: text)
        let line = text.substring(with: contentRange)
        let caretInLine = caret - contentRange.location
        guard caretInLine <= contentRange.length else { return nil }
        if let prefix = MarkdownListPrefix.parse(line) {
            guard caretInLine >= prefix.length else { return nil }
            let body = (line as NSString).substring(from: prefix.length)
            if body.trimmingCharacters(in: .whitespaces).isEmpty {
                return TextEdit(range: contentRange, replacement: "", selectedRange: NSRange(location: contentRange.location, length: 0))
            }
            var marker = prefix.indentation
            if let number = prefix.number {
                marker += "\(number + 1)\(prefix.delimiter) "
            } else {
                marker += (prefix.bullet ?? "-") + " "
            }
            if prefix.checkbox != nil {
                marker += "[ ] "
            }
            let head = "\n" + marker
            let headLength = (head as NSString).length
            guard let number = prefix.number else {
                return TextEdit(range: selection, replacement: head, selectedRange: NSRange(location: caret + headLength, length: 0))
            }
            let rest = text.substring(with: NSRange(location: caret, length: NSMaxRange(lineRange) - caret))
            let renumbered = renumberedItems(after: NSMaxRange(lineRange), in: text, indentation: prefix.indentation, firstNumber: number + 2)
            let range = NSRange(location: caret, length: NSMaxRange(lineRange) - caret + renumbered.length)
            return TextEdit(range: range, replacement: head + rest + renumbered.text, selectedRange: NSRange(location: caret + headLength, length: 0))
        }
        let quoteLength = quotePrefixLength(of: line)
        guard quoteLength > 0, caretInLine >= quoteLength else { return nil }
        let quotePrefix = (line as NSString).substring(to: quoteLength)
        if (line as NSString).substring(from: quoteLength).trimmingCharacters(in: .whitespaces).isEmpty {
            return TextEdit(range: contentRange, replacement: "", selectedRange: NSRange(location: contentRange.location, length: 0))
        }
        let marker = quotePrefix.hasSuffix(" ") ? quotePrefix : quotePrefix + " "
        let head = "\n" + marker
        return TextEdit(range: selection, replacement: head, selectedRange: NSRange(location: caret + (head as NSString).length, length: 0))
    }

    /// Rewrites the numbers of the ordered items that follow `location` at the same indentation.
    private static func renumberedItems(after location: Int, in text: NSString, indentation: String, firstNumber: Int) -> (text: String, length: Int) {
        var cursor = location
        var next = firstNumber
        var result = ""
        var consumedEnd = location
        var pending = ""
        var blankRun = 0
        while cursor < text.length {
            let lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
            let raw = text.substring(with: lineRange)
            let line = raw.trimmingCharacters(in: .newlines)
            cursor = NSMaxRange(lineRange)
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blankRun += 1
                if blankRun > 1 {
                    break
                }
                pending += raw
                continue
            }
            blankRun = 0
            if let prefix = MarkdownListPrefix.parse(line), prefix.indentation == indentation {
                guard prefix.isOrdered else { break }
                let numberStart = (indentation as NSString).length
                let numberLength = String(prefix.number ?? 0).utf16.count
                let rewritten = (raw as NSString).replacingCharacters(in: NSRange(location: numberStart, length: numberLength), with: String(next))
                next += 1
                result += pending + rewritten
                pending = ""
                consumedEnd = NSMaxRange(lineRange)
                continue
            }
            let lineIndentation = line.prefix { $0 == " " || $0 == "\t" }
            if lineIndentation.count > indentation.count {
                pending += raw
                continue
            }
            break
        }
        return (result, consumedEnd - location)
    }

    /// Markdown for an image file, with a path relative to `folderURL` when possible.
    public static func imageMarkdown(for fileURL: URL, relativeTo folderURL: URL?) -> String {
        let alt = fileURL.deletingPathExtension().lastPathComponent
        let path = folderURL.flatMap { relativePath(from: $0, to: fileURL) } ?? fileURL.standardizedFileURL.path
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "()")
        let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
        return "![\(alt)](\(encoded))"
    }

    /// The path of `fileURL` relative to `folderURL`, or `nil` when they share nothing but the root.
    static func relativePath(from folderURL: URL, to fileURL: URL) -> String? {
        let folder = folderURL.standardizedFileURL.pathComponents
        let file = fileURL.standardizedFileURL.pathComponents
        var common = 0
        while common < folder.count, common < file.count, folder[common] == file[common] {
            common += 1
        }
        guard common > 1 else { return nil }
        let ups = Array(repeating: "..", count: folder.count - common)
        return (ups + file[common...]).joined(separator: "/")
    }

    struct LineSlice {
        let range: NSRange
        let text: String
    }

    static func contentRange(of lineRange: NSRange, in text: NSString) -> NSRange {
        var range = lineRange
        if range.length > 0, text.character(at: NSMaxRange(range) - 1) == 0x0A {
            range.length -= 1
        }
        return range
    }

    static func lineSlices(for selection: NSRange, in text: NSString) -> [LineSlice] {
        let block = LineOperations.contentLineRange(for: selection, in: text)
        var slices: [LineSlice] = []
        var location = block.location
        let end = NSMaxRange(block)
        repeat {
            let lineRange = contentRange(of: text.lineRange(for: NSRange(location: location, length: 0)), in: text)
            let clipped = NSRange(location: lineRange.location, length: min(NSMaxRange(lineRange), end) - lineRange.location)
            slices.append(LineSlice(range: clipped, text: text.substring(with: clipped)))
            location = NSMaxRange(lineRange) + 1
        } while location <= end && location < text.length
        if location == text.length, location <= end, text.length > 0, text.character(at: text.length - 1) == 0x0A, slices.last.map({ NSMaxRange($0.range) < end }) == true {
            slices.append(LineSlice(range: NSRange(location: location, length: 0), text: ""))
        }
        return slices
    }

    /// Rewrites every line with `transform`, which returns the new line and the old and new prefix lengths.
    static func rewriteLines(
        _ lines: [LineSlice],
        in text: NSString,
        selection: NSRange,
        transform: (String) -> (line: String, oldPrefix: Int, newPrefix: Int)
    ) -> TextEdit {
        guard let first = lines.first, let last = lines.last else {
            return TextEdit(range: selection, replacement: text.substring(with: selection), selectedRange: selection)
        }
        let block = NSRange(location: first.range.location, length: NSMaxRange(last.range) - first.range.location)
        var rewritten: [String] = []
        var caret = selection.location
        for line in lines {
            let result = transform(line.text)
            rewritten.append(result.line)
            if selection.length == 0, selection.location >= line.range.location, selection.location <= NSMaxRange(line.range) {
                let offset = selection.location - line.range.location
                let shifted = max(result.newPrefix, offset - result.oldPrefix + result.newPrefix)
                caret = block.location + rewritten.dropLast().reduce(0) { $0 + ($1 as NSString).length + 1 } + min(shifted, (result.line as NSString).length)
            }
        }
        let replacement = rewritten.joined(separator: "\n")
        let selected = selection.length == 0
            ? NSRange(location: caret, length: 0)
            : NSRange(location: block.location, length: (replacement as NSString).length)
        return TextEdit(range: block, replacement: replacement, selectedRange: selected)
    }
}
