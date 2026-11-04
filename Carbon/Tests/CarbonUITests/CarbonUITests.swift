import XCTest

final class CarbonUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.resetAuthorizationStatus(for: .camera)
        
        // Enable sample shot mode for testing
        app.launchArguments = ["--ui-testing", "--insert-sample-shot"]
        app.launch()
    }
    
    func testCaptureAllScreens() throws {
        // Wait for welcome screen
        let openCameraButton = app.buttons["Open camera"]
        XCTAssertTrue(openCameraButton.waitForExistence(timeout: 15))
        
        // Screenshot 1: Welcome
        let welcome = app.screenshot()
        let welcomeAttachment = XCTAttachment(screenshot: welcome)
        welcomeAttachment.name = "01-welcome"
        welcomeAttachment.lifetime = .keepAlways
        add(welcomeAttachment)
        
        // Navigate to camera
        openCameraButton.tap()
        let continueButton = app.buttons["Allow camera & continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        let permissionAlert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if permissionAlert.waitForExistence(timeout: 5) {
            let allowButton = permissionAlert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
            } else {
                permissionAlert.buttons["OK"].tap()
            }
        }

        let presetName = app.buttons["preset-name-button"]
        XCTAssertTrue(presetName.waitForExistence(timeout: 15))
        
        // Screenshot 2: Camera viewfinder
        let camera = app.screenshot()
        let cameraAttachment = XCTAttachment(screenshot: camera)
        cameraAttachment.name = "02-camera"
        cameraAttachment.lifetime = .keepAlways
        add(cameraAttachment)
        
        // Tap preset name to open menu
        do {
            presetName.tap()
            sleep(1)
            
            // Screenshot 3: Preset browser
            let presetMenu = app.screenshot()
            let presetAttachment = XCTAttachment(screenshot: presetMenu)
            presetAttachment.name = "03-preset-menu"
            presetAttachment.lifetime = .keepAlways
            add(presetAttachment)
            
            // Close preset menu
            app.buttons["Done"].tap()
            sleep(1)
        }
        
        // Navigate to rolls screen
        let rollsButton = app.buttons.matching(identifier: "rolls-button").firstMatch
        XCTAssertTrue(rollsButton.waitForExistence(timeout: 5))
        do {
            rollsButton.tap()
            sleep(2)
            
            // Screenshot 4: Rolls screen
            let rolls = app.screenshot()
            let rollsAttachment = XCTAttachment(screenshot: rolls)
            rollsAttachment.name = "04-rolls"
            rollsAttachment.lifetime = .keepAlways
            add(rollsAttachment)
            
            // Go back to camera
            let cameraButton = app.buttons["Camera"]
            XCTAssertTrue(cameraButton.waitForExistence(timeout: 5))
            cameraButton.tap()
            sleep(1)
        }
        
        // Open settings
        let settingsButton = app.buttons.matching(identifier: "settings-button").firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        do {
            settingsButton.tap()
            sleep(1)
            
            // Screenshot 5: Settings
            let settings = app.screenshot()
            let settingsAttachment = XCTAttachment(screenshot: settings)
            settingsAttachment.name = "05-settings"
            settingsAttachment.lifetime = .keepAlways
            add(settingsAttachment)
        }
    }
}
