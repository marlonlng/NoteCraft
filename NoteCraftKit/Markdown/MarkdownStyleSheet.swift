import Foundation

public struct MarkdownStyleSheet: Equatable, Sendable {
    public var theme: Theme
    public var printTheme: Theme
    public var darkTheme: Theme?
    public var codeFontName: String?

    /// Creates the styles for `theme`; `darkTheme` adds colors for the dark system appearance, `printTheme` is used on paper.
    public init(theme: Theme, printTheme: Theme = .paper, darkTheme: Theme? = nil, codeFontName: String? = nil) {
        self.theme = theme
        self.printTheme = printTheme
        self.darkTheme = darkTheme
        self.codeFontName = codeFontName
    }

    /// The complete CSS for the preview or an exported document.
    public var css: String {
        var result = ":root {\n\(Self.variables(for: theme))\n  --nc-code-font: \(codeFontFamily);\n}\n"
        if let darkTheme {
            result += "@media (prefers-color-scheme: dark) {\n  :root {\n\(Self.variables(for: darkTheme))\n  }\n}\n"
        }
        result += "@media print {\n  :root {\n\(Self.variables(for: printTheme))\n  }\n}\n"
        result += TokenKind.allCases.map { ".tk-\($0.rawValue) { color: var(--nc-tk-\($0.rawValue)); }" }.joined(separator: "\n")
        result += "\n" + Self.layout
        return result
    }

    var codeFontFamily: String {
        let fallback = "ui-monospace, \"SF Mono\", Menlo, monospace"
        guard let codeFontName, !codeFontName.isEmpty else { return fallback }
        let escaped = codeFontName.replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: "\"", with: "")
        return "\"\(escaped)\", \(fallback)"
    }

    /// The CSS custom properties with the colors of `theme`.
    static func variables(for theme: Theme) -> String {
        let border = theme.lineNumber.withAlpha(0.35)
        let stripe = theme.currentLine.withAlpha(0.6)
        var entries: [(String, String)] = [
            ("background", theme.background.hexString),
            ("text", theme.text.hexString),
            ("secondary", theme.color(for: .comment).hexString),
            ("link", theme.color(for: .link).hexString),
            ("border", border.hexString),
            ("code-background", theme.currentLine.hexString),
            ("stripe", stripe.hexString),
            ("selection", theme.selection.hexString),
            ("color-scheme", theme.isDark ? "dark" : "light")
        ]
        entries += TokenKind.allCases.map { ("tk-\($0.rawValue)", theme.color(for: $0).hexString) }
        return entries.map { "  --nc-\($0.0): \($0.1);" }.joined(separator: "\n")
    }

    static let layout = """
    html { background: var(--nc-background); color-scheme: var(--nc-color-scheme); }
    body { margin: 0 auto; max-width: 860px; padding: 20px 28px 48px; color: var(--nc-text); background: var(--nc-background); font: 15px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; overflow-wrap: break-word; }
    #content > :first-child { margin-top: 0; }
    h1, h2, h3, h4, h5, h6 { margin: 1.4em 0 0.6em; line-height: 1.25; font-weight: 600; }
    h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid var(--nc-border); }
    h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid var(--nc-border); }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: 0.875em; }
    h6 { font-size: 0.85em; color: var(--nc-secondary); }
    p, ul, ol, blockquote, pre, table, .html-block { margin: 0 0 1em; }
    a { color: var(--nc-link); text-decoration: none; }
    a:hover { text-decoration: underline; }
    code { font-family: var(--nc-code-font); font-size: 0.875em; background: var(--nc-code-background); border-radius: 4px; padding: 0.15em 0.35em; }
    pre { background: var(--nc-code-background); border-radius: 6px; padding: 12px 14px; overflow: auto; line-height: 1.45; }
    pre code { background: none; padding: 0; white-space: pre; }
    pre.front-matter { font-size: 0.9em; }
    blockquote { margin-left: 0; margin-right: 0; padding: 0 1em; color: var(--nc-secondary); border-left: 0.25em solid var(--nc-border); }
    ul, ol { padding-left: 2em; }
    li + li { margin-top: 0.25em; }
    li > ul, li > ol { margin-bottom: 0; }
    ul.contains-task-list { padding-left: 1.6em; }
    li.task-list-item { list-style: none; }
    li.task-list-item > input { margin: 0 0.4em 0.2em -1.4em; vertical-align: middle; }
    table { border-collapse: collapse; display: block; overflow: auto; width: max-content; max-width: 100%; }
    th, td { border: 1px solid var(--nc-border); padding: 6px 13px; }
    th { font-weight: 600; }
    tbody tr:nth-child(2n) { background: var(--nc-stripe); }
    hr { border: 0; height: 2px; background: var(--nc-border); margin: 1.5em 0; }
    img { max-width: 100%; }
    del { color: var(--nc-secondary); }
    ::selection { background: var(--nc-selection); }
    .image-placeholder { display: inline-flex; flex-direction: column; gap: 2px; max-width: 100%; padding: 8px 12px; border: 1px dashed var(--nc-border); border-radius: 6px; color: var(--nc-secondary); font-size: 0.85em; vertical-align: middle; }
    .image-placeholder-alt { color: var(--nc-text); }
    .image-placeholder-address { font-family: var(--nc-code-font); word-break: break-all; }
    @media print {
      body { max-width: none; padding: 0; }
      pre, table, img, blockquote { break-inside: avoid; }
      a { text-decoration: underline; }
    }
    """
}

extension HexColor {
    /// The same color with the given opacity.
    func withAlpha(_ alpha: Double) -> HexColor {
        HexColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
