import XCTest

final class AppStoreScreenshotTests: XCTestCase {
    private static let sample = #"""
    import Foundation

    /// Eine Notiz mit Titel, Text und Schlagwörtern.
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
        Note(id: UUID(), title: "Einkauf", body: "Äpfel, Brot, Kaffee"),
        Note(id: UUID(), title: "Ideen", body: "Texteditor für den Mac bauen", tags: ["app"])
    ]

    for note in notes.sorted(by: { $0.title < $1.title }) {
        print("\(note.title): \(note.wordCount) Wörter")
    }

    """#

    private static let markdown = """
    # Projektnotizen

    ## Nächste Schritte
    - **Version 1.0** vorbereiten
    - Screenshots für den *App Store* erstellen
    - [Feedback sammeln](https://example.com/feedback)

    > Ungesicherte Dokumente bleiben beim Beenden erhalten.

    `⌘S` sichert, `⇧⌘A` öffnet die Befehlspalette.

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
        let sampleURL = folder.appendingPathComponent("Notizen.swift")
        try Self.sample.write(to: sampleURL, atomically: true, encoding: .utf8)

        let app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES", "-NSQuitAlwaysKeepsWindows", "NO", "-AppleInterfaceStyle", "Dark", "-ShowsSidebar", "NO"]
        app.launch()
        app.open(sampleURL)
        let window = app.windows["Notizen.swift"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let editor = window.textViews["Texteditor"]
        editor.click()
        editor.typeKey(.upArrow, modifierFlags: .command)
        for _ in 0..<9 {
            editor.typeKey(.downArrow, modifierFlags: [])
        }
        editor.typeKey(.rightArrow, modifierFlags: .command)
        capture(window, name: "01-Editor")

        app.typeKey("f", modifierFlags: [.command, .option])
        let searchField = window.textFields["Suchen"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeText("note")
        window.textFields["Ersetzen"].click()
        window.textFields["Ersetzen"].typeText("entry")
        capture(window, name: "02-Suchen")
        window.buttons["Fertig"].click()

        app.typeKey("a", modifierFlags: [.command, .shift])
        let paletteField = app.textFields["Befehl suchen"]
        XCTAssertTrue(paletteField.waitForExistence(timeout: 3))
        paletteField.typeText("sortier")
        capture(window, name: "03-Befehlspalette")
        paletteField.typeKey(.escape, modifierFlags: [])

        app.typeKey(",", modifierFlags: .command)
        app.toolbars.buttons["Farbschema"].click()
        let settings = app.windows["Farbschema"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        capture(settings, name: "05-Farbschema")
        settings.typeKey("w", modifierFlags: .command)

        let markdownURL = folder.appendingPathComponent("Projektnotizen.md")
        try Self.markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
        app.open(markdownURL)
        let markdownWindow = app.windows["Projektnotizen.md"]
        XCTAssertTrue(markdownWindow.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1)
        capture(markdownWindow, name: "04-Markdown")

        app.terminate()
    }
}
