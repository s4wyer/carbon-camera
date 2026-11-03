// Tests for CaptureJournal atomic writes and crash recovery (SET04)

import XCTest
@testable import CarbonKit

final class CaptureJournalTests: XCTestCase {
    func testPersistAndRecoverRAWandHEVC() async throws {
        let journal = CaptureJournal.shared
        
        // Dummy RAW + HEVC byte patterns
        let rawBytes = Data([0xAA, 0xBB, 0xCC, 0xDD] + Array(repeating: 0x00, count: 1024))
        let hevcBytes = Data([0x11, 0x22, 0x33, 0x44] + Array(repeating: 0xFF, count: 2048))
        
        let recipe = RecipeVersion(
            recipeID: "test-v1",
            presetDefinitionID: UUID(),
            engineVersion: "1.0",
            source: .rawBayer,
            parameters: RecipeVersion.Parameters(
                filmPreset: "TestFilm",
                filmStrength: 0.9,
                exposureEV: 0.5,
                temperatureK: 100,
                tintOffset: 0,
                contrastAmount: 1.1,
                saturationAmount: 1.0
            )
        )
        
        // Persist capture
        let entry = try await journal.persist(
            captureID: "test-capture-\(UUID().uuidString)",
            rawBytes: rawBytes,
            hevcBytes: hevcBytes,
            recipe: recipe
        )
        
        // Validate entry structure
        XCTAssertNotNil(entry.rawFilename)
        XCTAssertNotNil(entry.hevcFilename)
        XCTAssertNotNil(entry.rawSHA256)
        XCTAssertNotNil(entry.hevcSHA256)
        XCTAssertEqual(entry.rawSHA256?.count, 64) // SHA-256 hex string
        XCTAssertEqual(entry.hevcSHA256?.count, 64)
        XCTAssertEqual(entry.recipeVersionID, recipe.id)
        XCTAssertTrue(entry.isCommitted)
        
        // Recover all and verify entry exists
        let recovered = try await journal.recoverAll()
        XCTAssertTrue(recovered.contains(where: { $0.id == entry.id }))
        
        // Verify file URLs resolve and files exist
        let rawURL = await journal.fileURL(for: entry.rawFilename!)
        let hevcURL = await journal.fileURL(for: entry.hevcFilename!)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: hevcURL.path))
        
        // Verify byte integrity
        let recoveredRaw = try Data(contentsOf: rawURL)
        let recoveredHEVC = try Data(contentsOf: hevcURL)
        XCTAssertEqual(recoveredRaw, rawBytes)
        XCTAssertEqual(recoveredHEVC, hevcBytes)
    }
    
    func testJournalOnlyHEVCNilRAW() async throws {
        let journal = CaptureJournal.shared
        let hevcBytes = Data([0xFF] + Array(repeating: 0xAA, count: 512))
        
        let recipe = RecipeVersion(
            recipeID: "hevc-only",
            presetDefinitionID: UUID(),
            engineVersion: "1.0",
            source: .hevcProcessed,
            parameters: RecipeVersion.Parameters(
                filmPreset: "Natural",
                filmStrength: 1.0,
                exposureEV: 0,
                temperatureK: 0,
                tintOffset: 0,
                contrastAmount: 1.0,
                saturationAmount: 1.0
            )
        )
        
        let entry = try await journal.persist(
            captureID: "hevc-only-\(UUID().uuidString)",
            rawBytes: nil,
            hevcBytes: hevcBytes,
            recipe: recipe
        )
        
        XCTAssertNil(entry.rawFilename)
        XCTAssertNil(entry.rawSHA256)
        XCTAssertNotNil(entry.hevcFilename)
        XCTAssertNotNil(entry.hevcSHA256)
        
        let recovered = try await journal.recoverAll()
        XCTAssertTrue(recovered.contains(where: { $0.id == entry.id }))
    }
}
