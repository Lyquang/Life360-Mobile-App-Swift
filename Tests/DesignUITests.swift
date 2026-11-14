import XCTest
import UIKit

/// Run only on an isolated, signed-out Simulator. No valid credentials are submitted.
final class DesignUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testPasswordVisibilityPreservesValueAndAccessibleTarget() throws {
        let app = launch(language: "en")
        capture(app, "Login-English")
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
        let eye = app.buttons["password.visibility"].firstMatch
        reveal(eye, in: app)
        XCTAssertEqual(eye.label, "Show password")
        XCTAssertEqual(eye.value as? String, "Hidden")
        XCTAssertGreaterThanOrEqual(eye.frame.width, 44)
        XCTAssertGreaterThanOrEqual(eye.frame.height, 44)

        let password = app.secureTextFields["Password"]
        XCTAssertTrue(password.exists)
        XCTAssertLessThanOrEqual(password.frame.maxX, eye.frame.minX)
        password.tap()
        password.typeText("SyntheticQA123")
        eye.tap()
        XCTAssertEqual(eye.label, "Hide password")
        XCTAssertEqual(eye.value as? String, "Visible")
        let visible = app.textFields["Password"]
        XCTAssertTrue(visible.exists)
        XCTAssertEqual(visible.value as? String, "SyntheticQA123")
        capture(app, "Password-Visible-Synthetic-Fixture")
        eye.tap()
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertEqual(eye.label, "Show password")
        // Never tap submit with these entered values.
    }

    @MainActor
    func testEmptyLoginShowsLocalError() throws {
        let app = launch(language: "en")
        let submit = app.buttons["auth.login.submit"]
        reveal(submit, in: app)
        submit.tap()
        let error = app.staticTexts["The information is invalid. Check it and try again."]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        capture(app, "Login-Local-Validation-Error")
    }

    @MainActor
    func testVietnameseRegisterHasAccessibleControlsAndScrollableAction() throws {
        let app = launch(language: "vi")
        capture(app, "Login-Vietnamese")
        let register = app.buttons["auth.register.open"]
        reveal(register, in: app)
        register.tap()
        let submit = app.buttons["auth.register.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        capture(app, "Register-Top-Vietnamese")
        reveal(submit, in: app)
        XCTAssertGreaterThanOrEqual(submit.frame.height, 44)
        capture(app, "Register-Action-Vietnamese")
        // A native sheet can be dismissed without changing authentication state.
        app.swipeDown()
    }

    @MainActor
    func testFieldAndPrimaryActionContrastAcrossAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            UITraitCollection(userInterfaceStyle: style).performAsCurrent {
                for background in [FTColors.card, FTColors.surface] {
                    let back = rgba(UIColor(background))
                    let front = rgba(UIColor(FTColors.fieldHint))
                    let composed = zip(front.prefix(3), back.prefix(3)).map { $0 * front[3] + $1 * (1 - front[3]) }
                    XCTAssertGreaterThanOrEqual(contrast(composed, Array(back.prefix(3))), 4.5)
                }
                XCTAssertGreaterThanOrEqual(contrast(Array(rgba(UIColor(FTColors.onPrimary)).prefix(3)), Array(rgba(UIColor(FTColors.primary)).prefix(3))), 4.5)
            }
        }
    }

    private func rgba(_ color: UIColor) -> [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(color.resolvedColor(with: .current).getRed(&r, green: &g, blue: &b, alpha: &a))
        return [Double(r), Double(g), Double(b), Double(a)]
    }

    private func contrast(_ first: [Double], _ second: [Double]) -> Double {
        func luminance(_ rgb: [Double]) -> Double {
            let channels = rgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    @MainActor
    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.lyq02.familytracker")
        app.launchArguments = ["-app.language", language]
        app.launch()
        XCTAssertTrue(app.buttons["settings.language"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Control could not be reached by scrolling: \(element.identifier)")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
