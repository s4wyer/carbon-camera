import SwiftUI

/// Motion observation is deliberately isolated to this overlay so device updates
/// don't invalidate the static typography and background artwork.
struct StockSheenView: View {
    @ObservedObject var motion: StockMotionManager
    let strength: Double
    let fallbackTilt: CGSize
    let reduceMotion: Bool

    private var tilt: CGSize { reduceMotion ? .zero : (motion.isMotionAvailable ? motion.tilt : fallbackTilt) }

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(stops: [
                .init(color: .white.opacity(0), location: 0),
                .init(color: .white.opacity(strength * 0.35), location: 0.34),
                .init(color: .white.opacity(strength), location: 0.50),
                .init(color: .white.opacity(strength * 0.25), location: 0.61),
                .init(color: .white.opacity(0), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: proxy.size.width * 1.45, height: proxy.size.height * 1.8)
            .rotationEffect(.degrees(-18))
            .offset(x: proxy.size.width * 0.24 + tilt.width * 1.8,
                    y: -proxy.size.height * 0.38 + tilt.height * 1.8)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }
}
