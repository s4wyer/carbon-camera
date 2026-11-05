import XCTest
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import CarbonKit

final class PhotoRendererTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDown() {
        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()
        super.tearDown()
    }

    private func makeRecipe(crop: RecipeVersion.Crop? = nil,
                            source: SourceResource.SourceType = .processedHEVC) -> RecipeVersion {
        RecipeVersion(
            recipeID: "renderer-test",
            presetDefinitionID: UUID(),
            engineVersion: "test",
            source: source,
            parameters: RecipeVersion.Parameters(
                filmPreset: "Test",
                filmStrength: 1,
                exposureEV: 0,
                temperatureK: 0,
                tintOffset: 0,
                contrastAmount: 1,
                saturationAmount: 1
            ),
            crop: crop
        )
    }

    private func makeShot(sourceURL: URL? = nil, crop: RecipeVersion.Crop? = nil,
                          sourceType: SourceResource.SourceType = .processedHEVC,
                          extraSources: [SourceResource] = []) -> Shot {
        let recipe = makeRecipe(crop: crop, source: sourceType)
        let sources: [SourceResource] = extraSources + (sourceURL.map {
            [SourceResource(
                captureID: "renderer-test",
                type: sourceType,
                mediaURL: $0,
                mediaHash: "test-hash",
                provenance: SourceResource.Provenance(
                    engine: "test",
                    version: "test",
                    timestamp: Date(),
                    isUserEditable: true
                )
            )]
        } ?? [])

        return Shot(
            captureID: "renderer-test",
            timestamp: Date(),
            sources: sources,
            currentRecipe: recipe,
            captureMetadata: Shot.CaptureMetadata(
                temperature: 5500,
                tint: 0,
                iso: 100,
                exposureDuration: .zero,
                sceneEV: 8,
                flashState: .off,
                lensPosition: 0.5,
                orientation: 1
            )
        )
    }

    private func makePNG(width: Int = 8, height: Int = 8) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("carbon-render-test-\(UUID().uuidString).png")
        temporaryURLs.append(url)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw TestError.fixtureCreationFailed
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw TestError.fixtureCreationFailed
        }
        return url
    }

    private var preset: PresetDefinition {
        PresetLibrary.defaultPreset ?? PresetLibrary.all[0]
    }

    private enum TestError: Error {
        case fixtureCreationFailed
    }

    private func constantLUTRenderer() throws -> PhotoRenderer {
        guard let renderer = PhotoRenderer(loadLUT: { _ in
            LUTData(dimension: 2, rgba: Array(repeating: [Float(0.2), 0.35, 0.1, 1], count: 8).flatMap { $0 })
        }) else { throw XCTSkip("Metal is unavailable") }
        return renderer
    }

    private func sample(_ image: CIImage, x: CGFloat = 32, y: CGFloat = 32) -> [Float] {
        var rgba = [Float](repeating: 0, count: 4)
        rgba.withUnsafeMutableBytes { bytes in
            CIContextProvider.shared.render(
                image, toBitmap: bytes.baseAddress!, rowBytes: 16,
                bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBAf,
                colorSpace: CIContextProvider.workingColorSpace
            )
        }
        return rgba
    }

    func testRendererRejectsCancellationBeforeSchedulingWork() async throws {
        guard let renderer = PhotoRenderer() else {
            throw XCTSkip("Metal is unavailable on this test device")
        }
        let token = RenderCancellationToken()
        token.cancel()

        do {
            _ = try await renderer.render(
                shot: makeShot(),
                preset: preset,
                parameters: preset.baseParameters,
                cancellation: token
            )
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testRendererReportsMissingSource() async throws {
        guard let renderer = PhotoRenderer() else {
            throw XCTSkip("Metal is unavailable on this test device")
        }

        do {
            _ = try await renderer.render(
                shot: makeShot(),
                preset: preset,
                parameters: preset.baseParameters,
                cancellation: RenderCancellationToken()
            )
            XCTFail("Expected sourceNotFound")
        } catch RenderError.sourceNotFound {
            // Expected.
        }
    }

    func testRendererReportsMissingLUT() async throws {
        guard let renderer = PhotoRenderer() else {
            throw XCTSkip("Metal is unavailable on this test device")
        }
        let image = CIImage(color: CIColor(red: 0.2, green: 0.3, blue: 0.4))
        do {
            _ = try await renderer.renderPreview(
                image: image,
                parameters: PresetParameters(lutID: "missing-lut")
            )
            XCTFail("Expected missing LUT error")
        } catch LUTError.resourceNotFound("missing-lut") {
            // Expected.
        }
    }

    func testRendererProducesHashedOutputOffTheMainActor() async throws {
        guard let renderer = PhotoRenderer() else {
            throw XCTSkip("Metal is unavailable on this test device")
        }
        let sourceURL = try makePNG()
        let revision = try await renderer.render(
            shot: makeShot(sourceURL: sourceURL),
            preset: preset,
            parameters: PresetParameters(),
            cancellation: RenderCancellationToken()
        )

        XCTAssertEqual(revision.outputFormat, .heif)
        XCTAssertEqual(revision.renderingEngine, "ci-metal-tonechain-pure-raw-v1")
        XCTAssertEqual(revision.outputHash.count, 64)
        XCTAssertTrue(FileManager.default.fileExists(atPath: revision.outputURL.path))
        try? FileManager.default.removeItem(at: revision.outputURL)
    }

    func testRendererEncodesTwoByThreeCrop() async throws {
        guard let renderer = PhotoRenderer() else {
            throw XCTSkip("Metal is unavailable on this test device")
        }
        let sourceURL = try makePNG(width: 72, height: 96)
        let crop = try XCTUnwrap(PhotoAspectRatio.twoByThree.crop(for: CGSize(width: 72, height: 96)))
        let revision = try await renderer.render(
            shot: makeShot(sourceURL: sourceURL, crop: crop),
            preset: preset,
            parameters: PresetParameters(),
            cancellation: RenderCancellationToken()
        )
        temporaryURLs.append(revision.outputURL)
        let output = try XCTUnwrap(CIImage(contentsOf: revision.outputURL))
        XCTAssertEqual(output.extent.width, 64)
        XCTAssertEqual(output.extent.height, 96)
    }

    func testRAWRecipePrefersDNGOverProcessedSafetyImageRegardlessOfArrayOrder() throws {
        guard let renderer = PhotoRenderer() else { throw XCTSkip("Metal is unavailable") }
        let rawURL = FileManager.default.temporaryDirectory.appendingPathComponent("carbon-source-\(UUID()).dng")
        temporaryURLs.append(rawURL)
        try SyntheticRAWFixture.data().write(to: rawURL)
        let safetyURL = try makePNG(width: 8, height: 8)
        let safetySource = makeShot(sourceURL: safetyURL).sources[0]
        let shot = makeShot(sourceURL: rawURL, sourceType: .rawBayer, extraSources: [safetySource])
        // Source selection is independent of platform RAW decoder availability.
        var decodedURLs: [URL] = []
        let expected = CIImage(color: CIColor(red: 0.2, green: 0.2, blue: 0.2))
            .cropped(to: CGRect(x: 0, y: 0, width: SyntheticRAWFixture.width,
                               height: SyntheticRAWFixture.height))
        let source = try XCTUnwrap(renderer.loadSourceImage(shot: shot) { url in
            decodedURLs.append(url)
            return url == rawURL ? expected : nil
        })
        XCTAssertEqual(decodedURLs, [rawURL])
        XCTAssertEqual(source.extent.width, CGFloat(SyntheticRAWFixture.width))
        XCTAssertEqual(source.extent.height, CGFloat(SyntheticRAWFixture.height))

        decodedURLs.removeAll()
        XCTAssertNil(renderer.loadSourceImage(shot: shot) { url in
            decodedURLs.append(url)
            return nil
        })
        XCTAssertEqual(decodedURLs, [rawURL], "A failed RAW decode must not try the safety image")

        // An existing but undecodable RAW must fail rather than silently using
        // either its embedded preview or the processed safety image.
        try Data("broken DNG".utf8).write(to: rawURL)
        XCTAssertNil(renderer.loadSourceImage(shot: shot))
    }

    func testProcessedRecipeSkipsAuxiliaryImagesAndStillUsesItsDeclaredSource() throws {
        guard let renderer = PhotoRenderer() else { throw XCTSkip("Metal is unavailable") }
        let auxiliaryURL = try makePNG(width: 16, height: 16)
        let auxiliary = makeShot(sourceURL: auxiliaryURL, sourceType: .depthAuxiliary).sources[0]
        let sourceURL = try makePNG(width: 72, height: 96)
        let shot = makeShot(sourceURL: sourceURL, extraSources: [auxiliary])
        let image = try XCTUnwrap(renderer.loadSourceImage(shot: shot))
        XCTAssertEqual(image.extent.size, CGSize(width: 72, height: 96))
    }

    func testCreativeExposureFollowsLUTInLinearLight() async throws {
        let renderer = try constantLUTRenderer()
        let image = CIImage(color: CIColor(red: 0.12, green: 0.18, blue: 0.24))
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let base = try await renderer.renderPreview(
            image: image, parameters: PresetParameters(lutID: "constant-test")
        )
        let exposed = try await renderer.renderPreview(
            image: image, parameters: PresetParameters(lutID: "constant-test", exposureEV: 1)
        )
        let before = sample(base)
        let after = sample(exposed)
        for channel in 0..<3 {
            XCTAssertGreaterThan(before[channel], 0.001)
            XCTAssertEqual(after[channel], before[channel] * 2, accuracy: 0.003)
        }
    }

    func testCreativeWhiteBalanceFollowsLUT() async throws {
        let renderer = try constantLUTRenderer()
        let image = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let base = try await renderer.renderPreview(
            image: image, parameters: PresetParameters(lutID: "constant-test")
        )
        let warmed = try await renderer.renderPreview(
            image: image, parameters: PresetParameters(lutID: "constant-test", temperatureOffsetK: 1500)
        )
        let before = sample(base)
        let after = sample(warmed)
        XCTAssertGreaterThan((0..<3).reduce(Float(0)) { $0 + abs(before[$1] - after[$1]) }, 0.001)
    }

    func testVignettePrecedesLUT() async throws {
        let renderer = try constantLUTRenderer()
        let image = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256))
        let result = try await renderer.renderPreview(
            image: image,
            parameters: PresetParameters(lutID: "constant-test", vignetteIntensity: 1, vignetteRadius: 40)
        )
        // A constant cube erases any upstream vignette. A vignette mistakenly
        // applied after it would darken the corners and fail this property.
        let corner = sample(result, x: 4, y: 4)
        let center = sample(result, x: 128, y: 128)
        for channel in 0..<3 {
            XCTAssertGreaterThan(center[channel], 0.001)
            XCTAssertEqual(corner[channel], center[channel], accuracy: 0.001)
        }
    }

    func testRendererPreviewUsesBackgroundRenderQueue() async throws {
        guard let renderer = PhotoRenderer() else {
            throw XCTSkip("Metal is unavailable on this test device")
        }
        let image = CIImage(color: CIColor(red: 0.2, green: 0.3, blue: 0.4))
        let preview = try await renderer.renderPreview(
            image: image,
            parameters: PresetParameters()
        )

        XCTAssertFalse(preview.extent.isEmpty)
    }

    func testRendererPreviewExercisesEveryToneChainStage() async throws {
        guard let renderer = PhotoRenderer() else {
            throw XCTSkip("Metal is unavailable on this test device")
        }
        let image = CIImage(color: CIColor(red: 0.2, green: 0.3, blue: 0.4))
        let parameters = PresetParameters(
            exposureEV: 0.5,
            temperatureOffsetK: 250,
            tintOffset: 5,
            contrast: 1.2,
            saturation: 1.15,
            vibrance: 0.2,
            curveBlack: 0.02,
            curveShadow: 0.03,
            curveMidtone: 0.02,
            curveHighlight: -0.02,
            curveWhite: -0.01,
            hsl: [HSLAdjustment(hue: 0.05, saturation: 1.1)]
                + Array(repeating: HSLAdjustment(), count: 7),
            grainAmount: 0.35,
            grainSize: 0.8,
            halationRadius: 2,
            halationIntensity: 0.3,
            bloomAmount: 0.25,
            bloomRadius: 4,
            vignetteIntensity: 0.25,
            vignetteRadius: 1.2
        )

        let preview = try await renderer.renderPreview(image: image, parameters: parameters)
        XCTAssertFalse(preview.extent.isEmpty)
    }
}
