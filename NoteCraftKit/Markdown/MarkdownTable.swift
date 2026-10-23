import Foundation

public struct MarkdownTable: Equatable, Sendable {
    public enum Alignment: Equatable, Sendable {
        case none
        case left
        case center
        case right
    }

    public var header: [String]
    public var alignments: [Alignment]
    public var rows: [[String]]

    public init(header: [String], alignments: [Alignment], rows: [[String]]) {
        self.header = header
        self.alignments = alignments
        self.rows = rows
    }

    public var columnCount: Int {
        max(header.count, alignments.count, rows.map(\.count).max() ?? 0)
    }

    /// Parses a table from its header line, delimiter line and body lines.
    public static func parse(_ lines: [String]) -> MarkdownTable? {
        guard lines.count >= 2, let alignments = delimiterAlignments(lines[1]) else { return nil }
        return MarkdownTable(header: cells(of: lines[0]), alignments: alignments, rows: lines.dropFirst(2).map(cells(of:)))
    }

    /// Splits a table line into trimmed cells, honoring `\|` escapes and pipes inside code spans.
    static func cells(of line: String) -> [String] {
        var content = line.trimmingCharacters(in: .whitespaces)
        if content.hasPrefix("|") {
            content.removeFirst()
        }
        if content.hasSuffix("|"), !content.hasSuffix("\\|") {
            content.removeLast()
        }
        var cells: [String] = []
        var current = ""
        var isEscaped = false
        var isInCode = false
        for character in content {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }
            switch character {
            case "\\":
                current.append(character)
                isEscaped = true
            case "`":
                current.append(character)
                isInCode.toggle()
            case "|" where !isInCode:
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            default:
                current.append(character)
            }
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    /// The column alignments of a delimiter line such as `| :-- | :-: | --: |`, or `nil` for other lines.
    static func delimiterAlignments(_ line: String) -> [Alignment]? {
        guard line.contains("-") else { return nil }
        var alignments: [Alignment] = []
        for cell in cells(of: line) {
            guard !cell.isEmpty, cell.allSatisfy({ $0 == "-" || $0 == ":" }), cell.contains("-"),
                  !cell.dropFirst().dropLast().contains(":") else { return nil }
            switch (cell.hasPrefix(":"), cell.hasSuffix(":")) {
            case (true, true): alignments.append(.center)
            case (true, false): alignments.append(.left)
            case (false, true): alignments.append(.right)
            case (false, false): alignments.append(.none)
            }
        }
        return alignments
    }

    /// The lines of the table with every column padded to the same width.
    public func formattedLines() -> [String] {
        let count = max(columnCount, 1)
        let widths = (0..<count).map { column in
            max(3, ([header] + rows).map { $0.indices.contains(column) ? $0[column].count : 0 }.max() ?? 0)
        }
        func line(_ cells: [String]) -> String {
            let padded = (0..<count).map { column -> String in
                let cell = cells.indices.contains(column) ? cells[column] : ""
                return cell + String(repeating: " ", count: widths[column] - cell.count)
            }
            return "| " + padded.joined(separator: " | ") + " |"
        }
        let delimiter = (0..<count).map { column -> String in
            let alignment = alignments.indices.contains(column) ? alignments[column] : .none
            let width = widths[column]
            switch alignment {
            case .none: return String(repeating: "-", count: width)
            case .left: return ":" + String(repeating: "-", count: width - 1)
            case .right: return String(repeating: "-", count: width - 1) + ":"
            case .center: return ":" + String(repeating: "-", count: width - 2) + ":"
            }
        }
        return [line(header), "| " + delimiter.joined(separator: " | ") + " |"] + rows.map(line)
    }

    /// The offset of the content of `column` in the formatted line, in UTF-16 units.
    func contentOffset(ofColumn column: Int, in formattedLine: String) -> Int {
        var pipes = 0
        for (offset, unit) in formattedLine.utf16.enumerated() where unit == 0x7C {
            if pipes == column {
                return offset + 2
            }
            pipes += 1
        }
        return (formattedLine as NSString).length
    }
}

public enum MarkdownTableEditing {
    struct Block {
        let range: NSRange
        let lines: [String]
        let caretRow: Int
        let caretColumn: Int
        let caretOffsetInCell: Int
    }

    /// Inserts an empty table with `headers` and two rows at the start of the caret's line.
    public static func insertTable(in text: NSString, selection: NSRange, headers: [String]) -> TextEdit {
        let empty = headers.map { _ in "" }
        let table = MarkdownTable(header: headers, alignments: headers.map { _ in .none }, rows: [empty, empty])
        let body = table.formattedLines().joined(separator: "\n")
        let lineRange = text.lineRange(for: NSRange(location: selection.location, length: 0))
        let content = MarkdownEditing.contentRange(of: lineRange, in: text)
        let replaced: NSRange
        let leading: String
        let trailing: String
        if text.substring(with: content).trimmingCharacters(in: .whitespaces).isEmpty {
            replaced = content
            leading = content.location >= 2 && text.character(at: content.location - 2) != 0x0A ? "\n" : ""
            trailing = ""
        } else if content.length < lineRange.length {
            replaced = NSRange(location: NSMaxRange(lineRange), length: 0)
            leading = "\n"
            trailing = "\n"
        } else {
            replaced = NSRange(location: NSMaxRange(lineRange), length: 0)
            leading = "\n\n"
            trailing = ""
        }
        let firstCell = replaced.location + (leading as NSString).length + 2
        let firstHeaderLength = ((headers.first ?? "") as NSString).length
        return TextEdit(range: replaced, replacement: leading + body + trailing, selectedRange: NSRange(location: firstCell, length: firstHeaderLength))
    }

    /// Aligns the columns of the table around the caret.
    public static func format(in text: NSString, selection: NSRange) -> TextEdit? {
        guard let block = block(around: selection.location, in: text), let table = MarkdownTable.parse(block.lines) else { return nil }
        return edit(for: table, replacing: block, caretRow: block.caretRow, caretColumn: block.caretColumn, offsetInCell: block.caretOffsetInCell)
    }

    /// Adds an empty row below the caret's row, or below the header when the caret is in the header.
    public static func addRow(in text: NSString, selection: NSRange) -> TextEdit? {
        guard let block = block(around: selection.location, in: text), var table = MarkdownTable.parse(block.lines) else { return nil }
        let bodyIndex = max(block.caretRow - 1, 0)
        table.rows.insert(Array(repeating: "", count: table.columnCount), at: min(bodyIndex, table.rows.count))
        return edit(for: table, replacing: block, caretRow: bodyIndex + 2, caretColumn: 0, offsetInCell: 0)
    }

    /// Adds an empty column to the right of the caret's column.
    public static func addColumn(in text: NSString, selection: NSRange) -> TextEdit? {
        guard let block = block(around: selection.location, in: text), var table = MarkdownTable.parse(block.lines) else { return nil }
        let count = table.columnCount
        let index = min(block.caretColumn + 1, count)
        func inserting(_ cells: [String]) -> [String] {
            var padded = cells + Array(repeating: "", count: max(0, count - cells.count))
            padded.insert("", at: index)
            return padded
        }
        table.header = inserting(table.header)
        var alignments = table.alignments + Array(repeating: MarkdownTable.Alignment.none, count: max(0, count - table.alignments.count))
        alignments.insert(.none, at: index)
        table.alignments = alignments
        table.rows = table.rows.map(inserting)
        return edit(for: table, replacing: block, caretRow: block.caretRow, caretColumn: index, offsetInCell: 0)
    }

    private static func edit(for table: MarkdownTable, replacing block: Block, caretRow: Int, caretColumn: Int, offsetInCell: Int) -> TextEdit {
        let lines = table.formattedLines()
        let row = min(max(caretRow == 1 ? 0 : caretRow, 0), lines.count - 1)
        let column = min(max(caretColumn, 0), max(table.columnCount - 1, 0))
        let lineStart = lines.prefix(row).reduce(0) { $0 + ($1 as NSString).length + 1 }
        let cells = row == 0 ? table.header : (row >= 2 && row - 2 < table.rows.count ? table.rows[row - 2] : [])
        let cellLength = cells.indices.contains(column) ? (cells[column] as NSString).length : 0
        let caret = block.range.location + lineStart + table.contentOffset(ofColumn: column, in: lines[row]) + min(offsetInCell, cellLength)
        return TextEdit(range: block.range, replacement: lines.joined(separator: "\n"), selectedRange: NSRange(location: caret, length: 0))
    }

    /// Finds the table around `location`: the header, the delimiter line and the following lines with pipes.
    static func block(around location: Int, in text: NSString) -> Block? {
        var lineRanges: [NSRange] = []
        var cursor = 0
        while cursor < text.length {
            let range = text.lineRange(for: NSRange(location: cursor, length: 0))
            lineRanges.append(MarkdownEditing.contentRange(of: range, in: text))
            cursor = NSMaxRange(range)
        }
        guard let caretLine = lineRanges.firstIndex(where: { location >= $0.location && location <= NSMaxRange($0) }) else { return nil }
        func isTableLine(_ index: Int) -> Bool {
            let line = text.substring(with: lineRanges[index])
            return line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard isTableLine(caretLine) else { return nil }
        var first = caretLine
        while first > 0, isTableLine(first - 1) {
            first -= 1
        }
        var last = caretLine
        while last + 1 < lineRanges.count, isTableLine(last + 1) {
            last += 1
        }
        guard let delimiter = (first + 1...max(first + 1, last)).first(where: {
            $0 <= last && MarkdownTable.delimiterAlignments(text.substring(with: lineRanges[$0])) != nil
        }), delimiter <= last else { return nil }
        let header = delimiter - 1
        guard caretLine >= header else { return nil }
        let lines = (header...last).map { text.substring(with: lineRanges[$0]) }
        let range = NSRange(location: lineRanges[header].location, length: NSMaxRange(lineRanges[last]) - lineRanges[header].location)
        let caretText = text.substring(with: lineRanges[caretLine]) as NSString
        let offset = location - lineRanges[caretLine].location
        let beforeCaret = caretText.substring(to: min(offset, caretText.length))
        let hasLeadingPipe = beforeCaret.trimmingCharacters(in: .whitespaces).hasPrefix("|")
        let pipes = beforeCaret.filter { $0 == "|" }.count
        let column = max(0, pipes - (hasLeadingPipe ? 1 : 0))
        let lastPipe = (beforeCaret as NSString).range(of: "|", options: .backwards)
        var cellStart = lastPipe.location == NSNotFound ? 0 : NSMaxRange(lastPipe)
        while cellStart < beforeCaret.utf16.count, (beforeCaret as NSString).character(at: cellStart) == 0x20 {
            cellStart += 1
        }
        return Block(
            range: range,
            lines: lines,
            caretRow: caretLine - header,
            caretColumn: column,
            caretOffsetInCell: max(0, offset - cellStart)
        )
    }
}
