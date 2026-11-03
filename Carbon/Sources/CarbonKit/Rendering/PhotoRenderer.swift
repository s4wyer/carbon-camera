import Metal
import MetalKit
import CoreImage
import os.log

/// Photo renderer: Applies ToneChain preset pipeline to captured RAW+HEVC photos
/// Implements D-005 render order with Metal compute shaders for real-time performance
@MainActor
final class PhotoRenderer: NSObject, ObservableObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private let logger = Logger(subsystem: "app.carbon", category: "PhotoRenderer")
    
    // Metal compute pipeline
    private var toneChainPipeline: MTLComputePipelineState?
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            logger.error("Failed to create Metal device/queue")
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlDevice: device)
        
        super.init()
        
        setupPipeline()
    }
    
    private func setupPipeline() {
        // TODO SET05: Compile Metal shader library
        // For now, use CoreImage filters as fallback
        logger.info("PhotoRenderer initialized with CoreImage fallback")
    }
    
    // MARK: - Public API
    
    /// Render a shot with a preset, producing a new revision
    func render(
        shot: Shot,
        preset: PresetDefinition,
        parameters: PresetParameters
    ) async throws -> RenderRevision {
        logger.info("Starting render: shot=\(shot.id), preset=\(preset.id)")
        
        // Load source resources (RAW or HEVC)
        guard let sourceImage = try await loadSourceImage(shot: shot) else {
            throw RenderError.sourceNotFound
        }
        
        // Apply ToneChain pipeline
        let processedImage = try await applyToneChain(
            to: sourceImage,
            parameters: parameters
        )
        
        // Encode to HEVC
        let outputData = try await encodeOutput(processedImage)
        
        // Create render revision
        let revision = RenderRevision(
            id: UUID().uuidString,
            shotID: shot.id,
            recipeVersionID: preset.id + "-v1",  // TODO: proper versioning
            renderTimestamp: Date(),
            outputResourceID: UUID().uuidString,  // TODO: save to storage
            renderTimeMs: 0  // TODO: measure
        )
        
        logger.info("Render complete: revision=\(revision.id)")
        return revision
    }
    
    /// Quick preview render (lower quality, faster)
    func renderPreview(
        image: CIImage,
        parameters: PresetParameters
    ) async throws -> CIImage {
        return try await applyToneChain(to: image, parameters: parameters)
    }
    
    // MARK: - Pipeline implementation
    
    private func loadSourceImage(shot: Shot) async throws -> CIImage? {
        // TODO SET04: Load from persistent storage
        // For now, return nil (will be wired up with PHPhotoLibrary)
        logger.warning("Source image loading not yet implemented")
        return nil
    }
    
    private func applyToneChain(
        to inputImage: CIImage,
        parameters: PresetParameters
    ) async throws -> CIImage {
        var image = inputImage
        
        // D-005 render order:
        // geometry → RAW → shoulder → halation → bloom → LUT → 
        // exposure → temp-tint → contrast-sat → curve → vibrance → HSL → grain → overlays
        
        // 1. Geometry (crop, rotation) - skip for now
        
        // 2. RAW decode - input is already decoded CIImage
        
        // 3. Shoulder (highlight rolloff)
        if parameters.highlights != 0.0 {
            image = applyHighlightRolloff(to: image, amount: parameters.highlights)
        }
        
        // 4. Halation (glow around highlights)
        if parameters.halationIntensity > 0.0 {
            image = applyHalation(
                to: image,
                radius: parameters.halationRadius,
                intensity: parameters.halationIntensity
            )
        }
        
        // 5. Bloom (bright-region glow)
        if parameters.bloomIntensity > 0.0 {
            image = applyBloom(
                to: image,
                radius: parameters.bloomRadius,
                intensity: parameters.bloomIntensity
            )
        }
        
        // 6. LUT (color grading lookup table)
        if let lutID = parameters.lutID {
            image = try await applyLUT(to: image, lutID: lutID)
        }
        
        // 7. Exposure
        if parameters.exposureEV != 0.0 {
            image = applyExposure(to: image, ev: parameters.exposureEV)
        }
        
        // 8. Temperature & Tint
        if parameters.temperatureShift != 0 || parameters.tintShift != 0 {
            image = applyWhiteBalance(
                to: image,
                temperature: parameters.temperatureShift,
                tint: parameters.tintShift
            )
        }
        
        // 9. Contrast & Saturation
        if parameters.contrast != 1.0 || parameters.saturation != 1.0 {
            image = applyContrastSaturation(
                to: image,
                contrast: parameters.contrast,
                saturation: parameters.saturation
            )
        }
        
        // 10. Curve (custom tone curve)
        if let curve = parameters.curve {
            image = applyCurve(to: image, curve: curve)
        }
        
        // 11. Vibrance (smart saturation)
        if parameters.vibrance != 0.0 {
            image = applyVibrance(to: image, amount: parameters.vibrance)
        }
        
        // 12. HSL adjustments (hue/sat/lum per color)
        if !parameters.hslAdjustments.isEmpty {
            image = applyHSLAdjustments(to: image, adjustments: parameters.hslAdjustments)
        }
        
        // 13. Grain (film texture)
        if parameters.grainIntensity > 0.0 {
            image = applyGrain(
                to: image,
                intensity: parameters.grainIntensity,
                size: parameters.grainSize
            )
        }
        
        // 14. Overlays (vignette, borders) - skip for now
        
        return image
    }
    
    // MARK: - Individual effects (CoreImage fallback)
    
    private func applyExposure(to image: CIImage, ev: Float) -> CIImage {
        let filter = CIFilter(name: "CIExposureAdjust")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(ev, forKey: kCIInputEVKey)
        return filter.outputImage ?? image
    }
    
    private func applyWhiteBalance(to image: CIImage, temperature: Int, tint: Int) -> CIImage {
        let filter = CIFilter(name: "CITemperatureAndTint")!
        filter.setValue(image, forKey: kCIInputImageKey)
        
        // Map temperature shift to CIVector (approximate)
        let tempVector = CIVector(x: 6500 + CGFloat(temperature), y: 0)
        let tintVector = CIVector(x: 0, y: CGFloat(tint))
        
        filter.setValue(tempVector, forKey: "inputNeutral")
        filter.setValue(tintVector, forKey: "inputTargetNeutral")
        
        return filter.outputImage ?? image
    }
    
    private func applyContrastSaturation(to image: CIImage, contrast: Float, saturation: Float) -> CIImage {
        var result = image
        
        // Contrast
        if contrast != 1.0 {
            let contrastFilter = CIFilter(name: "CIColorControls")!
            contrastFilter.setValue(result, forKey: kCIInputImageKey)
            contrastFilter.setValue(contrast, forKey: kCIInputContrastKey)
            result = contrastFilter.outputImage ?? result
        }
        
        // Saturation
        if saturation != 1.0 {
            let satFilter = CIFilter(name: "CIColorControls")!
            satFilter.setValue(result, forKey: kCIInputImageKey)
            satFilter.setValue(saturation, forKey: kCIInputSaturationKey)
            result = satFilter.outputImage ?? result
        }
        
        return result
    }
    
    private func applyHighlightRolloff(to image: CIImage, amount: Float) -> CIImage {
        // Approximate with highlight/shadow filter
        let filter = CIFilter(name: "CIHighlightShadowAdjust")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.0 + amount, forKey: "inputHighlightAmount")
        return filter.outputImage ?? image
    }
    
    private func applyHalation(to image: CIImage, radius: Float, intensity: Float) -> CIImage {
        // Halation = bloom on highlights only
        guard let bloom = CIFilter(name: "CIBloom") else { return image }
        bloom.setValue(image, forKey: kCIInputImageKey)
        bloom.setValue(radius, forKey: kCIInputRadiusKey)
        bloom.setValue(intensity, forKey: kCIInputIntensityKey)
        
        guard let bloomImage = bloom.outputImage else { return image }
        
        // Blend with original
        let composite = CIFilter(name: "CIAdditionCompositing")!
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
    
    private func applyCurve(to image: CIImage, curve: ToneCurve) -> CIImage {
        // TODO: Implement custom curve with CIColorCurves or Metal shader
        logger.warning("Custom curve not yet implemented")
        return image
    }
    
    private func applyVibrance(to image: CIImage, amount: Float) -> CIImage {
        let filter = CIFilter(name: "CIVibrance")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(amount, forKey: "inputAmount")
        return filter.outputImage ?? image
    }
    
    private func applyHSLAdjustments(to image: CIImage, adjustments: [HSLAdjustment]) -> CIImage {
        // TODO: Implement HSL per-color adjustments with CIHueAdjust + masking
        logger.warning("HSL adjustments not yet implemented")
        return image
    }
    
    private func applyGrain(to image: CIImage, intensity: Float, size: Float) -> CIImage {
        // Generate procedural grain texture
        let grainFilter = CIFilter(name: "CIRandomGenerator")!
        guard var grain = grainFilter.outputImage else { return image }
        
        // Scale grain to match image size
        let scaleFilter = CIFilter(name: "CIAffineTransform")!
        let transform = CGAffineTransform(scaleX: CGFloat(size), y: CGFloat(size))
        scaleFilter.setValue(grain, forKey: kCIInputImageKey)
        scaleFilter.setValue(NSValue(cgAffineTransform: transform), forKey: kCIInputTransformKey)
        grain = scaleFilter.outputImage ?? grain
        
        // Crop to image extent
        grain = grain.cropped(to: image.extent)
        
        // Blend with original
        let blendFilter = CIFilter(name: "CIAdditionCompositing")!
        blendFilter.setValue(grain, forKey: kCIInputImageKey)
        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        guard let blended = blendFilter.outputImage else { return image }
        
        // Reduce opacity based on intensity
        let opacityFilter = CIFilter(name: "CIColorMatrix")!
        opacityFilter.setValue(blended, forKey: kCIInputImageKey)
        opacityFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        opacityFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        opacityFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        opacityFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity)), forKey: "inputAVector")
        
        return opacityFilter.outputImage ?? image
    }
    
    private func applyLUT(to image: CIImage, lutID: String) async throws -> CIImage {
        // TODO SET05: Load 3D LUT cube file
        logger.warning("LUT application not yet implemented")
        return image
    }
    
    private func encodeOutput(_ image: CIImage) async throws -> Data {
        // TODO SET04: Encode to HEVC with proper quality settings
        logger.warning("Output encoding not yet implemented")
        return Data()
    }
}

// MARK: - Errors

enum RenderError: Error {
    case sourceNotFound
    case metalUnavailable
    case encodingFailed
    case lutNotFound(String)
}
