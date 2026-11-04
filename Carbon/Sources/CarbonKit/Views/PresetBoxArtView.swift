// Film box art and preset visual representation
// Generates unique, authentic film box styling for each preset

import SwiftUI

/// Distinctive visual box art for a film preset
struct PresetBoxArtView: View {
    let preset: PresetDefinition
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Background base
            boxBackground
            
            // Diagonal stripe pattern overlay
            GeometryReader { geo in
                Canvas { context, size in
                    let stripeSpacing: CGFloat = 8
                    let stripeWidth: CGFloat = 1
                    let stripeCount = Int(size.width / stripeSpacing) + 20
                    
                    for i in 0..<stripeCount {
                        let x = CGFloat(i) * stripeSpacing - size.height
                        let path = Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                        }
                        context.stroke(
                            path,
                            with: .color(.white.opacity(0.02)),
                            lineWidth: stripeWidth
                        )
                    }
                }
            }
            
            // Vignette effect
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                center: .center,
                startRadius: 30,
                endRadius: 120
            )
            
            // Content layout
            VStack(alignment: .leading, spacing: 0) {
                // Top bar: brand badge + metadata
                HStack(alignment: .center, spacing: 8) {
                    // Brand badge with icon
                    HStack(spacing: 4) {
                        brandIcon
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(brandTextColor)
                        
                        Text(brandLabel)
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(brandTextColor)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(brandBadgeBackground)
                    .clipShape(Capsule())
                    .shadow(color: brandBadgeBackground.opacity(0.3), radius: 2, y: 1)
                    
                    Spacer()
                    
                    // ISO rating badge
                    Text(isoRating)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color("Receipt").opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                
                Spacer()
                
                // Center: Accent band and visual identity
                VStack(spacing: 6) {
                    accentBand
                    
                    // Film perforation-style dots
                    HStack(spacing: 4) {
                        ForEach(0..<8, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 3, height: 3)
                        }
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                // Bottom: Preset name + tags
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.displayName.uppercased())
                        .font(.system(size: 15, weight: .black, design: .default))
                        .tracking(0.3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color("Receipt"), Color("Receipt").opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, y: 1)
                    
                    // Effect tags with separators
                    HStack(spacing: 4) {
                        ForEach(effectTags.indices, id: \.self) { index in
                            if index > 0 {
                                Text("/")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color("Brass").opacity(0.5))
                            }
                            Text(effectTags[index])
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color("Receipt").opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            
            // Selected state overlay
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color("Brass"), Color("Brass").opacity(0.6), Color("Brass")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .shadow(color: Color("Brass").opacity(0.4), radius: 4)
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.clear : Color("Receipt").opacity(0.15),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(isSelected ? 0.4 : 0.2),
            radius: isSelected ? 8 : 3,
            y: isSelected ? 4 : 2
        )
    }
    
    // MARK: - Subviews & Styling
    
    private var brandIcon: Image {
        switch preset.source {
        case .original:
            return Image(systemName: "c.circle.fill")
        case .halideReference:
            return Image(systemName: "h.circle.fill")
        case .lapseReference:
            return Image(systemName: "l.circle.fill")
        case .nofusionReference:
            return Image(systemName: "n.circle.fill")
        }
    }
    
    private var boxBackground: some View {
        Group {
            switch preset.source {
            case .original:
                // Carbon: Rich charcoal with brass undertones
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.15, blue: 0.13),
                        Color(red: 0.12, green: 0.11, blue: 0.10),
                        Color(red: 0.08, green: 0.07, blue: 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .halideReference:
                // Halide: Deep technical navy with purple hints
                LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.16, blue: 0.24),
                        Color(red: 0.10, green: 0.11, blue: 0.18),
                        Color(red: 0.06, green: 0.07, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .lapseReference:
                // Lapse: Vintage amber and mahogany
                LinearGradient(
                    colors: [
                        Color(red: 0.24, green: 0.15, blue: 0.08),
                        Color(red: 0.18, green: 0.11, blue: 0.06),
                        Color(red: 0.10, green: 0.06, blue: 0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .nofusionReference:
                // No Fusion: Film stock-specific gradients
                nofusionBackground
            }
        }
    }
    
    private var nofusionBackground: some View {
        let name = preset.displayName.lowercased()
        if name.contains("kodak") || name.contains("portra") || name.contains("ultramax") || name.contains("pro image") {
            // Kodak: Iconic yellow and red box heritage
            return LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.18, blue: 0.06),
                    Color(red: 0.20, green: 0.12, blue: 0.05),
                    Color(red: 0.12, green: 0.07, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if name.contains("fuji") || name.contains("chrome") || name.contains("classic") {
            // Fuji: Deep forest green packaging
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.22, blue: 0.15),
                    Color(red: 0.06, green: 0.16, blue: 0.11),
                    Color(red: 0.04, green: 0.10, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if name.contains("mono") || name.contains("bw") || name.contains("eternal") || name.contains("sepia") {
            // B&W film: Classic silver and graphite
            return LinearGradient(
                colors: [
                    Color(white: 0.24),
                    Color(white: 0.16),
                    Color(white: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if name.contains("gr") {
            // Ricoh GR: Minimalist black with subtle blue
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.14),
                    Color(red: 0.08, green: 0.08, blue: 0.10),
                    Color(red: 0.05, green: 0.05, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if name.contains("hasselblad") {
            // Hasselblad: Sophisticated gunmetal grey
            return LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.18, blue: 0.20),
                    Color(red: 0.12, green: 0.12, blue: 0.14),
                    Color(red: 0.08, green: 0.08, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Contemporary: Deep charcoal with violet hints
            return LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.14, blue: 0.18),
                    Color(red: 0.11, green: 0.10, blue: 0.13),
                    Color(red: 0.07, green: 0.06, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var brandLabel: String {
        switch preset.source {
        case .original: return "CARBON"
        case .halideReference: return "HALIDE"
        case .lapseReference: return "LAPSE"
        case .nofusionReference: return "NO FUSION"
        }
    }
    
    private var brandBadgeBackground: Color {
        switch preset.source {
        case .original:
            return Color("Brass")
        case .halideReference:
            return Color(red: 0.25, green: 0.50, blue: 0.85)
        case .lapseReference:
            return Color("Safelight")
        case .nofusionReference:
            let name = preset.displayName.lowercased()
            if name.contains("kodak") || name.contains("portra") {
                return Color(red: 0.85, green: 0.65, blue: 0.15) // Kodak yellow
            } else if name.contains("fuji") || name.contains("chrome") {
                return Color(red: 0.30, green: 0.70, blue: 0.45) // Fuji green
            } else {
                return Color(red: 0.40, green: 0.65, blue: 0.50) // Generic teal
            }
        }
    }
    
    private var brandTextColor: Color {
        switch preset.source {
        case .original: return Color("Remjet")
        default: return .white
        }
    }
    
    private var isoRating: String {
        // Visual flair reminiscent of film canisters
        let name = preset.displayName.lowercased()
        if name.contains("400") { return "400" }
        if name.contains("200") { return "200" }
        if name.contains("100") { return "100" }
        if name.contains("800") { return "800" }
        if preset.baseParameters.grainAmount > 0.4 { return "800" }
        if preset.baseParameters.grainAmount > 0.2 { return "400" }
        return "200"
    }
    
    private var accentBand: some View {
        HStack(spacing: 2) {
            // Color palette swatches representing the film's character
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                paletteColor(index: index),
                                paletteColor(index: index).opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 6)
                    .shadow(color: paletteColor(index: index).opacity(0.3), radius: 1, y: 1)
            }
        }
    }
    
    private func paletteColor(index: Int) -> Color {
        let p = preset.baseParameters
        let temp = p.temperatureOffsetK
        let name = preset.displayName.lowercased()
        let isMono = name.contains("mono") || name.contains("bw") ||
                     name.contains("quicksilver") || name.contains("chroma noir") ||
                     name.contains("onyx") || name.contains("eternal")
        
        // B&W films: Silver gradient
        if isMono {
            switch index {
            case 0: return Color(white: 0.95)
            case 1: return Color(white: 0.60)
            default: return Color(white: 0.25)
            }
        }
        
        // Kodak stocks: Golden warmth
        if name.contains("kodak") || name.contains("portra") || name.contains("ultramax") {
            switch index {
            case 0: return Color(red: 0.98, green: 0.82, blue: 0.45)
            case 1: return Color(red: 0.92, green: 0.58, blue: 0.32)
            default: return Color(red: 0.75, green: 0.38, blue: 0.22)
            }
        }
        
        // Fuji stocks: Green-blue cast
        if name.contains("fuji") || name.contains("chrome") || name.contains("classic") {
            switch index {
            case 0: return Color(red: 0.45, green: 0.85, blue: 0.65)
            case 1: return Color(red: 0.35, green: 0.68, blue: 0.55)
            default: return Color(red: 0.25, green: 0.50, blue: 0.42)
            }
        }
        
        // Temperature-based for others
        if temp > 200 {
            // Warm-leaning presets
            switch index {
            case 0: return Color(red: 0.98, green: 0.78, blue: 0.42)
            case 1: return Color(red: 0.88, green: 0.55, blue: 0.30)
            default: return Color(red: 0.70, green: 0.35, blue: 0.20)
            }
        } else if temp < -200 {
            // Cool-leaning presets
            switch index {
            case 0: return Color(red: 0.42, green: 0.75, blue: 0.98)
            case 1: return Color(red: 0.32, green: 0.55, blue: 0.85)
            default: return Color(red: 0.22, green: 0.38, blue: 0.65)
            }
        } else {
            // Neutral/balanced presets
            switch index {
            case 0: return Color("Brass")
            case 1: return Color("Safelight")
            default: return Color(red: 0.42, green: 0.65, blue: 0.55)
            }
        }
    }
    
    private var effectTags: [String] {
        var tags: [String] = []
        let p = preset.baseParameters
        
        // Primary characteristics first
        if p.grainAmount > 0.15 { tags.append("GRAIN") }
        if p.halationIntensity > 0.15 { tags.append("GLOW") }
        if p.bloomAmount > 0.1 { tags.append("BLOOM") }
        if p.contrast > 1.15 { tags.append("PUNCHY") }
        else if p.contrast < 0.9 { tags.append("SOFT") }
        
        // Temperature characteristics
        if p.temperatureOffsetK > 300 { tags.append("WARM") }
        else if p.temperatureOffsetK < -300 { tags.append("COOL") }
        
        // Saturation characteristics
        if p.saturation > 1.15 { tags.append("VIVID") }
        else if p.saturation < 0.85 { tags.append("MUTED") }
        
        // Default if no strong characteristics
        if tags.isEmpty { tags.append("BALANCED") }
        
        return Array(tags.prefix(3))
    }
}
