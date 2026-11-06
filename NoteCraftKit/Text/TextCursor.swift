import Foundation

public struct TextCursor: Equatable, Sendable {
    public var anchor: Int
    public var head: Int
    public var goalX: Double?

    public init(anchor: Int, head: Int, goalX: Double? = nil) {
        self.anchor = anchor
        self.head = head
        self.goalX = goalX
    }

    public init(caret location: Int) {
        self.init(anchor: location, head: location)
    }

    public init(range: NSRange) {
        self.init(anchor: range.location, head: NSMaxRange(range))
    }

    public var range: NSRange {
        NSRange(location: min(anchor, head), length: abs(head - anchor))
    }

    public var isEmpty: Bool {
        anchor == head
    }

    /// Sorts `cursors` by position and merges cursors whose ranges overlap, as well as carets on the same spot or at the edge of a selection.
    public static func merged(_ cursors: [TextCursor]) -> [TextCursor] {
        let sorted = cursors.sorted {
            ($0.range.location, NSMaxRange($0.range)) < ($1.range.location, NSMaxRange($1.range))
        }
        var result: [TextCursor] = []
        for cursor in sorted {
            guard let last = result.last else {
                result.append(cursor)
                continue
            }
            let previous = last.range
            let current = cursor.range
            let end = NSMaxRange(previous)
            guard current.location < end || (current.location == end && (last.isEmpty || cursor.isEmpty)) else {
                result.append(cursor)
                continue
            }
            let union = NSUnionRange(previous, current)
            let reference = last.isEmpty ? cursor : last
            let isForward = reference.head >= reference.anchor
            result[result.count - 1] = isForward
                ? TextCursor(anchor: union.location, head: NSMaxRange(union))
                : TextCursor(anchor: NSMaxRange(union), head: union.location)
        }
        return result
    }
}
