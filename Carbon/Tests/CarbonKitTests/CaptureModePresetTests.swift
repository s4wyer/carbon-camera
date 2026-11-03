// Tests for CaptureModePreset and Lapse §1/§2 session config (SET06c)

import XCTest
import AVFoundation
@testable import CarbonKit

final class CaptureModePresetTests: XCTestCase {
    func testCarbonDefaultPresetConfig() {
        let preset = CaptureModePreset.carbonDefault
        
        XCTAssertEqual(preset.id, "carbon-natural-capture")
        XCTAssertEqual(preset.displayName, "Natural (35mm)")
        XCTAssertEqual(preset.defaultFocalLengthEquivalentMM, 35.0) // D-002: 35mm
        XCTAssertEqual(preset.defaultFlashModeRaw, 2) // D-002: auto flash
        XCTAssertEqual(preset.softwareSharpeningAmount, 0.0) // D-002: sharpening disabled
        XCTAssertTrue(preset.enablesRAWCapture) // D-002: HEVC+RAW
        XCTAssertEqual(preset.qualityPrioritizationRaw, 3) // Lapse §1: .quality
        XCTAssertEqual(preset.preferredCodec, "hevc")
        XCTAssertTrue(preset.enablesLowLightBoost)
        XCTAssertTrue(preset.enablesSmoothAutoFocus)
        XCTAssertEqual(preset.defaultFocusPointOfInterest, CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(preset.defaultExposurePointOfInterest, CGPoint(x: 0.5, y: 0.5))
    }
    
    func testLapseBaselinePresetConfig() {
        let preset = CaptureModePreset.lapseBaseline
        
        XCTAssertEqual(preset.id, "lapse-baseline-capture")
        XCTAssertEqual(preset.defaultFocalLengthEquivalentMM, 28.0) // Wide native
        XCTAssertEqual(preset.defaultFlashModeRaw, 0) // Off
        XCTAssertEqual(preset.softwareSharpeningAmount, 0.5) // Standard sharpening
        XCTAssertFalse(preset.enablesRAWCapture) // Processed HEVC only
    }
    
    func testPresetSerializationRoundTrip() throws {
        let preset = CaptureModePreset.carbonDefault
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(CaptureModePreset.self, from: data)
        XCTAssertEqual(decoded, preset)
    }
}
