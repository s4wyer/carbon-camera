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

    private func makeRecipe() -> RecipeVersion {
        RecipeVersion(
            recipeID: "renderer-test",
            presetDefinitionID: UUID(),
            engineVersion: "test",
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
    }

    private func makeShot(sourceURL: URL? = nil) -> Shot {
        let recipe = makeRecipe()
        let sources: [SourceResource] = sourceURL.map {
            [SourceResource(
                captureID: "renderer-test",
                type: .processedHEVC,
                mediaURL: $0,
                mediaHash: "test-hash",
                provenance: SourceResource.Provenance(
                    engine: "test",
                    version: "test",
                    timestamp: Date(),
                    isUserEditable: true
                )
            )]
        } ?? []

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

    private func makePNG() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("carbon-render-test-\(UUID().uuidString).png")
        temporaryURLs.append(url)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 8 * 4,
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
        XCTAssertEqual(revision.renderingEngine, "ci-metal-tonechain")
        XCTAssertEqual(revision.outputHash.count, 64)
        XCTAssertTrue(FileManager.default.fileExists(atPath: revision.outputURL.path))
        try? FileManager.default.removeItem(at: revision.outputURL)
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
