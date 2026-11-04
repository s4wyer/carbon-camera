import CoreImage

/// Shared Core Image context for image loading paths that do not need a dedicated Metal context.
enum CIContextProvider {
    static let shared = CIContext(options: [.useSoftwareRenderer: false])
}
