import XCTest

final class MapDesignPreviewTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    @MainActor private func app(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-app.language", "vi", "-qa.screen", mode, "-app.appearance", "system"]
        app.launch()
        return app
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    @MainActor func testMapSearchAndKeyboard() {
        let app = app("map")
        let search = app.buttons["map.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        XCTAssertLessThan(search.frame.minY, app.frame.height * 0.3)
        XCTAssertGreaterThanOrEqual(app.buttons["map.recenter"].frame.height, 44)
        XCTAssertGreaterThan(app.buttons["map.recenter"].frame.minY, search.frame.maxY)
        capture(app, "Native-Map-Components")
        search.tap()
        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Cong vien")
        XCTAssertTrue(app.buttons["search.close"].exists)
        XCTAssertTrue(app.staticTexts["Công viên QA"].waitForExistence(timeout: 5))
        capture(app, "Native-Search-Keyboard")
        app.buttons["search.close"].tap()
        XCTAssertTrue(app.buttons["map.search"].waitForExistence(timeout: 5))
    }
    @MainActor func testMemberPanelAndUnknownTime() {
        let app = app("member")
        XCTAssertTrue(app.descendants(matching: .any)["map.member_detail"].waitForExistence(timeout: 15))
        capture(app, "Native-Member-Panel")
        app.buttons["Đóng"].firstMatch.tap()
        let unknown = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Chưa rõ thời điểm cập nhật"))
        for _ in 0..<8 {
            if unknown.firstMatch.exists { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(unknown.firstMatch.exists)
    }
    @MainActor func testAppearanceChangesAndPersists() {
        let app = app("appearance")
        let dark = app.buttons["appearance.dark"]
        XCTAssertTrue(dark.waitForExistence(timeout: 15))
        dark.tap()
        XCTAssertTrue(dark.isSelected)
        capture(app, "Native-Appearance-Dark")
        app.terminate()
        app.launchArguments = ["-app.language", "vi", "-qa.screen", "appearance"]
        app.launch()
        XCTAssertTrue(app.buttons["appearance.dark"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["appearance.dark"].isSelected)
        app.buttons["appearance.light"].tap()
        capture(app, "Native-Appearance-Light")
        app.buttons["appearance.system"].tap()
        XCTAssertTrue(app.buttons["appearance.system"].isSelected)
    }
    @MainActor func testDisconnectedWarningRemainsVisible() {
        let app = app("offline")
        XCTAssertTrue(app.descendants(matching: .any)["map.connection_warning"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["map.search"].exists)
        capture(app, "Native-Realtime-Disconnected")
    }
}
