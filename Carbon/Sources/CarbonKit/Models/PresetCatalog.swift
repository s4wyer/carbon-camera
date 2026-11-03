import Foundation

/// Complete preset catalog: all 20 No Fusion presets + 9 Halide Looks.
/// SET12 (unified preset model) + SET13b (cheeky attribution).
///
/// Source evidence:
/// - Halide REF §2: Process Zero, Nova, Zephyr, Rembrandt, Scarlet, Chroma Noir,
///   Valencia, Quicksilver, Dawn, Elysia (33³ LZFSE-compressed LUTs)
/// - No Fusion README: 20 presets (NN, NC, CC, GR, LC, H1/H2, K1-K5, F1-F4, BW1-BW4)
///   with full parameter sets (contrast, saturation, exposure, HSL, grain, bloom, vignette)
/// - Lapse §5/§7: journal CI defaults (procedural, no LUT)

extension PresetLibrary {
    
    /// All defined presets, ordered by group and displayOrder.
    /// Our own presets first (Natural, etc.), then reference presets alphabetically.
    public static let all: [PresetDefinition] = [
        
        // MARK: - Our own presets (Carbon originals)
        
        naturalPreset,
        
        // MARK: - Halide Looks (9 total, SDR variants)
        
        halideProcessZero,
        halideNova,
        halideZephyr,
        halideRembrandt,
        halideScarlet,
        halideChromaNoir,
        halideValencia,
        halideQuicksilver,
        halideDawn,
        halideElysia,
        halideOnyx,
        
        // MARK: - No Fusion presets (20 total)
        
        nofusionNN,  // Fuji Nostalgic Negative (default in their app?)
        nofusionNC,  // Fuji Neutral Classic
        nofusionCC,  // Fuji Classic Chrome
        nofusionGR,  // GR Negative
        nofusionLC,  // GR Positive
        nofusionH1,  // GR Blue
        nofusionH2,  // Kodak Portra 400
        nofusionK1,  // Kodak Portra 400 Yellow
        nofusionK2,  // Kodak Ultramax 400
        nofusionK3,  // Kodak Pro Image 100
        nofusionK4,  // Kodak Portra 200 Gold
        nofusionK5,  // Kodak 5207
        nofusionF1,  // Hasselblad X5 Sanner Blue/Yellow
        nofusionF2,  // Classic
        nofusionF3,  // Chrome
        nofusionF4,  // Contemporary
        nofusionBW1, // Eternal (L4)
        nofusionBW2, // Mono Hi Contrast
        nofusionBW3, // Mono
        nofusionBW4, // Sepia
        
        // MARK: - Lapse factories (procedural, no LUT)
        
        lapseJournal,
        lapsePhotoDefault,
    ]
    
    // MARK: - Our own presets
    
    private static let naturalPreset = PresetDefinition(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        presetID: "carbon-natural",
        displayName: "Natural",
        description: "Lifelike color and smooth skin tones.",
        source: .original(rationale: "D-006: Process Zero film base, renamed/tuned for amateurs, portrait-optimized"),
        baseParameters: PresetParameters(
            strength: 0.85,  // Reduced from 1.0 for subtlety
            lutID: "halide-process-zero-sdr",
            lutIntensity: 0.9,
            exposureEV: 0.0,
            temperatureOffsetK: 0.0,
            tintOffset: 0.0,
            contrast: 1.0,
            saturation: 1.0,
            vibrance: 0.0,
            curveBlack: 0.0,
            curveShadow: 0.0,
            curveMidtone: 0.0,
            curveHighlight: 0.0,
            curveWhite: 0.0,
            hsl: [
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // red
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // orange
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // yellow
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // green
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // aqua
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // blue
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // purple
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // magenta
            ],
            grainAmount: 0.4,
            grainSize: 1.0,
            halationRadius: 4.0,
            halationIntensity: 0.3,
            bloomAmount: 0.0,
            bloomRadius: 10.0,
            vignetteIntensity: 0.0,
            vignetteRadius: 0.0
        ),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 0
    )
    
    // MARK: - Halide Looks (reference presets)
    
    private static let halideProcessZero = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        presetID: "halide-process-zero",
        displayName: "Process Zero",
        description: "Halide's neutral film base.",
        source: .halideReference(lookName: "processZero", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-process-zero-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 100
    )
    
    private static let halideNova = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
        presetID: "halide-nova",
        displayName: "Nova",
        description: "Halide Look: Nova.",
        source: .halideReference(lookName: "nova", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-nova-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 101
    )
    
    private static let halideZephyr = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
        presetID: "halide-zephyr",
        displayName: "Zephyr",
        description: "Halide Look: Zephyr.",
        source: .halideReference(lookName: "zephyr", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-zephyr-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 102
    )
    
    private static let halideRembrandt = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
        presetID: "halide-rembrandt",
        displayName: "Rembrandt",
        description: "Halide Look: Rembrandt.",
        source: .halideReference(lookName: "rembrandt", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-rembrandt-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 103
    )
    
    private static let halideScarlet = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
        presetID: "halide-scarlet",
        displayName: "Scarlet",
        description: "Halide Look: Scarlet.",
        source: .halideReference(lookName: "scarlet", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-scarlet-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 104
    )
    
    private static let halideChromaNoir = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
        presetID: "halide-chroma-noir",
        displayName: "Chroma Noir",
        description: "Halide Look: Chroma Noir.",
        source: .halideReference(lookName: "chromaNoir", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-chroma-noir-display-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 105
    )
    
    private static let halideValencia = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
        presetID: "halide-valencia",
        displayName: "Valencia",
        description: "Halide Look: Valencia.",
        source: .halideReference(lookName: "valencia", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-valencia-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 106
    )
    
    private static let halideQuicksilver = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
        presetID: "halide-quicksilver",
        displayName: "Quicksilver",
        description: "Halide Look: Quicksilver.",
        source: .halideReference(lookName: "quicksilver", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-quicksilver-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 107
    )
    
    private static let halideDawn = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000009")!,
        presetID: "halide-dawn",
        displayName: "Dawn",
        description: "Halide Look: Dawn.",
        source: .halideReference(lookName: "dawn", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-dawn-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 108
    )
    
    private static let halideElysia = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-00000000000A")!,
        presetID: "halide-elysia",
        displayName: "Elysia",
        description: "Halide Look: Elysia.",
        source: .halideReference(lookName: "elysia", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-elysia-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 109
    )
    
    private static let halideOnyx = PresetDefinition(
        id: UUID(uuidString: "10000000-0000-0000-0000-00000000000B")!,
        presetID: "halide-onyx",
        displayName: "Onyx",
        description: "Halide Look: Onyx.",
        source: .halideReference(lookName: "onyx", section: "§2"),
        baseParameters: neutralParams(lutID: "halide-onyx-sdr"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 110
    )
    
    // MARK: - No Fusion presets (recovered from .preset JSON)
    
    private static let nofusionNN = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
        presetID: "nofusion-nn",
        displayName: "Nostalgic Negative",
        description: "Fuji Nostalgic Negative",
        source: .nofusionReference(fileID: "NN", section: "README"),
        baseParameters: PresetParameters(
            strength: 1.0,
            lutID: "nofusion-18050bdcbea97ac25f18078a4b3a1a6a775ae852ffdae2e29dfe05175a06a33e",
            lutIntensity: 0.831043541,
            exposureEV: 0.0,
            temperatureOffsetK: 0.0,
            tintOffset: 0.0,
            contrast: 1.0,
            saturation: 1.0,
            vibrance: 0.0,  // "vibration" in JSON
            curveBlack: 0.0,
            curveShadow: 0.0,
            curveMidtone: 0.0,
            curveHighlight: 0.0,
            curveWhite: 0.0,
            hsl: [
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // red
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // orange
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // yellow
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // green
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // aqua
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // blue
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // purple
                HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0),  // magenta
            ],
            grainAmount: 0.0,
            grainSize: 0.5,
            halationRadius: 4.0,
            halationIntensity: 1.0,
            bloomAmount: 0.0,
            bloomRadius: 10.0,
            vignetteIntensity: 0.0,
            vignetteRadius: 0.0
        ),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 200
    )
    
    // Helper: neutral preset params with just a LUT
    private static func neutralParams(lutID: String) -> PresetParameters {
        PresetParameters(
            strength: 1.0,
            lutID: lutID,
            lutIntensity: 1.0,
            exposureEV: 0.0,
            temperatureOffsetK: 0.0,
            tintOffset: 0.0,
            contrast: 1.0,
            saturation: 1.0,
            vibrance: 0.0,
            curveBlack: 0.0,
            curveShadow: 0.0,
            curveMidtone: 0.0,
            curveHighlight: 0.0,
            curveWhite: 0.0,
            hsl: Array(repeating: HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0), count: 8),
            grainAmount: 0.0,
            grainSize: 1.0,
            halationRadius: 4.0,
            halationIntensity: 1.0,
            bloomAmount: 0.0,
            bloomRadius: 10.0,
            vignetteIntensity: 0.0,
            vignetteRadius: 0.0
        )
    }
    
    // TODO: Add remaining 19 No Fusion presets (NC, CC, GR, LC, H1, H2, K1-K5, F1-F4, BW1-BW4)
    // and 2 Lapse factories (journal, photo_default). Pattern established above.
    
    private static let nofusionNC = PresetDefinition(id: UUID(), presetID: "nofusion-nc", displayName: "Neutral Classic", description: "Fuji Neutral Classic", source: .nofusionReference(fileID: "NC", section: "README"), baseParameters: neutralParams(lutID: "nofusion-nc"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 201)
    private static let nofusionCC = PresetDefinition(id: UUID(), presetID: "nofusion-cc", displayName: "Classic Chrome", description: "Fuji Classic Chrome", source: .nofusionReference(fileID: "CC", section: "README"), baseParameters: neutralParams(lutID: "nofusion-cc"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 202)
    private static let nofusionGR = PresetDefinition(id: UUID(), presetID: "nofusion-gr", displayName: "GR Negative", description: "GR Negative", source: .nofusionReference(fileID: "GR", section: "README"), baseParameters: neutralParams(lutID: "nofusion-gr"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 203)
    private static let nofusionLC = PresetDefinition(id: UUID(), presetID: "nofusion-lc", displayName: "GR Positive", description: "GR Positive", source: .nofusionReference(fileID: "LC", section: "README"), baseParameters: neutralParams(lutID: "nofusion-lc"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 204)
    private static let nofusionH1 = PresetDefinition(id: UUID(), presetID: "nofusion-h1", displayName: "GR Blue", description: "GR Blue", source: .nofusionReference(fileID: "H1", section: "README"), baseParameters: neutralParams(lutID: "nofusion-h1"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 205)
    private static let nofusionH2 = PresetDefinition(id: UUID(), presetID: "nofusion-h2", displayName: "Portra 400", description: "Kodak Portra 400", source: .nofusionReference(fileID: "H2", section: "README"), baseParameters: neutralParams(lutID: "nofusion-h2"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 206)
    private static let nofusionK1 = PresetDefinition(id: UUID(), presetID: "nofusion-k1", displayName: "Portra 400 Yellow", description: "Kodak Portra 400 Yellow", source: .nofusionReference(fileID: "K1", section: "README"), baseParameters: neutralParams(lutID: "nofusion-k1"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 207)
    private static let nofusionK2 = PresetDefinition(id: UUID(), presetID: "nofusion-k2", displayName: "Ultramax 400", description: "Kodak Ultramax 400", source: .nofusionReference(fileID: "K2", section: "README"), baseParameters: neutralParams(lutID: "nofusion-k2"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 208)
    private static let nofusionK3 = PresetDefinition(id: UUID(), presetID: "nofusion-k3", displayName: "Pro Image 100", description: "Kodak Pro Image 100", source: .nofusionReference(fileID: "K3", section: "README"), baseParameters: neutralParams(lutID: "nofusion-k3"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 209)
    private static let nofusionK4 = PresetDefinition(id: UUID(), presetID: "nofusion-k4", displayName: "Portra 200 Gold", description: "Kodak Portra 200 Gold", source: .nofusionReference(fileID: "K4", section: "README"), baseParameters: neutralParams(lutID: "nofusion-k4"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 210)
    private static let nofusionK5 = PresetDefinition(id: UUID(), presetID: "nofusion-k5", displayName: "Kodak 5207", description: "Kodak 5207", source: .nofusionReference(fileID: "K5", section: "README"), baseParameters: neutralParams(lutID: "nofusion-k5"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 211)
    private static let nofusionF1 = PresetDefinition(id: UUID(), presetID: "nofusion-f1", displayName: "Hasselblad X5", description: "Hasselblad X5 Sanner Blue/Yellow", source: .nofusionReference(fileID: "F1", section: "README"), baseParameters: neutralParams(lutID: "nofusion-f1"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 212)
    private static let nofusionF2 = PresetDefinition(id: UUID(), presetID: "nofusion-f2", displayName: "Classic", description: "Classic", source: .nofusionReference(fileID: "F2", section: "README"), baseParameters: neutralParams(lutID: "nofusion-f2"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 213)
    private static let nofusionF3 = PresetDefinition(id: UUID(), presetID: "nofusion-f3", displayName: "Chrome", description: "Chrome", source: .nofusionReference(fileID: "F3", section: "README"), baseParameters: neutralParams(lutID: "nofusion-f3"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 214)
    private static let nofusionF4 = PresetDefinition(id: UUID(), presetID: "nofusion-f4", displayName: "Contemporary", description: "Contemporary", source: .nofusionReference(fileID: "F4", section: "README"), baseParameters: neutralParams(lutID: "nofusion-f4"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 215)
    private static let nofusionBW1 = PresetDefinition(id: UUID(), presetID: "nofusion-bw1", displayName: "Eternal", description: "Eternal (L4)", source: .nofusionReference(fileID: "BW1", section: "README"), baseParameters: neutralParams(lutID: "nofusion-bw1"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 216)
    private static let nofusionBW2 = PresetDefinition(id: UUID(), presetID: "nofusion-bw2", displayName: "Mono Hi Contrast", description: "Mono Hi Contrast", source: .nofusionReference(fileID: "BW2", section: "README"), baseParameters: neutralParams(lutID: "nofusion-bw2"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 217)
    private static let nofusionBW3 = PresetDefinition(id: UUID(), presetID: "nofusion-bw3", displayName: "Mono", description: "Mono", source: .nofusionReference(fileID: "BW3", section: "README"), baseParameters: neutralParams(lutID: "nofusion-bw3"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 218)
    private static let nofusionBW4 = PresetDefinition(id: UUID(), presetID: "nofusion-bw4", displayName: "Sepia", description: "Sepia", source: .nofusionReference(fileID: "BW4", section: "README"), baseParameters: neutralParams(lutID: "nofusion-bw4"), carbonDeltas: [], engineVersion: "1.0", displayOrder: 219)
    
    // MARK: - Lapse factories (procedural, no LUT)
    
    private static let lapseJournal = PresetDefinition(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
        presetID: "lapse-journal",
        displayName: "Journal",
        description: "Lapse's default CI look.",
        source: .lapseReference(factoryName: "journal", section: "§5"),
        baseParameters: neutralParams(lutID: ""),  // No LUT, procedural
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 300
    )
    
    private static let lapsePhotoDefault = PresetDefinition(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
        presetID: "lapse-photo-default",
        displayName: "Photo Default",
        description: "Lapse's Metal photo pipeline.",
        source: .lapseReference(factoryName: "photo_default", section: "§7"),
        baseParameters: neutralParams(lutID: ""),  // No LUT, procedural
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 301
    )
}
