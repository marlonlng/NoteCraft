import XCTest

final class NoteCraftUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES", "-NSQuitAlwaysKeepsWindows", "NO", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
    }

    private var editor: XCUIElement {
        app.windows.firstMatch.textViews["Text Editor"]
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
        newDocument(with: "Hello\nWorld")
        XCTAssertTrue(app.buttons["Line 2, Column 6"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["UTF-8"].exists || app.buttons["UTF-8"].exists || app.menuButtons["UTF-8"].exists)
        attachScreenshot("Editor")
    }

    func testFindAndReplace() {
        newDocument(with: "apple pear apple")
        app.typeKey("f", modifierFlags: [.command, .option])
        let searchField = app.textFields["Find"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.typeKey("a", modifierFlags: .command)
        searchField.typeText("apple")
        XCTAssertTrue(app.staticTexts["2 matches"].waitForExistence(timeout: 3))
        let replaceField = app.textFields["Replace"]
        replaceField.click()
        replaceField.typeText("kiwi")
        attachScreenshot("Find and Replace")
        app.buttons["Replace All"].click()
        XCTAssertTrue(app.staticTexts["Replaced 2 matches"].waitForExistence(timeout: 3))
        XCTAssertEqual(editor.value as? String, "kiwi pear kiwi")
    }

    func testSaveSuggestsExtensionOfLanguage() {
        newDocument(with: "# Title")
        app.menuBars.menuBarItems["Text"].click()
        app.menuBars.menuItems["Language"].click()
        app.menuBars.menuItems["Markdown"].click()
        app.typeKey("s", modifierFlags: .command)
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        let nameField = sheet.textFields.matching(NSPredicate(format: "value ENDSWITH '.md'")).firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertFalse(sheet.textFields.matching(NSPredicate(format: "value ENDSWITH '.txt'")).firstMatch.exists)
        attachScreenshot("Save Markdown")
        sheet.buttons["Cancel"].click()
    }

    func testMarkdownShowsPreviewAndFormatsText() {
        newDocument(with: "Hello")
        app.menuBars.menuBarItems["Text"].click()
        app.menuBars.menuItems["Language"].click()
        app.menuBars.menuItems["Markdown"].click()
        let preview = app.webViews.firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey("b", modifierFlags: .command)
        XCTAssertEqual(editor.value as? String, "**Hello**")
        XCTAssertTrue(preview.staticTexts["Hello"].waitForExistence(timeout: 5))
        attachScreenshot("Markdown Preview")
        app.typeKey("p", modifierFlags: [.command, .option])
        let hidden = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: preview)
        wait(for: [hidden], timeout: 3)
        app.toolbars.buttons["Preview"].click()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.toolbars.menuButtons["Format"].exists || app.toolbars.popUpButtons["Format"].exists || app.toolbars.buttons["Format"].exists)
    }

    func testCommandPaletteRunsTransformation() {
        newDocument(with: "loud")
        app.typeKey("a", modifierFlags: .command)
        app.typeKey("a", modifierFlags: [.command, .shift])
        let field = app.textFields["Search Commands"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("upperc")
        attachScreenshot("Command Palette")
        field.typeKey(.return, modifierFlags: [])
        let expectation = expectation(for: NSPredicate(format: "value == 'LOUD'"), evaluatedWith: editor)
        wait(for: [expectation], timeout: 3)
    }

    func testGoToLineValidatesInput() {
        newDocument(with: "a\nb\nc")
        app.typeKey("l", modifierFlags: .command)
        let field = app.textFields["Line or line:column"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("9")
        XCTAssertTrue(app.staticTexts["Enter a line number between 1 and 3."].waitForExistence(timeout: 3))
        attachScreenshot("Go to Line")
        field.typeKey(.delete, modifierFlags: [])
        field.typeText("2")
        field.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.buttons["Line 2, Column 1"].waitForExistence(timeout: 3))
    }

    func testSettingsWindowShowsPanes() {
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows["General"].exists ? app.windows["General"] : app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 3))
        for pane in ["Editor", "Themes", "Files", "General"] {
            app.toolbars.buttons[pane].click()
            XCTAssertTrue(app.windows[pane].waitForExistence(timeout: 3))
            let attachment = XCTAttachment(screenshot: app.windows[pane].screenshot())
            attachment.name = "Settings \(pane)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSidebarShowsFindInFiles() {
        newDocument(with: "Text")
        app.typeKey("f", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["No Folder Open"].waitForExistence(timeout: 3))
        attachScreenshot("Sidebar")
    }

    func testHelpWindowListsShortcuts() {
        app.menuBars.menuBarItems["Help"].click()
        app.menuItems["NoteCraft Help"].click()
        XCTAssertTrue(app.windows["NoteCraft Help"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Keyboard Shortcuts"].exists)
    }
}
