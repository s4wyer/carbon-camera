import XCTest
import SwiftUI
import UIKit
@testable import CarbonKit

final class StockCardDesignTests: XCTestCase {
    func testEveryPresetHasAHandAuthoredPaletteAndStableCatalogNumber() {
        let ids = Set(StockCardDesign.palettes.keys)
        for preset in PresetLibrary.all {
            XCTAssertTrue(ids.contains(preset.presetID), "Missing Stock palette for \(preset.presetID)")
            XCTAssertGreaterThan(preset.catalogNumber, 0)
        }
    }

    func testAdjacentPresetsNeverShareALayoutWithinBrand() {
        XCTAssertTrue(StockCardDesign.assertAdjacentLayoutsDiffer(PresetLibrary.all))
        for brand in ["halide", "nofusion"] {
            let presets = PresetLibrary.all.filter { $0.presetID.hasPrefix(brand + "-") }
            XCTAssertTrue(StockCardDesign.assertAdjacentLayoutsDiffer(presets), brand)
        }
    }

    func testPaletteInkMeetsAAContrastAgainstGroundAndAutoInkAgainstBlocks() {
        for preset in PresetLibrary.all {
            let palette = StockCardDesign.palette(for: preset)
            XCTAssertGreaterThanOrEqual(StockCardDesign.contrastRatio(palette.ink, palette.ground), 4.5, preset.presetID)
            let blockInk = StockCardDesign.contrastInk(for: palette.block)
            XCTAssertGreaterThanOrEqual(StockCardDesign.contrastRatio(blockInk, palette.block), 4.5, preset.presetID)
        }
    }

    func testLegacyPresetPayloadDecodesWithoutCatalogNumber() throws {
        let preset = try XCTUnwrap(PresetLibrary.all.first)
        let encoded = try JSONEncoder().encode(preset)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payload.removeValue(forKey: "catalogNumber")
        let legacyData = try JSONSerialization.data(withJSONObject: payload)
        let decoded = try JSONDecoder().decode(PresetDefinition.self, from: legacyData)
        XCTAssertEqual(decoded.catalogNumber, max(1, decoded.displayOrder % 100 + 1))
    }

    func testBrandThumbnailsHaveDistinctGroundColors() {
        for prefix in ["halide-", "nofusion-"] {
            let presets = PresetLibrary.all.filter { $0.presetID.hasPrefix(prefix) }
            let signatures = presets.map { preset in
                let color = UIColor(StockCardDesign.palette(for: preset).ground)
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                return "\(Int((red * 255).rounded()))-\(Int((green * 255).rounded()))-\(Int((blue * 255).rounded()))"
            }
            XCTAssertEqual(Set(signatures).count, signatures.count, prefix)
        }
    }
}
