import CoreImage

/// Shared geometry for development, source previews, and exports.
enum PhotoGeometry {
    static func sourceImage(at url: URL) -> CIImage? {
        if url.pathExtension.lowercased() == "dng",
           let raw = CIRAWFilter(imageURL: url), let image = raw.outputImage {
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
