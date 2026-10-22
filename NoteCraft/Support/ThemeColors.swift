import AppKit
import NoteCraftKit
import SwiftUI

extension HexColor {
    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color {
        Color(nsColor: nsColor)
    }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

extension EditorSettings {
    /// The editor font, falling back to the monospaced system font.
    func editorFont(scale: CGFloat = 1) -> NSFont {
        let size = CGFloat(fontSize) * scale
        if fontName != EditorSettings.systemFontName, let font = NSFont(name: fontName, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// The theme that matches `appearance`, switching to a high-contrast theme when the system asks for more contrast.
    func resolvedTheme(for appearance: NSAppearance, increasesContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast) -> Theme {
        let isDark = appearance.isDark
        if increasesContrast {
            return isDark ? .highContrastDark : .highContrastLight
        }
        return theme(isDark: isDark)
    }
}

enum MonospacedFonts {
    /// Names of installed fixed-pitch font families, sorted for display.
    static var familyNames: [String] {
        let manager = NSFontManager.shared
        let names = manager.availableFontFamilies.filter { family in
            guard let members = manager.availableMembers(ofFontFamily: family),
                  let first = members.first,
                  let fontName = first[0] as? String,
                  let font = NSFont(name: fontName, size: 12) else { return false }
            return font.isFixedPitch
        }
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
