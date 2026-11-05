import CoreImage
import Foundation

/// Core Image reconstructions of the documented Lapse Journal and Photo Default routes.
enum LapseRenderer {
    enum Look { case journal, photoDefault }

    static func render(_ input: CIImage, look: Look, sceneEV: Float, flash: Bool = false,
                       loadLUT: (String) throws -> LUTData) throws -> CIImage {
        switch look {
        case .journal: return try journal(input, sceneEV: sceneEV, flash: flash, loadLUT: loadLUT)
        case .photoDefault: return try photoDefault(input, loadLUT: loadLUT)
        }
    }

    private static func journal(_ image: CIImage, sceneEV: Float, flash: Bool,
                                loadLUT: (String) throws -> LUTData) throws -> CIImage {
        var result = image
        result = halation(result)
        result = try lut(result, id: "lapse-v4-03", intensity: 1, loadLUT: loadLUT)
        result = gamma(result, power: flash ? 1.0 : 0.9)
        result = exposure(result, ev: journalExposureEV(sceneEV: sceneEV, flash: flash))
        result = faceBalanceAndSkinToneUnavailable(result)
        result = vibrance(result, amount: 0.4)
        result = highlightShadow(result)
        result = vignette(result, intensity: 1.75, radius: 0.15)
        result = chromaticAberration(result)
        result = globalBlur(result)
        result = gaussianBlur(result, radius: 0.3)
        return grain(result, intensity: 1 - 0.05 * sceneEV, seed: 4)
    }

    static func journalExposureEV(sceneEV: Float, flash: Bool = false) -> Float {
        flash ? 0.50 : 0.55 + sceneEV * (0.50 - 0.55) / 10
    }

    private static func photoDefault(_ image: CIImage,
                                     loadLUT: (String) throws -> LUTData) throws -> CIImage {
        var result = image
        result = try lut(result, id: "lapse-v4-03", intensity: 0.75, loadLUT: loadLUT)
        result = maskedAdjustments(result)
        result = maskedSelectiveColor(result)
        // Photo Default documents radius 1 and opacity 0.4; use the documented radius for both CI blur layers.
        result = globalBlur(result, regularRadius: 1, darkenRadius: 1, opacity: 0.4)
        result = halation(result)
        result = colorOverlay(result, red: 0.56, green: 0.51, blue: 0.45, alpha: 0.13)
        result = adaptiveShadows(result)
        result = vignette(result, intensity: 0.9, radius: 0.95, power: 0.09)
        let diagonal = hypot(result.extent.width, result.extent.height)
        result = chromaticAberration(result, offsets: (0, 0.006 * diagonal, 0.01275 * diagonal), scale: 1.05)
        result = gaussianBlur(result, radius: 0.5)
        return grain(result, intensity: 0.5, seed: 7)
    }

    private static func output(_ name: String, image: CIImage, values: [String: Any]) -> CIImage {
        guard let filter = CIFilter(name: name) else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        values.forEach { filter.setValue($0.value, forKey: $0.key) }
        return filter.outputImage ?? image
    }

    private static func exposure(_ image: CIImage, ev: Float) -> CIImage {
        output("CIExposureAdjust", image: image, values: [kCIInputEVKey: ev])
    }

    private static func gamma(_ image: CIImage, power: Float) -> CIImage {
        output("CIGammaAdjust", image: image, values: ["inputPower": power])
    }

    private static func colorControls(_ image: CIImage, contrast: Float, saturation: Float) -> CIImage {
        output("CIColorControls", image: image, values: [kCIInputContrastKey: contrast, kCIInputSaturationKey: saturation])
    }

    private static func vibrance(_ image: CIImage, amount: Float) -> CIImage {
        output("CIVibrance", image: image, values: ["inputAmount": amount])
    }

    private static func lut(_ image: CIImage, id: String, intensity: Float,
                            loadLUT: (String) throws -> LUTData) throws -> CIImage {
        let lut = try loadLUT(id)
        let data = lut.rgba.withUnsafeBufferPointer { Data(buffer: $0) }
        let transformed = output("CIColorCubeWithColorSpace", image: image, values: [
            "inputCubeDimension": lut.dimension, "inputCubeData": data,
            // Lapse §8 CI LUT processing uses Device RGB.
            "inputColorSpace": CGColorSpaceCreateDeviceRGB()
        ])
        guard intensity < 0.999 else { return transformed }
        return output("CIDissolveTransition", image: image, values: [
            kCIInputTargetImageKey: transformed, kCIInputTimeKey: intensity
        ]).cropped(to: image.extent)
    }

    private static func maskedAdjustments(_ image: CIImage) -> CIImage {
        // CIColorControls approximates Metal's mask-interpolated classic adjustments without its masks.
        var result = colorControls(image, contrast: 0.75, saturation: 0.3)
        // Stored Metal highlight/shadow deltas map to CI amounts: -0.4 highlights -> 0.6; -0.45 shadows -> -0.45.
        result = output("CIHighlightShadowAdjust", image: result, values: ["inputShadowAmount": -0.45, "inputHighlightAmount": 0.6])
        return vibrance(result, amount: 0.95)
    }

    private static func maskedSelectiveColor(_ image: CIImage) -> CIImage {
        // The Metal selective-color mask algorithm and values are unspecified; retain the documented stage as a no-op.
        return image
    }

    private static func adaptiveShadows(_ image: CIImage) -> CIImage {
        // CIFilter cannot reproduce Lapse's scene-adaptive Metal shadow mask; the documented base intensity is zero.
        return image
    }

    private static func halation(_ image: CIImage) -> CIImage {
        // Journal CI halation values were not recovered; use the documented shared Metal defaults (§7).
        let backLuma = halationLayer(image, channel: 0, lower: 0.92, upper: 0.95,
                                     sigma: 20, color: (0.9, 0.001, 0), intensity: 0.65)
        let backRed = halationLayer(image, channel: 1, lower: 0.93, upper: 0.99,
                                    sigma: 20, color: (0.9, 0.001, 0), intensity: 0.65)
        let front = halationLayer(image, channel: 0, lower: 0.92, upper: 0.95,
                                  sigma: 15, color: (0.99, 0.69, 0.24), intensity: 1)
        let joined = output("CIAdditionCompositing", image: backLuma, values: [kCIInputBackgroundImageKey: backRed])
        let layers = output("CIAdditionCompositing", image: joined, values: [kCIInputBackgroundImageKey: front])
        return output("CIAdditionCompositing", image: image, values: [kCIInputBackgroundImageKey: layers]).cropped(to: image.extent)
    }

    private static func halationLayer(_ image: CIImage, channel: Int, lower: Float, upper: Float,
                                     sigma: Float, color: (CGFloat, CGFloat, CGFloat), intensity: Float) -> CIImage {
        let value = channel == 0 ? "dot(s.rgb, vec3(0.2126,0.7152,0.0722))" : "s.r"
        let source = "kernel vec4 mask(__sample s) { float v = \(value); float m = smoothstep(\(lower), \(upper), v); return vec4(m,m,m,m); }"
        // Legacy CIColorKernel(source:) remains available on the app's deployment target and permits these documented per-pixel formulas.
        guard let kernel = CIColorKernel(source: source),
              let mask = kernel.apply(extent: image.extent, arguments: [image]) else { return image }
        let blur = gaussianBlur(mask, radius: sigma)
        let tinted = output("CIColorMatrix", image: blur, values: [
            "inputRVector": CIVector(x: color.0 * CGFloat(intensity), y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: color.1 * CGFloat(intensity), y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: color.2 * CGFloat(intensity), y: 0, z: 0, w: 0)
        ])
        return tinted.cropped(to: image.extent)
    }

    private static func faceBalanceAndSkinToneUnavailable(_ image: CIImage) -> CIImage {
        // CIFaceBalance and SkinToneTwo are Apple-private; §5 provides no Journal inputs, so these stages are intentionally no-ops.
        return image
    }

    private static func highlightShadow(_ image: CIImage) -> CIImage {
        var adjusted = output("CIHighlightShadowAdjust", image: image, values: [
            "inputHighlightAmount": 1 - 0.95, "inputShadowAmount": 0.15
        ])
        adjusted = output("CIColorControls", image: adjusted, values: [
            kCIInputSaturationKey: 0.95, kCIInputBrightnessKey: -0.35
        ])
        // Red-band shift is omitted because the recovered hue/saturation/brightness values lack a documented band width.
        let luminosity = output("CILuminosityBlendMode", image: adjusted, values: [kCIInputBackgroundImageKey: image])
        let layer = output("CIColorMatrix", image: luminosity, values: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.4)
        ])
        return output("CISourceOverCompositing", image: layer, values: [kCIInputBackgroundImageKey: image]).cropped(to: image.extent)
    }

    static func vignette(_ image: CIImage, intensity: Float, radius: Float, power: Float? = nil) -> CIImage {
        let extent = image.extent
        let side = max(extent.width, extent.height)
        let xOffset = (side - extent.width) / 2 - extent.minX
        let yOffset = (side - extent.height) / 2 - extent.minY
        let centered = image.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))
        let white = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
        let whiteBacked = output("CISourceOverCompositing", image: centered, values: [kCIInputBackgroundImageKey: white])
        let effected: CIImage
        if let power {
            effected = metalVignette(whiteBacked, intensity: intensity, radius: radius, power: power)
        } else {
            effected = output("CIVignette", image: whiteBacked, values: [kCIInputIntensityKey: intensity, kCIInputRadiusKey: CGFloat(radius) * side])
        }
        return effected.transformed(by: CGAffineTransform(translationX: -xOffset, y: -yOffset)).cropped(to: extent)
    }

    private static func metalVignette(_ image: CIImage, intensity: Float, radius: Float, power: Float) -> CIImage {
        // Metal q = clamp(radius * (uv - 0.5), -0.5, 0.5); this applies a radial power falloff to q.
        let extent = image.extent
        let source = "kernel vec4 vignette(__sample s) { vec2 uv = (destCoord() - vec2(\(extent.minX),\(extent.minY))) / vec2(\(extent.width),\(extent.height)); vec2 q = clamp(\(radius) * (uv - vec2(0.5)), vec2(-0.5), vec2(0.5)); float v = \(intensity) * pow(clamp(length(q) * 2.0, 0.0, 1.0), \(power)); return vec4(s.rgb * (1.0 - v), s.a); }"
        // Legacy CIColorKernel(source:) is used because the formulas need no separate Metal library asset.
        guard let kernel = CIColorKernel(source: source) else { return image }
        return kernel.apply(extent: image.extent, arguments: [image]) ?? image
    }

    private static func chromaticAberration(_ image: CIImage, offsets: (CGFloat, CGFloat, CGFloat) = (0, 6, 12.75), scale: CGFloat = 1.45) -> CIImage {
        // Radial channel scaling matches edge displacement; the documented 80-sample blur is not reproduced.
        let extent = image.extent
        let diagonal = hypot(extent.width, extent.height)
        guard diagonal > 0 else { return image }
        let centerX = extent.midX
        let centerY = extent.midY
        func plane(_ channel: String, offset: CGFloat) -> CIImage {
            let factor = 1 + offset * scale / (0.5 * diagonal)
            var layer = output("CIColorMatrix", image: image, values: [
                "inputRVector": channel == "R" ? CIVector(x: 1, y: 0, z: 0, w: 0) : CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": channel == "G" ? CIVector(x: 0, y: 1, z: 0, w: 0) : CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": channel == "B" ? CIVector(x: 0, y: 0, z: 1, w: 0) : CIVector(x: 0, y: 0, z: 0, w: 0)
            ])
            layer = layer.transformed(by: CGAffineTransform(translationX: -centerX, y: -centerY))
                .transformed(by: CGAffineTransform(scaleX: factor, y: factor))
                .transformed(by: CGAffineTransform(translationX: centerX, y: centerY))
            return layer
        }
        let red = plane("R", offset: offsets.0)
        let green = plane("G", offset: offsets.1)
        let blue = plane("B", offset: offsets.2)
        let rg = output("CIAdditionCompositing", image: red, values: [kCIInputBackgroundImageKey: green])
        return output("CIAdditionCompositing", image: rg, values: [kCIInputBackgroundImageKey: blue]).cropped(to: extent)
    }

    private static func globalBlur(_ image: CIImage, regularRadius: Float = 0.5,
                                   darkenRadius: Float = 4, opacity: Float = 0.3) -> CIImage {
        let regular = gaussianBlur(image, radius: regularRadius)
        let darken = gaussianBlur(image, radius: darkenRadius)
        let darkened = output("CIDarkenBlendMode", image: regular, values: [kCIInputBackgroundImageKey: darken])
        let translucent = output("CIColorMatrix", image: darkened, values: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
        ])
        return output("CISourceOverCompositing", image: translucent, values: [kCIInputBackgroundImageKey: image]).cropped(to: image.extent)
    }

    private static func gaussianBlur(_ image: CIImage, radius: Float) -> CIImage {
        output("CIGaussianBlur", image: image, values: [kCIInputRadiusKey: radius]).cropped(to: image.extent)
    }

    private static func colorOverlay(_ image: CIImage, red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> CIImage {
        let color = CIColor(red: red, green: green, blue: blue, alpha: alpha)
        let overlay = CIImage(color: color).cropped(to: image.extent)
        return output("CISourceOverCompositing", image: overlay, values: [kCIInputBackgroundImageKey: image]).cropped(to: image.extent)
    }

    private static func grain(_ image: CIImage, intensity: Float, seed: Float) -> CIImage {
        // Additive noise follows the documented 0.28 offset and RMS luminance; k=0.08 keeps uncalibrated noise subtle at intensity 1.
        let noiseSource = "kernel vec4 noise(__sample s) { vec2 p = destCoord(); float n = fract(sin(dot(p, vec2(12.9898,78.233)) + \(seed)) * 43758.5453); return vec4(n,n,n,1.0); }"
        guard let noiseKernel = CIColorKernel(source: noiseSource),
              var noise = noiseKernel.apply(extent: image.extent, arguments: [image]) else { return image }
        if seed == 7 { noise = gaussianBlur(noise, radius: 0.35) }
        let grainSource = "kernel vec4 grain(__sample s, __sample n) { float y = max(dot(s.rgb, vec3(0.2126,0.7152,0.0722)), 0.0); float d = (n.r - 0.28) * \(intensity) * 0.08 * sqrt(y); return vec4(s.rgb + d, s.a); }"
        // Legacy CIColorKernel(source:) is used because the formulas need no separate Metal library asset.
        guard let grainKernel = CIColorKernel(source: grainSource) else { return image }
        return grainKernel.apply(extent: image.extent, arguments: [image, noise]) ?? image
    }
}

enum LapseCubeLoader {
    static func load(data: Data) throws -> LUTData {
        guard let text = String(data: data, encoding: .utf8) else { throw LUTError.decompressionFailed }
        var dimension = 0
        var values: [Float] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let first = fields.first else { continue }
            if first == "LUT_3D_SIZE", fields.count == 2, let size = Int(fields[1]) {
                dimension = size
            } else if fields.count == 3, Float(fields[0]) != nil,
                      let r = Float(fields[0]), let g = Float(fields[1]), let b = Float(fields[2]) {
                values.append(contentsOf: [r, g, b, 1])
            }
        }
        guard dimension > 0, values.count == dimension * dimension * dimension * 4 else {
            throw LUTError.invalidSize(expected: dimension * dimension * dimension * 12, actual: values.count * 4)
        }
        return LUTData(dimension: dimension, rgba: values)
    }
}
