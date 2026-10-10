import XCTest

final class LocalizationUITests: XCTestCase {
    @MainActor
    func testLanguageSwitchPreservesFormAndPersists() throws {
        let app = XCUIApplication(bundleIdentifier: "com.lyq02.familytracker")
        app.launchArguments = ["-app.language", "vi"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Kết nối gia đình, mọi lúc mọi nơi"].waitForExistence(timeout: 15))

        let email = app.textFields.firstMatch
        email.tap()
        email.typeText("language-test@example.com")
        let picker = app.buttons["settings.language"]
        XCTAssertTrue(picker.exists)
        picker.tap()
        app.buttons["English"].tap()
        XCTAssertTrue(app.staticTexts["Stay connected with your family"].waitForExistence(timeout: 5))
        XCTAssertEqual(email.value as? String, "language-test@example.com")
        attach(app, name: "Login-English")

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["Stay connected with your family"].waitForExistence(timeout: 15))
        app.buttons["settings.language"].tap()
        app.buttons["Tiếng Việt"].tap()
        XCTAssertTrue(app.staticTexts["Kết nối gia đình, mọi lúc mọi nơi"].waitForExistence(timeout: 5))
        attach(app, name: "Login-Vietnamese")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
