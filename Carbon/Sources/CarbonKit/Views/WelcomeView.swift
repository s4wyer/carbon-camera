import SwiftUI

/// 01 WELCOME: First launch screen
struct WelcomeView: View {
    @ObservedObject var coordinator: AppCoordinator
    
    var body: some View {
        ZStack {
            // Warm neutral background
            Color(hex: "#F5F1ED")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Wordmark
                VStack(spacing: 8) {
                    Text("carbon")
                        .font(.custom("Charter", size: 48))
                        .fontWeight(.regular)
                        .foregroundColor(Color(hex: "#1A1614"))
                    
                    Text("A camera worth carrying.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: "#5A5652"))
                }
                .padding(.bottom, 48)
                
                // Hero image placeholder (film canister + film strip)
                HeroImagePlaceholder()
                    .frame(width: 320, height: 320)
                    .padding(.bottom, 64)
                
                // CTA button
                Button(action: {
                    coordinator.requestCameraAccess()
                }) {
                    Text("Open camera")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: "#2C5FFF"))
                        .clipShape(RoundedRectangle(cornerRadius: 999))
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 16)
                
                // Promise
                Text("No account. Just pictures.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "#8A8682"))
                
                Spacer()
            }
        }
    }
}

/// Placeholder for hero product shot
private struct HeroImagePlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#E8E3DE"))
            
            VStack(spacing: 12) {
                // Film canister silhouette
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#C8C3BE"))
                    .frame(width: 80, height: 120)
                
                // Film strip
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#C8C3BE"))
                    .frame(width: 160, height: 32)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var hexNumber: UInt64 = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            let r = Double((hexNumber & 0xff0000) >> 16) / 255
            let g = Double((hexNumber & 0x00ff00) >> 8) / 255
            let b = Double((hexNumber & 0x0000ff) >> 0) / 255
            self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
            return
        }
        
        self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
    }
}
