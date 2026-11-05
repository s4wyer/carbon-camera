import CoreImage

/// Shared Core Image context for image loading paths that do not need a dedicated Metal context.
enum CIContextProvider {
    // D-019: sRGB primaries, with linear light and extended range for scene
    // processing. LUTs and files use the sRGB transfer function explicitly.
    // Keep 16-bit floating-point intermediates; quantize only at export.
    static let workingColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    static let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    static let workingFormat = CIFormat.RGBAh
    static var renderingOptions: [CIContextOption: Any] {
        [
            .workingColorSpace: workingColorSpace,
            .workingFormat: workingFormat.rawValue,
            .outputColorSpace: outputColorSpace
        ]
    }

    static let shared = CIContext(options: renderingOptions.merging(
        [.useSoftwareRenderer: false], uniquingKeysWith: { _, new in new }
    ))
}
