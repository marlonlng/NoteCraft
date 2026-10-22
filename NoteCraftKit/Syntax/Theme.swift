import Foundation

public struct HexColor: Equatable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses `#RRGGBB` or `#RRGGBBAA`.
    public init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6 || value.count == 8, let number = UInt64(value, radix: 16) else { return nil }
        if value.count == 6 {
            red = Double((number >> 16) & 0xFF) / 255
            green = Double((number >> 8) & 0xFF) / 255
            blue = Double(number & 0xFF) / 255
            alpha = 1
        } else {
            red = Double((number >> 24) & 0xFF) / 255
            green = Double((number >> 16) & 0xFF) / 255
            blue = Double((number >> 8) & 0xFF) / 255
            alpha = Double(number & 0xFF) / 255
        }
    }

    public var hexString: String {
        let components = [red, green, blue] + (alpha < 1 ? [alpha] : [])
        return "#" + components.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    public var relativeLuminance: Double {
        func linearize(_ component: Double) -> Double {
            component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// The WCAG 2 contrast ratio between this color and `other`, from 1 to 21.
    public func contrastRatio(with other: HexColor) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

public struct Theme: Identifiable, Equatable, Sendable {
    public let id: String
    public let isDark: Bool
    public let background: HexColor
    public let text: HexColor
    public let selection: HexColor
    public let currentLine: HexColor
    public let lineNumber: HexColor
    public let currentLineNumber: HexColor
    public let invisibles: HexColor
    public let matchHighlight: HexColor
    public let tokens: [TokenKind: HexColor]

    public init(
        id: String,
        isDark: Bool,
        background: String,
        text: String,
        selection: String,
        currentLine: String,
        lineNumber: String,
        currentLineNumber: String,
        invisibles: String,
        matchHighlight: String,
        tokens: [TokenKind: String]
    ) {
        self.id = id
        self.isDark = isDark
        self.background = HexColor(hex: background) ?? HexColor(red: 1, green: 1, blue: 1)
        self.text = HexColor(hex: text) ?? HexColor(red: 0, green: 0, blue: 0)
        self.selection = HexColor(hex: selection) ?? HexColor(red: 0.7, green: 0.8, blue: 1)
        self.currentLine = HexColor(hex: currentLine) ?? self.background
        self.lineNumber = HexColor(hex: lineNumber) ?? self.text
        self.currentLineNumber = HexColor(hex: currentLineNumber) ?? self.text
        self.invisibles = HexColor(hex: invisibles) ?? self.lineNumber
        self.matchHighlight = HexColor(hex: matchHighlight) ?? self.selection
        self.tokens = tokens.compactMapValues { HexColor(hex: $0) }
    }

    /// Returns the color for `kind`, falling back to the text color.
    public func color(for kind: TokenKind) -> HexColor {
        tokens[kind] ?? text
    }

    /// Returns the theme with the given identifier.
    public static func theme(withID id: String) -> Theme? {
        all.first { $0.id == id }
    }

    public static let paper = Theme(
        id: "paper",
        isDark: false,
        background: "#FBFAF7",
        text: "#24292F",
        selection: "#C9DDFB",
        currentLine: "#F1EEE6",
        lineNumber: "#7D8187",
        currentLineNumber: "#24292F",
        invisibles: "#B9B6AE",
        matchHighlight: "#FFE58F",
        tokens: [
            .keyword: "#B4237A", .type: "#0B6E8A", .string: "#2F7A1F", .number: "#1C5FD0", .comment: "#696E75",
            .constant: "#975A00", .function: "#5B3CC4", .attribute: "#8A4B08", .tag: "#1F5FA8", .variable: "#B3381F",
            .directive: "#7A4D00", .heading: "#1F5FA8", .emphasis: "#8E3CB3", .link: "#1C5FD0", .inserted: "#1A7F37",
            .deleted: "#C4212C"
        ]
    )

    public static let graphite = Theme(
        id: "graphite",
        isDark: true,
        background: "#1E1F22",
        text: "#D7DAE0",
        selection: "#36486A",
        currentLine: "#27292D",
        lineNumber: "#7D838C",
        currentLineNumber: "#D7DAE0",
        invisibles: "#4A4E55",
        matchHighlight: "#6B5517",
        tokens: [
            .keyword: "#FF7AB8", .type: "#67D3E8", .string: "#A5D68A", .number: "#8FB8FF", .comment: "#8B929C",
            .constant: "#F0B35A", .function: "#C3A6FF", .attribute: "#E6B07A", .tag: "#7FB2FF", .variable: "#FF9C7A",
            .directive: "#E8C46A", .heading: "#8FB8FF", .emphasis: "#E6A1FF", .link: "#7FB2FF", .inserted: "#7EE08A",
            .deleted: "#FF8A8A"
        ]
    )

    public static let sage = Theme(
        id: "sage",
        isDark: false,
        background: "#F3F6F1",
        text: "#25302A",
        selection: "#CFE3C8",
        currentLine: "#E7EDE3",
        lineNumber: "#6F7B72",
        currentLineNumber: "#25302A",
        invisibles: "#AEBBB0",
        matchHighlight: "#F5DD84",
        tokens: [
            .keyword: "#8A2F6E", .type: "#1D6670", .string: "#4C6B12", .number: "#285E9E", .comment: "#626E66",
            .constant: "#8C5310", .function: "#4F45A8", .attribute: "#7F4A1C", .tag: "#22608C", .variable: "#A23A2A",
            .directive: "#735016", .heading: "#22608C", .emphasis: "#7D3D99", .link: "#285E9E", .inserted: "#2C7334",
            .deleted: "#B0262F"
        ]
    )

    public static let midnight = Theme(
        id: "midnight",
        isDark: true,
        background: "#111827",
        text: "#D2DAE8",
        selection: "#2E4573",
        currentLine: "#18213A",
        lineNumber: "#7584A0",
        currentLineNumber: "#D2DAE8",
        invisibles: "#3A4660",
        matchHighlight: "#5E4E14",
        tokens: [
            .keyword: "#C792EA", .type: "#7FDBCA", .string: "#C3E88D", .number: "#F78C6C", .comment: "#8590A6",
            .constant: "#FFCB6B", .function: "#82AAFF", .attribute: "#FFCB8B", .tag: "#89DDFF", .variable: "#F07178",
            .directive: "#FFD580", .heading: "#82AAFF", .emphasis: "#E4A8FF", .link: "#89DDFF", .inserted: "#A8E68C",
            .deleted: "#FF8B92"
        ]
    )

    public static let highContrastLight = Theme(
        id: "highContrastLight",
        isDark: false,
        background: "#FFFFFF",
        text: "#000000",
        selection: "#B3D1FF",
        currentLine: "#EDEDED",
        lineNumber: "#4D4D4D",
        currentLineNumber: "#000000",
        invisibles: "#8C8C8C",
        matchHighlight: "#FFD400",
        tokens: [
            .keyword: "#9A0060", .type: "#00546B", .string: "#185E00", .number: "#0039A6", .comment: "#4A4A4A",
            .constant: "#6E3D00", .function: "#3D1FA3", .attribute: "#6B3300", .tag: "#003F8C", .variable: "#8F1D00",
            .directive: "#5C3A00", .heading: "#003F8C", .emphasis: "#6A1B9A", .link: "#0039A6", .inserted: "#0B5E1F",
            .deleted: "#A10010"
        ]
    )

    public static let highContrastDark = Theme(
        id: "highContrastDark",
        isDark: true,
        background: "#000000",
        text: "#FFFFFF",
        selection: "#264F99",
        currentLine: "#1A1A1A",
        lineNumber: "#B3B3B3",
        currentLineNumber: "#FFFFFF",
        invisibles: "#666666",
        matchHighlight: "#7A6000",
        tokens: [
            .keyword: "#FF9ED2", .type: "#7CF5FF", .string: "#B5FF8A", .number: "#A8C8FF", .comment: "#C2C2C2",
            .constant: "#FFD27A", .function: "#D9C7FF", .attribute: "#FFC999", .tag: "#9CCBFF", .variable: "#FFB199",
            .directive: "#FFE08A", .heading: "#A8C8FF", .emphasis: "#F2B8FF", .link: "#9CCBFF", .inserted: "#9CFFA8",
            .deleted: "#FFA3A3"
        ]
    )

    public static let all: [Theme] = [paper, sage, highContrastLight, graphite, midnight, highContrastDark]
}
