// SET06c — Capture mode and timing reference
// Sourced from Lapse SET §1 (session configuration, focus/exposure, dimensions, codecs, quality)
// and Lapse SET §2 (capture metadata tuple).
// Overrides documented per D-002 (35mm default, auto flash, zero sharpening, HEVC+RAW).

import Foundation
import AVFoundation
import CoreMedia

/// First-class capture mode configuration.
/// Authority: Lapse SET §1 (baseline) + D-002 (Carbon portrait overrides).
public struct CaptureModePreset: Codable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let sessionPresetRaw: String
    
    // Audio session flags (Lapse SET §1)
    public let usesApplicationAudioSession: Bool
    public let automaticallyConfiguresApplicationAudioSession: Bool
    public let configuresApplicationAudioSessionToMixWithOthers: Bool
    public let automaticallyConfiguresCaptureDeviceForWideColor: Bool
    
    // Focus and exposure (Lapse SET §1: centered continuous point (0.5, 0.5))
    public let defaultFocusPointOfInterest: CGPoint
    public let defaultExposurePointOfInterest: CGPoint
    public let enablesLowLightBoost: Bool
    public let enablesSmoothAutoFocus: Bool
    
    // Quality & codecs (Lapse SET §1 + D-002)
    public let preferredCodec: String
    public let enablesRAWCapture: Bool
    public let qualityPrioritizationRaw: Int // 1 = speed, 2 = balanced, 3 = quality
    
    // Framing & optics (D-002 override: 35mm default)
    public let defaultFocalLengthEquivalentMM: Double
    public let defaultFlashModeRaw: Int // 0 = off, 1 = on, 2 = auto (D-002: auto)
    
    // Software sharpening override (D-002: 0.0, disabled)
    public let softwareSharpeningAmount: Float
    
    public init(
        id: String,
        displayName: String,
        sessionPresetRaw: String = "AVCaptureSessionPresetInputPriority",
        usesApplicationAudioSession: Bool = true,
        automaticallyConfiguresApplicationAudioSession: Bool = false,
        configuresApplicationAudioSessionToMixWithOthers: Bool = true,
        automaticallyConfiguresCaptureDeviceForWideColor: Bool = false,
        defaultFocusPointOfInterest: CGPoint = CGPoint(x: 0.5, y: 0.5),
        defaultExposurePointOfInterest: CGPoint = CGPoint(x: 0.5, y: 0.5),
        enablesLowLightBoost: Bool = true,
        enablesSmoothAutoFocus: Bool = true,
        preferredCodec: String = "hevc",
        enablesRAWCapture: Bool = true,
        qualityPrioritizationRaw: Int = 3, // .quality
        defaultFocalLengthEquivalentMM: Double = 35.0,
        defaultFlashModeRaw: Int = 2, // .auto
        softwareSharpeningAmount: Float = 0.0
    ) {
        self.id = id
        self.displayName = displayName
        self.sessionPresetRaw = sessionPresetRaw
        self.usesApplicationAudioSession = usesApplicationAudioSession
        self.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
        self.configuresApplicationAudioSessionToMixWithOthers = configuresApplicationAudioSessionToMixWithOthers
        self.automaticallyConfiguresCaptureDeviceForWideColor = automaticallyConfiguresCaptureDeviceForWideColor
        self.defaultFocusPointOfInterest = defaultFocusPointOfInterest
        self.defaultExposurePointOfInterest = defaultExposurePointOfInterest
        self.enablesLowLightBoost = enablesLowLightBoost
        self.enablesSmoothAutoFocus = enablesSmoothAutoFocus
        self.preferredCodec = preferredCodec
        self.enablesRAWCapture = enablesRAWCapture
        self.qualityPrioritizationRaw = qualityPrioritizationRaw
        self.defaultFocalLengthEquivalentMM = defaultFocalLengthEquivalentMM
        self.defaultFlashModeRaw = defaultFlashModeRaw
        self.softwareSharpeningAmount = softwareSharpeningAmount
    }
    
    /// Default capture preset: Carbon Natural Lens (D-002 baseline with overrides)
    public static let carbonDefault = CaptureModePreset(
        id: "carbon-natural-capture",
        displayName: "Natural (35mm)",
        defaultFocalLengthEquivalentMM: 35.0,
        defaultFlashModeRaw: 2,
        softwareSharpeningAmount: 0.0
    )
    
    /// Pure Lapse baseline (for comparison fixture / reference route)
    public static let lapseBaseline = CaptureModePreset(
        id: "lapse-baseline-capture",
        displayName: "Lapse Reference",
        sessionPresetRaw: "AVCaptureSessionPresetInputPriority",
        enablesRAWCapture: false,
        qualityPrioritizationRaw: 3,
        defaultFocalLengthEquivalentMM: 28.0, // wide native
        defaultFlashModeRaw: 0, // off
        softwareSharpeningAmount: 0.5
    )
}
