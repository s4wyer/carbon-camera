import SwiftUI
import UIKit
import CryptoKit

/// Caches only immutable card artwork. Sheen, selection chrome, and parallax stay live.
@MainActor
final class StockArtworkCache {
    /// Bump when the static artwork recipe or any hand-authored palette changes.
    static let cacheVersion = "stock-art-v2"
    static let shared = StockArtworkCache()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL

    private init() {
        memory.countLimit = 80
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StockArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func image(for key: String) -> UIImage? {
        memory.object(forKey: key as NSString)
    }

    func render<V: View>(key: String, size: CGSize, content: V) async -> UIImage? {
        if let cached = image(for: key) { return cached }
        if let data = await readData(at: fileURL(for: key)), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key as NSString)
            return image
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(size)
        guard let image = renderer.uiImage else { return nil }
        memory.setObject(image, forKey: key as NSString)
        if let data = image.pngData() {
            let destination = fileURL(for: key)
            Task.detached(priority: .utility) {
                try? data.write(to: destination, options: .atomic)
            }
        }
        return image
    }

    private nonisolated func readData(at url: URL) async -> Data? {
        await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name).appendingPathExtension("png")
    }
}
