import SwiftUI

/// B01 / O01 — application entry. Guest, offline, no account.
/// First launch shows the welcome; a returning user with a granted camera
/// permission goes straight to the camera. The decision of "has launched
/// before" is a single UserDefaults flag, not an account.
@main
struct CarbonApp: App {
    @AppStorage("carbon.hasCompletedWelcome") private var hasCompletedWelcome = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedWelcome {
                CameraPlaceholderView()
            } else {
                WelcomeView(onOpenCamera: { hasCompletedWelcome = true })
            }
        }
    }
}

/// O02 — cream canvas, lowercase serif wordmark, one short line, one action.
/// The film-canister artwork is a SET06 asset and is not embedded yet; the
/// layout reserves its frame so the composition does not shift when it lands.
struct WelcomeView: View {
    var onOpenCamera: () -> Void

    var body: some View {
        ZStack {
            Color("Receipt").ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Text("carbon")
                    .font(.custom("InstrumentSerif-Regular", size: 44, relativeTo: .largeTitle))
                    .foregroundStyle(Color("CarbonInk"))
                    .accessibilityAddTraits(.isHeader)
                Text("A camera for people.")
                    .font(.body)
                    .foregroundStyle(Color("SecondaryInk"))
                Color.clear.frame(height: 240)
                    .accessibilityHidden(true)
                Spacer()
                Button(action: onOpenCamera) {
                    Text("Open camera")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("CarbonInk"))
                .accessibilityHint("Opens the camera. You will be asked for camera access.")
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

/// U01 placeholder until the real camera surface (M1) exists. It is visibly a
/// placeholder and exposes no control that claims to capture.
struct CameraPlaceholderView: View {
    var body: some View {
        ZStack {
            Color("Remjet").ignoresSafeArea()
            VStack(spacing: 12) {
                Text("01 / 24")
                    .font(.custom("JetBrainsMono-Regular", size: 14, relativeTo: .caption))
                    .foregroundStyle(Color("Receipt"))
                Text("Camera surface arrives in M1.")
                    .font(.body)
                    .foregroundStyle(Color("Receipt").opacity(0.7))
            }
        }
    }
}