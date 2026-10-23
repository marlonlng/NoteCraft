import XCTest

final class SessionRestoreUITests: XCTestCase {
    private func attachState(of app: XCUIApplication, name: String) {
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name) – Hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        screenshot.name = "\(name) – Window"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testRestoresUnsavedUntitledDocumentAfterQuit() {
        let marker = "Unsaved note \(UUID().uuidString.prefix(8))"
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        let editor = app.windows.firstMatch.textViews["Text Editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        editor.typeText(marker)

        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 15))

        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        relaunched.launch()
        let restored = relaunched.textViews.matching(NSPredicate(format: "value == %@", marker)).firstMatch
        let wasRestored = restored.waitForExistence(timeout: 10)
        attachState(of: relaunched, name: "After Relaunch")
        XCTAssertTrue(wasRestored)

        if wasRestored {
            restored.click()
            relaunched.typeKey("w", modifierFlags: .command)
            let discard = relaunched.sheets.buttons["Delete"].firstMatch
            if discard.waitForExistence(timeout: 3) {
                discard.click()
            }
        }
        relaunched.terminate()
    }
}
