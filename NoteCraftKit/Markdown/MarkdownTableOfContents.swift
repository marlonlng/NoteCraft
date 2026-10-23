import Foundation

public enum MarkdownTableOfContents {
    public static let startMarker = "<!-- toc -->"
    public static let endMarker = "<!-- tocstop -->"

    public struct Entry: Equatable, Sendable {
        public let level: Int
        public let title: String
        public let slug: String
    }

    private static let atxHeading = try? NSRegularExpression(pattern: #"^ {0,3}(#{1,6})(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$"#)
    private static let setextUnderline = try? NSRegularExpression(pattern: #"^ {0,3}(=+|-+)[ \t]*$"#)
    private static let fence = try? NSRegularExpression(pattern: #"^ {0,3}(`{3,}|~{3,})"#)

    /// The headings of `text` outside code blocks and front matter, with GitHub anchors.
    public static func entries(in text: String) -> [Entry] {
        var lines = text.components(separatedBy: "\n")
        if let frontMatter = MarkdownRenderer.frontMatter(in: text) {
            lines = Array(lines.dropFirst(frontMatter.lineCount))
        }
        var entries: [Entry] = []
        var slugger = MarkdownSlugger()
        var openFence: String?
        for (index, line) in lines.enumerated() {
            if let fenceMarker = match(fence, in: line, group: 1) {
                if let open = openFence {
                    if fenceMarker.first == open.first, fenceMarker.count >= open.count {
                        openFence = nil
                    }
                } else {
                    openFence = fenceMarker
                }
                continue
            }
            guard openFence == nil else { continue }
            var level = 0
            var title = ""
            if let hashes = match(atxHeading, in: line, group: 1) {
                level = hashes.count
                title = match(atxHeading, in: line, group: 2) ?? ""
            } else if index + 1 < lines.count, isParagraphLine(line), let underline = match(setextUnderline, in: lines[index + 1], group: 1) {
                level = underline.hasPrefix("=") ? 1 : 2
                title = line.trimmingCharacters(in: .whitespaces)
            }
            guard level > 0 else { continue }
            let plain = plainTitle(title)
            entries.append(Entry(level: level, title: plain, slug: slugger.slug(for: plain)))
        }
        return entries
    }

    private static func isParagraphLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(">"), !trimmed.hasPrefix("|"), !trimmed.hasPrefix("<") else { return false }
        return MarkdownListPrefix.parse(line) == nil && match(atxHeading, in: line, group: 1) == nil
    }

    private static func match(_ regex: NSRegularExpression?, in line: String, group: Int) -> String? {
        guard let regex,
              let result = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else { return nil }
        let range = result.range(at: group)
        return range.location == NSNotFound ? nil : (line as NSString).substring(with: range)
    }

    /// The visible text of a heading without link, image, emphasis and code syntax.
    static func plainTitle(_ title: String) -> String {
        var result = title
        let replacements: [(String, String)] = [
            (#"!?\[([^\]]*)\]\([^)]*\)"#, "$1"),
            (#"`+"#, ""),
            (#"\*+|~~"#, ""),
            (#"(?<![\p{L}\p{N}])_+|_+(?![\p{L}\p{N}])"#, "")
        ]
        for (pattern, template) in replacements {
            result = result.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// The table of contents as a nested list of links between the start and end markers.
    public static func block(for entries: [Entry]) -> String {
        let minimum = entries.map(\.level).min() ?? 1
        let items = entries.map { entry in
            String(repeating: "  ", count: entry.level - minimum) + "- [\(entry.title)](#\(entry.slug))"
        }
        return ([startMarker] + items + [endMarker]).joined(separator: "\n")
    }

    /// Replaces the existing table of contents, or inserts one at the start of the caret's line.
    public static func update(in text: NSString, selection: NSRange) -> TextEdit {
        let block = block(for: entries(in: text as String))
        let start = text.range(of: startMarker)
        if start.location != NSNotFound {
            let searchRange = NSRange(location: NSMaxRange(start), length: text.length - NSMaxRange(start))
            let end = text.range(of: endMarker, options: [], range: searchRange)
            if end.location != NSNotFound {
                let range = NSRange(location: start.location, length: NSMaxRange(end) - start.location)
                let delta = (block as NSString).length - range.length
                let caret = selection.location >= NSMaxRange(range) ? selection.location + delta : min(selection.location, start.location)
                return TextEdit(range: range, replacement: block, selectedRange: NSRange(location: caret, length: 0))
            }
        }
        let lineRange = text.lineRange(for: NSRange(location: selection.location, length: 0))
        let isEmptyLine = text.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let replacement = block + (isEmptyLine ? "\n" : "\n\n")
        let location = lineRange.location
        return TextEdit(range: NSRange(location: location, length: 0), replacement: replacement, selectedRange: NSRange(location: location + (block as NSString).length, length: 0))
    }
}
