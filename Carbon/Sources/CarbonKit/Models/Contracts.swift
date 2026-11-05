// SET02 — Frozen product boundaries and engineering contracts.
// All records below are immutable per app version.
// See docs/decisions/D-002 through D-023 for derivation and authority.

import Foundation
import CoreMedia

// MARK: - Immutable records (SET02)

/// Durable shot record. One logical asset: primary still + optional motion/depth/alternates.
public struct Shot: Codable, Identifiable {
    public let id: UUID
    public let captureID: String  // Stable across re-edit (matches SourceResource)
    public let timestamp: Date
    
    /// Source resources: RAW data, processed HEIF, video companion, etc.
    public let sources: [SourceResource]
    
    /// Development path and current rendering output.
    public let currentRecipe: RecipeVersion
    public let currentRender: RenderRevision?  // nil = not yet rendered
    
    /// Metadata preserved from capture (no PII inferrable from here).
    public struct CaptureMetadata: Codable {
        public let temperature: Float  // Kelvin, or 4000 if invalid
        public let tint: Float  // Neutral offset, or 0 if invalid
        public let iso: Float
        public let exposureDuration: CMTime
        public let sceneEV: Float  // log2(aperture² / ((ISO/100)*seconds))
        public let flashState: FlashState
        public let lensPosition: Float  // 0.0 to 1.0
        public let orientation: Int  // EXIF orientation 1–8
        public init(temperature: Float, tint: Float, iso: Float, exposureDuration: CMTime,
                    sceneEV: Float, flashState: FlashState, lensPosition: Float, orientation: Int) {
            self.temperature = temperature
            self.tint = tint
            self.iso = iso
            self.exposureDuration = exposureDuration
            self.sceneEV = sceneEV
            self.flashState = flashState
            self.lensPosition = lensPosition
            self.orientation = orientation
        }

        private enum CodingKeys: String, CodingKey {
            case temperature
            case tint
            case iso
            case exposureDuration
            case sceneEV
            case flashState
            case lensPosition
            case orientation
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.temperature = try container.decode(Float.self, forKey: .temperature)
            self.tint = try container.decode(Float.self, forKey: .tint)
            self.iso = try container.decode(Float.self, forKey: .iso)
            self.exposureDuration = try container.decode(CMTime.self, forKey: .exposureDuration)
            self.sceneEV = try container.decode(Float.self, forKey: .sceneEV)
            self.flashState = try container.decode(FlashState.self, forKey: .flashState)
            self.lensPosition = try container.decode(Float.self, forKey: .lensPosition)
            self.orientation = try container.decode(Int.self, forKey: .orientation)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(temperature, forKey: .temperature)
            try container.encode(tint, forKey: .tint)
            try container.encode(iso, forKey: .iso)
            try container.encode(exposureDuration, forKey: .exposureDuration)
            try container.encode(sceneEV, forKey: .sceneEV)
            try container.encode(flashState, forKey: .flashState)
            try container.encode(lensPosition, forKey: .lensPosition)
            try container.encode(orientation, forKey: .orientation)
        }
    }
    public let captureMetadata: CaptureMetadata
    
    /// User ratings/flags.
    public let rating: Int? = nil  // 0-5 stars, nil = unrated
    public let userFlags: Set<String> = []  // "favorite", "rejects", "archived"
    
    /// Edit history: list of RecipeVersion changes, immutable chain.
    public let recipeHistory: [RecipeVersion] = []
    
    public enum FlashState: String, Codable {
        case auto, on, off
    }
    
    public init(id: UUID = UUID(),
                captureID: String,
                timestamp: Date,
                sources: [SourceResource],
                currentRecipe: RecipeVersion,
                captureMetadata: CaptureMetadata) {
        self.id = id
        self.captureID = captureID
        self.timestamp = timestamp
        self.sources = sources
        self.currentRecipe = currentRecipe
        self.currentRender = nil
        self.captureMetadata = captureMetadata
    }
}

/// Immutable source data reference. Multiple sources (RAW, processed fallback, motion) link to one Shot.
public struct SourceResource: Codable, Identifiable {
    public let id: UUID
    public let captureID: String  // Stable; matches Shot.captureID
    public let type: SourceType
    public let mediaURL: URL  // Local filesystem path
    public let mediaHash: String  // SHA-256 of media bytes; integrity check
    public let provenance: Provenance
    
    public enum SourceType: String, Codable {
        case rawBayer  // DNG Bayer RAW
        case rawAppleProRAW  // Apple ProRAW (computational)
        case processedHEVC  // HEVC fallback
        case processedHEIFPlus  // HEIF+ rasterization (No Fusion pipeline)
        case motionCompanion  // H.264 or ProRes video, Live Photo compatible
        case depthAuxiliary  // Depth/disparity map (generated or captured)
        case portraitMatte  // Portrait effects matte
    }
    
    public struct Provenance: Codable {
        public let engine: String  // "halide-raw", "lapse-hevc", "nofusion-heifplus", "generated-depth"
        public let version: String  // Engine version (commit hash or semantic version)
        public let timestamp: Date  // When this source was created
        public let isUserEditable: Bool  // true = user can re-grade/export; false = derived/fallback
    }
    
    public init(id: UUID = UUID(),
                captureID: String,
                type: SourceType,
                mediaURL: URL,
                mediaHash: String,
                provenance: Provenance) {
        self.id = id
        self.captureID = captureID
        self.type = type
        self.mediaURL = mediaURL
        self.mediaHash = mediaHash
        self.provenance = provenance
    }
}

/// Immutable recipe: processing parameters that, combined with a source, produce a render.
/// Same engine + source + recipe version + seed = reproducible render.
public struct RecipeVersion: Codable, Identifiable {
    public let id: UUID
    public let recipeID: String  // Stable; reusable preset reference or unique custom recipe
    public let presetDefinitionID: UUID  // Reference to the PresetDefinition used as base
    public let engineVersion: String  // Rendering engine commit/version
    public let source: SourceResource.SourceType  // Which source type is expected input
    
    /// Immutable parameter snapshot at creation time.
    public struct Parameters: Codable {
        // All-effects strengths (roadmap §6 requires durable contracts, no silent changes)
        public let filmPreset: String  // Name reference, or ID
        public let filmStrength: Float  // 0..1, scales all film effects
        public let exposureEV: Float  // Stops, applied post-LUT
        public let temperatureK: Float  // Kelvin offset (to neutral + this)
        public let tintOffset: Float  // Applied in CITemperatureAndTint units
        public let contrastAmount: Float  // 1.0 = neutral, <1 = reduced
        public let saturationAmount: Float  // 1.0 = neutral
        // ... grain, halation, vignette, etc. (see RecipeDefinition below)
    }
    public let parameters: Parameters
    
    /// Random seed for grain, dust, light-leaks (if applicable).
    public let grainSeed: UInt32
    
    /// Crop and straighten applied at render time (immutable per recipe).
    public struct Crop: Codable {
        public let sourceNormalized: CGRect  // 0..1 in source image space
        public let rotation: Float  // Degrees, applied before source crop
        public let straightenAngle: Float  // -45..+45 degrees, applied before rotation
    }
    public let crop: Crop?
    
    /// Marks whether re-editing is possible (true = source is mutable and editable; false = render-only).
    public let isEditable: Bool
    
    public init(id: UUID = UUID(),
                recipeID: String,
                presetDefinitionID: UUID,
                engineVersion: String,
                source: SourceResource.SourceType,
                parameters: Parameters,
                grainSeed: UInt32 = 0,
                isEditable: Bool = true) {
        self.id = id
        self.recipeID = recipeID
        self.presetDefinitionID = presetDefinitionID
        self.engineVersion = engineVersion
        self.source = source
        self.parameters = parameters
        self.grainSeed = grainSeed
        self.crop = nil
        self.isEditable = isEditable
    }
}

/// Immutable rendered output. Multiple RenderRevisions can share one RecipeVersion (e.g., JPEG + PNG export).
public struct RenderRevision: Codable, Identifiable {
    public let id: UUID
    public let recipeVersionID: UUID  // Immutable reference to the recipe
    public let outputFormat: OutputFormat
    public let outputURL: URL  // Local file path
    public let outputHash: String  // SHA-256; integrity check
    public let renderingEngine: String  // "ci-journal", "metal-photo", etc.
    public let renderTimestamp: Date
    
    public enum OutputFormat: String, Codable {
        case jpeg
        case heif
        case heifPlus  // HEIF with embedded RAW (if available)
        case dng  // DNG + JSON sidecar
        case proRes  // For motion
    }
    
    public init(id: UUID = UUID(),
                recipeVersionID: UUID,
                outputFormat: OutputFormat,
                outputURL: URL,
                outputHash: String,
                renderingEngine: String) {
        self.id = id
        self.recipeVersionID = recipeVersionID
        self.outputFormat = outputFormat
        self.outputURL = outputURL
        self.outputHash = outputHash
        self.renderingEngine = renderingEngine
        self.renderTimestamp = Date()
    }
}

/// Immutable development job. Maps to one or more render outputs.
public struct DevelopmentJob: Codable, Identifiable {
    public let id: UUID
    public let shotID: UUID
    public let recipeVersionID: UUID
    public let status: JobStatus
    public let createdAt: Date
    public let completedAt: Date?
    
    public enum JobStatus: String, Codable {
        case queued, inProgress, completed, failed, paused
    }
    
    public struct Checkpoint: Codable {
        public let stage: String  // "decode", "linearize", "white-balance", "grade", "halation", "grain", "export"
        public let progress: Float  // 0..1
        public let timestamp: Date
    }
    public let checkpoints: [Checkpoint] = []
    
    public init(id: UUID = UUID(),
                shotID: UUID,
                recipeVersionID: UUID,
                status: JobStatus = .queued) {
        self.id = id
        self.shotID = shotID
        self.recipeVersionID = recipeVersionID
        self.status = status
        self.createdAt = Date()
        self.completedAt = nil
    }
}

/// Immutable preset definition. Sourced from Halide, Lapse, or No Fusion (cited); or marked original with rationale.
public struct PresetDefinition: Codable, Identifiable, Equatable {
    public let id: UUID
    public let presetID: String  // e.g., "halide-zephyr", "nofusion-nn", "carbon-natural"
    public let displayName: String  // Plain language, predicted-by-user rule
    public let description: String  // One sentence, one obvious promise
    public let source: PresetSource
    
    public enum PresetSource: Codable, Equatable {
        case halideReference(lookName: String, section: String)  // e.g. "zephyr", "H§2"
        case lapseReference(factoryName: String, section: String)  // e.g. "journal", "L§5"
        case nofusionReference(presetFileID: String, section: String)  // e.g. "NN", "N§3"
        case original(rationale: String)  // Why this preset exists; links to a decision doc
    }
    
    /// Base parameters from the reference, or neutral defaults if original.
    public let baseParameters: PresetParameters
    
    /// Our deltas from base (empty if = original).
    public struct Delta: Codable, Equatable {
        public let field: String
        public let originalValue: Float
        public let carbonValue: Float
        public let rationale: String  // Why we changed it
    }
    public let carbonDeltas: [Delta]
    
    /// Rendering engine version at creation (for reproducibility).
    public let engineVersion: String
    
    /// Order hint for UI (0 = first/default).
    public let displayOrder: Int
    /// Stable catalog number printed on Stock artwork. It is independent of array order.
    public let catalogNumber: Int
    
    public init(id: UUID = UUID(),
                presetID: String,
                displayName: String,
                description: String,
                source: PresetSource,
                baseParameters: PresetParameters,
                carbonDeltas: [Delta] = [],
                engineVersion: String,
                displayOrder: Int,
                catalogNumber: Int? = nil) {
        self.id = id
        self.presetID = presetID
        self.displayName = displayName
        self.description = description
        self.source = source
        self.baseParameters = baseParameters
        self.carbonDeltas = carbonDeltas
        self.engineVersion = engineVersion
        self.displayOrder = displayOrder
        self.catalogNumber = catalogNumber ?? max(1, displayOrder % 100 + 1)
    }

    private enum CodingKeys: String, CodingKey {
        case id, presetID, displayName, description, source, baseParameters
        case carbonDeltas, engineVersion, displayOrder, catalogNumber
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        presetID = try values.decode(String.self, forKey: .presetID)
        displayName = try values.decode(String.self, forKey: .displayName)
        description = try values.decode(String.self, forKey: .description)
        source = try values.decode(PresetSource.self, forKey: .source)
        baseParameters = try values.decode(PresetParameters.self, forKey: .baseParameters)
        carbonDeltas = try values.decode([Delta].self, forKey: .carbonDeltas)
        engineVersion = try values.decode(String.self, forKey: .engineVersion)
        displayOrder = try values.decode(Int.self, forKey: .displayOrder)
        catalogNumber = try values.decodeIfPresent(Int.self, forKey: .catalogNumber)
            ?? max(1, displayOrder % 100 + 1)
    }
}

/// Immutable default camera configuration (Lapse baseline + overrides, D-002).
public struct CameraDefaultConfig: Codable {
    // Session and device setup (Lapse §1)
    public let sessionPreset: String  // AVCaptureSessionPreset value name
    public let usesApplicationAudioSession: Bool
    public let automaticallyConfiguresApplicationAudioSession: Bool
    public let automaticallyConfiguresCaptureDeviceForWideColor: Bool
    public let configuresApplicationAudioSessionToMixWithOthers: Bool
    
    // Focus/exposure defaults (Lapse §1)
    public let focusPointX: Float  // 0..1 normalized
    public let focusPointY: Float  // 0..1 normalized
    public let focusModeAutomatic: Bool
    public let exposureModeAutomatic: Bool
    public let automaticallyEnablesLowLightBoost: Bool
    public let isSmoothAutoFocusEnabled: Bool
    public let isSubjectAreaChangeMonitoringEnabled: Bool
    
    // Frame rate (Lapse §1)
    public let activeVideoMinFrameDuration: CMTime
    public let activeVideoMaxFrameDuration: CMTime
    
    // Zoom (Lapse §1, clamped)
    public let initialVideoZoomFactor: Float
    public let maxVideoZoomFactor: Float
    
    // Photo output (Lapse §1)
    public let isDepthDataDeliveryEnabled: Bool
    public let isLivePhotoCaptureEnabled: Bool
    public let maxPhotoQualityPrioritization: String  // ".quality"
    
    // Flash (override from D-002)
    public let defaultFlashState: String  // "auto", "on", "off"
    
    // Prime focal length (override from D-002)
    public let defaultPrimeFocalLengthMM: Float  // 35 for amateurs
    
    // Sharpening (override from D-002, Halide pure-RAW)
    public let disableRAWSharpening: Bool  // true
    
    // Film preset (override from D-006)
    public let defaultPresetID: UUID
    
    public init(sessionPreset: String = "inputPriority",
                usesApplicationAudioSession: Bool = true,
                automaticallyConfiguresApplicationAudioSession: Bool = false,
                automaticallyConfiguresCaptureDeviceForWideColor: Bool = false,
                configuresApplicationAudioSessionToMixWithOthers: Bool = true,
                focusPointX: Float = 0.5,
                focusPointY: Float = 0.5,
                focusModeAutomatic: Bool = true,
                exposureModeAutomatic: Bool = true,
                automaticallyEnablesLowLightBoost: Bool = true,
                isSmoothAutoFocusEnabled: Bool = true,
                isSubjectAreaChangeMonitoringEnabled: Bool = false,
                activeVideoMinFrameDuration: CMTime = CMTime(value: 1, timescale: 30),
                activeVideoMaxFrameDuration: CMTime = CMTime(value: 1, timescale: 30),
                initialVideoZoomFactor: Float = 1.0,
                maxVideoZoomFactor: Float = 20.0,
                isDepthDataDeliveryEnabled: Bool = false,
                isLivePhotoCaptureEnabled: Bool = false,
                maxPhotoQualityPrioritization: String = ".quality",
                defaultFlashState: String = "auto",
                defaultPrimeFocalLengthMM: Float = 35.0,
                disableRAWSharpening: Bool = true,
                defaultPresetID: UUID) {
        self.sessionPreset = sessionPreset
        self.usesApplicationAudioSession = usesApplicationAudioSession
        self.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
        self.automaticallyConfiguresCaptureDeviceForWideColor = automaticallyConfiguresCaptureDeviceForWideColor
        self.configuresApplicationAudioSessionToMixWithOthers = configuresApplicationAudioSessionToMixWithOthers
        self.focusPointX = focusPointX
        self.focusPointY = focusPointY
        self.focusModeAutomatic = focusModeAutomatic
        self.exposureModeAutomatic = exposureModeAutomatic
        self.automaticallyEnablesLowLightBoost = automaticallyEnablesLowLightBoost
        self.isSmoothAutoFocusEnabled = isSmoothAutoFocusEnabled
        self.isSubjectAreaChangeMonitoringEnabled = isSubjectAreaChangeMonitoringEnabled
        self.activeVideoMinFrameDuration = activeVideoMinFrameDuration
        self.activeVideoMaxFrameDuration = activeVideoMaxFrameDuration
        self.initialVideoZoomFactor = initialVideoZoomFactor
        self.maxVideoZoomFactor = maxVideoZoomFactor
        self.isDepthDataDeliveryEnabled = isDepthDataDeliveryEnabled
        self.isLivePhotoCaptureEnabled = isLivePhotoCaptureEnabled
        self.maxPhotoQualityPrioritization = maxPhotoQualityPrioritization
        self.defaultFlashState = defaultFlashState
        self.defaultPrimeFocalLengthMM = defaultPrimeFocalLengthMM
        self.disableRAWSharpening = disableRAWSharpening
        self.defaultPresetID = defaultPresetID
    }

    private enum CodingKeys: String, CodingKey {
        case sessionPreset
        case usesApplicationAudioSession
        case automaticallyConfiguresApplicationAudioSession
        case automaticallyConfiguresCaptureDeviceForWideColor
        case configuresApplicationAudioSessionToMixWithOthers
        case focusPointX
        case focusPointY
        case focusModeAutomatic
        case exposureModeAutomatic
        case automaticallyEnablesLowLightBoost
        case isSmoothAutoFocusEnabled
        case isSubjectAreaChangeMonitoringEnabled
        case activeVideoMinFrameDuration
        case activeVideoMaxFrameDuration
        case initialVideoZoomFactor
        case maxVideoZoomFactor
        case isDepthDataDeliveryEnabled
        case isLivePhotoCaptureEnabled
        case maxPhotoQualityPrioritization
        case defaultFlashState
        case defaultPrimeFocalLengthMM
        case disableRAWSharpening
        case defaultPresetID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionPreset = try container.decode(String.self, forKey: .sessionPreset)
        self.usesApplicationAudioSession = try container.decode(Bool.self, forKey: .usesApplicationAudioSession)
        self.automaticallyConfiguresApplicationAudioSession = try container.decode(Bool.self, forKey: .automaticallyConfiguresApplicationAudioSession)
        self.automaticallyConfiguresCaptureDeviceForWideColor = try container.decode(Bool.self, forKey: .automaticallyConfiguresCaptureDeviceForWideColor)
        self.configuresApplicationAudioSessionToMixWithOthers = try container.decode(Bool.self, forKey: .configuresApplicationAudioSessionToMixWithOthers)
        self.focusPointX = try container.decode(Float.self, forKey: .focusPointX)
        self.focusPointY = try container.decode(Float.self, forKey: .focusPointY)
        self.focusModeAutomatic = try container.decode(Bool.self, forKey: .focusModeAutomatic)
        self.exposureModeAutomatic = try container.decode(Bool.self, forKey: .exposureModeAutomatic)
        self.automaticallyEnablesLowLightBoost = try container.decode(Bool.self, forKey: .automaticallyEnablesLowLightBoost)
        self.isSmoothAutoFocusEnabled = try container.decode(Bool.self, forKey: .isSmoothAutoFocusEnabled)
        self.isSubjectAreaChangeMonitoringEnabled = try container.decode(Bool.self, forKey: .isSubjectAreaChangeMonitoringEnabled)
        self.activeVideoMinFrameDuration = try container.decode(CMTime.self, forKey: .activeVideoMinFrameDuration)
        self.activeVideoMaxFrameDuration = try container.decode(CMTime.self, forKey: .activeVideoMaxFrameDuration)
        self.initialVideoZoomFactor = try container.decode(Float.self, forKey: .initialVideoZoomFactor)
        self.maxVideoZoomFactor = try container.decode(Float.self, forKey: .maxVideoZoomFactor)
        self.isDepthDataDeliveryEnabled = try container.decode(Bool.self, forKey: .isDepthDataDeliveryEnabled)
        self.isLivePhotoCaptureEnabled = try container.decode(Bool.self, forKey: .isLivePhotoCaptureEnabled)
        self.maxPhotoQualityPrioritization = try container.decode(String.self, forKey: .maxPhotoQualityPrioritization)
        self.defaultFlashState = try container.decode(String.self, forKey: .defaultFlashState)
        self.defaultPrimeFocalLengthMM = try container.decode(Float.self, forKey: .defaultPrimeFocalLengthMM)
        self.disableRAWSharpening = try container.decode(Bool.self, forKey: .disableRAWSharpening)
        self.defaultPresetID = try container.decode(UUID.self, forKey: .defaultPresetID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionPreset, forKey: .sessionPreset)
        try container.encode(usesApplicationAudioSession, forKey: .usesApplicationAudioSession)
        try container.encode(automaticallyConfiguresApplicationAudioSession, forKey: .automaticallyConfiguresApplicationAudioSession)
        try container.encode(automaticallyConfiguresCaptureDeviceForWideColor, forKey: .automaticallyConfiguresCaptureDeviceForWideColor)
        try container.encode(configuresApplicationAudioSessionToMixWithOthers, forKey: .configuresApplicationAudioSessionToMixWithOthers)
        try container.encode(focusPointX, forKey: .focusPointX)
        try container.encode(focusPointY, forKey: .focusPointY)
        try container.encode(focusModeAutomatic, forKey: .focusModeAutomatic)
        try container.encode(exposureModeAutomatic, forKey: .exposureModeAutomatic)
        try container.encode(automaticallyEnablesLowLightBoost, forKey: .automaticallyEnablesLowLightBoost)
        try container.encode(isSmoothAutoFocusEnabled, forKey: .isSmoothAutoFocusEnabled)
        try container.encode(isSubjectAreaChangeMonitoringEnabled, forKey: .isSubjectAreaChangeMonitoringEnabled)
        try container.encode(activeVideoMinFrameDuration, forKey: .activeVideoMinFrameDuration)
        try container.encode(activeVideoMaxFrameDuration, forKey: .activeVideoMaxFrameDuration)
        try container.encode(initialVideoZoomFactor, forKey: .initialVideoZoomFactor)
        try container.encode(maxVideoZoomFactor, forKey: .maxVideoZoomFactor)
        try container.encode(isDepthDataDeliveryEnabled, forKey: .isDepthDataDeliveryEnabled)
        try container.encode(isLivePhotoCaptureEnabled, forKey: .isLivePhotoCaptureEnabled)
        try container.encode(maxPhotoQualityPrioritization, forKey: .maxPhotoQualityPrioritization)
        try container.encode(defaultFlashState, forKey: .defaultFlashState)
        try container.encode(defaultPrimeFocalLengthMM, forKey: .defaultPrimeFocalLengthMM)
        try container.encode(disableRAWSharpening, forKey: .disableRAWSharpening)
        try container.encode(defaultPresetID, forKey: .defaultPresetID)
    }
}

// MARK: - Helpers

/// Given a numeric 4:3 image dimension pair, is it "ordinary still" (use last) or "burst" (use first)?
public func shouldUseBurstDimension(_ context: String) -> Bool {
    context.lowercased().contains("burst")
}
