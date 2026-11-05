import SwiftUI

/// Redesigned preset box art cards inspired by preset-card-concepts.html.
/// Each brand family (Carbon, Halide, Lapse, No Fusion) has distinct design principles
/// that repeat across cards in that category, while each individual card varies by content
/// and preset characteristics.
struct PresetBoxArtView: View {
    let preset: PresetDefinition
    let isSelected: Bool

    private let palette: PresetPalette

    init(preset: PresetDefinition, isSelected: Bool) {
        self.preset = preset
        self.isSelected = isSelected
        self.palette = PresetPalette.make(for: preset)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            brandComposition
            if isSelected { selectionMark }
        }
        .aspectRatio(1.25, contentMode: .fit) // 320:256 reference ratio
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color("Brass") : Color.white.opacity(0.12),
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
        .shadow(
            color: .black.opacity(isSelected ? 0.45 : 0.25),
            radius: isSelected ? 8 : 4,
            y: isSelected ? 4 : 2
        )
        .accessibilityLabel("\(preset.displayName) film box")
    }

    @ViewBuilder
    private var brandComposition: some View {
        switch preset.source {
        case .original: carbonCard
        case .halideReference: halideCard
        case .lapseReference: lapseCard
        case .nofusionReference: noFusionCard
        }
    }

    // MARK: - Carbon: Braun-style restraint, lowercase labels, one orange line

    private var carbonCard: some View {
        let isDark = palette.midtone.luma < 0.45
        let bgColor = isDark ? Color(hex: "1A1A18") : Color(hex: "EDEAE2")
        let textColor = isDark ? Color(hex: "EDEAE2") : Color(hex: "141413")
        let subColor = isDark ? Color(hex: "B5B2AA") : Color(hex: "6B6860")

        return ZStack(alignment: .topLeading) {
            bgColor.ignoresSafeArea()

            // Orange accent line (Braun signature)
            Rectangle()
                .fill(Color(hex: "F0401F"))
                .frame(height: 0.012 * 256) // 3px at reference size
                .padding(.horizontal, 0.044 * 320) // 14px
                .offset(y: 0.164 * 256) // 42px

            // Header: lowercase name + "carbon" brand
            VStack(alignment: .leading, spacing: 0.008 * 256) {
                Text(preset.displayName.lowercased())
                    .font(CarbonFont.inter(size: 0.047 * 256, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Text("carbon")
                    .font(CarbonFont.inter(size: 0.043 * 256, weight: .semibold))
                    .foregroundStyle(subColor)
            }
            .padding(.leading, 0.044 * 320)
            .padding(.top, 0.055 * 256)

            // Giant display numeral (bottom left, ultra-light weight)
            Text(brandIndexString)
                .font(CarbonFont.interTightLight(size: 0.375 * 256))
                .tracking(-0.02 * 256) // -5px at reference size
                .foregroundStyle(textColor.opacity(isDark ? 0.28 : 0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 0.025 * 320)
                .padding(.bottom, -0.055 * 256)

            // Effect labels (bottom right)
            HStack(spacing: 0.016 * 320) {
                Spacer()
                Text(carbonEffectsLabel)
                    .font(CarbonFont.inter(size: 0.035 * 256, weight: .semibold))
                    .foregroundStyle(subColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 0.044 * 320)
            .padding(.bottom, 0.055 * 256)
        }
    }

    private var carbonEffectsLabel: String {
        var effects: [String] = []
        if preset.baseParameters.grainAmount > 0.15 { effects.append("grain") }
        if preset.baseParameters.halationIntensity > 0.1 || preset.baseParameters.bloomAmount > 0.1 {
            effects.append("glow")
        }
        return effects.isEmpty ? "tone" : effects.joined(separator: " / ")
    }

    // MARK: - Halide: Italian modernist grid, heavy type, flat color blocks

    private var halideCard: some View {
        ZStack {
            Color(hex: "111111").ignoresSafeArea()

            let index = brandIndex
            let (primaryColor, secondaryColor) = halideColors(index: index)
            let primaryLuma = primaryColor.1
            let secondaryLuma = secondaryColor.1
            let primaryInk = primaryLuma > 0.55 ? Color(hex: "111111") : Color.white
            let secondaryInk = secondaryLuma > 0.55 ? Color(hex: "111111") : Color.white

            if index % 2 == 1 {
                // Style A: Left/Right split + bottom bar
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Left block
                        ZStack(alignment: .topLeading) {
                            primaryColor.0.ignoresSafeArea()
                            VStack(alignment: .leading, spacing: 0.008 * 256) {
                                Text("HALIDE")
                                    .font(CarbonFont.interTightBlack(size: 0.035 * 256))
                                    .tracking(0.055)
                                    .foregroundStyle(primaryInk)

                                Spacer()

                                Text(preset.displayName.uppercased())
                                    .font(CarbonFont.interTightBlack(size: 0.086 * 256))
                                    .tracking(-0.031)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.55)
                                    .foregroundStyle(primaryInk)
                            }
                            .padding(0.047 * 320)
                        }
                        .frame(maxWidth: .infinity)

                        // Right block
                        ZStack(alignment: .topTrailing) {
                            secondaryColor.0.ignoresSafeArea()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text("NO.")
                                    .font(CarbonFont.spaceMono(size: 0.031 * 256, bold: true))
                                    .tracking(0.047)
                                    .foregroundStyle(secondaryInk)

                                Spacer()

                                Text(brandIndexString)
                                    .font(CarbonFont.interTightBlack(size: 0.219 * 256))
                                    .tracking(-0.117)
                                    .lineLimit(1)
                                    .foregroundStyle(secondaryInk)
                            }
                            .padding(0.039 * 320)
                        }
                        .frame(width: 0.256 * 320)
                    }
                    .frame(height: 0.406 * 256)

                    // Bottom bar
                    HStack {
                        Text("GLOW")
                            .font(CarbonFont.spaceMono(size: 0.031 * 256, bold: true))
                            .tracking(0.047)
                            .foregroundStyle(Color.white)
                        Spacer()
                    }
                    .padding(.horizontal, 0.047 * 320)
                    .frame(height: 0.133 * 256)
                    .background(Color(hex: "111111"))
                }
            } else {
                // Style B: Top bar + large body
                VStack(spacing: 0) {
                    HStack {
                        Text("HALIDE")
                            .font(CarbonFont.interTightBlack(size: 0.035 * 256))
                            .tracking(0.055)
                            .foregroundStyle(secondaryInk)
                        Spacer()
                        Text("NO. \(brandIndexString)")
                            .font(CarbonFont.interTightBlack(size: 0.043 * 256))
                            .tracking(0.02)
                            .foregroundStyle(secondaryInk)
                    }
                    .padding(.horizontal, 0.047 * 320)
                    .frame(height: 0.125 * 256)
                    .background(secondaryColor.0)

                    ZStack(alignment: .topLeading) {
                        primaryColor.0.ignoresSafeArea()
                        VStack(alignment: .leading, spacing: 0) {
                            Text("GLOW")
                                .font(CarbonFont.spaceMono(size: 0.031 * 256, bold: true))
                                .tracking(0.047)
                                .foregroundStyle(primaryInk.opacity(0.85))
                            Spacer()
                            Text(preset.displayName.uppercased())
                                .font(CarbonFont.interTightBlack(size: 0.148 * 256))
                                .tracking(-0.078)
                                .lineLimit(1)
                                .minimumScaleFactor(0.48)
                                .foregroundStyle(primaryInk)
                        }
                        .padding(0.047 * 320)
                        .padding(.bottom, 0.016 * 256)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }

    private func halideColors(index: Int) -> ((Color, Float), (Color, Float)) {
        // Curated Italian modernist color pairs per preset
        let pairs: [(String, String)] = [
            ("F7D417", "E10600"),  // Process Zero: yellow + red
            ("1F3DDB", "FF6A13"),  // Nova: cobalt + orange
            ("00A3E0", "FFB81C"),  // Zephyr: cyan + amber
            ("D2691E", "8B4513"),  // Rembrandt: chocolate + umber
            ("E10600", "FF1493"),  // Scarlet: red + deep pink
            ("333333", "CCCCCC"),  // Chroma Noir: mono black + light
            ("FF6A13", "90EE90"),  // Valencia: orange + light green
            ("555555", "AAAAAA"),  // Quicksilver: mono grey
            ("FFB347", "9370DB"),  // Dawn: peach + plum
            ("F0E68C", "98D98E"),  // Elysia: khaki + mint
            ("1A1A1A", "808080"),  // Onyx: mono jet + medium grey
        ]

        let pair = pairs[(index - 1) % pairs.count]
        let primary = Color(hex: pair.0)
        let secondary = Color(hex: pair.1)
        let primaryLuma = Float(primary.components.r) * 0.2126 + Float(primary.components.g) * 0.7152 + Float(primary.components.b) * 0.0722
        let secondaryLuma = Float(secondary.components.r) * 0.2126 + Float(secondary.components.g) * 0.7152 + Float(secondary.components.b) * 0.0722

        return ((primary, primaryLuma), (secondary, secondaryLuma))
    }

    // MARK: - Lapse: Japanese graphic, one big form, big numerals

    private var lapseCard: some View {
        let isDark = brandIndex % 2 == 0
        let bgColor = isDark ? Color(hex: "111111") : Color(hex: "F3EEE2")
        let textColor = isDark ? Color(hex: "F6F3EC") : Color(hex: "111111")
        let circleColor: Color = isDark ? Color(hex: "FFD21F") : Color(hex: "F0401F")

        return ZStack(alignment: .topLeading) {
            bgColor.ignoresSafeArea()

            // Giant circle graphic
            GeometryReader { geo in
                let diameter = 0.742 * geo.size.height
                Circle()
                    .fill(circleColor)
                    .frame(width: diameter, height: diameter)
                    .offset(
                        x: isDark ? -diameter * 0.45 : geo.size.width - diameter * 0.55,
                        y: isDark ? -diameter * 0.45 : geo.size.height - diameter * 0.55
                    )
            }

            if isDark {
                // Dark variant: right-aligned numeral, left-aligned name
                VStack(alignment: .trailing, spacing: 0.012 * 256) {
                    Text(brandIndexString)
                        .font(CarbonFont.zenKakuBlack(size: 0.227 * 256))
                        .lineLimit(1)
                        .foregroundStyle(circleColor)

                    Text("LAPSE")
                        .font(CarbonFont.inter(size: 0.039 * 256, weight: .bold))
                        .tracking(0.07)
                        .foregroundStyle(textColor)
                }
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.trailing, 0.055 * 320)
                .padding(.top, 0.039 * 256)

                VStack(alignment: .leading, spacing: 0) {
                    Text(preset.displayName)
                        .font(CarbonFont.zenKakuBlack(size: 0.102 * 256))
                        .tracking(-0.02)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(textColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 0.055 * 320)
                .padding(.bottom, 0.047 * 256)
            } else {
                // Light variant: left-aligned name, right-aligned numeral
                VStack(alignment: .leading, spacing: 0.012 * 256) {
                    Text(preset.displayName)
                        .font(CarbonFont.zenKakuBlack(size: 0.102 * 256))
                        .tracking(-0.02)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(textColor)

                    Text("LAPSE")
                        .font(CarbonFont.inter(size: 0.039 * 256, weight: .bold))
                        .tracking(0.07)
                        .foregroundStyle(textColor)
                }
                .padding(.leading, 0.055 * 320)
                .padding(.top, 0.047 * 256)

                VStack(alignment: .trailing, spacing: -0.016 * 256) {
                    Text("NO.")
                        .font(CarbonFont.spaceMono(size: 0.035 * 256, bold: true))
                        .tracking(0.055)
                        .foregroundStyle(Color.white)
                    Text(brandIndexString)
                        .font(CarbonFont.zenKakuBlack(size: 0.211 * 256))
                        .tracking(-0.078)
                        .foregroundStyle(Color.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 0.063 * 320)
                .padding(.bottom, 0.039 * 256)
            }
        }
    }

    // MARK: - No Fusion: Darkroom technical sheet, film stock labels

    private var noFusionCard: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "E6E3DC").ignoresSafeArea()

            let inkColor = Color(hex: "1F1E1C")
            let accentColor = filmStockAccent

            // Top emulsion registration stripe
            HStack(spacing: 0) {
                Rectangle().fill(palette.shadow.color).frame(width: 0.075 * 320)
                Rectangle().fill(palette.midtone.color)
                Rectangle().fill(accentColor).frame(width: 0.1 * 320)
                Rectangle().fill(palette.highlight.color)
            }
            .frame(height: 0.039 * 256)
            .offset(y: 0.039 * 256)

            // Technical stenciled code (top right)
            Text(presetCode)
                .font(CarbonFont.spaceMono(size: 0.078 * 256, bold: true))
                .tracking(0.02)
                .foregroundStyle(inkColor.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 0.047 * 320)
                .padding(.top, 0.047 * 256)

            // Vertical leader notch
            Rectangle()
                .fill(accentColor)
                .frame(width: 0.0156 * 320)
                .padding(.leading, 0.047 * 320)
                .offset(y: 0.109 * 256)

            // Main info block (bottom)
            VStack(alignment: .leading, spacing: 0.008 * 256) {
                Text("NO FUSION")
                    .font(CarbonFont.spaceMono(size: 0.031 * 256, bold: true))
                    .tracking(0.039)
                    .foregroundStyle(inkColor.opacity(0.65))

                Text(preset.displayName.uppercased())
                    .font(CarbonFont.interTightBlack(size: 0.059 * 256))
                    .tracking(0.008)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(inkColor)

                HStack(spacing: 0.024 * 320) {
                    Text(filmEmulsionSpec)
                        .font(CarbonFont.spaceMono(size: 0.027 * 256, bold: false))
                        .tracking(0.02)
                        .foregroundStyle(inkColor.opacity(0.70))

                    Spacer()

                    Text("EXP. \(brandIndexString)")
                        .font(CarbonFont.spaceMono(size: 0.027 * 256, bold: true))
                        .tracking(0.02)
                        .foregroundStyle(inkColor.opacity(0.60))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 0.086 * 320)
            .padding(.trailing, 0.047 * 320)
            .padding(.bottom, 0.047 * 256)
        }
    }

    private var filmStockAccent: Color {
        let id = preset.presetID.lowercased()
        if id.contains("bw") {
            return Color(hex: "7C7C7C")
        } else if id.contains("k") {
            return Color(hex: "F2A900")
        } else if id.contains("nn") || id.contains("nc") || id.contains("cc") {
            return Color(hex: "438945")
        } else if id.contains("gr") || id.contains("lc") || id.contains("h1") {
            return Color(hex: "00828A")
        } else if id.contains("f") {
            return Color(hex: "1F4E99")
        } else {
            return Color(hex: "C28B52")
        }
    }

    private var filmEmulsionSpec: String {
        if palette.isMonochrome {
            return "B&W EMULSION / 35MM"
        }
        return "COLOR NEGATIVE / 135"
    }

    private var presetCode: String {
        let id = preset.presetID
        if id.hasPrefix("nofusion-") {
            return id.replacingOccurrences(of: "nofusion-", with: "").uppercased()
        }
        return String(preset.displayName.prefix(2)).uppercased()
    }

    // MARK: - Numbering & Helpers

    private var brandIndex: Int {
        switch preset.source {
        case .original:
            return max(1, preset.displayOrder + 1)
        case .halideReference:
            return max(1, preset.displayOrder - 100 + 1)
        case .nofusionReference:
            return max(1, preset.displayOrder - 200 + 1)
        case .lapseReference:
            return max(1, preset.displayOrder - 300 + 1)
        }
    }

    private var brandIndexString: String {
        String(format: "%02d", min(brandIndex, 99))
    }

    private var selectionMark: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color("Remjet"))
                    .frame(width: 22, height: 22)
                    .background(Color("Brass"))
                    .clipShape(Circle())
                    .padding(8)
            }
            Spacer()
        }
    }
}

// MARK: - Color Hex Initializer

private extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var components: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
