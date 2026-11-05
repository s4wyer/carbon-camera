import XCTest
import AVFoundation
import CoreVideo
@testable import CarbonKit

final class PhotoSettingsTests: XCTestCase {
    private let qualityLimits: [AVCapturePhotoOutput.QualityPrioritization] = [.speed, .balanced, .quality]

    func testRAWAndProcessedOnlyFormatsFollowPhotoCaptureCompressionContract() throws {
        let rawFormats: [OSType?] = [nil, kCVPixelFormatType_14Bayer_RGGB]
        for rawFormat in rawFormats {
            let settings = CameraManager.makePhotoSettings(
                rawPixelFormatType: rawFormat,
                maximumQuality: .quality,
                flashMode: .off,
                supportedFlashModes: [.off]
            )
            let format = try XCTUnwrap(settings.format)

            // AVFoundation defers some validation until capturePhoto, which
            // simulator tests cannot exercise with a physical camera. Check
            // the documented photo-format contract on the real settings object:
            // https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/init(format:)
            // Previously quality was nested inside the video-only compression
            // dictionary; constructing settings and checking the codec missed it.
            XCTAssertEqual(Set(format.keys), Set([AVVideoCodecKey, AVVideoQualityKey]))
            XCTAssertEqual(format[AVVideoCodecKey] as? AVVideoCodecType, .hevc)
            XCTAssertEqual(format[AVVideoQualityKey] as? Double, 0.95)
        }
    }

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
