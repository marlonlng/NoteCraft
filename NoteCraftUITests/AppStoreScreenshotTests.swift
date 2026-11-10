import AppKit
import XCTest

/// Captures the five App Store windows; set `TEST_RUNNER_SCREENSHOT_LANGUAGE=de` for the German set.
///
/// Every slide starts the app anew in its own appearance, alternating dark and light, with the same tabs of demo
/// documents. The window corners are made transparent so that the slides show the window shape.
final class AppStoreScreenshotTests: XCTestCase {
    private struct Demo {
        let language: String
        let locale: String
        let untitledText: String
        let json: (name: String, text: String)
        let nginx: (name: String, text: String)
        let log: (name: String, text: String)
        let notes: (name: String, text: String)
        let checklist: (name: String, text: String)
        let customers: (name: String, text: String)
        let textEditor: String
        let heading: String
        let find: String
        let replace: String
        let regularExpression: String
        let searchCommands: String
        let replacement: String
    }

    private static let nginx = """
    server {
        listen 443 ssl;
        server_name example.com;

        root /var/www/example;
        index index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        location /api/ {
            proxy_pass http://127.0.0.1:8080/;
            proxy_set_header Host $host;
        }
    }

    """

    private static let log = """
    2026-10-27 09:14:02 INFO  Server started on port 8080
    2026-10-27 09:14:05 INFO  Connected to database
    2026-10-27 09:21:47 WARN  Slow query (812 ms): SELECT * FROM orders
    2026-10-27 09:22:10 INFO  GET /api/orders 200 34 ms
    2026-10-27 09:25:33 ERROR Payment service timeout after 30 s
    2026-10-27 09:25:34 INFO  Retrying payment request (1/3)

    """

    private static let english = Demo(
        language: "en",
        locale: "en_US",
        untitledText: "Ideas for 1.4",
        json: ("response.json", """
        {
          "id": 4211,
          "status": "shipped",
          "items": [
            { "sku": "NB-200", "name": "Notebook", "quantity": 2 },
            { "sku": "PN-010", "name": "Pen", "quantity": 5 }
          ],
          "shipping": { "carrier": "DHL", "tracking": "00340434161094015902" }
        }

        """),
        nginx: ("nginx.conf", nginx),
        log: ("server.log", log),
        notes: ("Meeting notes.txt", """
        Team sync, Tuesday

        - Release 1.3 is planned for November 18
        - Store texts are ready in English and German
        - Screenshots: session, Markdown toolbar, encodings

        Open questions
        - Which screenshot goes first?
        - Who checks the German texts?

        Next meeting: Thursday, 10:00

        """),
        checklist: ("Release checklist.md", """
        # Release checklist

        Version **1.3** adds a Markdown toolbar.

        ## Before the release
        - [x] Update the store texts
        - [x] Take new screenshots
        - [ ] Submit for review
        - [ ] Publish on *November 18*

        ## Languages

        | Language | Store texts | Screenshots |
        | --- | --- | --- |
        | English | done | done |
        | German | done | in progress |

        > Unsaved documents are kept when you quit.

        Run `swift test` before every release.

        """),
        customers: ("customers.csv", """
        Name;City;Country
        José García;Málaga;Spain
        Zoë Müller;Zürich;Switzerland
        François Dubois;Besançon;France
        Søren Østergaard;Århus;Denmark
        Anna Nováková;Brno;Czechia

        """),
        textEditor: "Text Editor",
        heading: "Heading",
        find: "Find",
        replace: "Replace",
        regularExpression: "Regular Expression",
        searchCommands: "Search Commands",
        replacement: "ALERT"
    )

    private static let german = Demo(
        language: "de",
        locale: "de_DE",
        untitledText: "Ideen für 1.4",
        json: ("antwort.json", """
        {
          "id": 4211,
          "status": "versendet",
          "artikel": [
            { "sku": "NB-200", "name": "Notizbuch", "menge": 2 },
            { "sku": "KS-010", "name": "Kugelschreiber", "menge": 5 }
          ],
          "versand": { "dienst": "DHL", "sendung": "00340434161094015902" }
        }

        """),
        nginx: ("nginx.conf", nginx),
        log: ("server.log", log),
        notes: ("Besprechung.txt", """
        Teamrunde, Dienstag

        - Version 1.3 erscheint am 18. November
        - Store-Texte auf Deutsch und Englisch sind fertig
        - Screenshots: Sitzung, Markdown-Symbolleiste, Kodierungen

        Offene Fragen
        - Welcher Screenshot kommt zuerst?
        - Wer prüft die deutschen Texte?

        Nächstes Treffen: Donnerstag, 10:00 Uhr

        """),
        checklist: ("Release-Checkliste.md", """
        # Release-Checkliste

        Version **1.3** bringt eine Markdown-Symbolleiste.

        ## Vor der Veröffentlichung
        - [x] Store-Texte aktualisieren
        - [x] Neue Screenshots aufnehmen
        - [ ] Zur Prüfung einreichen
        - [ ] Am *18. November* veröffentlichen

        ## Sprachen

        | Sprache | Store-Texte | Screenshots |
        | --- | --- | --- |
        | Englisch | fertig | fertig |
        | Deutsch | fertig | in Arbeit |

        > Ungesicherte Dokumente bleiben beim Beenden erhalten.

        Vor jeder Veröffentlichung `swift test` ausführen.

        """),
        customers: ("kunden.csv", """
        Name;Ort;Straße
        Jürgen Weiß;Köln;Hauptstraße 12
        Änne Schäfer;München;Bahnhofstraße 3
        Özlem Yüksel;Düsseldorf;Königsallee 8
        Martin Groß;Nürnberg;Lorenzer Platz 1
        Sören Löwe;Lübeck;Mühlenstraße 5

        """),
        textEditor: "Texteditor",
        heading: "Überschrift",
        find: "Suchen",
        replace: "Ersetzen",
        regularExpression: "Regulärer Ausdruck",
        searchCommands: "Befehl suchen",
        replacement: "ALARM"
    )

    private let demo = ProcessInfo.processInfo.environment["SCREENSHOT_LANGUAGE"] == "de" ? AppStoreScreenshotTests.german : AppStoreScreenshotTests.english
    private var folder: URL!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("NoteCraftScreenshots-\(demo.language)", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, text) in [demo.json, demo.nginx, demo.log, demo.notes, demo.checklist] {
            try text.write(to: url(name), atomically: true, encoding: .utf8)
        }
        let customers = demo.customers.text.replacingOccurrences(of: "\n", with: "\r\n")
        try XCTUnwrap(customers.data(using: .windowsCP1252)).write(to: url(demo.customers.name))
    }

    override func tearDown() {
        app?.terminate()
    }

    private func url(_ name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    /// Starts the app in the given appearance with an edited untitled tab and the demo documents in tabs.
    private func launch(dark: Bool) {
        app?.terminate()
        app = XCUIApplication()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES", "-NSQuitAlwaysKeepsWindows", "NO", "-ShowsSidebar", "NO",
            "-AppleWindowTabbingMode", "always", "-AppleLanguages", "(\(demo.language))", "-AppleLocale", demo.locale
        ]
        app.launchArguments += dark ? ["-AppleInterfaceStyle", "Dark"] : ["-NSRequiresAquaSystemAppearance", "YES"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        let untitled = app.windows.firstMatch.textViews[demo.textEditor]
        if !untitled.waitForExistence(timeout: 5) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(untitled.waitForExistence(timeout: 5))
        untitled.click()
        untitled.typeText(demo.untitledText)
        for name in [demo.json.name, demo.nginx.name, demo.log.name, demo.notes.name] {
            open([name])
            XCTAssertTrue(app.windows.firstMatch.tabs[name].waitForExistence(timeout: 10))
        }
        show(demo.notes.name)
    }

    /// Opens demo documents in the app under test while it stays active, so that they join its tabs.
    private func open(_ names: [String]) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.marlonlange.NoteCraft")
            .first { $0.bundleURL?.path.contains("/DerivedData/") == true }
        guard let appURL = running?.bundleURL else {
            XCTFail("The app under test is not running")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let opened = expectation(description: "Opened \(names)")
        NSWorkspace.shared.open(names.map(url), withApplicationAt: appURL, configuration: configuration) { _, error in
            XCTAssertNil(error)
            opened.fulfill()
        }
        wait(for: [opened], timeout: 10)
    }

    /// Selects the tab of a demo document, opening the document first when needed, and returns its window.
    @discardableResult
    private func show(_ name: String) -> XCUIElement {
        let tab = app.windows.firstMatch.tabs[name]
        if !tab.waitForExistence(timeout: 3) {
            open([name])
        }
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.click()
        let window = app.windows[name]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        return window
    }

    private func editor(in window: XCUIElement) -> XCUIElement {
        window.textViews[demo.textEditor]
    }

    /// Attaches the window as it appears on screen, including popovers, with the mouse moved out of the way.
    private func capture(_ window: XCUIElement, name: String) {
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.85)).hover()
        Thread.sleep(forTimeInterval: 1.5)
        let attachment = XCTAttachment(data: Self.windowImage(from: XCUIScreen.main.screenshot(), frame: window.frame), uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Cuts the window out of a screen image and clears the corners outside the window shape.
    private static func windowImage(from screen: XCUIScreenshot, frame: CGRect) -> Data {
        guard let source = NSBitmapImageRep(data: screen.pngRepresentation)?.cgImage else { return Data() }
        let scale = CGFloat(source.width) / screen.image.size.width
        let crop = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale).integral
        guard let window = source.cropping(to: crop),
              let space = window.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: window.width, height: window.height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return Data() }
        let bounds = CGRect(x: 0, y: 0, width: window.width, height: window.height)
        let radius = 17 * scale
        context.addPath(CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
        context.draw(window, in: bounds)
        guard let masked = context.makeImage() else { return Data() }
        return NSBitmapImageRep(cgImage: masked).representation(using: .png, properties: [:]) ?? Data()
    }

    private func moveCaret(in editor: XCUIElement, line: Int, column: Int) {
        editor.typeKey(.upArrow, modifierFlags: .command)
        for _ in 1..<line {
            editor.typeKey(.downArrow, modifierFlags: [])
        }
        editor.typeKey(.leftArrow, modifierFlags: .command)
        for _ in 1..<column {
            editor.typeKey(.rightArrow, modifierFlags: [])
        }
    }

    func testCaptureAppStoreScreenshots() throws {
        launch(dark: true)
        capture(app.windows[demo.notes.name], name: "01-session")

        launch(dark: false)
        let markdown = show(demo.checklist.name)
        editor(in: markdown).click()
        moveCaret(in: editor(in: markdown), line: 3, column: 12)
        markdown.toolbars.buttons[demo.heading].click()
        XCTAssertTrue(app.popovers.firstMatch.waitForExistence(timeout: 3))
        capture(markdown, name: "02-markdown")

        launch(dark: true)
        let log = show(demo.log.name)
        app.typeKey("f", modifierFlags: [.command, .option])
        let searchField = log.textFields[demo.find]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        log.descendants(matching: .any).matching(NSPredicate(format: "label == %@", demo.regularExpression)).firstMatch.click()
        searchField.click()
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeText("WARN|ERROR")
        log.textFields[demo.replace].click()
        log.textFields[demo.replace].typeText(demo.replacement)
        capture(log, name: "03-find")

        launch(dark: false)
        capture(show(demo.customers.name), name: "04-encoding")

        launch(dark: true)
        let notes = show(demo.notes.name)
        app.typeKey("a", modifierFlags: [.command, .shift])
        let paletteField = app.textFields[demo.searchCommands]
        XCTAssertTrue(paletteField.waitForExistence(timeout: 3))
        paletteField.typeText("sort")
        capture(notes, name: "05-private")
    }
}
