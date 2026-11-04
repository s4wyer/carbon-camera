import XCTest
@testable import CarbonKit

final class PresetPaletteTests: XCTestCase {
    func testEveryPresetProducesACompleteChartAndDistinctFamilyArtInputs() {
        let palettes = PresetLibrary.all.map(PresetPalette.make)
        XCTAssertEqual(palettes.count, PresetLibrary.all.count)
        XCTAssertTrue(palettes.allSatisfy { $0.testStrip.count == 14 })
        XCTAssertTrue(palettes.allSatisfy { $0.testStrip.allSatisfy { sample in
            [sample.r, sample.g, sample.b].allSatisfy { (0.0...1.0).contains($0) }
        }})
    }

    func testMonoPresetsUseNeutralChartColors() {
        let monoIDs = ["halide-chroma-noir", "halide-quicksilver", "halide-onyx", "nofusion-bw2", "nofusion-bw3"]
        for id in monoIDs {
            guard let preset = PresetLibrary.all.first(where: { $0.presetID == id }) else {
                XCTFail("Missing preset \(id)")
                continue
            }
            let palette = PresetPalette.make(for: preset)
            XCTAssertTrue(palette.isMonochrome, id)
            XCTAssertTrue(palette.testStrip.allSatisfy { sample in
                max(sample.r, max(sample.g, sample.b)) - min(sample.r, min(sample.g, sample.b)) < 0.001
            }, id)
        }
    }

    func testChangedPresetsDoNotCollapseToOnePalette() {
        let palettes = PresetLibrary.all.map(PresetPalette.make)
        let uniqueMidtones = Set(palettes.map { "\($0.midtone.r.rounded(toPlaces: 3))-\($0.midtone.g.rounded(toPlaces: 3))-\($0.midtone.b.rounded(toPlaces: 3))" })
        XCTAssertGreaterThan(uniqueMidtones.count, 8)
    }
}

private extension Float {
    func rounded(toPlaces places: Int) -> Float {
        let scale = powf(10, Float(places))
        return (self * scale).rounded() / scale
    }
}
