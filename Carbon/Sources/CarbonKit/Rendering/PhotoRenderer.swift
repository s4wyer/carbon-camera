import Metal
import MetalKit
import CoreImage
import Combine
import CryptoKit
import os.log

/// Photo renderer: Applies ToneChain preset pipeline to captured RAW+HEVC photos
/// Implements D-005 render order with CIContext and 3D color cubes for deterministic output.
final class PhotoRenderer: PhotoRendering, @unchecked Sendable {
    static let engineVersion = "ci-metal-tonechain-pure-raw-v1"
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private let loadLUT: (String) throws -> LUTData
    private let colorSpace = CIContextProvider.outputColorSpace
    private let logger = Logger(subsystem: "app.carbon", category: "PhotoRenderer")
    private let renderQueue = DispatchQueue(label: "app.carbon.photo-renderer", qos: .utility)
    
    init?(loadLUT: @escaping (String) throws -> LUTData = { try LUTResources.shared.load(lutID: $0) }) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            Logger(subsystem: "app.carbon", category: "PhotoRenderer")
                .error("Failed to create Metal device/queue")
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.loadLUT = loadLUT
        self.ciContext = CIContext(
            mtlDevice: device,
            options: CIContextProvider.renderingOptions
        )
        
        logger.info("PhotoRenderer initialized with Metal-backed CIContext")
    }
    
    // MARK: - Public API
    
    /// Render a shot with a preset, producing a new revision
    func render(
        shot: Shot,
        preset: PresetDefinition,
        parameters: PresetParameters,
        cancellation: RenderCancellationToken
    ) async throws -> RenderRevision {
        try cancellation.throwIfCancelled()
        return try await withCheckedThrowingContinuation { continuation in
            renderQueue.async { [self] in
                do {
                    let revision = try renderSynchronously(
                        shot: shot,
                        preset: preset,
                        parameters: parameters,
                        cancellation: cancellation
                    )
                    continuation.resume(returning: revision)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func renderSynchronously(
        shot: Shot,
        preset: PresetDefinition,
        parameters: PresetParameters,
        cancellation: RenderCancellationToken
    ) throws -> RenderRevision {
        logger.info("Starting render: shot=\(shot.id), preset=\(preset.presetID)")

        guard let sourceImage = loadSourceImage(shot: shot) else {
            throw RenderError.sourceNotFound
        }
        try cancellation.throwIfCancelled()

        let processedImage = try applyToneChain(
            to: PhotoGeometry.applying(shot.currentRecipe.crop, to: sourceImage),
            parameters: parameters,
            cancellation: cancellation
        )
        try cancellation.throwIfCancelled()

        let outputData = try encodeOutput(processedImage)
        try cancellation.throwIfCancelled()

        let digest = SHA256.hash(data: outputData)
        let hashString = digest.compactMap { String(format: "%02x", $0) }.joined()
        try cancellation.throwIfCancelled()

        let revisionID = UUID()
        let filename = "\(shot.captureID)_\(revisionID.uuidString).heic"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try outputData.write(to: outputURL, options: .atomic)

        let revision = RenderRevision(
            id: revisionID,
            recipeVersionID: shot.currentRecipe.id,
            outputFormat: .heif,
            outputURL: outputURL,
            outputHash: hashString,
            renderingEngine: Self.engineVersion
        )

        logger.info("Render complete: revision=\(revision.id), sha256=\(hashString)")
        return revision
    }
    
    /// Quick preview render (returns CIImage for live metal view)
    func renderPreview(
        image: CIImage,
        parameters: PresetParameters
    ) async throws -> CIImage {
        let sendableImage = UncheckedSendable(image)
        return try await withCheckedThrowingContinuation { continuation in
            renderQueue.async { [self, sendableImage] in
                do {
                    let result = try applyToneChain(
                        to: sendableImage.value,
                        parameters: parameters,
                        cancellation: RenderCancellationToken()
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Source Loading
    
    func loadSourceImage(shot: Shot) -> CIImage? {
        // Prefer the recipe's original, regardless of array order. Do not feed
        // a processed safety image into a RAW recipe while its RAW still exists.
        let stillTypes: [SourceResource.SourceType] = [.rawBayer, .rawAppleProRAW, .processedHEVC, .processedHEIFPlus]
        let preferred = shot.currentRecipe.source
        let types = stillTypes.contains(preferred)
            ? [preferred] + stillTypes.filter { $0 != preferred } : stillTypes
        let journal = CaptureJournal.shared
        for type in types {
            for source in shot.sources where source.type == type {
                if FileManager.default.fileExists(atPath: source.mediaURL.path) {
                    return PhotoGeometry.sourceImage(at: source.mediaURL)
                }
            }
            // Check the original's journal path before trying a different type.
            let ext = [.rawBayer, .rawAppleProRAW].contains(type) ? "dng" : "heic"
            let candidate = journal.fileURL(for: "\(shot.captureID).\(ext)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return PhotoGeometry.sourceImage(at: candidate)
            }
        }
        
        return nil
    }

    // MARK: - D-005 Pipeline Implementation
    
    private func applyToneChain(
        to inputImage: CIImage,
        parameters: PresetParameters,
        cancellation: RenderCancellationToken
    ) throws -> CIImage {
        var current = inputImage
        try cancellation.throwIfCancelled()
        
        // 1. Highlight shoulder in linear light, separate from RAW development.
        current = applyHighlightShoulder(to: current)
        
        // 2. Halation
        if parameters.halationIntensity > 0.001 {
            current = applyHalation(
                to: current,
                radius: parameters.halationRadius,
                intensity: parameters.halationIntensity
            )
        }
        
        // 3. Bloom
        if parameters.bloomAmount > 0.001 {
            current = applyBloom(
                to: current,
                radius: parameters.bloomRadius,
                intensity: parameters.bloomAmount
            )
        }
        
        try cancellation.throwIfCancelled()

        // 4. Vignette (D-005: before the LUT).
        if parameters.vignetteIntensity > 0.001 {
            current = applyVignette(
                to: current,
                intensity: parameters.vignetteIntensity,
                radius: parameters.vignetteRadius
            )
        }

        // 5. 3D LUT. CIColorCubeWithColorSpace handles the conversion between
        // the linear working buffer and the cube's encoded sRGB domain.
        if let lutID = parameters.lutID, !lutID.isEmpty {
            current = try applyLUT(
                to: current,
                lutID: lutID,
                intensity: parameters.lutIntensity,
                cancellation: cancellation
            )
        }

        // 6. Creative exposure and white balance follow the LUT (D-005/007/008).
        if abs(parameters.exposureEV) > 0.001 {
            current = applyExposure(to: current, ev: parameters.exposureEV)
        }
        if abs(parameters.temperatureOffsetK) > 0.1 || abs(parameters.tintOffset) > 0.001 {
            current = applyTemperatureAndTint(
                to: current,
                tempK: parameters.temperatureOffsetK,
                tint: parameters.tintOffset
            )
        }
        
        // 7. Contrast & Saturation
        if abs(parameters.contrast - 1.0) > 0.001 || abs(parameters.saturation - 1.0) > 0.001 {
            current = applyContrastAndSaturation(
                to: current,
                contrast: parameters.contrast,
                saturation: parameters.saturation
            )
        }
        
        // 8. Tone Curve (5-point)
        current = applyCurve(to: current, parameters: parameters)
        
        // 9. Vibrance
        if abs(parameters.vibrance) > 0.001 {
            current = applyVibrance(to: current, amount: parameters.vibrance)
        }
        
        // 10. Per-color HSL
        current = applyHSLAdjustments(to: current, adjustments: parameters.hsl)
        
        try cancellation.throwIfCancelled()

        // 11. Grain
        if parameters.grainAmount > 0.001 {
            current = applyGrain(
                to: current,
                intensity: parameters.grainAmount,
                size: parameters.grainSize
            )
        }
        
        return current
    }
    
    // MARK: - Stage Helpers
    
    private func applyExposure(to image: CIImage, ev: Float) -> CIImage {
        guard let filter = CIFilter(name: "CIExposureAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(ev, forKey: kCIInputEVKey)
        return filter.outputImage ?? image
    }
    
    private func applyTemperatureAndTint(to image: CIImage, tempK: Float, tint: Float) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        let neutral = CIVector(x: 6500, y: 0)
        let target = CIVector(x: CGFloat(6500.0 + tempK), y: CGFloat(tint))
        filter.setValue(neutral, forKey: "inputNeutral")
        filter.setValue(target, forKey: "inputTargetNeutral")
        return filter.outputImage ?? image
    }
    
    private func applyHighlightShoulder(to image: CIImage) -> CIImage {
        // Soft shoulder compression for blown highlights
        guard let filter = CIFilter(name: "CIHighlightShadowAdjust") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.9, forKey: "inputHighlightAmount")
        return filter.outputImage ?? image
    }
    
    private func applyContrastAndSaturation(to image: CIImage, contrast: Float, saturation: Float) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(saturation, forKey: kCIInputSaturationKey)
        return filter.outputImage ?? image
    }
    
    private func applyHalation(to image: CIImage, radius: Float, intensity: Float) -> CIImage {
        guard let bloom = CIFilter(name: "CIBloom") else { return image }
        bloom.setValue(image, forKey: kCIInputImageKey)
        bloom.setValue(radius, forKey: kCIInputRadiusKey)
        bloom.setValue(intensity, forKey: kCIInputIntensityKey)
        guard let bloomImage = bloom.outputImage else { return image }
        
        guard let composite = CIFilter(name: "CIScreenBlendMode") else { return image }
        composite.setValue(bloomImage, forKey: kCIInputImageKey)
        composite.setValue(image, forKey: kCIInputBackgroundImageKey)
        return composite.outputImage ?? image
    }
    
    private func applyBloom(to image: CIImage, radius: Float, intensity: Float) -> CIImage {
        guard let filter = CIFilter(name: "CIBloom") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        return filter.outputImage ?? image
    }
    
    private func applyCurve(to image: CIImage, parameters: PresetParameters) -> CIImage {
        guard let filter = CIFilter(name: "CIToneCurve") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        
        // 5 points: p0(0, black), p1(0.25, shadow), p2(0.5, midtone), p3(0.75, highlight), p4(1.0, white)
        let p0 = CIVector(x: 0.0, y: CGFloat(max(0.0, min(1.0, parameters.curveBlack))))
        let p1 = CIVector(x: 0.25, y: CGFloat(max(0.0, min(1.0, 0.25 + parameters.curveShadow))))
        let p2 = CIVector(x: 0.50, y: CGFloat(max(0.0, min(1.0, 0.50 + parameters.curveMidtone))))
        let p3 = CIVector(x: 0.75, y: CGFloat(max(0.0, min(1.0, 0.75 + parameters.curveHighlight))))
        let p4 = CIVector(x: 1.0, y: CGFloat(max(0.0, min(1.0, 1.0 + parameters.curveWhite))))
        
        filter.setValue(p0, forKey: "inputPoint0")
        filter.setValue(p1, forKey: "inputPoint1")
        filter.setValue(p2, forKey: "inputPoint2")
        filter.setValue(p3, forKey: "inputPoint3")
        filter.setValue(p4, forKey: "inputPoint4")
        
        return filter.outputImage ?? image
    }
    
    private func applyVibrance(to image: CIImage, amount: Float) -> CIImage {
        guard let filter = CIFilter(name: "CIVibrance") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(amount, forKey: "inputAmount")
        return filter.outputImage ?? image
    }
    
    private func applyHSLAdjustments(to image: CIImage, adjustments: [HSLAdjustment]) -> CIImage {
        // Average hue and saturation adjustments across defined channels
        guard !adjustments.isEmpty else { return image }
        var current = image
        
        for adj in adjustments {
            if abs(adj.hue) > 0.001 {
                if let hueFilter = CIFilter(name: "CIHueAdjust") {
                    hueFilter.setValue(current, forKey: kCIInputImageKey)
                    hueFilter.setValue(adj.hue, forKey: kCIInputAngleKey)
                    current = hueFilter.outputImage ?? current
                }
            }
            if abs(adj.saturation - 1.0) > 0.001 {
                if let satFilter = CIFilter(name: "CIColorControls") {
                    satFilter.setValue(current, forKey: kCIInputImageKey)
                    satFilter.setValue(adj.saturation, forKey: kCIInputSaturationKey)
                    current = satFilter.outputImage ?? current
                }
            }
        }
        return current
    }
    
    private func applyVignette(to image: CIImage, intensity: Float, radius: Float) -> CIImage {
        guard let filter = CIFilter(name: "CIVignette") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(intensity, forKey: kCIInputIntensityKey)
        filter.setValue(radius > 0 ? radius : 1.0, forKey: kCIInputRadiusKey)
        return filter.outputImage ?? image
    }
    
    private func applyGrain(to image: CIImage, intensity: Float, size: Float) -> CIImage {
        guard let grainFilter = CIFilter(name: "CIRandomGenerator"),
              let grain = grainFilter.outputImage else { return image }
        
        let transform = CGAffineTransform(scaleX: CGFloat(size), y: CGFloat(size))
        let scaledGrain = grain.transformed(by: transform).cropped(to: image.extent)
        
        guard let matrix = CIFilter(name: "CIColorMatrix") else { return image }
        matrix.setValue(scaledGrain, forKey: kCIInputImageKey)
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        matrix.setValue(CIVector(x: 1, y: 0, z: 0, w: CGFloat(intensity * 0.15)), forKey: "inputAVector")
        guard let translucentGrain = matrix.outputImage else { return image }
        
        guard let blend = CIFilter(name: "CISourceOverCompositing") else { return image }
        blend.setValue(translucentGrain, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        return blend.outputImage ?? image
    }
    
    private func applyLUT(
        to image: CIImage,
        lutID: String,
        intensity: Float = 1.0,
        cancellation: RenderCancellationToken
    ) throws -> CIImage {
        try cancellation.throwIfCancelled()
        let lutData = try loadLUT(lutID)
        try cancellation.throwIfCancelled()
        
        // Halide LUTs expect Apple Log (BT.2020) input.
        // Convert working linear sRGB → linear BT.2020 → Apple Log before sampling.
        // No Fusion and other LUTs expect sRGB gamma input (working linear → sRGB gamma).
        let preparedImage: CIImage
        let needsLinearConversion: Bool
        
        if lutID.hasPrefix("halide-") {
            preparedImage = try applyAppleLogEncoding(to: image)
            needsLinearConversion = true  // LUT outputs sRGB-encoded, but we stay in linear working space
        } else {
            // No Fusion: working linear → sRGB gamma
            preparedImage = image.applyingFilter("CILinearToSRGBToneCurve")
            needsLinearConversion = false  // Already in correct space
        }
        
        let rawData = lutData.rgba.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        
        guard let filter = CIFilter(name: "CIColorCube") else {
            throw RenderError.metalUnavailable
        }
        filter.setValue(lutData.dimension, forKey: "inputCubeDimension")
        filter.setValue(rawData, forKey: "inputCubeData")
        filter.setValue(preparedImage, forKey: kCIInputImageKey)
        
        guard let lutOutput = filter.outputImage else {
            throw RenderError.lutNotFound(lutID)
        }
        
        // Halide LUT output is sRGB-encoded; decode back to linear for rest of pipeline
        let linearOutput = needsLinearConversion
            ? lutOutput.applyingFilter("CISRGBToneCurveToLinear")
            : lutOutput
        
        // If intensity < 1.0, blend back with input
        if intensity < 0.999 {
            guard let blend = CIFilter(name: "CIDissolveTransition") else { return linearOutput }
            blend.setValue(image, forKey: kCIInputImageKey)
            blend.setValue(linearOutput, forKey: kCIInputTargetImageKey)
            blend.setValue(intensity, forKey: kCIInputTimeKey)
            return blend.outputImage ?? linearOutput
        }
        
        return linearOutput
    }
    
    /// Convert working linear sRGB to Apple Log (BT.2020 primaries).
    /// Apple Log formula: R0=-0.05641088, Rt=0.01, c=47.28711236,
    /// beta=0.00964052, gamma=0.08550479, delta=0.69336945.
    /// P = c*(R-R0)^2 for R0<=R<Rt, else gamma*log2(R+beta)+delta.
    private func applyAppleLogEncoding(to image: CIImage) throws -> CIImage {
        // 1. sRGB linear → BT.2020 linear (3x3 matrix)
        guard let matrixFilter = CIFilter(name: "CIColorMatrix") else {
            throw RenderError.metalUnavailable
        }
        matrixFilter.setValue(image, forKey: kCIInputImageKey)
        // Matrix: sRGB (D65) → XYZ → BT.2020 (D65)
        // Combined matrix (row vectors: R, G, B, bias)
        matrixFilter.setValue(CIVector(x:  0.627402, y: 0.329292, z: 0.043306, w: 0), forKey: "inputRVector")
        matrixFilter.setValue(CIVector(x:  0.069095, y: 0.919544, z: 0.011360, w: 0), forKey: "inputGVector")
        matrixFilter.setValue(CIVector(x:  0.016394, y: 0.088028, z: 0.895578, w: 0), forKey: "inputBVector")
        matrixFilter.setValue(CIVector(x:  0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        matrixFilter.setValue(CIVector(x:  0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
        
        guard let bt2020Linear = matrixFilter.outputImage else {
            throw RenderError.metalUnavailable
        }
        
        // 2. Apply Apple Log transfer function via CIColorKernel
        let kernel = try CIColorKernel(source: """
            kernel vec4 appleLogOETF(__sample pixel) {
                const float R0 = -0.05641088;
                const float Rt = 0.01;
                const float c = 47.28711236;
                const float beta = 0.00964052;
                const float gamma = 0.08550479;
                const float delta = 0.69336945;
                
                vec3 R = pixel.rgb;
                vec3 P;
                
                for (int i = 0; i < 3; i++) {
                    if (R[i] < R0) {
                        P[i] = 0.0;
                    } else if (R[i] < Rt) {
                        float d = R[i] - R0;
                        P[i] = c * d * d;
                    } else {
                        P[i] = gamma * log2(R[i] + beta) + delta;
                    }
                }
                
                return vec4(P, pixel.a);
            }
            """)
        
        guard let appleLogImage = kernel.apply(extent: bt2020Linear.extent, arguments: [bt2020Linear]) else {
            throw RenderError.metalUnavailable
        }
        
        return appleLogImage
    }
    
    private func encodeOutput(_ image: CIImage) throws -> Data {
        // Try HEIF first
        if let heifData = ciContext.heifRepresentation(
            of: image,
            format: .RGBA8,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95]
        ) {
            return heifData
        }
        
        // Fallback to JPEG
        if let jpegData = ciContext.jpegRepresentation(
            of: image,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95]
        ) {
            return jpegData
        }
        
        throw RenderError.encodingFailed
    }
}

// MARK: - Errors

enum RenderError: Error, LocalizedError {
    case sourceNotFound
    case metalUnavailable
    case encodingFailed
    case lutNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .sourceNotFound: return "Source image (RAW or HEVC) could not be located"
        case .metalUnavailable: return "Metal device or shader unavailable"
        case .encodingFailed: return "Failed to encode rendered image to HEIF/JPEG"
        case .lutNotFound(let id): return "LUT resource '\(id)' could not be loaded"
        }
    }
}
