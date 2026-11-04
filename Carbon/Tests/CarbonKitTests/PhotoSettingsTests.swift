import XCTest
import AVFoundation
import CoreVideo
@testable import CarbonKit

final class PhotoSettingsTests: XCTestCase {
    private let qualityLimits: [AVCapturePhotoOutput.QualityPrioritization] = [.speed, .balanced, .quality]

    func testBayerRAWPairUsesSpeedAtEveryOutputQualityLimit() {
        for maximumQuality in qualityLimits {
            // Construct the actual AVFoundation object: assigning .quality here
            // used to raise an Objective-C exception before capture even began.
            let settings = CameraManager.makePhotoSettings(
                rawPixelFormatType: kCVPixelFormatType_14Bayer_RGGB,
                maximumQuality: maximumQuality,
                flashMode: .off,
                supportedFlashModes: [.off]
            )

            XCTAssertEqual(settings.rawPhotoPixelFormatType, kCVPixelFormatType_14Bayer_RGGB)
            XCTAssertEqual(settings.photoQualityPrioritization, .speed)
            XCTAssertEqual(settings.format?[AVVideoCodecKey] as? AVVideoCodecType, .hevc)
        }
    }

    func testProcessedOnlyCaptureUsesOutputQualityLimit() {
        for maximumQuality in qualityLimits {
            let settings = CameraManager.makePhotoSettings(
                rawPixelFormatType: nil,
                maximumQuality: maximumQuality,
                flashMode: .auto,
                supportedFlashModes: [.off, .auto, .on]
            )

            XCTAssertEqual(settings.rawPhotoPixelFormatType, 0)
            XCTAssertEqual(settings.photoQualityPrioritization, maximumQuality)
            XCTAssertEqual(settings.format?[AVVideoCodecKey] as? AVVideoCodecType, .hevc)
            XCTAssertEqual(settings.flashMode, .auto)
        }
    }

    func testUnsupportedFlashFallsBackToOff() {
        let settings = CameraManager.makePhotoSettings(
            rawPixelFormatType: nil,
            maximumQuality: .quality,
            flashMode: .auto,
            supportedFlashModes: [.off]
        )

        XCTAssertEqual(settings.flashMode, .off)
    }

    func testRepeatedRequestsHaveUniqueSettings() {
        let settings = (0..<3).map { _ in
            CameraManager.makePhotoSettings(
                rawPixelFormatType: kCVPixelFormatType_14Bayer_RGGB,
                maximumQuality: .quality,
                flashMode: .off,
                supportedFlashModes: [.off]
            )
        }

        // Safety capture submits three requests; AVFoundation forbids reusing
        // a settings ID, so every call must construct a fresh settings object.
        XCTAssertEqual(Set(settings.map(\.uniqueID)).count, 3)
    }
}
