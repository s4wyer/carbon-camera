import Foundation

/// Serializable preset controls shared by the catalog and on-device renderer.
/// RecipeVersion.Parameters remains the immutable recipe snapshot contract.
public struct PresetParameters: Codable, Equatable {
    public var strength: Float
    public var lutID: String?
    public var lutIntensity: Float
    public var exposureEV: Float
    public var temperatureOffsetK: Float
    public var tintOffset: Float
    public var contrast: Float
    public var saturation: Float
    public var vibrance: Float
    public var curveBlack: Float
    public var curveShadow: Float
    public var curveMidtone: Float
    public var curveHighlight: Float
    public var curveWhite: Float
    public var hsl: [HSLAdjustment]
    public var grainAmount: Float
    public var grainSize: Float
    public var halationRadius: Float
    public var halationIntensity: Float
    public var bloomAmount: Float
    public var bloomRadius: Float
    public var vignetteIntensity: Float
    public var vignetteRadius: Float

    public init(
        strength: Float = 1,
        lutID: String? = nil,
        lutIntensity: Float = 1,
        exposureEV: Float = 0,
        temperatureOffsetK: Float = 0,
        tintOffset: Float = 0,
        contrast: Float = 1,
        saturation: Float = 1,
        vibrance: Float = 0,
        curveBlack: Float = 0,
        curveShadow: Float = 0,
        curveMidtone: Float = 0,
        curveHighlight: Float = 0,
        curveWhite: Float = 0,
        hsl: [HSLAdjustment] = Array(repeating: HSLAdjustment(), count: 8),
        grainAmount: Float = 0,
        grainSize: Float = 1,
        halationRadius: Float = 4,
        halationIntensity: Float = 0,
        bloomAmount: Float = 0,
        bloomRadius: Float = 10,
        vignetteIntensity: Float = 0,
        vignetteRadius: Float = 0
    ) {
        self.strength = strength
        self.lutID = lutID
        self.lutIntensity = lutIntensity
        self.exposureEV = exposureEV
        self.temperatureOffsetK = temperatureOffsetK
        self.tintOffset = tintOffset
        self.contrast = contrast
        self.saturation = saturation
        self.vibrance = vibrance
        self.curveBlack = curveBlack
        self.curveShadow = curveShadow
        self.curveMidtone = curveMidtone
        self.curveHighlight = curveHighlight
        self.curveWhite = curveWhite
        self.hsl = hsl
        self.grainAmount = grainAmount
        self.grainSize = grainSize
        self.halationRadius = halationRadius
        self.halationIntensity = halationIntensity
        self.bloomAmount = bloomAmount
        self.bloomRadius = bloomRadius
        self.vignetteIntensity = vignetteIntensity
        self.vignetteRadius = vignetteRadius
    }
}

public typealias HSLAdjustment = FilmEffectParameters.HSLChannel
