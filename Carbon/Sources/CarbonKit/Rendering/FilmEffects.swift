import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Effects shared by Carbon's preset path (PhotoRenderer) and the Lapse routes
/// (LapseRenderer). All inputs and outputs are in the CIContext working space,
/// extended linear sRGB (CIContextProvider, D-019).
enum FilmEffects {

    // MARK: - Halation (D-018: Lapse Metal defaults, comparison.md C18)

    /// Lapse processes stills at 3024 x 4032 (lapse-camera-settings.md section 4).
    /// Blur sigmas are defined at that size and scaled to the image's long edge.
    static let halationReferenceLongEdge: CGFloat = 4032

    /// Highlight-only halation. Masks come from sRGB-encoded values, as in the
    /// Lapse texture pipeline: luma .92-.95 drives the warm front glow (sigma 15,
    /// colour (.99,.69,.24), intensity 1); red .93-.99 drives the red back glow
    /// (sigma 20, colour (.9,.001,0), intensity .65). Glows add in linear light.
    /// `amount` scales both intensities; 1 = the documented defaults.
    /// Assumption: the reference lists two thresholds and two layers without
    /// pairing them; luma->front and red->back is Carbon's reading.
    static func halation(_ image: CIImage, amount: Float) -> CIImage {
        guard amount > 0.001 else { return image }
        let extent = image.extent
        let scale = extent.isInfinite ? 1 : max(extent.width, extent.height) / halationReferenceLongEdge
        let encoded = image.applyingFilter("CILinearToSRGBToneCurve")
        guard let front = mask(encoded, luma: true, lower: 0.92, upper: 0.95),
              let back = mask(encoded, luma: false, lower: 0.93, upper: 0.99) else { return image }
        let frontGlow = blur(front, sigma: 15 * scale, extent: extent)
        let backGlow = blur(back, sigma: 20 * scale, extent: extent)
        let source = """
        kernel vec4 halationCompose(__sample s, __sample f, __sample b, float k) {
            vec3 glow = f.r * vec3(0.99, 0.69, 0.24) * 1.0 + b.r * vec3(0.9, 0.001, 0.0) * 0.65;
            return vec4(s.rgb + glow * k * s.a, s.a);
        }
        """
        guard let kernel = CIColorKernel(source: source),
              let out = kernel.apply(extent: extent, arguments: [image, frontGlow, backGlow, amount]) else { return image }
        return out
    }

    private static func mask(_ encoded: CIImage, luma: Bool, lower: Float, upper: Float) -> CIImage? {
        let value = luma ? "dot(s.rgb, vec3(0.2126, 0.7152, 0.0722))" : "s.r"
        let source = "kernel vec4 halationMask(__sample s) { float m = smoothstep(\(lower), \(upper), \(value)); return vec4(m, m, m, 1.0); }"
        return CIColorKernel(source: source)?.apply(extent: encoded.extent, arguments: [encoded])
    }

    private static func blur(_ image: CIImage, sigma: CGFloat, extent: CGRect) -> CIImage {
        guard sigma > 0.01 else { return image }
        let blurred = image.clampedToExtent().applyingGaussianBlur(sigma: Double(sigma))
        return extent.isInfinite ? blurred : blurred.cropped(to: extent)
    }

    // MARK: - Grain (D-017: seeded integer hash; No Fusion amount/size semantics)

    /// Zero-mean additive grain in the sRGB-encoded domain, so it reads evenly
    /// from shadows to highlights. Noise comes from `integerHashNoise`, the same
    /// deterministic hash ToneChain documents, tiled at `size` pixels per cell.
    /// Opacity is amount * 0.2 (comparison.md C17, No Fusion).
    static func grain(_ image: CIImage, amount: Float, size: Float, seed: UInt32 = 0) -> CIImage {
        guard amount > 0.001, let tile = noiseTile(seed: seed) else { return image }
        let cell = CGFloat(max(1, size))
        // CIAffineTile repeats the cell; the typed filter avoids the UIKit-only NSValue initialiser.
        let tiler = CIFilter.affineTile()
        tiler.inputImage = tile.samplingNearest()
        tiler.transform = CGAffineTransform(scaleX: cell, y: cell)
        guard let noise = tiler.outputImage else { return image }
        let extent = image.extent
        let source = """
        kernel vec4 grainAdd(__sample s, __sample n, float k) {
            vec3 c = max(s.rgb, vec3(0.0));
            vec3 e = mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
            e += (n.r - 0.5) * k;
            vec3 l = mix(e / 12.92, pow(max((e + 0.055) / 1.055, vec3(0.0)), vec3(2.4)), step(vec3(0.04045), e));
            return vec4(l, s.a);
        }
        """
        guard let kernel = CIColorKernel(source: source),
              let out = kernel.apply(extent: extent, arguments: [image, noise, amount * 0.2]) else { return image }
        return out
    }

    private static let tileSide = 256

    private static func noiseTile(seed: UInt32) -> CIImage? {
        var values = [Float](repeating: 0, count: tileSide * tileSide * 4)
        for y in 0..<tileSide {
            for x in 0..<tileSide {
                let n = integerHashNoise(x: UInt32(x), y: UInt32(y), seed: seed)
                let i = (y * tileSide + x) * 4
                values[i] = n; values[i + 1] = n; values[i + 2] = n; values[i + 3] = 1
            }
        }
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        // colorSpace nil: the noise values are data, not colour, and must not be linearised.
        return CIImage(bitmapData: data, bytesPerRow: tileSide * 16,
                       size: CGSize(width: tileSide, height: tileSide), format: .RGBAf, colorSpace: nil)
    }

    // MARK: - Halide LUT input (Apple Log, Rec.2020 primaries)

    /// Halide cubes are indexed by Apple Log encoded Rec.2020 values and return
    /// sRGB-transfer values. Fitting Process Zero for identity on a gray ramp gives
    /// mean error 0.035 with Apple Log input vs 0.123 with sRGB input, and the
    /// flat toe on every Halide cube disappears (analysis/PROGRESS.md).
    /// Looks whose files are named DisplayP3 return Display P3 primaries.
    static func applyHalideCube(_ image: CIImage, lut: LUTData, displayP3Output: Bool) -> CIImage {
        // Linear sRGB -> linear Rec.2020 (D65), then Apple Log OETF.
        let source = """
        kernel vec4 appleLog2020(__sample s) {
            vec3 c = s.rgb;
            vec3 r = vec3(dot(c, vec3(0.6274524, 0.3292485, 0.0432991)),
                          dot(c, vec3(0.0691092, 0.9195311, 0.0113597)),
                          dot(c, vec3(0.0163976, 0.0880301, 0.8955723)));
            vec3 hi = 0.08550479 * log2(max(r + 0.00964052, vec3(1.0e-6))) + 0.69336945;
            vec3 d = max(r + 0.05641088, vec3(0.0));
            vec3 lo = 47.28711236 * d * d;
            vec3 e = mix(lo, hi, step(vec3(0.01), r));
            return vec4(clamp(e, 0.0, 1.0), s.a);
        }
        """
        guard let kernel = CIColorKernel(source: source),
              let encoded = kernel.apply(extent: image.extent, arguments: [image]) else { return image }
        let data = lut.rgba.withUnsafeBufferPointer { Data(buffer: $0) }
        // CIColorCube (no colour space) samples the working values as given,
        // which are now Apple Log codes.
        var out = encoded.applyingFilter("CIColorCube", parameters: [
            "inputCubeDimension": lut.dimension, "inputCubeData": data
        ])
        out = out.applyingFilter("CISRGBToneCurveToLinear")
        if displayP3Output {
            out = out.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.2249005, y: -0.2249005, z: 0, w: 0),
                "inputGVector": CIVector(x: -0.0420633, y: 1.0420633, z: 0, w: 0),
                "inputBVector": CIVector(x: -0.0196448, y: -0.0786536, z: 1.0982983, w: 0)
            ])
        }
        return image.extent.isInfinite ? out : out.cropped(to: image.extent)
    }
}
