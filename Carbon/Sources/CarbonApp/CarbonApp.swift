import SwiftUI

/// B01 / O01 — application entry. Guest, offline, no account.
/// Coordinator manages navigation between Welcome, Camera, and Library.
@main
struct CarbonApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
        // Handle UI testing flags
        if ProcessInfo.processInfo.arguments.contains("--insert-sample-shot") {
            insertSampleShotForTesting()
        }
    }

    private func insertSampleShotForTesting() {
        let shotID = UUID()
        let captureID = "test-sample-shot"
        
        let recipe = RecipeVersion(
            recipeID: "sample-recipe",
            presetDefinitionID: UUID(),
            engineVersion: "1.0",
            source: .processedHEVC,
            parameters: RecipeVersion.Parameters(
                filmPreset: "Natural",
                filmStrength: 0.85,
                exposureEV: 0.0,
                temperatureK: 0.0,
                tintOffset: 0.0,
                contrastAmount: 1.0,
                saturationAmount: 1.0
            )
        )
        
        let shot = Shot(
            id: shotID,
            captureID: captureID,
            timestamp: Date(),
            sources: [],
            currentRecipe: recipe,
            captureMetadata: Shot.CaptureMetadata(
                temperature: 5500,
                tint: 0,
                iso: 100,
                exposureDuration: CoreMedia.CMTime(value: 1, timescale: 60),
                sceneEV: 8.0,
                flashState: .auto,
                lensPosition: 0.5,
                orientation: 1
            )
        )
        
        // Add to active roll
        RollStore.shared.addShot(shotID)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch coordinator.currentScreen {
                case .welcome:
                    WelcomeView(coordinator: coordinator)
                case .camera:
                    CameraView(coordinator: coordinator)
                case .rolls:
                    RollsView(coordinator: coordinator)
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