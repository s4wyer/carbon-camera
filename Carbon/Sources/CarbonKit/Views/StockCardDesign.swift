import SwiftUI
import UIKit

/// Hand-authored print palette and deterministic layout assignment for the three
/// bespoke brands. Keep additions here: one row per preset ID.
struct StockCardDesign {
    struct Palette {
        let ground: Color
        let block: Color
        let ink: Color
        let accent: Color
        let metallic: Bool
    }

    enum Layout: Int, CaseIterable {
        case grid, header, split, bars, bleed, offset
    }

    static let palettes: [String: Palette] = [
        "carbon-natural": .init(ground: hex("EEEAE0"), block: hex("D9D4C8"), ink: hex("191A18"), accent: hex("F0401F"), metallic: false),
        "halide-process-zero": .init(ground: hex("F0C928"), block: hex("1639A5"), ink: hex("171914"), accent: hex("F0401F"), metallic: false),
        "halide-nova": .init(ground: hex("2944C7"), block: hex("FF7A36"), ink: hex("FFFFFF"), accent: hex("F4D64A"), metallic: false),
        "halide-zephyr": .init(ground: hex("16AFC0"), block: hex("123F56"), ink: hex("11191B"), accent: hex("E8CB59"), metallic: false),
        "halide-rembrandt": .init(ground: hex("A95431"), block: hex("3A211C"), ink: hex("FFF0D5"), accent: hex("D5AF70"), metallic: false),
        "halide-scarlet": .init(ground: hex("D83B35"), block: hex("F0D4B8"), ink: hex("FFFFFF"), accent: hex("521E2D"), metallic: false),
        "halide-chroma-noir": .init(ground: hex("303337"), block: hex("AEB5B8"), ink: hex("FFFFFF"), accent: hex("F0401F"), metallic: true),
        "halide-valencia": .init(ground: hex("E47C33"), block: hex("276A55"), ink: hex("211A17"), accent: hex("F2D0A0"), metallic: false),
        "halide-quicksilver": .init(ground: hex("707679"), block: hex("D6D8D6"), ink: hex("FFFFFF"), accent: hex("F0401F"), metallic: true),
        "halide-dawn": .init(ground: hex("E88969"), block: hex("643A70"), ink: hex("241827"), accent: hex("F5D9A2"), metallic: false),
        "halide-elysia": .init(ground: hex("D8D36E"), block: hex("39735B"), ink: hex("20251B"), accent: hex("F0E5C4"), metallic: false),
        "halide-onyx": .init(ground: hex("17191B"), block: hex("777D80"), ink: hex("F3F2EC"), accent: hex("F0401F"), metallic: true),
        "lapse-journal": .init(ground: hex("172A43"), block: hex("F4C842"), ink: hex("F8F1E3"), accent: hex("F0401F"), metallic: false),
        "lapse-photo-default": .init(ground: hex("E8E1D2"), block: hex("C43E36"), ink: hex("20201D"), accent: hex("315B69"), metallic: false),
        "nofusion-nn": .init(ground: hex("D5C7A8"), block: hex("3E6658"), ink: hex("20231F"), accent: hex("F0401F"), metallic: false),
        "nofusion-nc": .init(ground: hex("DBD4C5"), block: hex("536C73"), ink: hex("20211F"), accent: hex("F0401F"), metallic: false),
        "nofusion-cc": .init(ground: hex("E1C8A5"), block: hex("344F64"), ink: hex("20211F"), accent: hex("F0401F"), metallic: false),
        "nofusion-gr": .init(ground: hex("D7D0BD"), block: hex("777C63"), ink: hex("22231F"), accent: hex("F0401F"), metallic: false),
        "nofusion-lc": .init(ground: hex("D9CDB5"), block: hex("A75D35"), ink: hex("24211D"), accent: hex("F0401F"), metallic: false),
        "nofusion-h1": .init(ground: hex("D3D2CD"), block: hex("44494C"), ink: hex("17191A"), accent: hex("F0401F"), metallic: false),
        "nofusion-h2": .init(ground: hex("DEC5A6"), block: hex("7F4B55"), ink: hex("241D1D"), accent: hex("F0401F"), metallic: false),
        "nofusion-k1": .init(ground: hex("E3C29C"), block: hex("B96037"), ink: hex("241C17"), accent: hex("F0401F"), metallic: false),
        "nofusion-k2": .init(ground: hex("D9C5A6"), block: hex("B67B38"), ink: hex("241D17"), accent: hex("F0401F"), metallic: false),
        "nofusion-k3": .init(ground: hex("DFC6A4"), block: hex("C88138"), ink: hex("241D17"), accent: hex("F0401F"), metallic: false),
        "nofusion-k4": .init(ground: hex("DCC5A4"), block: hex("9E633E"), ink: hex("241D17"), accent: hex("F0401F"), metallic: false),
        "nofusion-k5": .init(ground: hex("D9C4A5"), block: hex("665B73"), ink: hex("201D25"), accent: hex("F0401F"), metallic: false),
        "nofusion-f1": .init(ground: hex("C8D0CF"), block: hex("397187"), ink: hex("1A2022"), accent: hex("F0401F"), metallic: false),
        "nofusion-f2": .init(ground: hex("D4CDB8"), block: hex("5C584C"), ink: hex("22211E"), accent: hex("F0401F"), metallic: false),
        "nofusion-f3": .init(ground: hex("D0D4D0"), block: hex("53656B"), ink: hex("1B2020"), accent: hex("F0401F"), metallic: false),
        "nofusion-f4": .init(ground: hex("D1C8B8"), block: hex("557366"), ink: hex("20221F"), accent: hex("F0401F"), metallic: false),
        "nofusion-bw1": .init(ground: hex("D4D1C8"), block: hex("666866"), ink: hex("20211F"), accent: hex("F0401F"), metallic: true),
        "nofusion-bw2": .init(ground: hex("D5D2CA"), block: hex("454849"), ink: hex("1D1F20"), accent: hex("F0401F"), metallic: true),
        "nofusion-bw3": .init(ground: hex("D8D6D0"), block: hex("777873"), ink: hex("222220"), accent: hex("F0401F"), metallic: true),
        "nofusion-bw4": .init(ground: hex("D9CDB7"), block: hex("96745D"), ink: hex("24201B"), accent: hex("F0401F"), metallic: true)
    ]

    static func palette(for preset: PresetDefinition) -> Palette {
        palettes[preset.presetID] ?? .init(ground: hex("EEEAE0"), block: hex("D9D4C8"), ink: hex("191A18"), accent: hex("F0401F"), metallic: false)
    }

    /// Assignment is derived from stable presetID order, not randomized Hasher or list position.
    /// The cyclic sequence guarantees every adjacent pair differs.
    static func layout(for preset: PresetDefinition) -> Layout {
        let family = PresetLibrary.all.filter { sameBrand($0, preset) }.sorted { $0.presetID < $1.presetID }
        let index = family.firstIndex { $0.presetID == preset.presetID } ?? 0
        return Layout.allCases[index % Layout.allCases.count]
    }

    static func sameBrand(_ lhs: PresetDefinition, _ rhs: PresetDefinition) -> Bool {
        switch (lhs.source, rhs.source) {
        case (.original, .original), (.halideReference, .halideReference), (.lapseReference, .lapseReference), (.nofusionReference, .nofusionReference): return true
        default: return false
        }
    }

    static func contrastInk(for color: Color) -> Color {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        let blackContrast = (luminance + 0.05) / 0.05
        let whiteContrast = 1.05 / (luminance + 0.05)
        return blackContrast >= whiteContrast ? .black : .white
    }

    static func contrastRatio(_ first: Color, _ second: Color) -> Double {
        func luminance(_ color: Color) -> Double {
            let ui = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ c: CGFloat) -> Double { let value = Double(c); return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    static func assertAdjacentLayoutsDiffer(_ presets: [PresetDefinition]) -> Bool {
        zip(presets, presets.dropFirst()).allSatisfy { lhs, rhs in
            !sameBrand(lhs, rhs) || layout(for: lhs) != layout(for: rhs)
        }
    }

    static func hex(_ value: String) -> Color {
        Color(hex: value)
    }
}

extension Color {
    init(hex: String) {
        let n = UInt64(hex, radix: 16) ?? 0
        self.init(.sRGB, red: Double((n >> 16) & 255) / 255,
                  green: Double((n >> 8) & 255) / 255, blue: Double(n & 255) / 255, opacity: 1)
    }
}
