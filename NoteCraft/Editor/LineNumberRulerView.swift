import AppKit
import NoteCraftKit

final class LineNumberRulerView: NSRulerView {
    var lineIndex = LineIndex(text: "") {
        didSet {
            if lineIndex.lineCount != oldValue.lineCount {
                updateThickness()
            }
            needsDisplay = true
        }
    }

    var numberFont: NSFont = .monospacedDigitSystemFont(ofSize: 11, weight: .regular) {
        didSet {
            updateThickness()
            needsDisplay = true
        }
    }

    var numberColor: NSColor = .secondaryLabelColor
    var currentNumberColor: NSColor = .labelColor
    var backgroundColor: NSColor = .textBackgroundColor
    var onSelectLine: ((Int) -> Void)?

    private weak var textView: NSTextView?

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        setAccessibilityLabel(L10n.Accessibility.lineNumbers)
        updateThickness()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    override var requiredThickness: CGFloat {
        ruleThickness
    }

    /// Recomputes the width needed for the largest line number.
    func updateThickness() {
        let digits = max(3, String(lineIndex.lineCount).count)
        let digitWidth = ("8" as NSString).size(withAttributes: [.font: numberFont]).width
        let thickness = ceil(CGFloat(digits) * digitWidth + 20)
        if abs(ruleThickness - thickness) > 0.5 {
            ruleThickness = thickness
        }
    }

    /// The one-based line numbers and their baselines for every line starting inside the visible area.
    ///
    /// Empty lines have no glyph to measure, so they reuse the baseline offset of a non-empty line.
    func visibleLineNumbers() -> [(number: Int, baseline: CGFloat)] {
        guard let textView, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return [] }
        let text = textView.string as NSString
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let offset = convert(NSPoint.zero, from: textView).y + textView.textContainerOrigin.y
        var entries: [(number: Int, fragmentMinY: CGFloat, baselineOffset: CGFloat?)] = []
        var lineNumber = lineIndex.lineNumber(at: characterRange.location)
        while lineNumber <= lineIndex.lineCount {
            let start = lineIndex.lineStarts[lineNumber - 1]
            if start > NSMaxRange(characterRange) {
                break
            }
            if start >= text.length {
                let extra = layoutManager.extraLineFragmentRect
                if extra.height > 0 {
                    entries.append((lineNumber, extra.minY, nil))
                }
                break
            }
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: start)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let isEmptyLine = text.character(at: start) == 0x0A
            let measured = isEmptyLine ? nil : layoutManager.location(forGlyphAt: glyphIndex).y
            entries.append((lineNumber, fragment.minY, measured))
            lineNumber += 1
        }
        let reference = entries.compactMap(\.baselineOffset).first ?? fallbackBaselineOffset(in: layoutManager)
        return entries.map { ($0.number, offset + $0.fragmentMinY + ($0.baselineOffset ?? reference)) }
    }

    private func fallbackBaselineOffset(in layoutManager: NSLayoutManager) -> CGFloat {
        guard let font = textView?.typingAttributes[.font] as? NSFont else { return numberFont.ascender }
        let style = textView?.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        let lineHeight = layoutManager.defaultLineHeight(for: font) * max(1, style?.lineHeightMultiple ?? 1)
        return lineHeight + font.descender
    }

    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        backgroundColor.setFill()
        bounds.fill()
        guard let textView else { return }
        let currentLine = lineIndex.lineNumber(at: textView.selectedRange().location)
        let width = ruleThickness - 10
        for entry in visibleLineNumbers() {
            let isCurrent = entry.number == currentLine
            let attributes: [NSAttributedString.Key: Any] = [
                .font: isCurrent ? NSFontManager.shared.convert(numberFont, toHaveTrait: .boldFontMask) : numberFont,
                .foregroundColor: isCurrent ? currentNumberColor : numberColor
            ]
            let label = String(entry.number) as NSString
            let size = label.size(withAttributes: attributes)
            let point = NSPoint(x: width - size.width, y: entry.baseline - numberFont.ascender)
            label.draw(at: point, withAttributes: attributes)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let textView else { return }
        let point = convert(event.locationInWindow, from: nil)
        let textPoint = convert(point, to: textView)
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        let containerPoint = NSPoint(x: 0, y: textPoint.y - textView.textContainerOrigin.y)
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        onSelectLine?(lineIndex.lineNumber(at: characterIndex))
    }
}
