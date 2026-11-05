import CoreImage
import Foundation

/// Core Image reconstructions of the documented Lapse Journal and Photo Default routes.
enum LapseRenderer {
    enum Look { case journal, photoDefault }

    static func render(_ input: CIImage, look: Look, sceneEV: Float,
                       loadLUT: (String) throws -> LUTData) throws -> CIImage {
        switch look {
        case .journal: return try journal(input, sceneEV: sceneEV, loadLUT: loadLUT)
        case .photoDefault: return try photoDefault(input, loadLUT: loadLUT)
        }
    }

    private static func journal(_ image: CIImage, sceneEV: Float,
                                loadLUT: (String) throws -> LUTData) throws -> CIImage {
        var result = image
        result = halation(result)
        result = try lut(result, id: "lapse-v4-03", intensity: 1, loadLUT: loadLUT)
        result = gamma(result, power: 0.9)
        result = exposure(result, ev: journalExposureEV(sceneEV: sceneEV))
        result = faceBalanceAndSkinTone(result)
        result = vibrance(result, amount: 0.4)
        result = highlightShadow(result)
        result = vignette(result, intensity: 1.75, radius: 0.15)
        result = chromaticAberration(result)
        result = globalBlur(result)
        result = gaussianBlur(result, radius: 0.3)
        return grain(result, intensity: max(0, min(2, 1 - 0.05 * sceneEV)))
    }

    static func journalExposureEV(sceneEV: Float) -> Float {
        0.55 + sceneEV * (0.50 - 0.55) / 10
    }

    private static func photoDefault(_ image: CIImage,
                                     loadLUT: (String) throws -> LUTData) throws -> CIImage {
        var result = image
        result = try lut(result, id: "lapse-v4-03", intensity: 0.75, loadLUT: loadLUT)
        result = maskedAdjustments(result)
        result = colorControls(result, contrast: 1, saturation: 1)
        result = vibrance(result, amount: 0.95)
        result = globalBlur(result)
        // CI Bloom approximates the documented Metal halation thresholds and dual-color masks.
        result = bloom(result, radius: 20, intensity: 0.65)
        result = colorOverlay(result, red: 0.56, green: 0.51, blue: 0.45, alpha: 0.13)
        result = adaptiveShadows(result)
        result = vignette(result, intensity: 0.9, radius: 0.95)
        result = chromaticAberration(result)
        result = gaussianBlur(result, radius: 0.5)
        return grain(result, intensity: 0.5)
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
            "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        ])
        guard intensity < 0.999 else { return transformed }
        return output("CIDissolveTransition", image: image, values: [
            kCIInputTargetImageKey: transformed, kCIInputTimeKey: intensity
        ]).cropped(to: image.extent)
    }

    private static func maskedAdjustments(_ image: CIImage) -> CIImage {
        // CIColorControls approximates Metal's mask-interpolated classic adjustments without its masks.
        var result = colorControls(image, contrast: 0.75, saturation: 0.3)
        result = output("CIHighlightShadowAdjust", image: result, values: ["inputShadowAmount": -0.45, "inputHighlightAmount": 0.6])
        return result
    }

    private static func adaptiveShadows(_ image: CIImage) -> CIImage {
        // CIFilter cannot reproduce Lapse's scene-adaptive Metal shadow mask; the documented base intensity is zero.
        return image
    }

    private static func halation(_ image: CIImage) -> CIImage {
        // CIBloom approximates Lapse's proprietary halation masks and color-specific blur composition.
        return bloom(image, radius: 16, intensity: 0.65)
    }

    private static func bloom(_ image: CIImage, radius: Float, intensity: Float) -> CIImage {
        output("CIBloom", image: image, values: [kCIInputRadiusKey: radius, kCIInputIntensityKey: intensity])
    }

    private static func faceBalanceAndSkinTone(_ image: CIImage) -> CIImage {
        // CIColorControls approximates Apple-private CIFaceBalance and SkinToneTwo, which cannot be instantiated publicly.
        let balanced = output("CIColorControls", image: image, values: [kCIInputSaturationKey: 1.0])
        return output("CITemperatureAndTint", image: balanced, values: [
            "inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 6500, y: 0)
        ])
    }

    private static func highlightShadow(_ image: CIImage) -> CIImage {
        // CIHighlightShadowAdjust approximates the documented highlight/shadow color-shift and opacity blend.
        var result = output("CIHighlightShadowAdjust", image: image, values: ["inputHighlightAmount": 1 - 0.95, "inputShadowAmount": 0.15])
        result = output("CIColorControls", image: result, values: [
            kCIInputContrastKey: 0.95, kCIInputSaturationKey: 0.95, kCIInputBrightnessKey: -0.35
        ])
        return result
    }

    private static func vignette(_ image: CIImage, intensity: Float, radius: Float) -> CIImage {
        let extent = image.extent
        let side = max(extent.width, extent.height)
        let centered = image.transformed(by: CGAffineTransform(translationX: (side - extent.width) / 2 - extent.minX,
                                                               y: (side - extent.height) / 2 - extent.minY))
        let effected = output("CIVignette", image: centered, values: [kCIInputIntensityKey: intensity, kCIInputRadiusKey: CGFloat(radius)])
        return effected.transformed(by: CGAffineTransform(translationX: extent.minX - (side - extent.width) / 2,
                                                         y: extent.minY - (side - extent.height) / 2)).cropped(to: extent)
    }

    private static func chromaticAberration(_ image: CIImage) -> CIImage {
        // Channel offsets approximate the private Metal chromatic-aberration kernel and its UV sampling.
        let red = output("CIColorMatrix", image: image, values: [
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ]).transformed(by: CGAffineTransform(translationX: 12.75, y: 0))
        let green = output("CIColorMatrix", image: image, values: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ]).transformed(by: CGAffineTransform(translationX: 6, y: 0))
        let blue = output("CIColorMatrix", image: image, values: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])
        let combined = output("CIAdditionCompositing", image: red, values: [kCIInputBackgroundImageKey: green])
        return output("CIAdditionCompositing", image: combined, values: [kCIInputBackgroundImageKey: blue]).cropped(to: image.extent)
    }

    private static func globalBlur(_ image: CIImage) -> CIImage {
        let regular = gaussianBlur(image, radius: 0.5)
        let darken = gaussianBlur(image, radius: 4)
        let darkened = output("CIDarkenBlendMode", image: regular, values: [kCIInputBackgroundImageKey: darken])
        let translucent = output("CIColorMatrix", image: darkened, values: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.3)
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

    private static func grain(_ image: CIImage, intensity: Float) -> CIImage {
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?.cropped(to: image.extent),
              let blend = CIFilter(name: "CISoftLightBlendMode") else { return image }
        let grainImage = output("CIColorMatrix", image: noise, values: [
            "inputRVector": CIVector(x: CGFloat(intensity * 0.03), y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: CGFloat(intensity * 0.03), y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: CGFloat(intensity * 0.03), y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        blend.setValue(grainImage, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        return blend.outputImage?.cropped(to: image.extent) ?? image
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
