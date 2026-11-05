import CoreImage
import UniformTypeIdentifiers

/// Carbon's ungraded negative, before the D-005 shoulder and creative stages.
/// Authority: D-002/D-004 and HALIDE-IPA-TECHNICAL-PACKAGE.md, section 1.
/// This reproduces the recovered pure-RAW controls, not Halide's unrecovered
/// demosaic internals or its optional Exposure Fusion/MTF/grade branches.
enum RAWDevelopment {
    static func isRAW(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "dng"
            || UTType(filenameExtension: url.pathExtension)?.conforms(to: .rawImage) == true
    }

    static func filter(at url: URL) -> CIRAWFilter? {
        // CIRAWFilter can initialize a generic, zero-sized filter even when
        // ImageIO cannot decode the file. Reject it before configuring/scaling.
        guard let raw = CIRAWFilter(imageURL: url),
              raw.nativeSize.width.isFinite, raw.nativeSize.width > 0,
              raw.nativeSize.height.isFinite, raw.nativeSize.height > 0 else { return nil }
        configure(raw)
        return raw
    }

    static func configure(_ raw: CIRAWFilter) {
        // D-007: keep the decoder's camera baseline calibration. There is no
        // histogram auto-brightening or per-scene middle-gray normalization.
        // The recovered notes do not establish a universal gray-card code value.
        if !raw.baselineExposure.isFinite { raw.baselineExposure = 0 }
        raw.exposure = 0
        raw.boostAmount = 0
        raw.boostShadowAmount = 0
        raw.shadowBias = 0
        raw.extendedDynamicRangeAmount = 0
        raw.isGamutMappingEnabled = false
        raw.isDraftModeEnabled = false
        raw.scaleFactor = 1
        raw.linearSpaceFilter = nil

        if raw.isSharpnessSupported { raw.sharpnessAmount = 0 }
        if raw.isContrastSupported { raw.contrastAmount = 0 }
        if raw.isDetailSupported { raw.detailAmount = 0 }
        if raw.isColorNoiseReductionSupported { raw.colorNoiseReductionAmount = 0 }
        if raw.isLuminanceNoiseReductionSupported { raw.luminanceNoiseReductionAmount = 0 }
        if raw.isMoireReductionSupported { raw.moireReductionAmount = 0 }
        if raw.isLocalToneMapSupported { raw.localToneMapAmount = 0 }
        if raw.isLensCorrectionSupported { raw.isLensCorrectionEnabled = false }

        // Older decoder controls still exposed through CIFilter. Never send an
        // unsupported KVC key: available inputs vary by camera and decoder.
        let pureRAWOptions: [CIRAWFilterOption: Any] = [
            .enableSharpening: false,
            .enableChromaticNoiseTracking: false,
            .noiseReductionAmount: 0,
            .noiseReductionSharpnessAmount: 0,
            .noiseReductionContrastAmount: 0,
            .noiseReductionDetailAmount: 0
        ]
        for (option, value) in pureRAWOptions where raw.inputKeys.contains(option.rawValue) {
            raw.setValue(value, forKey: option.rawValue)
        }

        // Leave the decoder's as-shot camera white balance intact. EXIF's
        // WhiteBalance field is an auto/manual flag, not a Kelvin temperature.
        // D-008 specifies 4000 K / zero tint only for invalid neutral values.
        if !raw.neutralTemperature.isFinite || !(2000...50000).contains(raw.neutralTemperature)
            || !raw.neutralTint.isFinite || !(-150...150).contains(raw.neutralTint) {
            raw.neutralTemperature = 4000
            raw.neutralTint = 0
        }
        // CIRAWFilter applies its metadata orientation; do not orient it twice.
    }
}
