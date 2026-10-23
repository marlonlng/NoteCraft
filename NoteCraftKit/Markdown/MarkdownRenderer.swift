import Foundation
import Markdown

public enum MarkdownResourceLocation: Equatable, Sendable {
    case local(URL)
    case external(URL)
    case embedded(String)
    case unresolved(String)

    /// Resolves the address of an image or link against the folder of the document.
    public static func resolve(_ address: String, relativeTo folderURL: URL?) -> MarkdownResourceLocation {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("data:") {
            return .embedded(trimmed)
        }
        if trimmed.hasPrefix("//"), let url = URL(string: "https:" + trimmed) {
            return .external(url)
        }
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme.count > 1 {
            switch scheme {
            case "http", "https":
                return .external(url)
            case "file":
                return .local(url.standardizedFileURL)
            default:
                return .unresolved(trimmed)
            }
        }
        var path = trimmed
        if let end = path.firstIndex(where: { $0 == "?" || $0 == "#" }) {
            path = String(path[..<end])
        }
        path = path.removingPercentEncoding ?? path
        guard !path.isEmpty, !path.hasPrefix("~") else { return .unresolved(trimmed) }
        if path.hasPrefix("/") {
            return .local(URL(fileURLWithPath: path).standardizedFileURL)
        }
        guard let folderURL else { return .unresolved(trimmed) }
        return .local(folderURL.appendingPathComponent(path).standardizedFileURL)
    }
}

public struct MarkdownRendering: Equatable, Sendable {
    public var html: String
    public var localImages: [URL]
    public var blockedImages: [URL]
}

public struct MarkdownRenderer {
    public var folderURL: URL?
    public var loadsExternalImages: Bool
    public var allowsTaskToggling: Bool
    public var localImageSource: (URL) -> String

    public init(
        folderURL: URL? = nil,
        loadsExternalImages: Bool = true,
        allowsTaskToggling: Bool = false,
        localImageSource: @escaping (URL) -> String = { $0.absoluteString }
    ) {
        self.folderURL = folderURL
        self.loadsExternalImages = loadsExternalImages
        self.allowsTaskToggling = allowsTaskToggling
        self.localImageSource = localImageSource
    }

    /// Converts GitHub Flavored Markdown to HTML; every block carries its one-based source line in `data-line`.
    public func render(_ text: String) -> MarkdownRendering {
        var writer = MarkdownHTMLWriter(renderer: self)
        var body = text
        if let frontMatter = Self.frontMatter(in: text) {
            writer.writeCodeBlock(frontMatter.content, info: "yaml", line: 1, className: "front-matter")
            writer.lineOffset = frontMatter.lineCount
            body = frontMatter.remainder
        }
        let document = Document(parsing: body, options: [.disableSmartOpts])
        writer.visit(document)
        return MarkdownRendering(html: writer.html, localImages: writer.localImages, blockedImages: writer.blockedImages)
    }

    /// Splits a leading YAML front matter block delimited by `---` lines from the rest of the text.
    static func frontMatter(in text: String) -> (content: String, lineCount: Int, remainder: String)? {
        let lines = text.components(separatedBy: "\n")
        guard lines.count > 1, lines[0].trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        for index in 1..<lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line == "---" || line == "..." {
                let content = lines[1..<index].joined(separator: "\n")
                let remainder = lines[(index + 1)...].joined(separator: "\n")
                return (content, index + 1, remainder)
            }
        }
        return nil
    }
}

struct MarkdownHTMLWriter: MarkupVisitor {
    private static let filteredTags = try? NSRegularExpression(
        pattern: "<(/?)(title|textarea|style|xmp|iframe|noembed|noframes|script|plaintext)(?=[\\s/>])",
        options: [.caseInsensitive]
    )
    private static let bareLink = try? NSRegularExpression(
        pattern: #"(?:https?://|www\.)[^\s<]*\([^\s<()]*\)|(?:https?://|www\.)[^\s<]*[^\s<?!.,:;*_~'"\])]"#,
        options: [.caseInsensitive]
    )

    let renderer: MarkdownRenderer
    var html = ""
    var lineOffset = 0
    var localImages: [URL] = []
    var blockedImages: [URL] = []
    private var slugger = MarkdownSlugger()
    private var linkDepth = 0
    private var tightLists: [Bool] = []

    init(renderer: MarkdownRenderer) {
        self.renderer = renderer
    }

    mutating func defaultVisit(_ markup: Markup) {
        for child in markup.children {
            visit(child)
        }
    }

    private func lineAttribute(_ markup: Markup) -> String {
        guard let line = markup.range?.lowerBound.line else { return "" }
        return " data-line=\"\(line + lineOffset)\""
    }

    private func escape(_ text: String) -> String {
        HTMLEntities.escape(text)
    }

    mutating func visitDocument(_ document: Document) {
        defaultVisit(document)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if tightLists.last == true, paragraph.parent is ListItem {
            defaultVisit(paragraph)
            if paragraph.indexInParent < (paragraph.parent?.childCount ?? 1) - 1 {
                html += "\n"
            }
            return
        }
        html += "<p\(lineAttribute(paragraph))>"
        defaultVisit(paragraph)
        html += "</p>\n"
    }

    mutating func visitHeading(_ heading: Heading) {
        let level = min(max(heading.level, 1), 6)
        let slug = slugger.slug(for: heading.plainText)
        html += "<h\(level) id=\"\(escape(slug))\"\(lineAttribute(heading))>"
        defaultVisit(heading)
        html += "</h\(level)>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        html += "<blockquote\(lineAttribute(blockQuote))>\n"
        tightLists.append(false)
        defaultVisit(blockQuote)
        tightLists.removeLast()
        html += "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let line = codeBlock.range.map { $0.lowerBound.line + lineOffset } ?? 0
        writeCodeBlock(codeBlock.code, info: codeBlock.language, line: line, className: nil)
    }

    /// Writes a code block with NoteCraft syntax colors for the language named in `info`.
    mutating func writeCodeBlock(_ code: String, info: String?, line: Int, className: String?) {
        let language = info.flatMap(Language.language(forCodeFenceInfo:))
        var classes: [String] = []
        if let className {
            classes.append(className)
        }
        let classAttribute = classes.isEmpty ? "" : " class=\"\(classes.joined(separator: " "))\""
        let languageAttribute = language.map { " class=\"language-\(escape($0.id))\"" } ?? ""
        let lineAttribute = line > 0 ? " data-line=\"\(line)\"" : ""
        let content = code.hasSuffix("\n") ? String(code.dropLast()) : code
        html += "<pre\(classAttribute)\(lineAttribute)><code\(languageAttribute)>"
        html += Self.highlightedHTML(content, language: language)
        html += "</code></pre>\n"
    }

    /// Escapes `code` and wraps every token of `language` in a `span` with a `tk-` class.
    static func highlightedHTML(_ code: String, language: Language?) -> String {
        guard let language, let highlighter = SyntaxHighlighterCache.shared.highlighter(for: language) else {
            return HTMLEntities.escape(code)
        }
        let nsCode = code as NSString
        var result = ""
        var cursor = 0
        for token in highlighter.tokens(in: code) where token.range.location >= cursor {
            result += HTMLEntities.escape(nsCode.substring(with: NSRange(location: cursor, length: token.range.location - cursor)))
            result += "<span class=\"tk-\(token.kind.rawValue)\">"
            result += HTMLEntities.escape(nsCode.substring(with: token.range))
            result += "</span>"
            cursor = NSMaxRange(token.range)
        }
        result += HTMLEntities.escape(nsCode.substring(from: cursor))
        return result
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        html += "<hr\(lineAttribute(thematicBreak))>\n"
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) {
        html += "<div class=\"html-block\"\(lineAttribute(htmlBlock))>\(Self.filterTags(htmlBlock.rawHTML))</div>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        let isTask = unorderedList.listItems.contains { $0.checkbox != nil }
        html += "<ul\(isTask ? " class=\"contains-task-list\"" : "")\(lineAttribute(unorderedList))>\n"
        visitListItems(of: unorderedList)
        html += "</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let start = orderedList.startIndex == 1 ? "" : " start=\"\(orderedList.startIndex)\""
        html += "<ol\(start)\(lineAttribute(orderedList))>\n"
        visitListItems(of: orderedList)
        html += "</ol>\n"
    }

    private mutating func visitListItems(of list: ListItemContainer) {
        tightLists.append(!Self.isLoose(list))
        for item in list.listItems {
            visit(item)
        }
        tightLists.removeLast()
    }

    /// A list is loose when a blank line separates two of its items or two blocks inside an item.
    static func isLoose(_ list: ListItemContainer) -> Bool {
        let items = Array(list.listItems)
        for (index, item) in items.enumerated() {
            let children = Array(item.children)
            for pair in zip(children, children.dropFirst()) {
                if let end = pair.0.range?.upperBound.line, let start = pair.1.range?.lowerBound.line, start > end + 1 {
                    return true
                }
            }
            if index + 1 < items.count,
               let end = children.last?.range?.upperBound.line,
               let start = items[index + 1].range?.lowerBound.line,
               start > end + 1 {
                return true
            }
        }
        return false
    }

    mutating func visitListItem(_ listItem: ListItem) {
        guard let checkbox = listItem.checkbox else {
            html += "<li\(lineAttribute(listItem))>"
            defaultVisit(listItem)
            html += "</li>\n"
            return
        }
        let line = listItem.range.map { $0.lowerBound.line + lineOffset } ?? 0
        let checked = checkbox == .checked ? " checked" : ""
        let disabled = renderer.allowsTaskToggling ? "" : " disabled"
        html += "<li class=\"task-list-item\"\(lineAttribute(listItem))>"
        html += "<input type=\"checkbox\" data-task-line=\"\(line)\"\(checked)\(disabled)> "
        defaultVisit(listItem)
        html += "</li>\n"
    }

    mutating func visitTable(_ table: Table) {
        let alignments = table.columnAlignments
        html += "<table\(lineAttribute(table))>\n<thead>\n"
        writeRow(Array(table.head.cells), tag: "th", alignments: alignments, line: lineAttribute(table.head))
        html += "</thead>\n"
        let rows = Array(table.body.rows)
        if !rows.isEmpty {
            html += "<tbody>\n"
            for row in rows {
                writeRow(Array(row.cells), tag: "td", alignments: alignments, line: lineAttribute(row))
            }
            html += "</tbody>\n"
        }
        html += "</table>\n"
    }

    private mutating func writeRow(_ cells: [Table.Cell], tag: String, alignments: [Table.ColumnAlignment?], line: String) {
        html += "<tr\(line)>"
        for (index, cell) in cells.enumerated() {
            var style = ""
            if index < alignments.count, let alignment = alignments[index] {
                switch alignment {
                case .left: style = " style=\"text-align: left\""
                case .center: style = " style=\"text-align: center\""
                case .right: style = " style=\"text-align: right\""
                }
            }
            html += "<\(tag)\(style)>"
            defaultVisit(cell)
            html += "</\(tag)>"
        }
        html += "</tr>\n"
    }

    mutating func visitText(_ text: Text) {
        guard linkDepth == 0, let regex = Self.bareLink else {
            html += escape(text.string)
            return
        }
        let string = text.string
        let nsString = string as NSString
        var cursor = 0
        for match in regex.matches(in: string, range: NSRange(location: 0, length: nsString.length)) {
            html += escape(nsString.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            let address = nsString.substring(with: match.range)
            let destination = address.lowercased().hasPrefix("www.") ? "http://" + address : address
            html += "<a href=\"\(escape(destination))\">\(escape(address))</a>"
            cursor = NSMaxRange(match.range)
        }
        html += escape(nsString.substring(from: cursor))
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        html += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        html += "<br>\n"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        html += "<code>\(escape(inlineCode.code))</code>"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        html += Self.filterTags(inlineHTML.rawHTML)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        html += "<em>"
        defaultVisit(emphasis)
        html += "</em>"
    }

    mutating func visitStrong(_ strong: Strong) {
        html += "<strong>"
        defaultVisit(strong)
        html += "</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        html += "<del>"
        defaultVisit(strikethrough)
        html += "</del>"
    }

    mutating func visitLink(_ link: Link) {
        let title = link.title.map { " title=\"\(escape($0))\"" } ?? ""
        html += "<a href=\"\(escape(link.destination ?? ""))\"\(title)>"
        linkDepth += 1
        defaultVisit(link)
        linkDepth -= 1
        html += "</a>"
    }

    mutating func visitImage(_ image: Image) {
        let address = image.source ?? ""
        let alt = image.plainText
        let title = image.title.map { " title=\"\(escape($0))\"" } ?? ""
        switch MarkdownResourceLocation.resolve(address, relativeTo: renderer.folderURL) {
        case .local(let url):
            localImages.append(url)
            html += "<img src=\"\(escape(renderer.localImageSource(url)))\" alt=\"\(escape(alt))\"\(title)>"
        case .external(let url):
            if renderer.loadsExternalImages {
                html += "<img src=\"\(escape(url.absoluteString))\" alt=\"\(escape(alt))\"\(title)>"
            } else {
                blockedImages.append(url)
                writePlaceholder(alt: alt, address: url.absoluteString)
            }
        case .embedded(let data):
            html += "<img src=\"\(escape(data))\" alt=\"\(escape(alt))\"\(title)>"
        case .unresolved(let original):
            writePlaceholder(alt: alt, address: original)
        }
    }

    private mutating func writePlaceholder(alt: String, address: String) {
        html += "<span class=\"image-placeholder\" title=\"\(escape(address))\">"
        if !alt.isEmpty {
            html += "<span class=\"image-placeholder-alt\">\(escape(alt))</span>"
        }
        html += "<span class=\"image-placeholder-address\">\(escape(address))</span></span>"
    }

    /// Disables raw HTML tags that GitHub filters, such as `script` and `iframe`.
    static func filterTags(_ html: String) -> String {
        guard let regex = filteredTags else { return html }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(location: 0, length: (html as NSString).length),
            withTemplate: "&lt;$1$2"
        )
    }
}

public struct MarkdownSlugger: Sendable {
    private var counts: [String: Int] = [:]

    public init() {}

    /// Returns the GitHub anchor of a heading; repeated headings get `-1`, `-2` and so on.
    public mutating func slug(for title: String) -> String {
        let base = Self.baseSlug(for: title)
        let count = counts[base, default: 0]
        counts[base] = count + 1
        return count == 0 ? base : "\(base)-\(count)"
    }

    static func baseSlug(for title: String) -> String {
        var result = ""
        for character in title.lowercased() {
            if character == " " {
                result.append("-")
            } else if character == "-" || character == "_" || character.isLetter || character.isNumber {
                result.append(character)
            }
        }
        return result
    }
}
