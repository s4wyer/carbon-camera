import XCTest
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import CarbonKit

final class PhotoAspectRatioTests: XCTestCase {
    func testNativeFormatPreservesSource() {
        XCTAssertNil(PhotoAspectRatio.threeByFour.crop(for: CGSize(width: 3024, height: 4032)))
    }

    func testTwoByThreeCropIsCenteredInEitherOrientation() throws {
        for size in [CGSize(width: 3024, height: 4032), CGSize(width: 4032, height: 3024)] {
            let crop = try XCTUnwrap(PhotoAspectRatio.twoByThree.crop(for: size))
            XCTAssertEqual(crop.sourceNormalized.midX, 0.5, accuracy: 0.000001)
            XCTAssertEqual(crop.sourceNormalized.midY, 0.5, accuracy: 0.000001)
            let source = CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: size))
            let cropped = PhotoGeometry.applying(crop, to: source)
            XCTAssertEqual(cropped.extent.width / cropped.extent.height,
                           size.width > size.height ? 3.0 / 2.0 : 2.0 / 3.0,
                           accuracy: 0.000001)
            XCTAssertEqual(cropped.extent.origin, .zero)
        }
    }

    func testCropHandlesSourceWithNonzeroOrigin() throws {
        let crop = try XCTUnwrap(PhotoAspectRatio.twoByThree.crop(for: CGSize(width: 72, height: 96)))
        let source = CIImage(color: .white).cropped(to: CGRect(x: 20, y: 30, width: 72, height: 96))
        XCTAssertEqual(PhotoGeometry.applying(crop, to: source).extent,
                       CGRect(x: 0, y: 0, width: 64, height: 96))
    }

    func testSourceOrientationIsAppliedBeforePortraitCrop() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("crop-orientation-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        let context = CIContext(options: [.useSoftwareRenderer: true])
        let pixels = try XCTUnwrap(context.createCGImage(
            CIImage(color: .white), from: CGRect(x: 0, y: 0, width: 96, height: 72)
        ))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, pixels, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let source = try XCTUnwrap(PhotoGeometry.sourceImage(at: url))
        XCTAssertEqual(source.extent.size, CGSize(width: 72, height: 96))
        let crop = try XCTUnwrap(PhotoAspectRatio.twoByThree.crop(for: source.extent.size))
        XCTAssertEqual(PhotoGeometry.applying(crop, to: source).extent.size, CGSize(width: 64, height: 96))
    }

    func testCaptureRecipePreservesCropThroughSerialization() throws {
        let crop = try XCTUnwrap(PhotoAspectRatio.twoByThree.crop(for: CGSize(width: 3024, height: 4032)))
        let recipe = RecipeVersion(
            recipeID: "crop-test", presetDefinitionID: UUID(), engineVersion: "test",
            source: .processedHEVC,
            parameters: RecipeVersion.Parameters(
                filmPreset: "Test", filmStrength: 1, exposureEV: 0, temperatureK: 0,
                tintOffset: 0, contrastAmount: 1, saturationAmount: 1
            ),
            crop: crop
        )
        let decoded = try JSONDecoder().decode(RecipeVersion.self, from: JSONEncoder().encode(recipe))
        XCTAssertEqual(decoded.crop?.sourceNormalized, crop.sourceNormalized)

        // Older journal recipes omitted the optional crop entirely.
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(recipe)) as? [String: Any])
        legacy.removeValue(forKey: "crop")
        let oldRecipe = try JSONDecoder().decode(RecipeVersion.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(oldRecipe.crop)
    }
}
