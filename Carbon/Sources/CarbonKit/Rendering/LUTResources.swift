import Foundation

/// LUT resource manager: loads and caches all LUTs at launch.
/// SET12 (unified preset model): lazy-load LUTs on demand, keyed by lutID.
///
/// Usage:
///   let lut = try LUTResources.shared.load(lutID: "halide-zephyr-sdr")
///   // Returns LUTData with dimension 33 and RGBA floats

public class LUTResources {
    public static let shared = LUTResources()
    
    private var cache: [String: LUTData] = [:]
    private let queue = DispatchQueue(label: "app.carbon.lut-cache")
    
    private init() {}
    
    /// Load a LUT by its lutID (as referenced in PresetParameters).
    /// Caches the result for future lookups.
    public func load(lutID: String) throws -> LUTData {
        return try queue.sync {
            if let cached = cache[lutID] {
                return cached
            }
            
            let lut = try loadFromBundle(lutID: lutID)
            cache[lutID] = lut
            return lut
        }
    }
    
    /// Preload all LUTs at launch (optional, for faster first render).
    public func preloadAll() {
        queue.async {
            var loadedIDs = Set<String>()
            for preset in PresetLibrary.all {
                guard let lutID = preset.baseParameters.lutID,
                      !lutID.isEmpty,
                      loadedIDs.insert(lutID).inserted,
                      self.cache[lutID] == nil else { continue }
                if let lut = try? self.loadFromBundle(lutID: lutID) {
                    self.cache[lutID] = lut
                }
            }
        }
    }
    
    private func loadFromBundle(lutID: String) throws -> LUTData {
        if lutID == "lapse-v4-03" {
            guard let url = Bundle.main.url(forResource: "Lapse-V4-03", withExtension: "cube", subdirectory: "LUTs/lapse") else {
                throw LUTError.resourceNotFound("lapse/Lapse-V4-03.cube")
            }
            return try LapseCubeLoader.load(data: Data(contentsOf: url))
        }
        // Halide LUTs: "halide-{look}-sdr" → "Resources/LUTs/halide/{Look}SDR.ccube"
        if lutID.hasPrefix("halide-") {
            // Explicit map from preset lutID to bundled .ccube basename.
            // A transform chain proved fragile (e.g. chroma-noir-display); this
            // table is the single source of truth for Halide file resolution.
            let halideMap: [String: String] = [
                "halide-process-zero-sdr": "p0sdr",
                "halide-process-zero-hdr": "p0hdr",
                "halide-nova-sdr": "NovaSDR",
                "halide-nova-hdr": "NovaHDR",
                "halide-zephyr-sdr": "ZephyrDisplayP3SDR",
                "halide-zephyr-hdr": "ZephyrDisplayP3HDR",
                "halide-rembrandt-sdr": "RembrandtSDR",
                "halide-rembrandt-hdr": "RembrandtHDR",
                "halide-scarlet-sdr": "ScarletSDR",
                "halide-scarlet-hdr": "ScarletHDR",
                "halide-valencia-sdr": "ValenciaDisplayP3SDR",
                "halide-valencia-hdr": "ValenciaDisplayP3HDR",
                "halide-quicksilver-sdr": "QuicksilverSDR",
                "halide-quicksilver-hdr": "QuicksilverHDR",
                "halide-dawn-sdr": "DawnSDR",
                "halide-dawn-hdr": "DawnHDR",
                "halide-elysia-sdr": "ElysiaSDR",
                "halide-elysia-hdr": "ElysiaHDR",
                "halide-onyx-sdr": "OnyxSDR",
                "halide-onyx-hdr": "OnyxHDR",
                "halide-chroma-noir-scene-sdr": "ChromaNoirSceneSDR",
                "halide-chroma-noir-scene-hdr": "ChromaNoirSceneHDR",
                "halide-chroma-noir-display-sdr": "ChromaNoirDisplaySDR",
                "halide-chroma-noir-display-hdr": "ChromaNoirDisplayHDR",
            ]

            guard let ccubeFilename = halideMap[lutID] else {
                throw LUTError.resourceNotFound("halide/\(lutID) (no entry in halideMap)")
            }
            
            guard let url = Bundle.main.url(forResource: ccubeFilename, withExtension: "ccube", subdirectory: "LUTs/halide") else {
                throw LUTError.resourceNotFound("halide/\(ccubeFilename).ccube")
            }
            
            let data = try Data(contentsOf: url)
            return try LUTLoader.loadHalideCCube(data: data)
        }
        
        // No Fusion LUTs: "nofusion-{hash}" → "Resources/LUTs/nofusion/{hash}.lutbin"
        if lutID.hasPrefix("nofusion-") {
            let hash = String(lutID.dropFirst("nofusion-".count))
            
            guard let url = Bundle.main.url(forResource: hash, withExtension: "lutbin", subdirectory: "LUTs/nofusion") else {
                throw LUTError.resourceNotFound("nofusion/\(hash).lutbin")
            }
            
            let data = try Data(contentsOf: url)
            
            // Determine dimension from file size
            let dimension: Int
            switch data.count {
            case 250_000:  // 25³ * 16
                dimension = 25
            case 524_288:  // 32³ * 16
                dimension = 32
            case 574_992:  // 33³ * 16
                dimension = 33
            default:
                throw LUTError.invalidSize(expected: 0, actual: data.count)
            }
            
            return try LUTLoader.loadNoFusionLutbin(data: data, dimension: dimension)
        }
        
        throw LUTError.resourceNotFound(lutID)
    }
}
