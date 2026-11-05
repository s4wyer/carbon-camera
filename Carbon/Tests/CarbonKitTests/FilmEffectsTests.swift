import XCTest
import CoreImage
@testable import CarbonKit

/// Regression tests for the shared render effects. Each test pins one bug found
/// by the preset measurement harness (analysis/PROGRESS.md).
final class FilmEffectsTests: XCTestCase {
    private let side: CGFloat = 96

    private func flat(_ v: CGFloat) -> CIImage {
        // Working space is linear; build the patch from sRGB-encoded values.
        CIImage(color: CIColor(red: v, green: v, blue: v, colorSpace: CIContextProvider.outputColorSpace)!)
            .cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
    }

    /// Mean and standard deviation of sRGB-encoded red over the image.
    private func stats(_ image: CIImage) -> (mean: Double, std: Double) {
        let w = Int(image.extent.width), h = Int(image.extent.height)
        var px = [Float](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBytes { buf in
            CIContextProvider.shared.render(image, toBitmap: buf.baseAddress!, rowBytes: w * 16,
                                            bounds: image.extent, format: .RGBAf,
                                            colorSpace: CIContextProvider.outputColorSpace)
        }
        let reds = stride(from: 0, to: px.count, by: 4).map { Double(px[$0]) }
        let mean = reds.reduce(0, +) / Double(reds.count)
        let variance = reds.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(reds.count)
        return (mean, variance.squareRoot())
    }

    func testGrainKeepsMeanBrightness() {
        // Bug: grain source-over'd a black layer with noise alpha (0.52 -> 0.29).
        let input = flat(0.5)
        let out = stats(FilmEffects.grain(input, amount: 0.4, size: 1))
        XCTAssertEqual(out.mean, 0.5, accuracy: 0.01)
        XCTAssertGreaterThan(out.std, 0.01, "grain should add texture")
        XCTAssertLessThan(out.std, 0.05, "amount 0.4 should be visible, not salt-and-pepper")
    }

    func testGrainIsDeterministic() {
        let input = flat(0.5)
        let a = FilmEffects.grain(input, amount: 0.4, size: 1, seed: 3)
        let b = FilmEffects.grain(input, amount: 0.4, size: 1, seed: 3)
        XCTAssertEqual(stats(a).std, stats(b).std, accuracy: 1e-9)
    }

    func testHalationLeavesMidtonesAlone() {
        // Bug: CIBloom + screen brightened flat midtones (Process Zero 0.52 -> 0.91).
        for v in [0.2, 0.5, 0.8] as [CGFloat] {
            XCTAssertEqual(stats(FilmEffects.halation(flat(v), amount: 1)).mean, Double(v), accuracy: 0.004,
                           "flat \(v) must not change")
        }
    }

    func testHalationGlowsAroundHighlights() {
        // Blur sigmas scale with the long edge (15/20 px at 4032), so use a
        // 1008 px frame where they are about 4-5 px.
        let frame = CGRect(x: 0, y: 0, width: 1008, height: 1008)
        let dark = CIImage(color: CIColor(red: 0.3, green: 0.3, blue: 0.3,
                                          colorSpace: CIContextProvider.outputColorSpace)!).cropped(to: frame)
        let spot = CIImage(color: .white).cropped(to: CGRect(x: 400, y: 400, width: 160, height: 160))
        let out = FilmEffects.halation(spot.composited(over: dark), amount: 1)
        let ring = stats(out.cropped(to: CGRect(x: 562, y: 460, width: 4, height: 40)))
        let far = stats(out.cropped(to: CGRect(x: 40, y: 40, width: 40, height: 40)))
        XCTAssertGreaterThan(ring.mean, 0.32, "glow just outside the highlight")
        XCTAssertEqual(far.mean, 0.3, accuracy: 0.004, "no glow far from the highlight")
    }

    func testHalideCubeUsesAppleLogInput() throws {
        // Process Zero is the Halide film base. With Apple Log input it tracks the
        // input closely; with sRGB input mid-gray 0.18 rendered near 0.05.
        let lut = try LUTResources.shared.load(lutID: "halide-process-zero-sdr")
        for (v, tolerance) in [(0.18, 0.05), (0.5, 0.07), (0.8, 0.07)] as [(CGFloat, Double)] {
            let out = stats(FilmEffects.applyHalideCube(flat(v), lut: lut, displayP3Output: false))
            XCTAssertEqual(out.mean, Double(v), accuracy: tolerance, "Process Zero at \(v)")
        }
    }
}
