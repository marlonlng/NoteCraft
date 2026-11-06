import AppKit
import NoteCraftKit

enum CursorMotion {
    case characterBackward
    case characterForward
    case wordBackward
    case wordForward
    case lineStart
    case lineEnd
    case paragraphBackward
    case paragraphForward
    case documentStart
    case documentEnd
    case lineUp
    case lineDown

    var collapsesSelection: Bool {
        switch self {
        case .characterBackward, .characterForward, .wordBackward, .wordForward: true
        default: false
        }
    }

    var isBackward: Bool {
        switch self {
        case .characterBackward, .wordBackward, .lineStart, .paragraphBackward, .documentStart, .lineUp: true
        case .characterForward, .wordForward, .lineEnd, .paragraphForward, .documentEnd, .lineDown: false
        }
    }
}

extension EditorTextView {
    static let cursorMoveCommands: [Selector: (motion: CursorMotion, extendsSelection: Bool)] = [
        #selector(moveLeft(_:)): (.characterBackward, false),
        #selector(moveBackward(_:)): (.characterBackward, false),
        #selector(moveRight(_:)): (.characterForward, false),
        #selector(moveForward(_:)): (.characterForward, false),
        #selector(moveWordLeft(_:)): (.wordBackward, false),
        #selector(moveWordBackward(_:)): (.wordBackward, false),
        #selector(moveWordRight(_:)): (.wordForward, false),
        #selector(moveWordForward(_:)): (.wordForward, false),
        #selector(moveToLeftEndOfLine(_:)): (.lineStart, false),
        #selector(moveToBeginningOfLine(_:)): (.lineStart, false),
        #selector(moveToBeginningOfParagraph(_:)): (.lineStart, false),
        #selector(moveToRightEndOfLine(_:)): (.lineEnd, false),
        #selector(moveToEndOfLine(_:)): (.lineEnd, false),
        #selector(moveToEndOfParagraph(_:)): (.lineEnd, false),
        #selector(moveToBeginningOfDocument(_:)): (.documentStart, false),
        #selector(moveToEndOfDocument(_:)): (.documentEnd, false),
        #selector(moveUp(_:)): (.lineUp, false),
        #selector(moveDown(_:)): (.lineDown, false),
        #selector(moveLeftAndModifySelection(_:)): (.characterBackward, true),
        #selector(moveBackwardAndModifySelection(_:)): (.characterBackward, true),
        #selector(moveRightAndModifySelection(_:)): (.characterForward, true),
        #selector(moveForwardAndModifySelection(_:)): (.characterForward, true),
        #selector(moveWordLeftAndModifySelection(_:)): (.wordBackward, true),
        #selector(moveWordBackwardAndModifySelection(_:)): (.wordBackward, true),
        #selector(moveWordRightAndModifySelection(_:)): (.wordForward, true),
        #selector(moveWordForwardAndModifySelection(_:)): (.wordForward, true),
        #selector(moveToLeftEndOfLineAndModifySelection(_:)): (.lineStart, true),
        #selector(moveToBeginningOfLineAndModifySelection(_:)): (.lineStart, true),
        #selector(moveToBeginningOfParagraphAndModifySelection(_:)): (.lineStart, true),
        #selector(moveParagraphBackwardAndModifySelection(_:)): (.paragraphBackward, true),
        #selector(moveToRightEndOfLineAndModifySelection(_:)): (.lineEnd, true),
        #selector(moveToEndOfLineAndModifySelection(_:)): (.lineEnd, true),
        #selector(moveToEndOfParagraphAndModifySelection(_:)): (.lineEnd, true),
        #selector(moveParagraphForwardAndModifySelection(_:)): (.paragraphForward, true),
        #selector(moveToBeginningOfDocumentAndModifySelection(_:)): (.documentStart, true),
        #selector(moveToEndOfDocumentAndModifySelection(_:)): (.documentEnd, true),
        #selector(moveUpAndModifySelection(_:)): (.lineUp, true),
        #selector(moveDownAndModifySelection(_:)): (.lineDown, true)
    ]

    static let cursorDeleteCommands: [Selector: CursorMotion] = [
        #selector(deleteForward(_:)): .characterForward,
        #selector(deleteWordBackward(_:)): .wordBackward,
        #selector(deleteWordForward(_:)): .wordForward,
        #selector(deleteToBeginningOfLine(_:)): .lineStart,
        #selector(deleteToBeginningOfParagraph(_:)): .lineStart,
        #selector(deleteToEndOfLine(_:)): .lineEnd,
        #selector(deleteToEndOfParagraph(_:)): .lineEnd
    ]

    /// The cursors that keyboard commands act on: the active cursors, or every range of a multiple selection.
    var activeCursors: [TextCursor]? {
        if cursors.count > 1 {
            return cursors
        }
        let ranges = selectedRanges.map(\.rangeValue)
        return ranges.count > 1 ? ranges.map(TextCursor.init(range:)) : nil
    }

    override func doCommand(by selector: Selector) {
        if let current = activeCursors {
            if let command = Self.cursorMoveCommands[selector] {
                moveCursors(current, by: command.motion, extendingSelection: command.extendsSelection)
                return
            }
            if let motion = Self.cursorDeleteCommands[selector] {
                deleteAtCursors(current, toward: motion)
                return
            }
        }
        super.doCommand(by: selector)
    }

    /// Moves every cursor; without extending, a selection collapses to its edge in the direction of the motion first.
    func moveCursors(_ current: [TextCursor], by motion: CursorMotion, extendingSelection: Bool) {
        let moved = current.map { cursor -> TextCursor in
            if extendingSelection {
                let target = destination(of: motion, from: cursor.head, goalX: cursor.goalX)
                return TextCursor(anchor: cursor.anchor, head: target.position, goalX: target.goalX)
            }
            var start = cursor.head
            if !cursor.isEmpty {
                start = motion.isBackward ? cursor.range.location : NSMaxRange(cursor.range)
                if motion.collapsesSelection {
                    return TextCursor(caret: start)
                }
            }
            let target = destination(of: motion, from: start, goalX: cursor.isEmpty ? cursor.goalX : nil)
            return TextCursor(anchor: target.position, head: target.position, goalX: target.goalX)
        }
        setCursors(moved)
        let visible = motion.isBackward ? moved.map(\.head).min() : moved.map(\.head).max()
        if let visible {
            scrollRangeToVisible(NSRange(location: visible, length: 0))
        }
    }

    /// Deletes every selection, or the text between each caret and the end of `motion`.
    func deleteAtCursors(_ current: [TextCursor], toward motion: CursorMotion) {
        let ranges = current.map { cursor -> NSRange in
            guard cursor.isEmpty else { return cursor.range }
            let target = destination(of: motion, from: cursor.head, goalX: nil).position
            return NSRange(location: min(target, cursor.head), length: abs(target - cursor.head))
        }
        let merged = TextCursor.merged(ranges.map(TextCursor.init(range:))).map(\.range)
        guard merged.contains(where: { $0.length > 0 }) else {
            NSSound.beep()
            return
        }
        replace(merged, with: Array(repeating: "", count: merged.count))
    }

    /// The position a caret at `position` reaches with `motion`, and the horizontal goal for further vertical moves.
    func destination(of motion: CursorMotion, from position: Int, goalX: Double?) -> (position: Int, goalX: Double?) {
        let text = nsString
        let length = text.length
        switch motion {
        case .characterBackward:
            return (position > 0 ? text.rangeOfComposedCharacterSequence(at: position - 1).location : 0, nil)
        case .characterForward:
            return (position < length ? NSMaxRange(text.rangeOfComposedCharacterSequence(at: position)) : length, nil)
        case .wordBackward:
            return (position > 0 ? textStorage?.nextWord(from: position, forward: false) ?? 0 : 0, nil)
        case .wordForward:
            return (position < length ? textStorage?.nextWord(from: position, forward: true) ?? length : length, nil)
        case .lineStart:
            return (lineStart(at: position), nil)
        case .lineEnd:
            return (lineContentEnd(at: position), nil)
        case .paragraphBackward:
            let start = lineStart(at: position)
            return (start < position || start == 0 ? start : lineStart(at: start - 1), nil)
        case .paragraphForward:
            let end = lineContentEnd(at: position)
            return (end > position || end == length ? end : lineContentEnd(at: end + 1), nil)
        case .documentStart:
            return (0, nil)
        case .documentEnd:
            return (length, nil)
        case .lineUp, .lineDown:
            return verticalDestination(from: position, goalX: goalX, upward: motion == .lineUp)
        }
    }

    private func lineStart(at position: Int) -> Int {
        nsString.lineRange(for: NSRange(location: min(position, nsString.length), length: 0)).location
    }

    private func lineContentEnd(at position: Int) -> Int {
        let range = nsString.lineRange(for: NSRange(location: min(position, nsString.length), length: 0))
        let end = NSMaxRange(range)
        return end > range.location && nsString.character(at: end - 1) == 0x0A ? end - 1 : end
    }

    private func verticalDestination(from position: Int, goalX: Double?, upward: Bool) -> (position: Int, goalX: Double?) {
        guard let layoutManager, let textContainer, let caret = caretRect(at: position) else { return (position, goalX) }
        let x = goalX ?? Double(caret.minX)
        let y = upward ? caret.minY - caret.height / 2 : caret.maxY + caret.height / 2
        let used = layoutManager.usedRect(for: textContainer).union(layoutManager.extraLineFragmentRect)
        if y < textContainerOrigin.y {
            return (0, x)
        }
        if y > textContainerOrigin.y + used.maxY {
            return (nsString.length, x)
        }
        return (characterIndexForInsertion(at: NSPoint(x: x, y: y)), x)
    }

    /// Places a blinking system caret at every additional cursor without a selection.
    func updateCaretIndicators() {
        var locations = insertionLocations
        if cursors.count > 1, cursors.allSatisfy(\.isEmpty) {
            locations.removeFirst()
        }
        while caretIndicators.count < locations.count {
            let indicator = NSTextInsertionIndicator(frame: .zero)
            indicator.automaticModeOptions = []
            addSubview(indicator)
            caretIndicators.append(indicator)
        }
        while caretIndicators.count > locations.count {
            caretIndicators.removeLast().removeFromSuperview()
        }
        let isActive = window?.isKeyWindow == true && window?.firstResponder === self
        for (indicator, location) in zip(caretIndicators, locations) {
            if let rect = caretRect(at: location) {
                indicator.frame = NSRect(x: rect.minX, y: rect.minY, width: max(rect.width, 2), height: rect.height)
            }
            indicator.color = insertionPointColor
            indicator.displayMode = isActive ? .automatic : .hidden
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers = []
        guard let window else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            windowObservers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateCaretIndicators()
                }
            })
        }
    }

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        updateCaretIndicators()
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        updateCaretIndicators()
        return didResign
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if !caretIndicators.isEmpty {
            updateCaretIndicators()
        }
    }
}
