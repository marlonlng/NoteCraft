import Foundation
import Testing
@testable import NoteCraftKit

struct MarkdownRendererTests {
    private func render(_ text: String, _ configure: (inout MarkdownRenderer) -> Void = { _ in }) -> MarkdownRendering {
        var renderer = MarkdownRenderer(folderURL: URL(fileURLWithPath: "/notes"))
        configure(&renderer)
        return renderer.render(text)
    }

    @Test func rendersBlocksWithSourceLines() {
        let html = render("# Title\n\nSome *text* and **bold**.\n\n---\n\n> Quote").html
        #expect(html.contains("<h1 id=\"title\" data-line=\"1\">Title</h1>"))
        #expect(html.contains("<p data-line=\"3\">Some <em>text</em> and <strong>bold</strong>.</p>"))
        #expect(html.contains("<hr data-line=\"5\">"))
        #expect(html.contains("<blockquote data-line=\"7\">"))
    }

    @Test func rendersGitHubExtensions() {
        let html = render("~~old~~ www.example.com\n\n| A | B |\n| :- | -: |\n| 1 | 2 |").html
        #expect(html.contains("<del>old</del>"))
        #expect(html.contains("<a href=\"http://www.example.com\">www.example.com</a>"))
        #expect(html.contains("<table data-line=\"3\">"))
        #expect(html.contains("<th style=\"text-align: left\">A</th><th style=\"text-align: right\">B</th>"))
        #expect(html.contains("<tr data-line=\"5\"><td style=\"text-align: left\">1</td>"))
    }

    @Test func linksBareAddressesOnlyOutsideLinks() {
        let html = render("See https://example.com/a_(b). and [https://x.org](https://x.org)").html
        #expect(html.contains("<a href=\"https://example.com/a_(b)\">https://example.com/a_(b)</a>."))
        #expect(html.contains("<a href=\"https://x.org\">https://x.org</a>"))
    }

    @Test func rendersTasksWithTheirLines() {
        let preview = render("- [ ] open\n- [x] done") { $0.allowsTaskToggling = true }.html
        #expect(preview.contains("<ul class=\"contains-task-list\" data-line=\"1\">"))
        #expect(preview.contains("<input type=\"checkbox\" data-task-line=\"1\"> open"))
        #expect(preview.contains("<input type=\"checkbox\" data-task-line=\"2\" checked> done"))
        #expect(render("- [ ] open").html.contains("data-task-line=\"1\" disabled>"))
    }

    @Test func distinguishesTightAndLooseLists() {
        let tight = render("1. one\n2. two").html
        #expect(tight.contains("<li data-line=\"1\">one</li>"))
        let loose = render("3. one\n\n4. two").html
        #expect(loose.contains("<ol start=\"3\" data-line=\"1\">"))
        #expect(loose.contains("<li data-line=\"1\"><p data-line=\"1\">one</p>"))
    }

    @Test func highlightsCodeBlocks() {
        let html = render("```swift\nlet x = 1\n```").html
        #expect(html.contains("<pre data-line=\"1\"><code class=\"language-swift\"><span class=\"tk-keyword\">let</span> x = <span class=\"tk-number\">1</span></code></pre>"))
        #expect(render("```\n<b>\n```").html.contains("<code>&lt;b&gt;</code>"))
        #expect(MarkdownHTMLWriter.highlightedHTML("a < b", language: nil) == "a &lt; b")
    }

    @Test func rendersFrontMatterAsCodeAndKeepsLineNumbers() {
        let html = render("---\ntitle: Notes\n---\n# Heading").html
        #expect(html.contains("<pre class=\"front-matter\" data-line=\"1\"><code class=\"language-yaml\">"))
        #expect(html.contains("<h1 id=\"heading\" data-line=\"4\">"))
        #expect(MarkdownRenderer.frontMatter(in: "---\nno end") == nil)
        #expect(MarkdownRenderer.frontMatter(in: "text") == nil)
    }

    @Test func resolvesImagesByLocation() {
        let rendering = render("![Logo](images/logo%20big.png) ![Web](https://example.com/a.png) ![Inline](data:image/png;base64,AA==) ![Odd](~/x.png)") {
            $0.loadsExternalImages = false
            $0.localImageSource = { "local:" + $0.path }
        }
        #expect(rendering.localImages == [URL(fileURLWithPath: "/notes/images/logo big.png")])
        #expect(rendering.blockedImages == [URL(string: "https://example.com/a.png")!])
        #expect(rendering.html.contains("<img src=\"local:/notes/images/logo big.png\" alt=\"Logo\">"))
        #expect(rendering.html.contains("<span class=\"image-placeholder\" title=\"https://example.com/a.png\"><span class=\"image-placeholder-alt\">Web</span>"))
        #expect(rendering.html.contains("<img src=\"data:image/png;base64,AA==\" alt=\"Inline\">"))
        #expect(rendering.html.contains("<span class=\"image-placeholder-address\">~/x.png</span>"))
        let loaded = render("![Web](https://example.com/a.png \"Title\")").html
        #expect(loaded.contains("<img src=\"https://example.com/a.png\" alt=\"Web\" title=\"Title\">"))
    }

    @Test func resolvesResourceLocations() {
        let folder = URL(fileURLWithPath: "/notes")
        #expect(MarkdownResourceLocation.resolve("//cdn.example.com/a.png", relativeTo: folder) == .external(URL(string: "https://cdn.example.com/a.png")!))
        #expect(MarkdownResourceLocation.resolve("file:///tmp/a.png", relativeTo: folder) == .local(URL(fileURLWithPath: "/tmp/a.png")))
        #expect(MarkdownResourceLocation.resolve("/abs/a.png", relativeTo: nil) == .local(URL(fileURLWithPath: "/abs/a.png")))
        #expect(MarkdownResourceLocation.resolve("../up.png?raw=1", relativeTo: folder) == .local(URL(fileURLWithPath: "/up.png")))
        #expect(MarkdownResourceLocation.resolve("a.png", relativeTo: nil) == .unresolved("a.png"))
        #expect(MarkdownResourceLocation.resolve("ftp://x/a.png", relativeTo: folder) == .unresolved("ftp://x/a.png"))
    }

    @Test func filtersDangerousTags() {
        let html = render("<script>alert(1)</script>\n\nText <iframe src=x></iframe> <b>ok</b>").html
        #expect(html.contains("&lt;script>alert(1)&lt;/script>"))
        #expect(html.contains("&lt;iframe src=x>&lt;/iframe>"))
        #expect(html.contains("<b>ok</b>"))
    }

    @Test func rendersInlineDetails() {
        let html = render("a  \nb `c<d>` [x](https://e.org \"T\")").html
        #expect(html.contains("a<br>\nb <code>c&lt;d&gt;</code> <a href=\"https://e.org\" title=\"T\">x</a>"))
    }

    @Test func createsUniqueGitHubSlugs() {
        var slugger = MarkdownSlugger()
        #expect(slugger.slug(for: "Hello, World!") == "hello-world")
        #expect(slugger.slug(for: "Hello World") == "hello-world-1")
        #expect(slugger.slug(for: "Über snake_case") == "über-snake_case")
        let html = render("# Same\n# Same").html
        #expect(html.contains("id=\"same\"") && html.contains("id=\"same-1\""))
    }
}

struct MarkdownPageTests {
    @Test func buildsPreviewWithPolicy() {
        let blocked = MarkdownPage.previewHTML(body: "<p>x</p>", css: "body{}", nonce: "abc", allowsExternalImages: false)
        #expect(blocked.contains("img-src notecraft: data:;"))
        #expect(blocked.contains("script-src 'nonce-abc'"))
        #expect(blocked.contains("<script nonce=\"abc\">"))
        #expect(blocked.contains("<article id=\"content\"><p>x</p></article>"))
        let allowed = MarkdownPage.previewHTML(body: "", css: "", nonce: "n", allowsExternalImages: true)
        #expect(allowed.contains("img-src notecraft: data: https: http:;"))
    }

    @Test func buildsExportDocument() {
        let html = MarkdownPage.exportHTML(title: "A & B", body: "<p>x</p>", css: "p{}")
        #expect(html.contains("<title>A &amp; B</title>"))
        #expect(html.contains("<style>p{}</style>"))
        #expect(!html.contains("<script"))
    }

    @Test func mapsResourceAddresses() {
        let url = URL(fileURLWithPath: "/Users/me/My Notes/a.png")
        let address = MarkdownPage.resourceAddress(for: url)
        #expect(address == "notecraft://file/Users/me/My%20Notes/a.png")
        #expect(MarkdownPage.fileURL(forResourceAddress: URL(string: address)!) == url)
        #expect(MarkdownPage.fileURL(forResourceAddress: URL(string: "https://file/a")!) == nil)
    }
}

struct MarkdownStyleSheetTests {
    @Test func definesThemeVariablesForScreenPrintAndDarkMode() {
        let css = MarkdownStyleSheet(theme: .graphite, printTheme: .paper, darkTheme: .midnight, codeFontName: "Menlo\"").css
        #expect(css.contains("--nc-background: #1E1F22;"))
        #expect(css.contains("@media (prefers-color-scheme: dark)"))
        #expect(css.contains("--nc-background: #111827;"))
        #expect(css.contains("@media print"))
        #expect(css.contains("--nc-background: #FBFAF7;"))
        #expect(css.contains(".tk-keyword { color: var(--nc-tk-keyword); }"))
        #expect(css.contains("--nc-code-font: \"Menlo\", ui-monospace"))
        #expect(css.contains("--nc-border: #7D838C59;"))
        let plain = MarkdownStyleSheet(theme: .paper).css
        #expect(!plain.contains("prefers-color-scheme"))
        #expect(plain.contains("--nc-code-font: ui-monospace"))
    }

    @Test func findsLanguagesForCodeFences() {
        #expect(Language.language(forCodeFenceInfo: "swift") == LanguageCatalog.swift)
        #expect(Language.language(forCodeFenceInfo: "JS title=x") == LanguageCatalog.javaScript)
        #expect(Language.language(forCodeFenceInfo: "bash") == LanguageCatalog.shell)
        #expect(Language.language(forCodeFenceInfo: "Dockerfile") == LanguageCatalog.dockerfile)
        #expect(Language.language(forCodeFenceInfo: "") == nil)
        #expect(Language.language(forCodeFenceInfo: "klingon") == nil)
    }
}
