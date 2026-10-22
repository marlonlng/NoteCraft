import Foundation

/// A single replacement in a text together with the selection to show afterwards.
public struct TextEdit: Equatable, Sendable {
    public let range: NSRange
    public let replacement: String
    public let selectedRange: NSRange

    public init(range: NSRange, replacement: String, selectedRange: NSRange) {
        self.range = range
        self.replacement = replacement
        self.selectedRange = selectedRange
    }

    /// Returns `text` with the edit applied.
    public func applied(to text: String) -> String {
        (text as NSString).replacingCharacters(in: range, with: replacement)
    }
}

public enum LineMoveDirection: Sendable {
    case up
    case down
}
