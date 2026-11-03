// Smoke test: verify all types compile

import Foundation
import SwiftUI
import AVFoundation
import CoreMedia
import CoreImage
import CryptoKit

// Test CaptureJournal
func testJournal() async throws {
    let journal = CaptureJournal.shared
    let recipe = RecipeVersion(
        recipeID: "test",
        presetDefinitionID: UUID(),
        engineVersion: "1.0",
        source: .processedHEVC,
        parameters: RecipeVersion.Parameters(
            filmPreset: "Test",
            filmStrength: 1,
            exposureEV: 0,
            temperatureK: 0,
            tintOffset: 0,
            contrastAmount: 1,
            saturationAmount: 1
        )
    )
    
    let entry = try await journal.persist(
        captureID: "test",
        rawBytes: nil,
        hevcBytes: Data([0x00]),
        recipe: recipe
    )
    
    let url = journal.fileURL(for: entry.hevcFilename!)
    print(url)
}

// Test Shot construction
func testShot() {
    let shot = Shot(
        captureID: "test",
        timestamp: Date(),
        sources: [],
        currentRecipe: RecipeVersion(
            recipeID: "test",
            presetDefinitionID: UUID(),
            engineVersion: "1.0",
            source: .processedHEVC,
            parameters: RecipeVersion.Parameters(
                filmPreset: "Natural",
                filmStrength: 1,
                exposureEV: 0,
                temperatureK: 0,
                tintOffset: 0,
                contrastAmount: 1,
                saturationAmount: 1
            )
        ),
        captureMetadata: Shot.CaptureMetadata(
            temperature: 5500,
            tint: 0,
            iso: 100,
            exposureDuration: .zero,
            sceneEV: 8,
            flashState: .auto,
            lensPosition: 0.5,
            orientation: 1
        )
    )
    print(shot.id)
}

// Test SourceResource
func testSource() {
    let source = SourceResource(
        captureID: "test",
        type: .processedHEVC,
        mediaURL: URL(fileURLWithPath: "/tmp/test.heic"),
        mediaHash: "abc123",
        provenance: SourceResource.Provenance(
            engine: "test",
            version: "1.0",
            timestamp: Date(),
            isUserEditable: true
        )
    )
    print(source.mediaURL)
}
