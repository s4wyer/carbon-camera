import Foundation
import Compression

/// LUT loader: decodes Halide .ccube (LZFSE-compressed 33³ half-float RGB)
/// and No Fusion .lutbin (raw float32 RGBA) into Metal textures.
///
/// Source evidence:
/// - Halide REF §2: "LookupTableIO.decompress decompresses with COMPRESSION_LZFSE;
///   stream decodes to dimension³ * 6 bytes (three 16-bit half-float RGB per texel);
///   decoder converts each half-float RGB triplet to float and appends alpha 1.0."
/// - No Fusion README: "Every LUT consists entirely of little-endian IEEE-754 float32
///   quadruples (RGBA); size³ * 4 * 4 bytes; no header or trailer."
///
/// SET12 (unified preset model): load all reference LUTs at launch.

public enum LUTFormat {
    case halide33Cube  // 33³ LZFSE-compressed half-float RGB → float RGBA
    case nofusionRaw   // size³ raw float32 RGBA
}

public struct LUTData {
    public let dimension: Int
    public let rgba: [Float]  // dimension³ * 4 floats (R,G,B,A per texel)
    
    public init(dimension: Int, rgba: [Float]) {
        precondition(rgba.count == dimension * dimension * dimension * 4,
                     "LUT data must be dimension³ * 4 RGBA floats")
        self.dimension = dimension
        self.rgba = rgba
    }
}

public enum LUTLoader {
    
    // MARK: - Halide .ccube (LZFSE-compressed 33³ half-float RGB)
    
    /// Decode a Halide .ccube LUT (LZFSE-compressed, 33³ half-float RGB).
    /// Returns LUTData with dimension 33 and RGBA floats (alpha appended as 1.0).
    public static func loadHalideCCube(data: Data) throws -> LUTData {
        // LZFSE decompress
        let decompressed = try decompress(data: data, algorithm: COMPRESSION_LZFSE)
        
        // Expected: 33³ * 6 bytes = 215,622 bytes (3 half-floats per texel)
        let expectedBytes = 33 * 33 * 33 * 6
        guard decompressed.count == expectedBytes else {
            throw LUTError.invalidSize(expected: expectedBytes, actual: decompressed.count)
        }
        
        // Decode half-floats to RGBA floats (append alpha 1.0)
        var rgba: [Float] = []
        rgba.reserveCapacity(33 * 33 * 33 * 4)
        
        decompressed.withUnsafeBytes { buffer in
            let halfFloats = buffer.bindMemory(to: UInt16.self)
            for i in stride(from: 0, to: halfFloats.count, by: 3) {
                let r = Float16(bitPattern: halfFloats[i])
                let g = Float16(bitPattern: halfFloats[i + 1])
                let b = Float16(bitPattern: halfFloats[i + 2])
                rgba.append(Float(r))
                rgba.append(Float(g))
                rgba.append(Float(b))
                rgba.append(1.0)  // alpha
            }
        }
        
        return LUTData(dimension: 33, rgba: rgba)
    }
    
    // MARK: - No Fusion .lutbin (raw float32 RGBA)
    
    /// Decode a No Fusion .lutbin LUT (raw float32 RGBA, size³ * 16 bytes).
    /// Dimension must match the preset's declared size (25, 32, or 33).
    public static func loadNoFusionLutbin(data: Data, dimension: Int) throws -> LUTData {
        let expectedBytes = dimension * dimension * dimension * 4 * 4
        guard data.count == expectedBytes else {
            throw LUTError.invalidSize(expected: expectedBytes, actual: data.count)
        }
        
        // Decode little-endian float32 RGBA
        var rgba: [Float] = []
        rgba.reserveCapacity(dimension * dimension * dimension * 4)
        
        data.withUnsafeBytes { buffer in
            let floats = buffer.bindMemory(to: Float.self)
            rgba.append(contentsOf: floats)
        }
        
        // Verify alpha is 1.0 (per No Fusion README)
        #if DEBUG
        for i in stride(from: 3, to: rgba.count, by: 4) {
            assert(rgba[i] == 1.0, "No Fusion LUT alpha must be 1.0")
        }
        #endif
        
        return LUTData(dimension: dimension, rgba: rgba)
    }
    
    // MARK: - LZFSE decompression
    
    private static func decompress(data: Data, algorithm: compression_algorithm) throws -> Data {
        let bufferSize = 1024 * 1024  // 1MB buffer
        var decompressed = Data()
        
        try data.withUnsafeBytes { (srcBuffer: UnsafeRawBufferPointer) in
            guard let srcPtr = srcBuffer.baseAddress else {
                throw LUTError.decompressionFailed
            }
            
            var dstBuffer = [UInt8](repeating: 0, count: bufferSize)
            
            let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
            defer { stream.deallocate() }
            
            var status = compression_stream_init(stream, COMPRESSION_STREAM_DECODE, algorithm)
            guard status == COMPRESSION_STATUS_OK else {
                throw LUTError.decompressionFailed
            }
            defer { compression_stream_destroy(stream) }
            
            stream.pointee.src_ptr = srcPtr.assumingMemoryBound(to: UInt8.self)
            stream.pointee.src_size = data.count
            
            try dstBuffer.withUnsafeMutableBufferPointer { destination in
                repeat {
                    stream.pointee.dst_ptr = destination.baseAddress!
                    stream.pointee.dst_size = destination.count

                    status = compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                    guard status == COMPRESSION_STATUS_OK || status == COMPRESSION_STATUS_END else {
                        throw LUTError.decompressionFailed
                    }
                    let written = destination.count - stream.pointee.dst_size
                    decompressed.append(destination.baseAddress!, count: written)
                } while status == COMPRESSION_STATUS_OK
            }
        }
        
        return decompressed
    }
}

public enum LUTError: Error, LocalizedError {
    case invalidSize(expected: Int, actual: Int)
    case decompressionFailed
    case resourceNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidSize(let expected, let actual):
            return "LUT size mismatch: expected \(expected) bytes, got \(actual)"
        case .decompressionFailed:
            return "LZFSE decompression failed"
        case .resourceNotFound(let name):
            return "LUT resource not found: \(name)"
        }
    }
}
