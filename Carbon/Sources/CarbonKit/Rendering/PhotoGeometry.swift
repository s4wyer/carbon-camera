import CoreImage

/// Shared geometry for development, source previews, and exports.
enum PhotoGeometry {
    static func sourceImage(at url: URL, maxPixelSize: CGFloat? = nil) -> CIImage? {
        if RAWDevelopment.isRAW(url) {
            // A failed RAW decode must not fall through to a rendered DNG preview.
            guard let raw = RAWDevelopment.filter(at: url) else { return nil }
            if let maxPixelSize, maxPixelSize > 0 {
                raw.scaleFactor = Float(min(1, maxPixelSize / max(raw.nativeSize.width, raw.nativeSize.height)))
            }
            // Some decoders return a non-nil empty image for invalid input.
            // Treat that as a failed decode before preview sizing or rendering.
            guard let image = raw.outputImage,
                  !image.extent.isEmpty, !image.extent.isInfinite,
                  image.extent.width.isFinite, image.extent.height.isFinite else { return nil }
            return image
        }
        return CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
    }

    static func applying(_ crop: RecipeVersion.Crop?, to image: CIImage) -> CIImage {
        guard let crop else { return image }
        let bounds = image.extent
        let normalized = crop.sourceNormalized
        let rect = CGRect(
            x: bounds.minX + normalized.minX * bounds.width,
            y: bounds.minY + normalized.minY * bounds.height,
            width: normalized.width * bounds.width,
            height: normalized.height * bounds.height
        ).integral.intersection(bounds)
        guard !rect.isEmpty else { return image }
        return image.cropped(to: rect)
            .transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
    }
}
