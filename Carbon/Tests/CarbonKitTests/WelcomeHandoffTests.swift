import XCTest
import AVFoundation
@testable import CarbonKit

final class WelcomeHandoffTests: XCTestCase {
    @MainActor func testDeniedPermissionNavigatesImmediatelyAndIgnoresRepeatRequest() async {
        let coordinator = AppCoordinator()
        coordinator.currentScreen = .welcome
        coordinator.cameraPermissionStatus = .denied
        coordinator.requestCameraAccess()
        XCTAssertEqual(coordinator.currentScreen, .camera)
        XCTAssertTrue(coordinator.hasCompletedWelcome)
        XCTAssertEqual(coordinator.cameraPermissionStatus, .denied)
        coordinator.navigateTo(.rolls)
        coordinator.requestCameraAccess()
        XCTAssertEqual(coordinator.currentScreen, .rolls)
    }

    @MainActor func testAuthorizedPermissionNavigatesWithoutRequestingAgain() async {
        let coordinator = AppCoordinator()
        coordinator.currentScreen = .welcome
        coordinator.cameraPermissionStatus = .authorized
        coordinator.requestCameraAccess()
        XCTAssertEqual(coordinator.currentScreen, .camera)
        XCTAssertEqual(coordinator.cameraPermissionStatus, .authorized)
    }

    @MainActor func testRestrictedPermissionDoesNotStrandWelcome() async {
        let coordinator = AppCoordinator()
        coordinator.currentScreen = .welcome
        coordinator.cameraPermissionStatus = .restricted
        coordinator.requestCameraAccess()
        XCTAssertEqual(coordinator.currentScreen, .camera)
        XCTAssertEqual(coordinator.cameraPermissionStatus, .restricted)
    }
}
