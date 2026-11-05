import Foundation

enum PhotoAspectRatio: String, CaseIterable, Identifiable {
    case threeByFour = "3:4"
    case twoByThree = "2:3"

    var id: String { rawValue }

    var portraitRatio: CGFloat {
        switch self {
        case .threeByFour: return 3.0 / 4.0
        case .twoByThree: return 2.0 / 3.0
        }
    }

    /// The native format keeps the whole source. Crops use the upright image's coordinates.
    func crop(for size: CGSize) -> RecipeVersion.Crop? {
        guard self != .threeByFour, size.width > 0, size.height > 0 else { return nil }
        let target = size.width > size.height ? 1 / portraitRatio : portraitRatio
        let source = size.width / size.height
        let width = min(1, target / source)
        let height = min(1, source / target)
        return RecipeVersion.Crop(
            sourceNormalized: CGRect(x: (1 - width) / 2, y: (1 - height) / 2,
                                     width: width, height: height),
            rotation: 0,
            straightenAngle: 0
        )
    }
}
