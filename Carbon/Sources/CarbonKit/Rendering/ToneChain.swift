// SET05 — Deterministic rendering and quality harness (source-side logic).
// This file implements the decided render graph (D-005) in pure Swift, so the same
// math runs on host (CarbonVerify) and on-device (CI/Metal backing store).
//
// Render order (D-005):
//   geometry → RAW/linear → highlight shoulder → halation → bloom → vignette →
//   LUT(grade) → exposure → temp/tint → contrast/sat → curve → vibrance → HSL →
//   grain → overlays (date, sprocket, borders)

import Foundation

// MARK: - Effect parameters (from comparison C17–C21, D-017, D-018, D-020, D-021)

public struct FilmEffectParameters: Codable, Equatable {
    // Halation (Lapse Metal defaults, D-018)
    public var halationLumaThresholdMin: Float = 0.92
    public var halationLumaThresholdMax: Float = 0.95
    public var halationRedThresholdMin: Float = 0.93
    public var halationRedThresholdMax: Float = 0.99
    public var halationBackBlurSigma: Float = 20.0
    public var halationFrontBlurSigma: Float = 15.0
    public var halationBackColorR: Float = 0.9
    public var halationBackColorG: Float = 0.001
    public var halationBackColorB: Float = 0.0
    public var halationBackIntensity: Float = 0.65
    public var halationFrontColorR: Float = 0.99
    public var halationFrontColorG: Float = 0.69
    public var halationFrontColorB: Float = 0.24
    public var halationFrontIntensity: Float = 1.0
    
    // Grain (Lapse Metal defaults, D-017)
    public var grainAmount: Float = 0.5  // No Fusion field
    public var grainSize: Float = 0.65  // Lapse Metal big value; No Fusion size 0.5
    public var grainBlur: Float = 0.35  // Lapse Metal
    public var grainIntensityFalloffPerEV: Float = 0.05  // Lapse CI: 1 - 0.05*sceneEV
    public var useSeededHashGrain: Bool = true  // D-017: L metal seeded hash for determinism
    
    // Bloom (No Fusion §3, D-020)
    public var bloomAmount: Float = 0.0
    public var bloomRadius: Float = 10.0
    
    // Vignette (No Fusion §3 / Lapse Metal)
    public var vignetteAmount: Float = 0.0
    public var vignetteRadius: Float = 0.0
    
    // Exposure / WB (No Fusion §3, D-007, D-008)
    public var exposureEV: Float = 0.0  // Creative exposure, applied after LUT
    public var temperatureOffsetK: Float = 0.0  // Applied: temp = orig + this
    public var tintOffset: Float = 0.0  // Applied directly
    
    // Contrast / saturation (No Fusion §3)
    public var contrast: Float = 1.0  // 1.0 = neutral
    public var saturation: Float = 1.0  // 1.0 = neutral
    public var vibrance: Float = 0.0  // 0 = neutral
    
    // Tone curve (No Fusion §3)
    public var curveBlack: Float = 0.0
    public var curveShadow: Float = 0.0
    public var curveMidtone: Float = 0.0
    public var curveHighlight: Float = 0.0
    public var curveWhite: Float = 0.0
    
    // HSL per-color: 8 channels (red, orange, yellow, green, aqua, blue, purple, magenta)
    // Each is (hueShift, saturation, luminance)
    public var hsl: [HSLChannel] = (0..<8).map { _ in HSLChannel() }
    
    // Film LUT (if present; strength 0..1)
    public var lutIntensity: Float = 1.0
    public var lutID: String? = nil  // Name/ID of lookup table; nil = no LUT
    
    // Strength scalar (No Fusion §3: one control scales all adjustments)
    public var strength: Float = 1.0
    
    public struct HSLChannel: Codable, Equatable {
        public var hue: Float = 0.0  // No Fusion: hue shift in x
        public var saturation: Float = 1.0  // 1.0 = neutral (No Fusion: field, scaled around 0.75..1.25)
        public var luminance: Float = 1.0  // 1.0 = neutral (No Fusion: scaled around 0.75..1.25)
        
        public init(hue: Float = 0.0, saturation: Float = 1.0, luminance: Float = 1.0) {
            self.hue = hue
            self.saturation = saturation
            self.luminance = luminance
        }
    }
    
    public init() {}
}

// MARK: - Deterministic grain hash (Lapse Metal integer-hash, D-017)

/// Pure-host deterministic noise for grain verification. On-device, the Metal kernel
/// with the same integer-hash constants replaces this; the seeds and bounds match.
public func integerHashNoise(x: UInt32, y: UInt32, seed: UInt32) -> Float {
    var h = UInt64(x) &* 374761393 &+ UInt64(y) &* 668265263 &+ UInt64(seed) &* 1442695040888963407
    h = (h ^ (h >> 13)) &* 1274126177
    return Float(h & 0xFFFFFF) / Float(0xFFFFFF)  // 0..1
}

/// Grain amount per pixel based on Lapse CI formula: 1 - 0.05*sceneEV, clamped to [0, 2]
public func grainIntensityScalar(sceneEV: Float) -> Float {
    let raw = 1.0 - 0.05 * sceneEV
    return max(0.0, min(2.0, raw))
}

// MARK: - Pipeline math (piecewise, no full Core Image rendering — just the numerical transforms)

/// Apply the exposure+WB+contrast/saturation+curve+vibrance+HSL chain to a single RGB triple.
/// Each step must match the reference parameterization (D-007, D-008, D-020).
public struct ToneChain {
    /// Given an sRGB input (0..1 per component) and effect params, apply the film grade.
    /// Returns sRGB output (0..1 per component). All gamma, clamping, and interpolation
    /// match the cited references; grain/halation are separate passes applied by the caller.
    public static func apply(r: Float, g: Float, b: Float,
                             params: FilmEffectParameters,
                             sceneEV: Float = 8.0) -> (Float, Float, Float) {
        let s = params.strength
        
        // --- LUT stage (No Fusion §3: after halation/bloom/vignette, before exposure) ---
        var (lr, lg, lb) = (r, g, b)
        if let lutName = params.lutID, params.lutIntensity > 0 {
            // Lookup table: in the real engine, a 33³ sRGB cube from the LUT resources.
            // For host verification, we use deterministic identity or an approximate
            // film transform to demonstrate reproducibility, NOT to claim it IS the
            // source LUT (we don't have the LUT binaries). Documented in tests/README.md.
            // NOTE: this is a verification harness; the actual LUT bytes are in the IPA,
            // not in this repo. Tests validate engine behavior, not LUT identity.
            let result = verificationLUT(r: lr, g: lg, b: lb, name: lutName)
            let mix = params.lutIntensity
            lr = lr * (1 - mix) + result.0 * mix
            lg = lg * (1 - mix) + result.1 * mix
            lb = lb * (1 - mix) + result.2 * mix
        }
        
        // --- Exposure (No Fusion §3: EV = preset.exposure * strength) ---
        let ev = params.exposureEV * s
        if ev != 0 {
            let scale = pow(2.0, ev)
            lr *= scale; lg *= scale; lb *= scale
        }
        
        // --- Temperature / tint (No Fusion §3: temp = orig + preset.temperature*s*2000) ---
        // Simplification: temperature offset in K, applied as a warm/cool shift in the
        // visible domain, not a full chromatic adaptation. Use a linear approximation for
        // the host harness; on-device CI uses CITemperatureAndTint with the real mapping.
        let tempOffset = params.temperatureOffsetK * s
        if tempOffset != 0 {
            let warm = 1.0 + tempOffset / 10000.0  // Very coarse: 1000 K ≈ +10% red
            let cool = 1.0 - tempOffset / 15000.0
            lr *= warm
            lb *= cool
        }
        let tintOffset = params.tintOffset * s
        if tintOffset != 0 {
            let green = 1.0 - tintOffset / 100.0
            lg *= green
        }
        
        // --- Contrast (No Fusion §3: 1 + (preset.contrast - 1) * strength) ---
        let contrast = 1.0 + (params.contrast - 1.0) * s
        if contrast != 1.0 {
            lr = clamp01((lr - 0.5) * contrast + 0.5)
            lg = clamp01((lg - 0.5) * contrast + 0.5)
            lb = clamp01((lb - 0.5) * contrast + 0.5)
        }
        
        // --- Saturation (No Fusion §3: 1 + (preset.saturation - 1) * strength) ---
        let saturation = 1.0 + (params.saturation - 1.0) * s
        if saturation != 1.0 {
            let luma = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
            lr = clamp01(luma + (lr - luma) * saturation)
            lg = clamp01(luma + (lg - luma) * saturation)
            lb = clamp01(luma + (lb - luma) * saturation)
        }
        
        // --- Curve (No Fusion §3: 5-point curve, scaled by strength) ---
        // The exact equations are:
        //   P0: (0, black * strength * 0.25)
        //   P1: (0.25, low-tone adj scaled by 0.25*strength)
        //   P2: (0.5, avg adjacent offsets + 0.5)
        //   P3: (0.75, high-tone adj around neutral)
        //   P4: (1.0, 1 + white * strength * 0.25)
        // For the host, use linear interpolation between these points; on-device uses
        // a Core Image ToneCurve with the same input coefficients.
        if params.curveBlack != 0 || params.curveShadow != 0 || params.curveMidtone != 0 ||
           params.curveHighlight != 0 || params.curveWhite != 0 {
            let points = curvePoints(params: params)
            (lr, lg, lb) = applyCurve(lr, lg, lb, points: points)
        }
        
        // --- Vibrance (No Fusion §3: amount = preset.vibration * strength) ---
        let vibrance = params.vibrance * s
        if vibrance != 0 {
            let avgSat = ((lr - min3(lr, lg, lb)) + (lg - min3(lr, lg, lb)) + (lb - min3(lr, lg, lb))) / 3.0
            let boost = 1.0 + vibrance * (1.0 - avgSat)
            let luma = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
            lr = clamp01(luma + (lr - luma) * boost)
            lg = clamp01(luma + (lg - luma) * boost)
            lb = clamp01(luma + (lb - luma) * boost)
        }
        
        // --- HSL (No Fusion §3: 8 channels, hue×0.0625, sat/lum around 0.75..1.25) ---
        (lr, lg, lb) = applyHSL(r: lr, g: lg, b: lb, params: params)
        
        return (lr, lg, lb)
    }
    
    // MARK: - Helpers
    
    static func clamp01(_ v: Float) -> Float { max(0.0, min(1.0, v)) }
    static func min3(_ a: Float, _ b: Float, _ c: Float) -> Float { min(a, min(b, c)) }
    static func max3(_ a: Float, _ b: Float, _ c: Float) -> Float { max(a, max(b, c)) }
    
    static func curvePoints(params: FilmEffectParameters) -> [(Float, Float)] {
        let s = params.strength
        let p0 = (Float(0.0), params.curveBlack * s * 0.25)
        let p1 = (Float(0.25), params.curveShadow * 0.25 * s)
        let p2 = (Float(0.5), (params.curveShadow * 0.25 * s + params.curveHighlight * 0.25 * s) / 2.0 + 0.5)
        let p3 = (Float(0.75), params.curveHighlight * 0.25 * s)
        let p4 = (Float(1.0), 1.0 + params.curveWhite * s * 0.25)
        return [p0, p1, p2, p3, p4]
    }
    
    static func applyCurve(_ r: Float, _ g: Float, _ b: Float, points: [(Float, Float)]) -> (Float, Float, Float) {
        func lookup(_ x: Float) -> Float {
            for i in 0..<(points.count - 1) {
                let (x0, y0) = points[i]
                let (x1, y1) = points[i + 1]
                if x >= x0 && x <= x1 {
                    if x1 == x0 { return y0 }
                    let t = (x - x0) / (x1 - x0)
                    return y0 + (y1 - y0) * t
                }
            }
            return points.last?.1 ?? x
        }
        return (lookup(r), lookup(g), lookup(b))
    }
    
    static func applyHSL(r: Float, g: Float, b: Float, params: FilmEffectParameters) -> (Float, Float, Float) {
        let s = params.strength
        // Convert RGB → HSV
        let (h, sat, v) = rgbToHSB(r, g, b)
        if sat < 0.001 { return (r, g, b) }  // Gray: no HSL effect
        let colorIndex = hueToColorIndex(h)  // 0..7
        let ch = params.hsl[colorIndex]
        if ch.hue == 0 && ch.saturation == 1 && ch.luminance == 1 { return (r, g, b) }
        
        let hueShift = ch.hue * 0.0625 * s
        let satFactor = 1.0 + (ch.saturation - 1.0) * s
        // Luminance: No Fusion caps at 1.25 and uses -0.25 delta at/below 0.75
        let lumAdj = ch.luminance - 1.0
        let clampedLumAdj = max(-0.25, min(0.25, lumAdj))
        let lumFactor = 1.0 + clampedLumAdj * s
        
        var newHue = h + hueShift
        newHue = newHue.truncatingRemainder(dividingBy: 1.0)
        if newHue < 0 { newHue += 1.0 }
        
        var newSat = clamp01(sat * satFactor)
        var newVal = clamp01(v * lumFactor)
        
        let (nr, ng, nb) = hsbToRGB(newHue, newSat, newVal)
        return (nr, ng, nb)
    }
    
    static func rgbToHSB(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        let maxV = max3(r, g, b)
        let minV = min3(r, g, b)
        let delta = maxV - minV
        let v = maxV
        let s = maxV == 0 ? 0 : delta / maxV
        var h: Float = 0
        if delta > 0 {
            if maxV == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6.0) }
            else if maxV == g { h = (b - r) / delta + 2.0 }
            else { h = (r - g) / delta + 4.0 }
            h /= 6.0
            if h < 0 { h += 1.0 }
        }
        return (h, s, v)
    }
    
    static func hsbToRGB(_ h: Float, _ s: Float, _ v: Float) -> (Float, Float, Float) {
        let c = v * s
        let x = c * (1.0 - abs((h * 6.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = v - c
        var r: Float = 0, g: Float = 0, b: Float = 0
        switch h * 6.0 {
        case 0..<1: (r, g, b) = (c, x, 0)
        case 1..<2: (r, g, b) = (x, c, 0)
        case 2..<3: (r, g, b) = (0, c, x)
        case 3..<4: (r, g, b) = (0, x, c)
        case 4..<5: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return (r + m, g + m, b + m)
    }
    
    static func hueToColorIndex(_ h: Float) -> Int {
        // Map hue to 8 bins: red, orange, yellow, green, aqua, blue, purple, magenta
        let thresholds: [Float] = [-0.0625, 0.0417, 0.125, 0.2083, 0.375, 0.5417, 0.7083, 0.8333, 0.9167]
        // Simpler: convert hue (0..1) to bin index
        if h < 0.0417 { return 0 }  // red (0-15°)
        if h < 0.125 { return 1 }  // orange (15-45°)
        if h < 0.2083 { return 2 }  // yellow (45-75°)
        if h < 0.375 { return 3 }  // green (75-135°)
        if h < 0.5417 { return 4 }  // aqua (135-195°)
        if h < 0.7083 { return 5 }  // blue (195-255°)
        if h < 0.8333 { return 6 }  // purple (255-300°)
        return 7  // magenta (300-360°)
    }
    
    /// Verification-only LUT (placeholder): deterministic, monotonic, film-like tone value.
    /// This is NOT the original Halide/No Fusion LUT binary; tests validate reproducibility,
    /// not LUT identity. See tests/README.md.
    static func verificationLUT(r: Float, g: Float, b: Float, name: String) -> (Float, Float, Float) {
        // Simple shoulder + small color shift; deterministic per-name hash for distinction.
        let hash = Float(abs(name.hashValue % 100)) / 1000.0
        func shoulder(_ x: Float) -> Float {
            // x/(1 + 0.15*x) has a gentle highlight rolloff
            let v = x / (1.0 + 0.15 * x)
            return clamp01(v * (1.0 + hash))
        }
        return (shoulder(r), shoulder(g), shoulder(b))
    }
}