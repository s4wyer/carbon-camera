import SwiftUI

/// Generated film-box palette. Samples are derived from the same tone chain used by
/// the verification renderer, including the bundled LUT when it is available.
struct PresetPalette {
    struct RGB: Hashable {
        let r: Float
        let g: Float
        let b: Float

        var color: Color { Color(red: Double(r), green: Double(g), blue: Double(b)) }
        var luma: Float { 0.2126 * r + 0.7152 * g + 0.0722 * b }
        var saturation: Float {
            let high = max(r, max(g, b))
            let low = min(r, min(g, b))
            return high == 0 ? 0 : (high - low) / high
        }
    }

    let shadow: RGB
    let highlight: RGB
    let midtone: RGB
    let accent: RGB
    let testStrip: [RGB]
    let isMonochrome: Bool

    // One synthetic reference chart shared by every stock. Its first five samples
    // are the neutral ramp, followed by primaries, skin, and low-saturation pastels.
    private static let referenceChart: [RGB] = [
        RGB(r: 0.035, g: 0.035, b: 0.035), RGB(r: 0.22, g: 0.22, b: 0.22),
        RGB(r: 0.50, g: 0.50, b: 0.50), RGB(r: 0.78, g: 0.78, b: 0.78),
        RGB(r: 0.96, g: 0.96, b: 0.96), RGB(r: 0.92, g: 0.08, b: 0.08),
        RGB(r: 0.08, g: 0.78, b: 0.14), RGB(r: 0.08, g: 0.28, b: 0.92),
        RGB(r: 0.92, g: 0.78, b: 0.08), RGB(r: 0.78, g: 0.10, b: 0.72),
        RGB(r: 0.72, g: 0.40, b: 0.26), RGB(r: 0.86, g: 0.68, b: 0.58),
        RGB(r: 0.72, g: 0.82, b: 0.78), RGB(r: 0.84, g: 0.76, b: 0.88)
    ]

    static func make(for preset: PresetDefinition) -> PresetPalette {
        let reference = referenceChart
        let parameters = preset.baseParameters
        let toneParameters = FilmEffectParameters(from: parameters)
        let lutTransform: ((Float, Float, Float) -> (Float, Float, Float))? = parameters.lutID.flatMap { lutID in
            guard !lutID.isEmpty, let lut = try? LUTResources.shared.load(lutID: lutID) else { return nil }
            return { r, g, b in lut.sample(r, g, b) }
        }
        let processed = reference.map { sample in
            ToneChain.apply(r: sample.r, g: sample.g, b: sample.b, params: toneParameters,
                            lutTransform: lutTransform)
        }.map { RGB(r: clamp($0.0), g: clamp($0.1), b: clamp($0.2)) }

        let mono = isMonochrome(processed, preset: preset)
        let normalized = mono ? processed.map { sample in
            let gray = sample.luma
            return RGB(r: gray, g: gray, b: gray)
        } : processed
        let shadow = normalized[0]
        let highlight = normalized[4]
        let midtone = normalized[2]
        let accentIndex = (5..<processed.count).max { lhs, rhs in
            colorShift(processed[lhs], from: reference[lhs]) < colorShift(processed[rhs], from: reference[rhs])
        } ?? 5
        var accent = normalized[accentIndex]
        if mono {
            accent = RGB(r: 0.72, g: 0.72, b: 0.72)
        } else if colorShift(accent, from: reference[accentIndex]) < 0.08 {
            // Neutral looks still need a clear box-print accent.
            accent = RGB(r: 0.82, g: 0.36, b: 0.16)
        }
        return PresetPalette(shadow: shadow, highlight: highlight, midtone: midtone,
                             accent: accent, testStrip: normalized, isMonochrome: mono)
    }

    private static func clamp(_ value: Float) -> Float { max(0, min(1, value)) }
    private static func colorShift(_ a: RGB, from b: RGB) -> Float {
        abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b) + abs(a.saturation - b.saturation)
    }
    private static func isMonochrome(_ samples: [RGB], preset: PresetDefinition) -> Bool {
        let name = preset.displayName.lowercased()
        let monoName = name.contains("mono") || name.contains("chroma noir") || name.contains("quicksilver") || name.contains("onyx") || name.contains("eternal")
        let neutralOutput = samples.allSatisfy { max($0.r, max($0.g, $0.b)) - min($0.r, min($0.g, $0.b)) < 0.045 }
        return monoName || neutralOutput
    }
}

private extension FilmEffectParameters {
    init(from parameters: PresetParameters) {
        self.init()
        strength = parameters.strength
        lutID = parameters.lutID
        lutIntensity = parameters.lutIntensity
        exposureEV = parameters.exposureEV
        temperatureOffsetK = parameters.temperatureOffsetK
        tintOffset = parameters.tintOffset
        contrast = parameters.contrast
        saturation = parameters.saturation
        vibrance = parameters.vibrance
        curveBlack = parameters.curveBlack
        curveShadow = parameters.curveShadow
        curveMidtone = parameters.curveMidtone
        curveHighlight = parameters.curveHighlight
        curveWhite = parameters.curveWhite
        hsl = parameters.hsl
    }
}

private extension LUTData {
    func sample(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        func index(_ value: Float) -> Int { min(dimension - 1, max(0, Int((value * Float(dimension - 1)).rounded()))) }
        let ri = index(r), gi = index(g), bi = index(b)
        let offset = ((bi * dimension + gi) * dimension + ri) * 4
        return (rgba[offset], rgba[offset + 1], rgba[offset + 2])
    }
}
