import Foundation
import Testing
@testable import NoteCraftKit

struct TextCursorTests {
    @Test func describesRangeAndDirection() {
        let backward = TextCursor(anchor: 8, head: 3)
        #expect(backward.range == NSRange(location: 3, length: 5))
        #expect(!backward.isEmpty)
        #expect(TextCursor(caret: 4).isEmpty)
        #expect(TextCursor(range: NSRange(location: 2, length: 3)) == TextCursor(anchor: 2, head: 5))
    }

    @Test func sortsAndKeepsSeparateCursors() {
        let cursors = [TextCursor(caret: 9), TextCursor(anchor: 1, head: 3), TextCursor(anchor: 3, head: 5)]
        #expect(TextCursor.merged(cursors) == [TextCursor(anchor: 1, head: 3), TextCursor(anchor: 3, head: 5), TextCursor(caret: 9)])
    }

    @Test func mergesOverlappingCursors() {
        #expect(TextCursor.merged([TextCursor(caret: 4), TextCursor(caret: 4)]) == [TextCursor(caret: 4)])
        #expect(TextCursor.merged([TextCursor(anchor: 2, head: 6), TextCursor(caret: 4)]) == [TextCursor(anchor: 2, head: 6)])
        #expect(TextCursor.merged([TextCursor(anchor: 2, head: 6), TextCursor(caret: 6)]) == [TextCursor(anchor: 2, head: 6)])
        #expect(TextCursor.merged([TextCursor(caret: 2), TextCursor(anchor: 6, head: 2)]) == [TextCursor(anchor: 6, head: 2)])
        #expect(TextCursor.merged([TextCursor(anchor: 5, head: 1), TextCursor(anchor: 3, head: 8)]) == [TextCursor(anchor: 8, head: 1)])
        #expect(TextCursor.merged([]).isEmpty)
    }
}
