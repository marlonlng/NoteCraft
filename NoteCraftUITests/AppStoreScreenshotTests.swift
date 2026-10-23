import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    private static let sample = #"""
    import Foundation

    /// A note with a title, a body and tags.
    struct Note: Identifiable, Codable {
        let id: UUID
        var title: String
        var body: String
        var tags: [String] = []

        var wordCount: Int {
            body.split(whereSeparator: \.isWhitespace).count
        }
    }

    let notes = [
        Note(id: UUID(), title: "Groceries", body: "Apples, bread, coffee"),
        Note(id: UUID(), title: "Ideas", body: "Build a text editor for the Mac", tags: ["app"])
    ]

    for note in notes.sorted(by: { $0.title < $1.title }) {
        print("\(note.title): \(note.wordCount) words")
    }

    """#

    private static let markdown = """
    # Project Notes

    ## Next Steps
    - Prepare **version 1.0**
    - Create screenshots for the *App Store*
    - [Collect feedback](https://example.com/feedback)

    > Unsaved documents are kept when you quit.

    `⌘S` saves, `⇧⌘A` opens the command palette.

    """

    private func capture(_ element: XCUIElement, name: String) {
        let attachment = XCTAttachment(screenshot: element.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureAppStoreScreenshots() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("NoteCraftScreenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sampleURL = folder.appendingPathComponent("Notes.swift")
        try Self.sample.write(to: sampleURL, atomically: true, encoding: .utf8)

        let app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES", "-NSQuitAlwaysKeepsWindows", "NO", "-AppleInterfaceStyle", "Dark", "-ShowsSidebar", "NO", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.open(sampleURL)
        let window = app.windows["Notes.swift"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let editor = window.textViews["Text Editor"]
        editor.click()
        editor.typeKey(.upArrow, modifierFlags: .command)
        for _ in 0..<9 {
            editor.typeKey(.downArrow, modifierFlags: [])
        }
        editor.typeKey(.rightArrow, modifierFlags: .command)
        capture(window, name: "01-Editor")

        app.typeKey("f", modifierFlags: [.command, .option])
        let searchField = window.textFields["Find"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeText("note")
        window.textFields["Replace"].click()
        window.textFields["Replace"].typeText("entry")
        capture(window, name: "02-Find")
        window.buttons["Done"].click()

        app.typeKey("a", modifierFlags: [.command, .shift])
        let paletteField = app.textFields["Search Commands"]
        XCTAssertTrue(paletteField.waitForExistence(timeout: 3))
        paletteField.typeText("sort")
        capture(window, name: "03-Command-Palette")
        paletteField.typeKey(.escape, modifierFlags: [])

        app.typeKey(",", modifierFlags: .command)
        app.toolbars.buttons["Themes"].click()
        let settings = app.windows["Themes"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        capture(settings, name: "05-Themes")
        settings.typeKey("w", modifierFlags: .command)

        let markdownURL = folder.appendingPathComponent("Project Notes.md")
        try Self.markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
        app.open(markdownURL)
        let markdownWindow = app.windows["Project Notes.md"]
        XCTAssertTrue(markdownWindow.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        capture(markdownWindow, name: "04-Markdown")

        app.terminate()
    }
}
