import XCTest
import CoreMedia
@testable import CarbonKit

final class ContractsTests: XCTestCase {
    private func makeRecipe() -> RecipeVersion {
        RecipeVersion(
            recipeID: "natural-v1",
            presetDefinitionID: UUID(),
            engineVersion: "1.0",
            source: .rawBayer,
            parameters: RecipeVersion.Parameters(
                filmPreset: "Natural", filmStrength: 1, exposureEV: 0,
                temperatureK: 0, tintOffset: 0, contrastAmount: 1, saturationAmount: 1
            )
        )
    }

    func testShotCreationAndSerialization() throws {
        let recipe = makeRecipe()
        let metadata = Shot.CaptureMetadata(
            temperature: 4000, tint: 0, iso: 100,
            exposureDuration: CMTime(value: 1, timescale: 60),
            sceneEV: 8, flashState: .auto, lensPosition: 0.5, orientation: 1
        )
        let shot = Shot(
            captureID: "test-capture", timestamp: Date(), sources: [],
            currentRecipe: recipe, captureMetadata: metadata
        )
        let decoded = try JSONDecoder().decode(Shot.self, from: JSONEncoder().encode(shot))

        XCTAssertEqual(decoded.id, shot.id)
        XCTAssertEqual(decoded.captureID, "test-capture")
        XCTAssertEqual(decoded.currentRecipe.id, recipe.id)
        XCTAssertEqual(decoded.captureMetadata.iso, 100)
        XCTAssertEqual(decoded.captureMetadata.exposureDuration.value, 1)
        XCTAssertEqual(decoded.captureMetadata.exposureDuration.timescale, 60)
        XCTAssertEqual(decoded.captureMetadata.exposureDuration.flags, metadata.exposureDuration.flags)
        XCTAssertNil(decoded.currentRender)
    }

    func testRecipeVersionCreation() {
        let recipe = makeRecipe()
        XCTAssertEqual(recipe.recipeID, "natural-v1")
        XCTAssertEqual(recipe.parameters.exposureEV, 0)
        XCTAssertEqual(recipe.grainSeed, 0)
        XCTAssertNil(recipe.crop)
        XCTAssertTrue(recipe.isEditable)
    }

    func testPresetParametersRoundTrip() throws {
        let parameters = PresetParameters(
            exposureEV: 0.5, temperatureOffsetK: 100, tintOffset: -50,
            contrast: 1.2, saturation: 1.1, grainAmount: 0.1
        )
        let decoded = try JSONDecoder().decode(
            PresetParameters.self, from: JSONEncoder().encode(parameters)
        )
        XCTAssertEqual(decoded, parameters)
    }

    func testDevelopmentJobCreation() {
        let job = DevelopmentJob(shotID: UUID(), recipeVersionID: UUID())
        XCTAssertEqual(job.status, .queued)
        XCTAssertNil(job.completedAt)
        XCTAssertTrue(job.checkpoints.isEmpty)
    }

    func testCameraDefaultConfigPreservesMediaTime() throws {
        let time = CMTime(value: 1001, timescale: 30000, flags: [.valid, .hasBeenRounded], epoch: 2)
        let config = CameraDefaultConfig(
            activeVideoMinFrameDuration: time, defaultPresetID: UUID()
        )
        let decoded = try JSONDecoder().decode(
            CameraDefaultConfig.self, from: JSONEncoder().encode(config)
        )
        XCTAssertEqual(decoded.activeVideoMinFrameDuration.value, time.value)
        XCTAssertEqual(decoded.activeVideoMinFrameDuration.timescale, time.timescale)
        XCTAssertEqual(decoded.activeVideoMinFrameDuration.flags, time.flags)
        XCTAssertEqual(decoded.activeVideoMinFrameDuration.epoch, time.epoch)
    }

    func testCatalogHasOneDefaultAndUniquePresetIDs() throws {
        let presets = PresetLibrary.all
        XCTAssertFalse(presets.isEmpty)
        XCTAssertEqual(Set(presets.map(\.presetID)).count, presets.count)
        XCTAssertEqual(PresetLibrary.defaultPreset?.presetID, "carbon-natural")
        let preset = try XCTUnwrap(PresetLibrary.defaultPreset)
        let decoded = try JSONDecoder().decode(
            PresetDefinition.self, from: JSONEncoder().encode(preset)
        )
        XCTAssertEqual(decoded.baseParameters, preset.baseParameters)
        XCTAssertEqual(decoded.presetID, preset.presetID)
    }
}
