import XCTest
import CoreImage
@testable import CarbonKit

final class RAWDevelopmentTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDown() {
        for url in temporaryURLs { try? FileManager.default.removeItem(at: url) }
        temporaryURLs.removeAll()
        super.tearDown()
    }

    private func fixture(orientation: UInt16 = 1, neutral: [Double] = [1, 1, 1]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("carbon-raw-\(UUID()).dng")
        temporaryURLs.append(url)
        try SyntheticRAWFixture.data(orientation: orientation, neutral: neutral).write(to: url)
        return url
    }

    private func pixel(_ image: CIImage, x: Int, y: Int, colorSpace: CGColorSpace) -> [Float] {
        var components = [Float](repeating: 0, count: 4)
        components.withUnsafeMutableBytes { bytes in
            CIContextProvider.shared.render(
                image, toBitmap: bytes.baseAddress!, rowBytes: 16,
                bounds: CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1),
                format: .RGBAf, colorSpace: colorSpace
            )
        }
        return components
    }

    func testPureRAWControlsPreserveCameraCalibration() throws {
        let raw = try XCTUnwrap(CIRAWFilter(imageURL: fixture(neutral: [1, 0.85, 0.6])))
        print("RAW diagnostic before configuration: size=\(raw.nativeSize) decoders=\(raw.supportedDecoderVersions) output=\(String(describing: raw.outputImage))")
        let temperature = raw.neutralTemperature
        let tint = raw.neutralTint
        let orientation = raw.orientation
        raw.baselineExposure = 0.75
        raw.exposure = 2
        raw.boostAmount = 1
        raw.shadowBias = 0.1
        RAWDevelopment.configure(raw)

        XCTAssertEqual(raw.baselineExposure, 0.75)
        XCTAssertEqual(raw.neutralTemperature, temperature)
        XCTAssertEqual(raw.neutralTint, tint)
        XCTAssertEqual(raw.orientation, orientation)
        XCTAssertEqual(raw.exposure, 0)
        XCTAssertEqual(raw.boostAmount, 0)
        XCTAssertEqual(raw.boostShadowAmount, 0)
        XCTAssertEqual(raw.shadowBias, 0)
        XCTAssertEqual(raw.extendedDynamicRangeAmount, 0)
        XCTAssertFalse(raw.isGamutMappingEnabled)
        XCTAssertFalse(raw.isDraftModeEnabled)
        XCTAssertEqual(raw.scaleFactor, 1)
        XCTAssertNil(raw.linearSpaceFilter)
        if raw.isSharpnessSupported { XCTAssertEqual(raw.sharpnessAmount, 0) }
        if raw.isContrastSupported { XCTAssertEqual(raw.contrastAmount, 0) }
        if raw.isDetailSupported { XCTAssertEqual(raw.detailAmount, 0) }
        if raw.isColorNoiseReductionSupported { XCTAssertEqual(raw.colorNoiseReductionAmount, 0) }
        if raw.isLuminanceNoiseReductionSupported { XCTAssertEqual(raw.luminanceNoiseReductionAmount, 0) }
        if raw.isMoireReductionSupported { XCTAssertEqual(raw.moireReductionAmount, 0) }
        if raw.isLocalToneMapSupported { XCTAssertEqual(raw.localToneMapAmount, 0) }
        if raw.isLensCorrectionSupported { XCTAssertFalse(raw.isLensCorrectionEnabled) }
        for option in [CIRAWFilterOption.enableSharpening, .enableChromaticNoiseTracking]
            where raw.inputKeys.contains(option.rawValue) {
            XCTAssertEqual((raw.value(forKey: option.rawValue) as? NSNumber)?.boolValue, false)
        }
    }

    func testCameraWhiteBalanceMakesNeutralRampNeutralAndLinear() throws {
        let image = try XCTUnwrap(PhotoGeometry.sourceImage(at: fixture(neutral: [1, 0.85, 0.6])))
        let samples = SyntheticRAWFixture.levels.indices.map { index in
            pixel(image, x: index * 64 + 32, y: 64, colorSpace: CIContextProvider.workingColorSpace)
        }
        let middle = samples[2][1]
        XCTAssertGreaterThan(middle, 0.01)
        for (index, sample) in samples.enumerated() {
            XCTAssertEqual(sample[0], sample[1], accuracy: 0.015, "Non-neutral red at patch \(index)")
            XCTAssertEqual(sample[2], sample[1], accuracy: 0.015, "Non-neutral blue at patch \(index)")
            // Ratios test linear response without assuming an undocumented
            // absolute gray-card target or overriding camera baseline exposure.
            XCTAssertEqual(sample[1] / middle,
                           Float(SyntheticRAWFixture.levels[index] / 0.18), accuracy: 0.05)
        }
    }

    func testSRGBEncodingHappensAtOutputAndPreservesFractionalPrecision() {
        let input: [Float] = [0.18, 0.18, 0.18, 1]
        let image = input.withUnsafeBytes {
            CIImage(bitmapData: Data($0), bytesPerRow: 16, size: CGSize(width: 1, height: 1),
                    format: .RGBAf, colorSpace: CIContextProvider.workingColorSpace)
        }
        let linear = pixel(image, x: 0, y: 0, colorSpace: CIContextProvider.workingColorSpace)
        let encoded = pixel(image, x: 0, y: 0, colorSpace: CIContextProvider.outputColorSpace)
        XCTAssertEqual(linear[0], 0.18, accuracy: 0.0005)
        XCTAssertEqual(encoded[0], 0.46136, accuracy: 0.001)
    }

    func testRAWOrientationIsAppliedExactlyOnce() throws {
        let image = try XCTUnwrap(PhotoGeometry.sourceImage(at: fixture(orientation: 6)))
        XCTAssertEqual(image.extent.size, CGSize(width: CGFloat(SyntheticRAWFixture.height),
                                                height: CGFloat(SyntheticRAWFixture.width)))
    }

    func testReducedRAWPreviewKeepsTheSameNeutralDevelopment() throws {
        let url = try fixture(neutral: [1, 0.85, 0.6])
        let full = try XCTUnwrap(PhotoGeometry.sourceImage(at: url))
        let preview = try XCTUnwrap(PhotoGeometry.sourceImage(at: url, maxPixelSize: 160))
        XCTAssertEqual(preview.extent.size, CGSize(width: 160, height: 64))
        let fullGray = pixel(full, x: 160, y: 64, colorSpace: CIContextProvider.workingColorSpace)
        let previewGray = pixel(preview, x: 80, y: 32, colorSpace: CIContextProvider.workingColorSpace)
        for channel in 0..<3 {
            XCTAssertEqual(previewGray[channel], fullGray[channel], accuracy: 0.01)
        }
    }

    func testBrokenDNGDoesNotFallBackToAnUncontrolledDecode() throws {
        let url = try fixture()
        try Data("not a RAW image".utf8).write(to: url)
        XCTAssertNil(PhotoGeometry.sourceImage(at: url))
    }

    func testEmptyAndTruncatedDNGAreRejectedForFullSizeAndPreview() throws {
        let url = try fixture()
        let validData = try Data(contentsOf: url)
        for data in [Data(), Data(validData.prefix(8)), Data(validData.prefix(512))] {
            try data.write(to: url)
            XCTAssertNil(PhotoGeometry.sourceImage(at: url))
            XCTAssertNil(PhotoGeometry.sourceImage(at: url, maxPixelSize: 160))
        }
    }
}
