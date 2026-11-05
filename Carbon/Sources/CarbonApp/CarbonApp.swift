import SwiftUI

/// B01 / O01 — application entry. Guest, offline, no account.
/// Coordinator manages navigation between Welcome, Camera, and Library.
@main
struct CarbonApp: App {
    @StateObject private var coordinator = AppCoordinator()
    @State private var sampleShotPrepared = !SampleShotFixture.isEnabled
    @State private var sampleShotError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if !sampleShotPrepared {
                    if let sampleShotError {
                        Text("Sample photo setup failed: \(sampleShotError)")
                    } else {
                        ProgressView("Preparing sample photo")
                            .task {
                                do {
                                    try await SampleShotFixture.seed()
                                    sampleShotPrepared = true
                                } catch {
                                    sampleShotError = error.localizedDescription
                                }
                            }
                    }
                } else {
                    WelcomeCameraTransition(coordinator: coordinator) {
                        switch coordinator.currentScreen {
                        case .welcome, .camera:
                            // Prepare the preview under the welcome cover, but
                            // activate capture only when the route is camera.
                            CameraView(coordinator: coordinator)
                        case .rolls:
                            RollsView(coordinator: coordinator)
                        case .library:
                            LibraryView(coordinator: coordinator)
                        case .lab:
                            LabView(coordinator: coordinator)
                        }
                    }
                }
            }
            .transition(.opacity)
        }
    }
}
