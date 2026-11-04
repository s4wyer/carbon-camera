import XCTest

/// Freeze the same production renderer for reproducible transition checkpoints;
/// separately exercise the real timed handoff, system dialog and tap guard.
final class WelcomeUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor private func prepare() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--insert-sample-shot", "--welcome-testing"]
    }

    @MainActor private func save(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor private func respondToPermission(allow: Bool) {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 4) {
            if allow {
                let button = alert.buttons["Allow"]
                (button.exists ? button : alert.buttons["OK"]).tap()
            } else {
                let button = alert.buttons["Don’t Allow"]
                (button.exists ? button : alert.buttons["Don't Allow"]).tap()
            }
        }
    }

    @MainActor func testRestingAndTransitionCheckpoints() async throws {
        prepare()
        app.launch()
        XCTAssertTrue(app.buttons["Open camera"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["No account. Just pictures."].exists)
        save("welcome-resting")
        for (name, progress) in [("start", "0.16"), ("peak-before", "0.45"),
                                 ("peak-after", "0.49"), ("end", "0.85"), ("camera", "1.0")] {
            app.terminate()
            app.launchArguments = ["--ui-testing", "--insert-sample-shot", "--welcome-testing", "--welcome-frame=\(progress)"]
            app.launch()
            if Double(progress)! < 0.46 {
                XCTAssertTrue(app.buttons["Open camera"].waitForExistence(timeout: 30))
            } else {
                XCTAssertTrue(app.images["sample-shot-preview"].waitForExistence(timeout: 30))
            }
            save("welcome-leak-\(name)")
        }
    }

    @MainActor func testRapidTapsThenCameraIsInteractive() async throws {
        prepare()
        app.resetAuthorizationStatus(for: .camera)
        app.launch()
        let button = app.buttons["Open camera"]
        XCTAssertTrue(button.waitForExistence(timeout: 30))
        button.doubleTap()
        respondToPermission(allow: true)
        let preset = app.buttons["preset-name-button"]
        XCTAssertTrue(preset.waitForExistence(timeout: 10))
        XCTAssertFalse(button.exists)
        save("welcome-after-rapid-taps")
        preset.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
    }

    @MainActor func testReduceMotion() async throws {
        prepare()
        app.launchArguments.append("--welcome-reduce-motion")
        app.launch()
        let button = app.buttons["Open camera"]
        XCTAssertTrue(button.waitForExistence(timeout: 30))
        button.tap()
        respondToPermission(allow: true)
        XCTAssertTrue(app.buttons["preset-name-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(button.exists)
        save("welcome-reduce-motion-camera")
    }

    @MainActor func testDeniedPermissionStillReachesCamera() async throws {
        prepare()
        app.resetAuthorizationStatus(for: .camera)
        app.launchArguments = ["--welcome-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["Open camera"].waitForExistence(timeout: 10))
        app.buttons["Open camera"].tap()
        respondToPermission(allow: false)
        XCTAssertTrue(app.staticTexts["Camera access is off"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertFalse(app.buttons["Open camera"].exists)
        save("welcome-permission-denied")
    }

    @MainActor func testAccessibilityTextSize() async throws {
        prepare()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let button = app.buttons["Open camera"]
        XCTAssertTrue(button.waitForExistence(timeout: 30))
        XCTAssertTrue(button.isHittable)
        XCTAssertTrue(app.staticTexts["A camera worth carrying."].exists)
        save("welcome-accessibility-xxxl")
        app.scrollViews["welcome-card-copy"].swipeUp()
        save("welcome-accessibility-xxxl-scrolled")
    }
}
