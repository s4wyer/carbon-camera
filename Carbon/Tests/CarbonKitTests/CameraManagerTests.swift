import XCTest
import AVFoundation
import CoreMedia
@testable import CarbonKit

final class CameraManagerTests: XCTestCase {
    func testSceneEVFormulaAndInvalidExposureFallback() {
        let cases: [(Float, Double)] = [(100, 1.0 / 30.0), (800, 1.0 / 30.0),
                                         (100, 1.0 / 500.0), (800, 1.0 / 500.0),
                                         (100, 1.0 / 2000.0), (800, 1.0 / 2000.0)]
        for (iso, duration) in cases {
            let actual = CameraManager.sceneEV(aperture: 1.8, iso: iso, exposureSeconds: duration)
            let expected = log2(1.8 * 1.8 / ((iso / 100) * Float(duration)))
            XCTAssertEqual(actual, expected, accuracy: 0.0001)
        }
        XCTAssertEqual(CameraManager.sceneEV(aperture: 1.8, iso: 0, exposureSeconds: 1.0 / 30), 8)
        XCTAssertEqual(CameraManager.sceneEV(aperture: 1.8, iso: 100, exposureSeconds: 0), 8)
    }

    func testInvalidWhiteBalanceFallsBackToLapseDefaults() {
        let result = CameraManager.whiteBalanceMetadata(
            redGain: 0.9, greenGain: 1, blueGain: 1,
            maximumGain: 8, convertedTemperature: 5200, convertedTint: 3
        )
        XCTAssertEqual(result.temperature, 4000)
        XCTAssertEqual(result.tint, 0)
    }

    func testQualityPriorityPreservesBayerExceptionAndLapseEVRule() {
        XCTAssertEqual(CameraManager.qualityPrioritization(isBayerRAW: true, sceneEV: 9, maximumQuality: .quality), .speed)
        XCTAssertEqual(CameraManager.qualityPrioritization(isBayerRAW: false, sceneEV: 6.01, maximumQuality: .quality), .balanced)
        XCTAssertEqual(CameraManager.qualityPrioritization(isBayerRAW: false, sceneEV: 6, maximumQuality: .quality), .quality)
    }

    func testPhotoDimensionsUseOnlyFourByThreeAndPreserveOrder() {
        let result = CameraManager.photoDimensions4x3([
            CMVideoDimensions(width: 1920, height: 1080),
            CMVideoDimensions(width: 4032, height: 3024),
            CMVideoDimensions(width: 2048, height: 1536)
        ])
        XCTAssertEqual(result.map(\.width), [4032, 2048])
        XCTAssertEqual(result.last?.width, 2048)
    }

    func testZoomClampsToDeviceBoundsAndTwentyCap() {
        XCTAssertEqual(CameraManager.clampedZoomFactor(25, minimum: 1, maximum: 30), 20)
        XCTAssertEqual(CameraManager.clampedZoomFactor(0.5, minimum: 1, maximum: 30), 1)
    }
}
