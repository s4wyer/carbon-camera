import SwiftUI
import AVFoundation

/// Root coordinator managing navigation between Welcome, Camera, and Library
@MainActor
final class AppCoordinator: ObservableObject {
    @Published var currentScreen: Screen = .welcome
    @Published var hasCompletedWelcome: Bool = false
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    
    enum Screen {
        case welcome
        case camera
        case rolls
        case library
        case lab
    }
    
    init() {
        // Check if user has previously granted camera permission
        self.cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--welcome-testing") { return }
        #endif
        
        // Skip welcome if permission already granted
        if cameraPermissionStatus == .authorized {
            self.hasCompletedWelcome = true
            self.currentScreen = .camera
        }
    }
    
    func requestCameraAccess() {
        // Navigate immediately, independently of the animation and system dialog.
        guard currentScreen == .welcome else { return }
        hasCompletedWelcome = true
        currentScreen = .camera
        guard cameraPermissionStatus == .notDetermined else { return }
        Task {
            let status = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionStatus = status ? .authorized : .denied
        }
    }
    
    func navigateTo(_ screen: Screen) {
        withAnimation {
            self.currentScreen = screen
        }
    }
}
