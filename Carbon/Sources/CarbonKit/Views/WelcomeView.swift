import SwiftUI
import UIKit

struct WelcomeView: View {
    let onOpenCamera: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var cardHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .title3) private var buttonSize = 20

    var body: some View {
        GeometryReader { geometry in
            let fullHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
            let compact = fullHeight < 700
            ZStack(alignment: .bottom) {
                WelcomePhotograph(cardHeight: cardHeight)
                    .accessibilityHidden(true)
                // The app uses white status-bar content. Localize its scrim.
                VStack {
                    LinearGradient(colors: [.black.opacity(0.75), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: geometry.safeAreaInsets.top + 64)
                    Spacer()
                }
                .allowsHitTesting(false)

                VStack(spacing: compact ? 10 : 14) {
                    Text("carbon")
                        .font(.system(size: compact ? 46 : 56, weight: .regular, design: .serif))
                        .tracking(-2)
                        .foregroundStyle(Color("Remjet"))
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1 : 0)
                        .animation(entrance(delay: 0.08), value: appeared)
                    Text("A camera worth carrying.")
                        .font(.body)
                        .foregroundStyle(Color("Remjet").opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1 : 0)
                        .animation(entrance(delay: 0.14), value: appeared)
                    Button(action: onOpenCamera) {
                        Text("Open camera")
                            .font(.system(size: buttonSize, weight: .bold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(Color("Receipt"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .padding(.horizontal, 12)
                            .background(Color("WelcomeAccent"), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, compact ? 6 : 10)
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)
                    .animation(entrance(delay: 0.20), value: appeared)
                }
                .padding(.horizontal, 28)
                .padding(.top, compact ? 20 : 28)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 18) + 12)
                .frame(maxWidth: .infinity)
                .background(Color("Receipt"), in: UnevenRoundedRectangle(
                    topLeadingRadius: 34, topTrailingRadius: 34))
                .background {
                    GeometryReader { card in
                        Color.clear.preference(key: WelcomeCardHeight.self, value: card.size.height)
                    }
                }
                .offset(y: appeared || reduceMotion ? 0 : fullHeight)
                .animation(entrance(delay: 0), value: appeared)
                .onPreferenceChange(WelcomeCardHeight.self) { cardHeight = $0 }
            }
            .frame(width: geometry.size.width, height: fullHeight)
            .clipped()
            .offset(y: -geometry.safeAreaInsets.top)
            .onAppear { appeared = true }
        }
        .preferredColorScheme(.light)
        .accessibilityIdentifier("welcome-screen")
    }

    private func entrance(delay: Double) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) :
            .spring(response: 0.56, dampingFraction: 1).delay(delay)
    }
}

private struct WelcomeCardHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct WelcomePhotograph: UIViewRepresentable {
    let cardHeight: CGFloat
    func makeUIView(context: Context) -> PhotographBackdrop { PhotographBackdrop() }
    func updateUIView(_ view: PhotographBackdrop, context: Context) { view.cardHeight = cardHeight }
}

/// Extend only the original outermost rows; draw the complete, unfiltered
/// photograph between them. Decode once, well before the camera button is used.
final class PhotographBackdrop: UIView {
    private let image = UIImage(named: "WelcomeHero")?.preparingForDisplay()
    var cardHeight: CGFloat = 0 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = UIColor(named: "Receipt")
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let image, let cgImage = image.cgImage,
              let context = UIGraphicsGetCurrentContext() else { return }
        UIColor(named: "Receipt")?.setFill()
        context.fill(bounds)
        // Reserve measured card height, including accessibility text sizes.
        let available = max(1, bounds.height - cardHeight - safeAreaInsets.top - 12)
        let width = min(bounds.width, available * image.size.width / image.size.height)
        let height = width * image.size.height / image.size.width
        let y = max(safeAreaInsets.top, (bounds.height - cardHeight - height) * 0.5)
        let photo = CGRect(x: (bounds.width - width) / 2, y: y, width: width, height: height)
        func edge(_ crop: CGRect, into destination: CGRect) {
            guard destination.width > 0, destination.height > 0,
                  let row = cgImage.cropping(to: crop) else { return }
            UIImage(cgImage: row).draw(in: destination)
        }
        let w = CGFloat(cgImage.width), h = CGFloat(cgImage.height)
        edge(CGRect(x: 0, y: 0, width: w, height: 1),
             into: CGRect(x: photo.minX, y: 0, width: width, height: photo.minY + 1))
        edge(CGRect(x: 0, y: h - 1, width: w, height: 1),
             into: CGRect(x: photo.minX, y: photo.maxY - 1, width: width, height: bounds.height - photo.maxY + 1))
        if width < bounds.width {
            edge(CGRect(x: 0, y: 0, width: 1, height: h),
                 into: CGRect(x: 0, y: y, width: photo.minX + 1, height: height))
            edge(CGRect(x: w - 1, y: 0, width: 1, height: h),
                 into: CGRect(x: photo.maxX - 1, y: y, width: bounds.width - photo.maxX + 1, height: height))
        }
        image.draw(in: photo)
    }
}
