// Export photos to system Photos library (deliberate action)
// Only exports current render, requests Photos permission only when needed

import Photos
import UIKit
import CoreImage
import os.log

enum ExportError: LocalizedError {
    case permissionDenied
    case noSource
    case writeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Photos access required to export."
        case .noSource: return "Photo has no source file."
        case .writeFailed(let msg): return "Failed to export: \(msg)"
        }
    }
}

@MainActor
final class PhotoExporter {
    static let shared = PhotoExporter()
    private let logger = Logger(subsystem: "app.carbon", category: "Exporter")
    
    func export(shot: Shot) async throws {
        // Request add-only permission (never reads existing library)
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.permissionDenied
        }
        
        // Prefer the render if available, otherwise the source
        guard let source = shot.sources.first else {
            throw ExportError.noSource
        }
        
        var temporaryURL: URL?
        defer {
            if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
        }

        let exportURL: URL
        if let render = shot.currentRender {
            exportURL = render.outputURL
        } else if let crop = shot.currentRecipe.crop {
            guard let image = PhotoGeometry.sourceImage(at: source.mediaURL) else {
                throw ExportError.noSource
            }
            let cropped = PhotoGeometry.applying(crop, to: image)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString).jpg")
            temporaryURL = url
            try CIContextProvider.shared.writeJPEGRepresentation(
                of: cropped, to: url,
                colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                options: [:]
            )
            exportURL = url
        } else {
            exportURL = source.mediaURL
        }
        
        guard FileManager.default.fileExists(atPath: exportURL.path) else {
            throw ExportError.writeFailed("File not found: \(exportURL.lastPathComponent)")
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: exportURL, options: nil)
            }
            logger.info("Exported shot \(shot.id) to Photos")
        } catch {
            logger.error("Export failed: \(error.localizedDescription)")
            throw ExportError.writeFailed(error.localizedDescription)
        }
    }
}
