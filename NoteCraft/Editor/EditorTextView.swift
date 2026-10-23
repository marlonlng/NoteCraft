import AppKit
import NoteCraftKit

final class EditorTextView: NSTextView {
    var indentation = Indentation(usesTabs: false, width: 4)
    var commentSyntax = CommentSyntax()
    var autoIndents = true
    var closesBrackets = true
    var highlightsMatchingBrackets = true
    var isMarkdown = false
    var documentFolderURL: URL?
    var onCancel: (() -> Bool)?
    var onOpenFiles: (([URL]) -> Void)?

    var highlightsCurrentLine = true {
        didSet { needsDisplay = true }
    }

    var currentLineColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    var bracketHighlightColor: NSColor = .clear

    private(set) var highlightedBracketRanges: [NSRange] = [] {
        didSet {
            if highlightedBracketRanges != oldValue {
                needsDisplay = true
            }
        }
    }

    private(set) var insertionLocations: [Int] = []
    private var isChangingSelectionInternally = false

    /// Builds a TextKit 1 editor sharing `textStorage` inside a scroll view.
    static func makeScrollableEditor(textStorage: NSTextStorage) -> (scrollView: NSScrollView, textView: EditorTextView) {
        let layoutManager = EditorLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 5
        layoutManager.addTextContainer(container)

        let textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), textContainer: container)
        textView.configureForPlainText()
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        return (scrollView, textView)
    }

    /// Turns off every rich text and automatic substitution feature that corrupts code.
    func configureForPlainText() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        usesFindBar = false
        isIncrementalSearchingEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        usesInspectorBar = false
        usesRuler = false
        displaysLinkToolTips = false
        allowsDocumentBackgroundColorChange = false
        textContainerInset = NSSize(width: 4, height: 8)
        setAccessibilityLabel(L10n.Accessibility.editor)
    }

    /// Switches between soft wrapping at the window edge and horizontal scrolling.
    func setWrapsLines(_ wraps: Bool) {
        guard let container = textContainer, let scrollView = enclosingScrollView else { return }
        if wraps {
            scrollView.hasHorizontalScroller = false
            isHorizontallyResizable = false
            autoresizingMask = [.width]
            container.widthTracksTextView = true
            frame.size.width = scrollView.contentSize.width
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        } else {
            scrollView.hasHorizontalScroller = true
            isHorizontallyResizable = true
            autoresizingMask = []
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        needsDisplay = true
    }

    var nsString: NSString {
        string as NSString
    }

    /// Replaces `range` with `replacement` as one undoable step and optionally selects `selectedRange`.
    @discardableResult
    func applyEdit(range: NSRange, replacement: String, selectedRange: NSRange?, actionName: String?) -> Bool {
        guard shouldChangeText(in: range, replacementString: replacement) else { return false }
        textStorage?.replaceCharacters(in: range, with: NSAttributedString(string: replacement, attributes: typingAttributes))
        didChangeText()
        if let actionName {
            undoManager?.setActionName(actionName)
        }
        if let selectedRange {
            setSelectedRange(selectedRange)
            scrollRangeToVisible(selectedRange)
        }
        return true
    }

    /// Applies a computed text edit, beeping when the edit is not possible.
    func apply(_ edit: TextEdit?, actionName: String) {
        guard let edit else {
            NSSound.beep()
            return
        }
        applyEdit(range: edit.range, replacement: edit.replacement, selectedRange: edit.selectedRange, actionName: actionName)
    }

    /// Replaces several ranges at once as a single undoable step and leaves a caret after each replacement.
    func replace(_ ranges: [NSRange], with strings: [String]) {
        let pairs = zip(ranges, strings).sorted { $0.0.location < $1.0.location }
        guard !pairs.isEmpty,
              shouldChangeText(inRanges: pairs.map { NSValue(range: $0.0) }, replacementStrings: pairs.map(\.1)) else { return }
        textStorage?.beginEditing()
        var offset = 0
        var carets: [Int] = []
        for (range, string) in pairs {
            let adjusted = NSRange(location: range.location + offset, length: range.length)
            textStorage?.replaceCharacters(in: adjusted, with: NSAttributedString(string: string, attributes: typingAttributes))
            let length = (string as NSString).length
            carets.append(adjusted.location + length)
            offset += length - range.length
        }
        textStorage?.endEditing()
        didChangeText()
        setInsertionLocations(carets)
    }

    /// Places one caret at every location; two or more locations enable multi-caret editing.
    func setInsertionLocations(_ locations: [Int]) {
        let unique = Array(Set(locations)).sorted()
        insertionLocations = unique.count > 1 ? unique : []
        isChangingSelectionInternally = true
        setSelectedRange(NSRange(location: unique.first ?? 0, length: 0))
        isChangingSelectionInternally = false
        needsDisplay = true
    }

    var editingRanges: [NSRange]? {
        if insertionLocations.count > 1 {
            return insertionLocations.map { NSRange(location: $0, length: 0) }
        }
        let ranges = selectedRanges.map(\.rangeValue)
        return ranges.count > 1 ? ranges : nil
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if !isChangingSelectionInternally, !insertionLocations.isEmpty {
            insertionLocations = []
            needsDisplay = true
        }
        if !stillSelecting {
            updateBracketHighlight()
        }
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let text = (string as? NSAttributedString)?.string ?? (string as? String) ?? ""
        guard !hasMarkedText(), replacementRange.location == NSNotFound else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        if let ranges = editingRanges {
            replace(ranges, with: Array(repeating: text, count: ranges.count))
            return
        }
        if closesBrackets, handleAutoPairing(text) {
            return
        }
        super.insertText(string, replacementRange: replacementRange)
    }

    private func handleAutoPairing(_ text: String) -> Bool {
        guard text.count == 1 else { return false }
        let selection = selectedRange()
        let next = character(at: NSMaxRange(selection))
        let previous = selection.location > 0 ? character(at: selection.location - 1) : nil
        if selection.length == 0, AutoPairing.shouldSkipOver(text, nextCharacter: next) {
            setSelectedRange(NSRange(location: selection.location + 1, length: 0))
            return true
        }
        if selection.length > 0, let closing = AutoPairing.closingCounterpart(for: text, before: nil, after: nil) {
            let selected = nsString.substring(with: selection)
            let inner = NSRange(location: selection.location + 1, length: selection.length)
            return applyEdit(range: selection, replacement: text + selected + closing, selectedRange: inner, actionName: L10n.Undo.typing)
        }
        guard selection.length == 0,
              let closing = AutoPairing.closingCounterpart(for: text, before: next, after: previous) else { return false }
        let caret = NSRange(location: selection.location + (text as NSString).length, length: 0)
        return applyEdit(range: selection, replacement: text + closing, selectedRange: caret, actionName: L10n.Undo.typing)
    }

    override func insertNewline(_ sender: Any?) {
        if isMarkdown, editingRanges == nil, let edit = MarkdownEditing.continueList(in: nsString, selection: selectedRange()) {
            applyEdit(range: edit.range, replacement: edit.replacement, selectedRange: edit.selectedRange, actionName: L10n.Undo.typing)
            return
        }
        guard autoIndents, editingRanges == nil else {
            if let ranges = editingRanges {
                replace(ranges, with: Array(repeating: "\n", count: ranges.count))
            } else {
                super.insertNewline(sender)
            }
            return
        }
        let selection = selectedRange()
        let lineBreak = indentation.lineBreak(at: selection.location, in: nsString)
        super.insertText(lineBreak.text, replacementRange: selection)
        setSelectedRange(NSRange(location: selection.location + lineBreak.caretOffset, length: 0))
    }

    override func insertTab(_ sender: Any?) {
        if let ranges = editingRanges {
            replace(ranges, with: Array(repeating: indentation.unit, count: ranges.count))
            return
        }
        let selection = selectedRange()
        if selection.length > 0, nsString.substring(with: selection).contains("\n") {
            shiftRight(sender)
            return
        }
        if isMarkdown, selection.length == 0, MarkdownEditing.isListItem(at: selection.location, in: nsString) {
            shiftRight(sender)
            return
        }
        guard !indentation.usesTabs else {
            super.insertTab(sender)
            return
        }
        let lineStart = nsString.lineRange(for: NSRange(location: selection.location, length: 0)).location
        let column = selection.location - lineStart
        let count = indentation.width - column % indentation.width
        super.insertText(String(repeating: " ", count: count), replacementRange: selection)
    }

    override func insertBacktab(_ sender: Any?) {
        shiftLeft(sender)
    }

    override func deleteBackward(_ sender: Any?) {
        if let ranges = editingRanges {
            let deletions = ranges.compactMap { range -> NSRange? in
                if range.length > 0 {
                    return range
                }
                guard range.location > 0 else { return nil }
                return nsString.rangeOfComposedCharacterSequence(at: range.location - 1)
            }
            if !deletions.isEmpty {
                replace(deletions, with: Array(repeating: "", count: deletions.count))
            }
            return
        }
        let selection = selectedRange()
        if selection.length == 0, selection.location > 0 {
            if closesBrackets,
               AutoPairing.shouldDeletePair(previousCharacter: character(at: selection.location - 1), nextCharacter: character(at: selection.location)) {
                applyEdit(
                    range: NSRange(location: selection.location - 1, length: 2),
                    replacement: "",
                    selectedRange: NSRange(location: selection.location - 1, length: 0),
                    actionName: L10n.Undo.typing
                )
                return
            }
            if !indentation.usesTabs, let range = softTabDeletionRange(at: selection.location) {
                applyEdit(range: range, replacement: "", selectedRange: NSRange(location: range.location, length: 0), actionName: L10n.Undo.typing)
                return
            }
        }
        super.deleteBackward(sender)
    }

    /// Returns the run of spaces back to the previous tab stop when only spaces precede the caret on its line.
    func softTabDeletionRange(at location: Int) -> NSRange? {
        let lineStart = nsString.lineRange(for: NSRange(location: location, length: 0)).location
        let column = location - lineStart
        guard column > 0 else { return nil }
        let previousStop = ((column - 1) / indentation.width) * indentation.width
        let range = NSRange(location: lineStart + previousStop, length: column - previousStop)
        guard range.length > 1, nsString.substring(with: range).allSatisfy({ $0 == " " }) else { return nil }
        let prefix = nsString.substring(with: NSRange(location: lineStart, length: column))
        guard prefix.allSatisfy({ $0 == " " }) else { return nil }
        return range
    }

    override func cancelOperation(_ sender: Any?) {
        if insertionLocations.count > 1 {
            setInsertionLocations([insertionLocations[0]])
            return
        }
        if selectedRanges.count > 1 {
            setSelectedRange(selectedRanges[0].rangeValue)
            return
        }
        if onCancel?() == true {
            return
        }
        super.cancelOperation(sender)
    }

    private func character(at index: Int) -> Character? {
        guard index >= 0, index < nsString.length else { return nil }
        return Character(nsString.substring(with: nsString.rangeOfComposedCharacterSequence(at: index)))
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == .string, let raw = pboard.string(forType: .string) else {
            return super.readSelection(from: pboard, type: type)
        }
        let text = LineEnding.normalize(raw, to: .lf)
        if let ranges = editingRanges {
            let lines = text.components(separatedBy: "\n")
            let strings = lines.count == ranges.count ? lines : Array(repeating: text, count: ranges.count)
            replace(ranges, with: strings)
            return true
        }
        let range = rangeForUserTextChange
        guard range.location != NSNotFound else { return false }
        if isMarkdown, let edit = MarkdownEditing.link(pasting: text, in: nsString, selection: range) {
            return applyEdit(range: edit.range, replacement: edit.replacement, selectedRange: edit.selectedRange, actionName: L10n.Undo.paste)
        }
        let caret = NSRange(location: range.location + (text as NSString).length, length: 0)
        return applyEdit(range: range, replacement: text, selectedRange: caret, actionName: L10n.Undo.paste)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           isMarkdown, !urls.isEmpty, urls.allSatisfy(Self.isImageFile) {
            let location = characterIndexForInsertion(at: convert(sender.draggingLocation, from: nil))
            return insertImages(urls, at: location)
        }
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           !urls.isEmpty, let onOpenFiles {
            onOpenFiles(urls)
            return true
        }
        return super.performDragOperation(sender)
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        if highlightsCurrentLine, insertionLocations.isEmpty, selectedRanges.count == 1, selectedRange().length == 0,
           let lineRect = lineRect(forCharacterAt: selectedRange().location) {
            currentLineColor.setFill()
            NSRect(x: rect.minX, y: lineRect.minY, width: rect.width, height: lineRect.height).fill()
        }
        guard !highlightedBracketRanges.isEmpty, let layoutManager, let textContainer else { return }
        bracketHighlightColor.setFill()
        for range in highlightedBracketRanges where NSMaxRange(range) <= nsString.length {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var bounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            bounds.origin.x += textContainerOrigin.x
            bounds.origin.y += textContainerOrigin.y
            NSBezierPath(roundedRect: bounds.insetBy(dx: -1, dy: 0), xRadius: 3, yRadius: 3).fill()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard insertionLocations.count > 1 else { return }
        insertionPointColor.setFill()
        for location in insertionLocations.dropFirst() {
            if let rect = caretRect(at: location), rect.intersects(dirtyRect) {
                rect.fill()
            }
        }
    }

    /// The rectangle covering the logical line that contains `location`, in view coordinates.
    func lineRect(forCharacterAt location: Int) -> NSRect? {
        guard let layoutManager, let textContainer else { return nil }
        let length = nsString.length
        if location >= length, length == 0 || nsString.character(at: length - 1) == 0x0A {
            let extra = layoutManager.extraLineFragmentRect
            guard extra.height > 0 else { return nil }
            return extra.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        }
        let paragraph = nsString.lineRange(for: NSRange(location: min(location, length), length: 0))
        let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraph, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        rect.origin.y = fragment.minY
        rect.size.height = max(rect.height, fragment.height)
        return rect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
    }

    /// The rectangle of a thin caret before the character at `location`, in view coordinates.
    func caretRect(at location: Int) -> NSRect? {
        guard let layoutManager, let textContainer else { return nil }
        let length = nsString.length
        let origin: NSPoint
        let height: CGFloat
        if location >= length {
            if length == 0 || nsString.character(at: length - 1) == 0x0A {
                let extra = layoutManager.extraLineFragmentRect
                origin = NSPoint(x: extra.minX + textContainer.lineFragmentPadding, y: extra.minY)
                height = extra.height
            } else {
                let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: length - 1, length: 1), actualCharacterRange: nil)
                let bounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                origin = NSPoint(x: bounds.maxX, y: bounds.minY)
                height = bounds.height
            }
        } else {
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: location)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
            origin = NSPoint(x: fragment.minX + glyphLocation.x, y: fragment.minY)
            height = fragment.height
        }
        return NSRect(x: origin.x + textContainerOrigin.x, y: origin.y + textContainerOrigin.y, width: 1.5, height: height)
    }

    private func updateBracketHighlight() {
        guard highlightsMatchingBrackets, selectedRanges.count == 1, selectedRange().length == 0 else {
            highlightedBracketRanges = []
            return
        }
        let location = selectedRange().location
        for candidate in [location - 1, location] where candidate >= 0 && candidate < nsString.length {
            if let match = Brackets.matchingBracket(at: candidate, in: nsString) {
                highlightedBracketRanges = [NSRange(location: candidate, length: 1), NSRange(location: match, length: 1)]
                return
            }
        }
        highlightedBracketRanges = []
    }
}
