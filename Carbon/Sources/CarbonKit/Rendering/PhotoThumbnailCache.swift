// Fast thumbnail generation and caching for Library grid
// Uses CIContext thumbnail generation with persistent disk cache

import UIKit
import CoreImage
import os.log

@MainActor
final class PhotoThumbnailCache {
    static let shared = PhotoThumbnailCache()
    
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let cacheDirectory: URL
    private let logger = Logger(subsystem: "app.carbon", category: "ThumbnailCache")
    
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = caches.appendingPathComponent("Thumbnails", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Generate or retrieve cached 512px thumbnail
    func thumbnail(for shot: Shot) -> UIImage? {
        // Check cache first
        let cacheKey = shot.id.uuidString
        let cacheURL = cacheDirectory.appendingPathComponent("\(cacheKey).jpg")
        
        if let cached = UIImage(contentsOfFile: cacheURL.path) {
            return cached
        }
        
        // Generate thumbnail from source
        guard let source = shot.sources.first,
              FileManager.default.fileExists(atPath: source.mediaURL.path) else {
            logger.warning("No source file for shot \(shot.id)")
            return nil
        }
        
        guard let ciImage = CIImage(contentsOf: source.mediaURL) else {
            logger.error("Failed to load CIImage from \(source.mediaURL.path)")
            return nil
        }
        
        // Scale to 512px on longest edge
        let targetSize: CGFloat = 512
        let scale = targetSize / max(ciImage.extent.width, ciImage.extent.height)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaled = ciImage.transformed(by: transform)
        
        // Render to JPEG
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else {
            logger.error("Failed to render thumbnail for \(shot.id)")
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        
        // Cache to disk
        if let jpegData = uiImage.jpegData(compressionQuality: 0.85) {
            try? jpegData.write(to: cacheURL, options: .atomic)
        }
        
        return uiImage
    }
    
    /// Pre-warm cache for multiple shots in background
    func prefetch(shots: [Shot]) {
        Task { @MainActor in
            for shot in shots {
                _ = thumbnail(for: shot)
            }
        }
    }
}
