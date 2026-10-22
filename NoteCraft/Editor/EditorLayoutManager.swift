import AppKit

final class EditorLayoutManager: NSLayoutManager {
    var drawsInvisibleCharacters = false {
        didSet {
            guard drawsInvisibleCharacters != oldValue, let textStorage else { return }
            invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        }
    }

    var invisiblesColor: NSColor = .tertiaryLabelColor
    var invisiblesFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)

    static func symbol(for character: unichar) -> String? {
        switch character {
        case 0x20: "·"
        case 0x09: "→"
        case 0x0A: "¬"
        case 0xA0: "°"
        case 0x3000: "□"
        default: nil
        }
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard drawsInvisibleCharacters, let textStorage else { return }
        let text = textStorage.string as NSString
        let characterRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: invisiblesColor, .font: invisiblesFont]
        for index in characterRange.location..<NSMaxRange(characterRange) {
            guard let symbol = Self.symbol(for: text.character(at: index)) else { continue }
            let glyphIndex = glyphIndexForCharacter(at: index)
            let lineRect = lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let glyphLocation = location(forGlyphAt: glyphIndex)
            let baseline = lineRect.minY + glyphLocation.y
            let point = NSPoint(
                x: origin.x + lineRect.minX + glyphLocation.x,
                y: origin.y + baseline - invisiblesFont.ascender
            )
            (symbol as NSString).draw(at: point, withAttributes: attributes)
        }
    }
}
