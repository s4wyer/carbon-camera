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
        source: .nofusionReference(presetFileID: "NN", section: "README"),
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
    
    // Helper: No Fusion preset params (grainSize 0.5 per recovered plists; most presets are neutral + LUT only)
    private static func nofusionParams(lutID: String, lutIntensity: Float = 1.0) -> PresetParameters {
        PresetParameters(
            strength: 1.0,
            lutID: lutID,
            lutIntensity: lutIntensity,
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
            grainSize: 0.5,
            halationRadius: 4.0,
            halationIntensity: 1.0,
            bloomAmount: 0.0,
            bloomRadius: 10.0,
            vignetteIntensity: 0.0,
            vignetteRadius: 0.0
        )
    }
    
    // No Fusion presets 2-20 (NN is above). LUT IDs are the recovered SHA-256 content
    // hashes from nofusion-recovered/preset_lut_map.csv, matching bundled .lutbin files.
    
    private static let nofusionNC = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000201")!,
        presetID: "nofusion-nc",
        displayName: "Neutral Classic",
        description: "Fuji Neutral Classic",
        source: .nofusionReference(presetFileID: "NC", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-822d19ac28e6c421761039993fd843b076e232b9b90bbb2adf110ef159ff1673"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 201
    )

    private static let nofusionCC = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000202")!,
        presetID: "nofusion-cc",
        displayName: "Classic Chrome",
        description: "Fuji Classic Chrome",
        source: .nofusionReference(presetFileID: "CC", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-e2c341b28e5e7de6a886e731c51ed88208979e8d19371555ef8dc7db458d620a"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 202
    )

    private static let nofusionGR = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000203")!,
        presetID: "nofusion-gr",
        displayName: "GR Negative",
        description: "GR Negative",
        source: .nofusionReference(presetFileID: "GR", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-685ed5807f1632c601976cfe6ebff38845d2fa1648daa0a9ce66729e6041242b"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 203
    )

    private static let nofusionLC = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000204")!,
        presetID: "nofusion-lc",
        displayName: "GR Positive",
        description: "GR Positive",
        source: .nofusionReference(presetFileID: "LC", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-1f0a2e71be20d72bbdb134a7181b921caf6f21cf1b217b8f0346005ecbec5e8f", lutIntensity: 0.910000026),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 204
    )

    private static let nofusionH1 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000205")!,
        presetID: "nofusion-h1",
        displayName: "GR Blue",
        description: "GR Blue",
        source: .nofusionReference(presetFileID: "H1", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-70a7e54e51d03e11ce5833944df379e4b4218e13170f69210e1f100f55a762e4"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 205
    )

    private static let nofusionH2 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000206")!,
        presetID: "nofusion-h2",
        displayName: "Portra 400",
        description: "Kodak Portra 400",
        source: .nofusionReference(presetFileID: "H2", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-0156edbce8ce9f3668dc0b7a703139dc3a35f4f8e014bdabaa13385913c5fcc5"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 206
    )

    private static let nofusionK1 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000207")!,
        presetID: "nofusion-k1",
        displayName: "Portra 400 Yellow",
        description: "Kodak Portra 400 Yellow",
        source: .nofusionReference(presetFileID: "K1", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-02198abeb11dd57e39be43e92b3455ecd6505bb6e22a2b60feeb25e53d8f2ab9"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 207
    )

    private static let nofusionK2 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000208")!,
        presetID: "nofusion-k2",
        displayName: "Ultramax 400",
        description: "Kodak Ultramax 400",
        source: .nofusionReference(presetFileID: "K2", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-b356cc9c1eaae54b9de3d58c4aea5f7a780a96133dbe213b735d69a89099773a", lutIntensity: 0.910000026),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 208
    )

    private static let nofusionK3 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000209")!,
        presetID: "nofusion-k3",
        displayName: "Pro Image 100",
        description: "Kodak Pro Image 100",
        source: .nofusionReference(presetFileID: "K3", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-b9246fa3f057253c66021c1ee9afd798c7351b2b73f4ae0744db9d4df79d3b14"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 209
    )

    private static let nofusionK4 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000210")!,
        presetID: "nofusion-k4",
        displayName: "Portra 200 Gold",
        description: "Kodak Portra 200 Gold",
        source: .nofusionReference(presetFileID: "K4", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-a75d5f375443e699c1f4b48cb6f5cafc914abf5934d6764fa3461c770f278b75"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 210
    )

    private static let nofusionK5 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000211")!,
        presetID: "nofusion-k5",
        displayName: "Kodak 5207",
        description: "Kodak 5207",
        source: .nofusionReference(presetFileID: "K5", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-8a14ae6faaddc31b4ea373f45c9dc7ffdd5377af2dd503bf23f34a7b16b6130b"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 211
    )

    private static let nofusionF1 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000212")!,
        presetID: "nofusion-f1",
        displayName: "Hasselblad X5",
        description: "Hasselblad X5 Sanner Blue/Yellow",
        source: .nofusionReference(presetFileID: "F1", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-246df6bf673a0b576495931c898d5eba079bd9d595715eb46555914eeae8a9f6"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 212
    )

    private static let nofusionF2 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000213")!,
        presetID: "nofusion-f2",
        displayName: "Classic",
        description: "Classic",
        source: .nofusionReference(presetFileID: "F2", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-6fb657704d167f9095ac4d703d2ea8ef2d0180139ce16512a33a372aa8c0cf2e"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 213
    )

    private static let nofusionF3 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000214")!,
        presetID: "nofusion-f3",
        displayName: "Chrome",
        description: "Chrome",
        source: .nofusionReference(presetFileID: "F3", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-8b9d1d4f5399f0ca880be86880eebb336c4952864ed7eba94ea6d20e162c4e85", lutIntensity: 0.910000026),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 214
    )

    private static let nofusionF4 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000215")!,
        presetID: "nofusion-f4",
        displayName: "Contemporary",
        description: "Contemporary",
        source: .nofusionReference(presetFileID: "F4", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-9fab23387aa2c5fe6024a54dab4cf2d9b3549152cdd489011b0e19051e335c5e"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 215
    )

    private static let nofusionBW1 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000216")!,
        presetID: "nofusion-bw1",
        displayName: "Eternal",
        description: "Eternal (L4)",
        source: .nofusionReference(presetFileID: "BW1", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-25b746015f41ff91387c2676383bb370ba67fc6f50db90eaa03ab36f1e26a83a"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 216
    )

    private static let nofusionBW2 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000217")!,
        presetID: "nofusion-bw2",
        displayName: "Mono Hi Contrast",
        description: "Mono Hi Contrast",
        source: .nofusionReference(presetFileID: "BW2", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-41743664a9e8bbabd4e1c84ecd16d81b772215f7526a8797e5217acddabe282c"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 217
    )

    private static let nofusionBW3 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000218")!,
        presetID: "nofusion-bw3",
        displayName: "Mono",
        description: "Mono",
        source: .nofusionReference(presetFileID: "BW3", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-8a2a46d974182d531d4ae80c2ff0900d215dc987ca4cfac55100569c9e408a7f"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 218
    )

    private static let nofusionBW4 = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000219")!,
        presetID: "nofusion-bw4",
        displayName: "Sepia",
        description: "Sepia",
        source: .nofusionReference(presetFileID: "BW4", section: "README"),
        baseParameters: nofusionParams(lutID: "nofusion-b19bcf382607739a7c0ab2b89e57e9b98632bc0b90cc57a659011b1be2cd9d8a"),
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: 219
    )
    
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
