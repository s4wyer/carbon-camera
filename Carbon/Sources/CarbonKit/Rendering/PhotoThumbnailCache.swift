// Fast thumbnail generation and caching for Library grid
// Uses ImageIO downsampling with a persistent disk cache.

import UIKit
import CoreImage
import ImageIO
import os.log

final class PhotoThumbnailCache: @unchecked Sendable {
    static let shared = PhotoThumbnailCache()

    private static let targetPixelSize = 512
    private static let cacheVersion = "v2"

    private let ciContext = CIContextProvider.shared
    private let cacheDirectory: URL
    private let workQueue = DispatchQueue(label: "app.carbon.thumbnail-cache", qos: .userInitiated)
    private let logger = Logger(subsystem: "app.carbon", category: "ThumbnailCache")

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = caches.appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Generates or retrieves a thumbnail without blocking the main actor.
    func thumbnail(for shot: Shot) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            workQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                if let key = self.cacheKey(for: shot) {
                    let cacheURL = self.cacheDirectory.appendingPathComponent("\(key).jpg")
                    if let cached = UIImage(contentsOfFile: cacheURL.path) {
                        continuation.resume(returning: cached)
                        return
                    }
                }

                let image = self.generateThumbnail(for: shot)
                continuation.resume(returning: image)
            }
        }
    }

    /// Pre-warm visible or nearby shots without competing with the main actor.
    func prefetch(shots: [Shot]) {
        workQueue.async { [weak self] in
            guard let self else { return }
            for shot in shots {
                guard let key = self.cacheKey(for: shot) else { continue }
                let cacheURL = self.cacheDirectory.appendingPathComponent("\(key).jpg")
                if UIImage(contentsOfFile: cacheURL.path) == nil {
                    _ = self.generateThumbnail(for: shot)
                }
            }
        }
    }

    private func generateThumbnail(for shot: Shot) -> UIImage? {
        guard let source = shot.sources.first,
              FileManager.default.fileExists(atPath: source.mediaURL.path),
              let key = cacheKey(for: shot) else {
            logger.warning("No source file for shot \(shot.id)")
            return nil
        }

        let cacheURL = cacheDirectory.appendingPathComponent("\(key).jpg")
        let image: UIImage?

        // ImageIO downsamples before decoding, avoiding full-resolution RAW/HEIC buffers.
        if let sourceImage = CGImageSourceCreateWithURL(source.mediaURL as CFURL, nil) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: Self.targetPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            image = CGImageSourceCreateThumbnailAtIndex(sourceImage, 0, options as CFDictionary)
                .map { UIImage(cgImage: $0) }
        } else if let ciImage = CIImage(contentsOf: source.mediaURL) {
            let scale = CGFloat(Self.targetPixelSize) / max(ciImage.extent.width, ciImage.extent.height)
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            image = ciContext.createCGImage(scaled, from: scaled.extent).map { UIImage(cgImage: $0) }
        } else {
            logger.error("Failed to load thumbnail source \(source.mediaURL.path)")
            return nil
        }

        guard let image else {
            logger.error("Failed to render thumbnail for \(shot.id)")
            return nil
        }

        if let jpegData = image.jpegData(compressionQuality: 0.85) {
            try? jpegData.write(to: cacheURL, options: .atomic)
        }
        return image
    }

    private func cacheKey(for shot: Shot) -> String? {
        guard let source = shot.sources.first else { return nil }
        let sourceVersion = source.mediaHash.isEmpty ? source.mediaURL.path : source.mediaHash
        let safeVersion = sourceVersion.replacingOccurrences(of: "/", with: "_")
        return "\(Self.cacheVersion)-\(shot.id.uuidString)-\(safeVersion)"
    }
}
