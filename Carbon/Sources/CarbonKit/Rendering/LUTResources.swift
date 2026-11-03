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
            for preset in PresetLibrary.all {
                guard let lutID = preset.baseParameters.lutID, !lutID.isEmpty else { continue }
                _ = try? self.loadFromBundle(lutID: lutID)
            }
        }
    }
    
    private func loadFromBundle(lutID: String) throws -> LUTData {
        // Halide LUTs: "halide-{look}-sdr" → "Resources/LUTs/halide/{Look}SDR.ccube"
        if lutID.hasPrefix("halide-") {
            let filename = lutID
                .replacingOccurrences(of: "halide-", with: "")
                .replacingOccurrences(of: "-sdr", with: "SDR")
                .replacingOccurrences(of: "-hdr", with: "HDR")
                .replacingOccurrences(of: "-", with: "")
                .capitalizingFirstLetter()
            
            // Special cases
            let ccubeFilename: String
            if lutID == "halide-process-zero-sdr" {
                ccubeFilename = "p0sdr"
            } else if lutID == "halide-process-zero-hdr" {
                ccubeFilename = "p0hdr"
            } else if lutID.contains("zephyr") {
                ccubeFilename = filename.replacingOccurrences(of: "Zephyr", with: "ZephyrDisplayP3")
            } else if lutID.contains("valencia") {
                ccubeFilename = filename.replacingOccurrences(of: "Valencia", with: "ValenciaDisplayP3")
            } else if lutID.contains("chroma-noir-scene") {
                ccubeFilename = filename.replacingOccurrences(of: "Chromanoir", with: "ChromaNoirScene")
            } else if lutID.contains("chroma-noir-display") {
                ccubeFilename = filename.replacingOccurrences(of: "Chromanoir", with: "ChromaNoirDisplay")
            } else {
                ccubeFilename = filename
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

private extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }
}
