import Foundation

public struct TextPosition: Equatable, Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

/// Maps UTF-16 offsets to line numbers for text that uses LF line endings.
public struct LineIndex: Equatable, Sendable {
    public private(set) var lineStarts: [Int]
    public private(set) var length: Int

    /// Builds the index by scanning `text` once.
    public init(text: NSString) {
        lineStarts = [0]
        length = text.length
        appendLineStarts(in: text, range: NSRange(location: 0, length: text.length))
    }

    /// Builds the index by scanning `text` once.
    public init(text: String) {
        self.init(text: text as NSString)
    }

    public var lineCount: Int {
        lineStarts.count
    }

    /// Returns the zero-based index of the line containing `offset`.
    public func lineIndex(containing offset: Int) -> Int {
        let target = min(max(offset, 0), length)
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= target {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    /// Returns the one-based line number of the line containing `offset`.
    public func lineNumber(at offset: Int) -> Int {
        lineIndex(containing: offset) + 1
    }

    /// Returns the one-based line and column for `offset`.
    public func position(at offset: Int) -> TextPosition {
        let clamped = min(max(offset, 0), length)
        let index = lineIndex(containing: clamped)
        return TextPosition(line: index + 1, column: clamped - lineStarts[index] + 1)
    }

    /// Returns the range of a one-based line without its line ending, or `nil` when the line does not exist.
    public func range(ofLine lineNumber: Int) -> NSRange? {
        guard lineNumber >= 1, lineNumber <= lineStarts.count else { return nil }
        let start = lineStarts[lineNumber - 1]
        let end = lineNumber < lineStarts.count ? lineStarts[lineNumber] - 1 : length
        return NSRange(location: start, length: end - start)
    }

    /// Returns the UTF-16 offset for a one-based line and column, clamped to the line.
    public func offset(line: Int, column: Int) -> Int? {
        guard let lineRange = range(ofLine: line) else { return nil }
        return lineRange.location + min(max(column - 1, 0), lineRange.length)
    }

    /// Updates the index after `editedRange` (in the new text) replaced text, changing the length by `changeInLength`.
    public mutating func applyEdit(editedRange: NSRange, changeInLength: Int, in text: NSString) {
        let location = editedRange.location
        let oldEnd = location + editedRange.length - changeInLength
        let firstLine = lineIndex(containing: location)
        let trailing = lineStarts[(firstLine + 1)...].filter { $0 > oldEnd }.map { $0 + changeInLength }
        lineStarts.removeSubrange((firstLine + 1)...)
        length = text.length
        appendLineStarts(in: text, range: editedRange)
        lineStarts.append(contentsOf: trailing)
    }

    private mutating func appendLineStarts(in text: NSString, range: NSRange) {
        let chunkSize = 16_384
        var buffer = [unichar](repeating: 0, count: chunkSize)
        var location = range.location
        let end = range.location + range.length
        while location < end {
            let count = min(chunkSize, end - location)
            buffer.withUnsafeMutableBufferPointer { pointer in
                text.getCharacters(pointer.baseAddress!, range: NSRange(location: location, length: count))
            }
            for index in 0..<count where buffer[index] == 0x0A {
                lineStarts.append(location + index + 1)
            }
            location += count
        }
    }
}
