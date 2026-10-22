import XCTest

final class SessionRestoreUITests: XCTestCase {
    private func attachState(of app: XCUIApplication, name: String) {
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name) – Hierarchie"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        screenshot.name = "\(name) – Fenster"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testRestoresUnsavedUntitledDocumentAfterQuit() {
        let marker = "Ungesicherte Notiz \(UUID().uuidString.prefix(8))"
        let app = XCUIApplication()
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        let editor = app.windows.firstMatch.textViews["Texteditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        editor.typeText(marker)

        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15))

        let relaunched = XCUIApplication()
        relaunched.launch()
        let restored = relaunched.textViews.matching(NSPredicate(format: "value == %@", marker)).firstMatch
        let wasRestored = restored.waitForExistence(timeout: 10)
        attachState(of: relaunched, name: "Nach Neustart")
        XCTAssertTrue(wasRestored)

        if wasRestored {
            restored.click()
            relaunched.typeKey("w", modifierFlags: .command)
            let discard = relaunched.sheets.buttons["Löschen"].firstMatch
            if discard.waitForExistence(timeout: 3) {
                discard.click()
            }
        }
        relaunched.terminate()
    }
}
