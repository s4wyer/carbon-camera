import SwiftUI

/// Typographic styles modeled directly on `preset-card-concepts.html`:
/// - `Inter-SemiBold` (weights 600) for running UI copy and restrained labels
/// - `InterTight-Light` (300) and `InterTight-Black` (900) for Braun numerals and modernist block headlines
/// - `SpaceMono-Regular` / `SpaceMono-Bold` for technical / ISO / darkroom indices
/// - `ZenKakuGothicNew-Black` (900) for the Japanese poster geometry of Lapse
///
/// Every font provides an explicit system-font fallback with matching metrics,
/// so SwiftPM test targets running without the application bundle render cleanly.
enum CarbonFont {
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if weight == .semibold || weight == .bold || weight == .heavy || weight == .black {
            return .custom("Inter-SemiBold", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
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
