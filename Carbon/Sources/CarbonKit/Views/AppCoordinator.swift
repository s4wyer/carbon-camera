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
        case library
        case lab
    }
    
    init() {
        // Check if user has previously granted camera permission
        self.cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        // Skip welcome if permission already granted
        if cameraPermissionStatus == .authorized {
            self.hasCompletedWelcome = true
            self.currentScreen = .camera
        }
    }
    
    func requestCameraAccess() {
        Task {
            let status = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                self.cameraPermissionStatus = status ? .authorized : .denied
                if status {
                    self.hasCompletedWelcome = true
                    self.currentScreen = .camera
                }
            }
        }
    }
    
    func navigateTo(_ screen: Screen) {
        withAnimation {
            self.currentScreen = screen
        }
    }
}
