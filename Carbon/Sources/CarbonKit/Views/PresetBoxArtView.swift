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
            
            // Texture / grain overlay hint
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.clear, Color.black.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Layout content
            VStack(alignment: .leading, spacing: 0) {
                // Top strip: source brand + category
                HStack(alignment: .center) {
                    Text(brandLabel)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(brandTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(brandBadgeBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    
                    Spacer()
                    
                    // Format/ISO hint
                    Text(isoRating)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color("Receipt").opacity(0.75))
                }
                .padding(.horizontal, 10)
                .padding(.top, 9)
                
                Spacer()
                
                // Color accent band across the middle
                accentBand
                    .padding(.horizontal, 10)
                
                Spacer()
                
                // Bottom: Preset name + characteristic tags
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.displayName.uppercased())
                        .font(.system(size: 14, weight: .black, design: .default))
                        .tracking(0.5)
                        .foregroundStyle(Color("Receipt"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text(effectSummary)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("Receipt").opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 9)
            }
            
            // Selected border
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("Brass"), lineWidth: 2)
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color("Brass") : Color("Receipt").opacity(0.12), lineWidth: isSelected ? 2 : 1)
        )
    }
    
    // MARK: - Subviews & Styling
    
    private var boxBackground: some View {
        Group {
            switch preset.source {
            case .original:
                // Carbon's signature deep charcoal with subtle warmth
                LinearGradient(
                    colors: [Color(red: 0.14, green: 0.13, blue: 0.13), Color(red: 0.08, green: 0.07, blue: 0.07)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .halideReference:
                // Halide: technical dark blue-grey
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.15, blue: 0.22), Color(red: 0.07, green: 0.08, blue: 0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .lapseReference:
                // Lapse: warm retro amber-brown
                LinearGradient(
                    colors: [Color(red: 0.22, green: 0.14, blue: 0.09), Color(red: 0.11, green: 0.07, blue: 0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .nofusionReference:
                // No Fusion: film stock aesthetic based on preset name
                nofusionBackground
            }
        }
    }
    
    private var nofusionBackground: some View {
        let name = preset.displayName.lowercased()
        if name.contains("kodak") || name.contains("portra") || name.contains("ultramax") {
            // Kodak gold/red heritage
            return LinearGradient(
                colors: [Color(red: 0.25, green: 0.16, blue: 0.06), Color(red: 0.12, green: 0.08, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if name.contains("fuji") || name.contains("chrome") {
            // Fuji green heritage
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.20, blue: 0.14), Color(red: 0.04, green: 0.10, blue: 0.07)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if name.contains("mono") || name.contains("bw") || name.contains("eternal") {
            // Classic black & white stock
            return LinearGradient(
                colors: [Color(white: 0.22), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Street / contemporary rich charcoal
            return LinearGradient(
                colors: [Color(red: 0.16, green: 0.14, blue: 0.18), Color(red: 0.08, green: 0.07, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
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
        case .original: return Color("Brass")
        case .halideReference: return Color(red: 0.2, green: 0.45, blue: 0.8)
        case .lapseReference: return Color("Safelight")
        case .nofusionReference: return Color(red: 0.35, green: 0.6, blue: 0.4)
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
        HStack(spacing: 3) {
            // Triple-color swatch representing the film's palette
            RoundedRectangle(cornerRadius: 1)
                .fill(paletteColor(index: 0))
                .frame(height: 5)
            RoundedRectangle(cornerRadius: 1)
                .fill(paletteColor(index: 1))
                .frame(height: 5)
            RoundedRectangle(cornerRadius: 1)
                .fill(paletteColor(index: 2))
                .frame(height: 5)
        }
    }
    
    private func paletteColor(index: Int) -> Color {
        let p = preset.baseParameters
        let temp = p.temperatureOffsetK
        let isMono = preset.displayName.lowercased().contains("mono") ||
                     preset.displayName.lowercased().contains("bw") ||
                     preset.displayName.lowercased().contains("quicksilver") ||
                     preset.displayName.lowercased().contains("chroma noir")
        
        if isMono {
            switch index {
            case 0: return Color(white: 0.9)
            case 1: return Color(white: 0.5)
            default: return Color(white: 0.2)
            }
        }
        
        if temp > 200 {
            // Warm tones
            switch index {
            case 0: return Color(red: 0.95, green: 0.75, blue: 0.4)
            case 1: return Color(red: 0.85, green: 0.5, blue: 0.3)
            default: return Color(red: 0.6, green: 0.3, blue: 0.2)
            }
        } else if temp < -200 {
            // Cool tones
            switch index {
            case 0: return Color(red: 0.4, green: 0.7, blue: 0.95)
            case 1: return Color(red: 0.3, green: 0.5, blue: 0.8)
            default: return Color(red: 0.2, green: 0.3, blue: 0.5)
            }
        } else {
            // Natural / balanced
            switch index {
            case 0: return Color("Brass")
            case 1: return Color("Safelight")
            default: return Color(red: 0.4, green: 0.6, blue: 0.5)
            }
        }
    }
    
    private var effectSummary: String {
        var traits: [String] = []
        let p = preset.baseParameters
        if p.grainAmount > 0.15 { traits.append("GRAIN") }
        if p.halationIntensity > 0.1 { traits.append("HALATION") }
        if p.bloomAmount > 0.1 { traits.append("BLOOM") }
        if p.temperatureOffsetK > 200 { traits.append("WARM") }
        if p.temperatureOffsetK < -200 { traits.append("COOL") }
        if p.contrast > 1.15 { traits.append("CONTRAST") }
        if traits.isEmpty { traits.append("CLEAN") }
        return traits.prefix(2).joined(separator: " · ")
    }
}
