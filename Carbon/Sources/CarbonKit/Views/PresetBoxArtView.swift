import SwiftUI

/// Flat, code-generated film-box packaging for a preset. The palette is sampled
/// from that preset's processing chain, while the composition identifies its brand.
struct PresetBoxArtView: View {
    let preset: PresetDefinition
    let isSelected: Bool

    private let palette: PresetPalette

    init(preset: PresetDefinition, isSelected: Bool) {
        self.preset = preset
        self.isSelected = isSelected
        self.palette = PresetPalette.make(for: preset)
    }

    private var ink: Color { palette.highlight.luma > 0.62 ? Color("Remjet") : Color("Receipt") }
    private var familyAccent: Color {
        if palette.isMonochrome { return Color(white: 0.72) }
        switch preset.source {
        case .original: return Color(red: 0.95, green: 0.70, blue: 0.18)
        case .halideReference: return Color(red: 0.35, green: 0.72, blue: 0.92)
        case .lapseReference: return Color(red: 0.95, green: 0.42, blue: 0.22)
        case .nofusionReference: return Color(red: 0.72, green: 0.84, blue: 0.30)
        }
    }
    private var brandName: String {
        switch preset.source {
        case .original: return "CARBON"
        case .halideReference: return "HALIDE"
        case .lapseReference: return "LAPSE"
        case .nofusionReference: return "NO FUSION"
        }
    }
    private var iso: String {
        let name = preset.displayName.lowercased()
        if name.contains("800") { return "800" }
        if name.contains("400") { return "400" }
        if name.contains("200") { return "200" }
        if name.contains("100") { return "100" }
        if palette.isMonochrome { return "320" }
        if preset.baseParameters.grainAmount > 0.3 { return "400" }
        return "200"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                palette.shadow.color
                brandComposition
                if isSelected { selectionMark }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: 138)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(isSelected ? Color("Brass") : Color.white.opacity(0.16), lineWidth: isSelected ? 2.5 : 1))
        .shadow(color: .black.opacity(isSelected ? 0.42 : 0.24), radius: isSelected ? 7 : 3, y: isSelected ? 4 : 2)
        .accessibilityLabel("\(preset.displayName) film box")
    }

    @ViewBuilder
    private var brandComposition: some View {
        switch preset.source {
        case .original: carbonBox
        case .halideReference: halideBox
        case .lapseReference: lapseBox
        case .nofusionReference: noFusionBox
        }
    }

    private var carbonBox: some View {
        ZStack(alignment: .topLeading) {
            palette.midtone.color
            Rectangle().fill(palette.accent.color).frame(height: 17).rotationEffect(.degrees(-7)).offset(y: 42)
            Rectangle().fill(familyAccent).frame(height: 4).offset(y: 62)
            VStack(alignment: .leading, spacing: 2) {
                brandLine
                Text(preset.displayName.uppercased())
                    .font(.system(size: 13, weight: .black, design: .default))
                    .tracking(0.5)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text("PORTRAIT FILM / 35 MM")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(ink.opacity(0.76))
            }
            .padding(.leading, 11).padding(.top, 10)
            isoBlock(alignment: .trailing).padding(.trailing, 10).padding(.top, 9)
            testStripPanel(x: 11, y: 91, width: 104, height: 28)
        }
    }

    private var halideBox: some View {
        ZStack(alignment: .topLeading) {
            palette.midtone.color
            Rectangle().fill(palette.accent.color).frame(width: 76).rotationEffect(.degrees(18)).offset(x: 118, y: 22)
            Rectangle().fill(familyAccent).frame(height: 12).offset(y: 76)
            Rectangle().fill(palette.highlight.color).frame(height: 3).offset(y: 89)
            VStack(alignment: .leading, spacing: 3) {
                Text("H / LOOKS")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .tracking(1.1).foregroundStyle(ink)
                Text(preset.displayName.uppercased())
                    .font(.system(size: 14, weight: .black, design: .default))
                    .tracking(0.4).foregroundStyle(ink)
                    .lineLimit(1).minimumScaleFactor(0.52)
                Text("PROCESS / EDITION 01")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .tracking(0.5).foregroundStyle(ink.opacity(0.72))
            }
            .padding(.leading, 12).padding(.top, 13)
            isoBlock(alignment: .leading).padding(.leading, 116).padding(.top, 12)
            testStripPanel(x: 11, y: 98, width: 128, height: 25)
        }
    }

    private var lapseBox: some View {
        ZStack(alignment: .topLeading) {
            palette.midtone.color
            Rectangle().fill(palette.highlight.color).frame(height: 48).offset(y: 18)
            Rectangle().fill(palette.accent.color).frame(height: 6).offset(y: 66)
            RoundedRectangle(cornerRadius: 12).fill(familyAccent).frame(width: 86, height: 33).offset(x: 10, y: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text("LAPSE")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.6).foregroundStyle(Color("Remjet"))
                Text(preset.displayName.uppercased())
                    .font(.system(size: 14, weight: .black, design: .default))
                    .tracking(0.3).foregroundStyle(Color("Remjet"))
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .padding(.leading, 19).padding(.top, 17)
            Text("COLOR NEGATIVE")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .tracking(0.7).foregroundStyle(ink.opacity(0.8))
                .rotationEffect(.degrees(-90))
                .offset(x: 142, y: 84)
            isoBlock(alignment: .trailing).padding(.trailing, 12).padding(.top, 69)
            testStripPanel(x: 11, y: 99, width: 117, height: 24)
        }
    }

    private var noFusionBox: some View {
        ZStack(alignment: .topLeading) {
            palette.midtone.color
            HStack(spacing: 0) {
                Rectangle().fill(palette.accent.color)
                Rectangle().fill(familyAccent)
                Rectangle().fill(palette.highlight.color)
            }
            .frame(height: 15).offset(y: 10)
            Rectangle().fill(palette.shadow.color).frame(width: 6).offset(x: 10, y: 35)
            VStack(alignment: .leading, spacing: 2) {
                Text("NO FUSION")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1.0).foregroundStyle(ink)
                Text(preset.displayName.uppercased())
                    .font(.system(size: 14, weight: .black, design: .default))
                    .tracking(0.35).foregroundStyle(ink)
                    .lineLimit(1).minimumScaleFactor(0.45)
                Text("ANALOG COLOR STUDY")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .tracking(0.5).foregroundStyle(ink.opacity(0.78))
            }
            .padding(.leading, 21).padding(.top, 38)
            isoBlock(alignment: .trailing).padding(.trailing, 11).padding(.top, 35)
            testStripPanel(x: 21, y: 98, width: 112, height: 24)
        }
    }

    private var brandLine: some View {
        HStack(spacing: 5) {
            Circle().fill(familyAccent).frame(width: 7, height: 7)
            Text(brandName)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(1.1).foregroundStyle(ink)
        }
    }

    private func isoBlock(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: -4) {
            Text("ISO")
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(1.2).foregroundStyle(ink.opacity(0.8))
            Text(iso)
                .font(.system(size: 31, weight: .black, design: .default))
                .tracking(-1).foregroundStyle(ink)
        }
    }

    private func testStripPanel(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 1) {
            ForEach(Array(palette.testStrip.enumerated()), id: \.offset) { item in
                Rectangle().fill(item.element.color)
            }
        }
        .padding(2)
        .background(Color.black.opacity(0.35))
        .overlay(alignment: .topLeading) {
            Text("TEST / 14")
                .font(.system(size: 5, weight: .black, design: .monospaced))
                .foregroundStyle(ink.opacity(0.78))
                .padding(3)
        }
        .frame(width: width, height: height)
        .position(x: x + width / 2, y: y + height / 2)
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
                    .padding(7)
            }
            Spacer()
        }
    }
}
