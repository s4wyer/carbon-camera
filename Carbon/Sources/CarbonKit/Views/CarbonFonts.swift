import SwiftUI

/// Typographic styles modeled directly on `preset-card-concepts.html`:
/// - `Inter-SemiBold` (weights 600) for running UI copy and restrained labels
/// - `InterTight-Light` (300) and `InterTight-Black` (900) for Braun numerals and modernist block headlines
/// - `ZenKakuGothicNew-Black` (900) for the Japanese poster geometry of Lapse
///
/// These faces are registered from the app bundle in project.yml; Stock artwork
/// intentionally does not silently substitute system fonts.
enum CarbonFont {
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if weight == .semibold || weight == .bold || weight == .heavy || weight == .black {
            return .custom("Inter-SemiBold", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    /// Fixed bundled face for Stock artwork, avoiding system-font substitution.
    static func stockInter(size: CGFloat) -> Font {
        .custom("Inter-SemiBold", size: size)
    }

    static func interTightLight(size: CGFloat) -> Font {
        .custom("InterTight-Light", size: size)
    }

    static func interTightBlack(size: CGFloat) -> Font {
        .custom("InterTight-Black", size: size)
    }

    static func spaceMono(size: CGFloat, bold: Bool = false) -> Font {
        if bold {
            return .custom("SpaceMono-Bold", size: size)
        }
        return .custom("SpaceMono-Regular", size: size)
    }

    static func zenKakuBlack(size: CGFloat) -> Font {
        .custom("ZenKakuGothicNew-Black", size: size)
    }
}
