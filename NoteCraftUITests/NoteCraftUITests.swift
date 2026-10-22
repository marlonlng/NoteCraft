import XCTest

final class NoteCraftUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES", "-NSQuitAlwaysKeepsWindows", "NO"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
    }

    private var editor: XCUIElement {
        app.windows.firstMatch.textViews["Texteditor"]
    }

    private func newDocument(with text: String) {
        if !editor.waitForExistence(timeout: 5) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        editor.typeText(text)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTypingUpdatesStatusBar() {
        newDocument(with: "Hallo\nWelt")
        XCTAssertTrue(app.buttons["Zeile 2, Spalte 5"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["UTF-8"].exists || app.buttons["UTF-8"].exists || app.menuButtons["UTF-8"].exists)
        attachScreenshot("Editor")
    }

    func testFindAndReplace() {
        newDocument(with: "Apfel Birne Apfel")
        app.typeKey("f", modifierFlags: [.command, .option])
        let searchField = app.textFields["Suchen"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeText("Apfel")
        XCTAssertTrue(app.staticTexts["2 Treffer"].waitForExistence(timeout: 3))
        let replaceField = app.textFields["Ersetzen"]
        replaceField.click()
        replaceField.typeText("Kiwi")
        attachScreenshot("Suchen und Ersetzen")
        app.buttons["Alle ersetzen"].click()
        XCTAssertTrue(app.staticTexts["2 Treffer ersetzt"].waitForExistence(timeout: 3))
        XCTAssertEqual(editor.value as? String, "Kiwi Birne Kiwi")
    }

    func testCommandPaletteRunsTransformation() {
        newDocument(with: "laut")
        app.typeKey("a", modifierFlags: .command)
        app.typeKey("a", modifierFlags: [.command, .shift])
        let field = app.textFields["Befehl suchen"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("grossbuch")
        attachScreenshot("Befehlspalette")
        field.typeKey(.return, modifierFlags: [])
        let expectation = expectation(for: NSPredicate(format: "value == 'LAUT'"), evaluatedWith: editor)
        wait(for: [expectation], timeout: 3)
    }

    func testGoToLineValidatesInput() {
        newDocument(with: "a\nb\nc")
        app.typeKey("l", modifierFlags: .command)
        let field = app.textFields["Zeile oder Zeile:Spalte"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("9")
        XCTAssertTrue(app.staticTexts["Gib eine Zeilennummer zwischen 1 und 3 ein."].waitForExistence(timeout: 3))
        attachScreenshot("Gehe zu Zeile")
        field.typeKey(.delete, modifierFlags: [])
        field.typeText("2")
        field.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.buttons["Zeile 2, Spalte 1"].waitForExistence(timeout: 3))
    }

    func testSettingsWindowShowsPanes() {
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows["Allgemein"].exists ? app.windows["Allgemein"] : app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        for pane in ["Editor", "Farbschema", "Dateien", "Allgemein"] {
            app.toolbars.buttons[pane].click()
            XCTAssertTrue(app.windows[pane].waitForExistence(timeout: 3))
            let attachment = XCTAttachment(screenshot: app.windows[pane].screenshot())
            attachment.name = "Einstellungen \(pane)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSidebarShowsFindInFiles() {
        newDocument(with: "Text")
        app.typeKey("f", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Kein Ordner geöffnet"].waitForExistence(timeout: 3))
        attachScreenshot("Seitenleiste")
    }

    func testHelpWindowListsShortcuts() {
        app.menuBars.menuBarItems["Hilfe"].click()
        app.menuItems["NoteCraft-Hilfe"].click()
        XCTAssertTrue(app.windows["NoteCraft-Hilfe"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Tastaturkurzbefehle"].exists)
    }
}
