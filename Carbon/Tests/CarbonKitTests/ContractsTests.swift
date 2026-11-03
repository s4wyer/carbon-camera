import XCTest
@testable import CarbonKit

final class ContractsTests: XCTestCase {
    
    func testShotCreation() {
        let shot = Shot(
            id: "test-123",
            captureTimestamp: Date(),
            rawResourceID: "raw-456",
            hevcResourceID: "hevc-789",
            recipeVersionID: "recipe-natural-v1",
            captureMetadata: CaptureMetadata(
                focalLengthMM: 35.0,
                exposureTimeSec: 1.0/60.0,
                isoSpeed: 100,
                fNumber: 1.8,
                lensModel: "iPhone 15 Pro"
            )
        )
        
        XCTAssertEqual(shot.id, "test-123")
        XCTAssertEqual(shot.rawResourceID, "raw-456")
        XCTAssertEqual(shot.captureMetadata.focalLengthMM, 35.0)
    }
    
    func testRecipeVersionCreation() {
        let recipe = RecipeVersion(
            id: "recipe-natural-v1",
            presetID: "natural",
            versionNumber: 1,
            parameterSnapshot: PresetParameters(
                exposureEV: 0.0,
                temperatureShift: 0,
                tintShift: 0,
                contrast: 1.0,
                saturation: 1.0,
                vibrance: 0.5,
                highlights: 0.0,
                shadows: 0.0,
                blackPoint: 0.0,
                curve: nil,
                hslAdjustments: [],
                grainIntensity: 0.0,
                grainSize: 1.0,
                lutID: nil,
                halationRadius: 0.0,
                halationIntensity: 0.0,
                bloomRadius: 0.0,
                bloomIntensity: 0.0
            )
        )
        
        XCTAssertEqual(recipe.presetID, "natural")
        XCTAssertEqual(recipe.versionNumber, 1)
        XCTAssertEqual(recipe.parameterSnapshot.exposureEV, 0.0)
    }
    
    func testPresetParametersEquality() {
        let params1 = PresetParameters(
            exposureEV: 0.5,
            temperatureShift: 100,
            tintShift: -50,
            contrast: 1.2,
            saturation: 1.1,
            vibrance: 0.6,
            highlights: -0.2,
            shadows: 0.3,
            blackPoint: 0.05,
            curve: nil,
            hslAdjustments: [],
            grainIntensity: 0.1,
            grainSize: 1.5,
            lutID: "lut-kodak-portra",
            halationRadius: 20.0,
            halationIntensity: 0.3,
            bloomRadius: 50.0,
            bloomIntensity: 0.2
        )
        
        let params2 = PresetParameters(
            exposureEV: 0.5,
            temperatureShift: 100,
            tintShift: -50,
            contrast: 1.2,
            saturation: 1.1,
            vibrance: 0.6,
            highlights: -0.2,
            shadows: 0.3,
            blackPoint: 0.05,
            curve: nil,
            hslAdjustments: [],
            grainIntensity: 0.1,
            grainSize: 1.5,
            lutID: "lut-kodak-portra",
            halationRadius: 20.0,
            halationIntensity: 0.3,
            bloomRadius: 50.0,
            bloomIntensity: 0.2
        )
        
        XCTAssertEqual(params1, params2)
    }
    
    func testDevelopmentJobCreation() {
        let job = DevelopmentJob(
            id: "job-abc",
            shotID: "shot-123",
            recipeVersionID: "recipe-natural-v1",
            status: .pending,
            createdAt: Date()
        )
        
        XCTAssertEqual(job.status, .pending)
        XCTAssertNil(job.completedAt)
        XCTAssertNil(job.errorMessage)
    }
}
