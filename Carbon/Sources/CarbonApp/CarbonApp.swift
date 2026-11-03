import SwiftUI

/// B01 / O01 — application entry. Guest, offline, no account.
/// Coordinator manages navigation between Welcome, Camera, and Library.
@main
struct CarbonApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            Group {
                switch coordinator.currentScreen {
                case .welcome:
                    WelcomeView(coordinator: coordinator)
                case .camera:
                    CameraView(coordinator: coordinator)
                case .library:
                    LibraryView(coordinator: coordinator)
                case .lab:
                    LabView(coordinator: coordinator)
                }
            }
            .transition(.opacity)
        }
    }
}