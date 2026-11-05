import SwiftUI

/// Collectible Stock artwork. The four families share material and interaction,
/// but each retains a deliberately different graphic language.
struct PresetBoxArtView: View {
    let preset: PresetDefinition
    let isSelected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let motion: StockMotionManager
    let viewportHeight: CGFloat
    @State private var dragTilt: CGSize = .zero

    init(preset: PresetDefinition, isSelected: Bool, motion: StockMotionManager = .shared, viewportHeight: CGFloat = 600) {
        self.preset = preset
        self.isSelected = isSelected
        self.motion = motion
        self.viewportHeight = viewportHeight
    }

    private var design: StockCardDesign.Palette { StockCardDesign.palette(for: preset) }
    private var brand: Brand {
        switch preset.source {
        case .original: .carbon
        case .halideReference: .halide
        case .lapseReference: .lapse
        case .nofusionReference: .noFusion
        }
    }
    private enum Brand { case carbon, halide, lapse, noFusion }
    private var layout: StockCardDesign.Layout { StockCardDesign.layout(for: preset) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                art(size: proxy.size)
                    .environment(\.dynamicTypeSize, .large)
                    .offset(y: reduceMotion ? 0 : parallax(proxy.frame(in: .named("stockScroll")).midY))
                StockSheenView(motion: motion, strength: reduceMotion ? 0.10 : (isSelected ? 0.30 : (design.metallic ? 0.28 : 0.17)), fallbackTilt: dragTilt, reduceMotion: reduceMotion)
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Circle().fill(Color(hex: "F0401F"))
                                .frame(width: 8, height: 8)
                                .padding(10)
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelected ? Color(hex: "F6F3EC") : Color.white.opacity(0.20), lineWidth: isSelected ? 3 : 1))
            .overlay(alignment: .top) {
                Rectangle().fill(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.02), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
            }
            .shadow(color: .black.opacity(0.38), radius: 10, x: 0, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { value in
                guard !motion.isMotionAvailable, !reduceMotion else { return }
                dragTilt = CGSize(width: max(-20, min(20, value.translation.width * 0.35)),
                                  height: max(-14, min(14, value.translation.height * 0.35)))
            }.onEnded { _ in withAnimation(.easeOut(duration: 0.35)) { dragTilt = .zero } })
            .accessibilityLabel("\(preset.displayName), \(preset.sourceDisplayName) preset")
        }
        .aspectRatio(1.25, contentMode: .fit)
    }

    private func parallax(_ midY: CGFloat) -> CGFloat {
        let normalized = (midY - viewportHeight * 0.5) / max(1, viewportHeight)
        return min(4, max(-4, normalized * -8))
    }

    @ViewBuilder private func art(size: CGSize) -> some View {
        switch brand {
        case .carbon: carbon(size)
        case .halide: halide(size)
        case .lapse: lapse(size)
        case .noFusion: noFusion(size)
        }
    }

    private func carbon(_ size: CGSize) -> some View {
        let ink = design.ink
        return ZStack(alignment: .topLeading) {
            design.ground
            VStack(alignment: .leading, spacing: 0) {
                Text("carbon").font(CarbonFont.stockInter(size: size.height * 0.085)).foregroundStyle(ink)
                Rectangle().fill(Color(hex: "F0401F")).frame(width: size.width * 0.23, height: 2)
                    .padding(.top, 3).padding(.bottom, 3)
                Text(preset.displayName.lowercased())
                    .font(CarbonFont.stockInter(size: size.height * 0.052)).foregroundStyle(ink)
                    .lineLimit(2).minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                Text(catalogNumber)
                    .font(CarbonFont.interTightLight(size: size.height * 0.64))
                    .tracking(-size.height * 0.04).foregroundStyle(ink)
                    .lineLimit(1).minimumScaleFactor(0.55)
                    .frame(maxWidth: size.width * 0.76, maxHeight: size.height * 0.60, alignment: .bottomLeading)
            }
            .padding(.leading, size.width * 0.07).padding(.top, size.height * 0.07).padding(.bottom, size.height * 0.02)
        }
    }

    private func halide(_ size: CGSize) -> some View {
        let number = catalogNumber
        return ZStack(alignment: .topLeading) {
            design.ground
            switch layout {
            case .grid:
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) { design.block; design.ground }
                        HStack(spacing: 0) { design.ground; design.block }
                    }.frame(height: size.height * 0.42)
                    design.ground
                }
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: size.height * 0.44)
                    HStack {
                        Text("HALIDE").font(CarbonFont.interTightBlack(size: size.height * 0.09)).foregroundStyle(design.ink)
                        Spacer()
                        Text(number).font(CarbonFont.interTightBlack(size: size.height * 0.09)).foregroundStyle(design.ink)
                    }
                    Spacer(minLength: size.height * 0.04)
                    Text(preset.displayName.uppercased()).font(CarbonFont.interTightBlack(size: size.height * 0.22))
                        .foregroundStyle(design.ink).lineLimit(2).minimumScaleFactor(0.48)
                }.padding(.horizontal, size.width * 0.07).padding(.bottom, size.height * 0.04).frame(maxHeight: .infinity, alignment: .top)
            case .header:
                VStack(spacing: 0) {
                    HStack { Text("HALIDE"); Spacer(); Text(number) }
                        .font(CarbonFont.interTightBlack(size: size.height * 0.105)).foregroundStyle(StockCardDesign.contrastInk(for: design.block))
                        .padding(.horizontal, size.width * 0.07).frame(height: size.height * 0.26).background(design.block)
                    ZStack(alignment: .bottomLeading) {
                        design.ground
                        Text(preset.displayName.uppercased()).font(CarbonFont.interTightBlack(size: size.height * 0.30))
                            .tracking(-size.height * 0.02).foregroundStyle(design.ink).lineLimit(2).minimumScaleFactor(0.45)
                            .offset(x: -size.width * 0.025, y: size.height * 0.04)
                    }
                }
            case .split:
                HStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        design.block
                        Text(number).font(CarbonFont.interTightBlack(size: size.height * 0.66)).foregroundStyle(StockCardDesign.contrastInk(for: design.block))
                            .offset(x: -size.width * 0.05, y: size.height * 0.10)
                    }.frame(width: size.width * 0.43)
                    VStack(alignment: .leading) {
                        Text("HALIDE").font(CarbonFont.interTightBlack(size: size.height * 0.095)).foregroundStyle(design.ink)
                        Spacer()
                        Text(preset.displayName.uppercased()).font(CarbonFont.interTightBlack(size: size.height * 0.19))
                            .foregroundStyle(design.ink).lineLimit(3).minimumScaleFactor(0.48)
                    }.padding(size.width * 0.06).frame(maxWidth: .infinity, alignment: .leading)
                }
            case .bars:
                VStack(spacing: 0) {
                    design.block.frame(height: size.height * 0.16)
                    Spacer(minLength: 0)
                    design.block.frame(height: size.height * 0.12)
                }
                VStack(alignment: .leading) {
                    Text("HALIDE").font(CarbonFont.interTightBlack(size: size.height * 0.09)).foregroundStyle(design.ink)
                    Spacer()
                    Text(preset.displayName.uppercased()).font(CarbonFont.interTightBlack(size: size.height * 0.23))
                        .foregroundStyle(design.ink).lineLimit(2).minimumScaleFactor(0.45)
                    Text(number).font(CarbonFont.interTightBlack(size: size.height * 0.09)).foregroundStyle(design.ink)
                }.padding(.horizontal, size.width * 0.06).padding(.vertical, size.height * 0.19)
            case .bleed:
                Rectangle().fill(design.block).frame(width: size.width * 0.58, height: size.height * 0.70)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                VStack(alignment: .leading) {
                    HStack {
                        Text("HALIDE").font(CarbonFont.interTightBlack(size: size.height * 0.09)).foregroundStyle(design.ink)
                        Spacer()
                        Text(number).font(CarbonFont.interTightBlack(size: size.height * 0.10)).foregroundStyle(StockCardDesign.contrastInk(for: design.block))
                    }
                    Spacer()
                    Text(preset.displayName.uppercased()).font(CarbonFont.interTightBlack(size: size.height * 0.15))
                        .foregroundStyle(design.ink).lineLimit(2).minimumScaleFactor(0.5).frame(maxWidth: size.width * 0.66, alignment: .leading)
                }.padding(size.width * 0.06)
            case .offset:
                Rectangle().fill(design.block).frame(width: size.width * 0.68, height: size.height * 0.62)
                    .offset(x: size.width * 0.32, y: size.height * 0.38)
                VStack(alignment: .leading) {
                    Text("HALIDE · \(number)").font(CarbonFont.interTightBlack(size: size.height * 0.09)).foregroundStyle(design.ink)
                    Spacer()
                    Text(preset.displayName.uppercased()).font(CarbonFont.interTightBlack(size: size.height * 0.24))
                        .foregroundStyle(design.ink).lineLimit(2).minimumScaleFactor(0.45)
                }.padding(size.width * 0.07)
            }
        }
        .clipped()
    }

    private func lapse(_ size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            design.ground
            Circle().fill(design.block).frame(width: size.height * (layout == .grid ? 1.25 : 1.42), height: size.height * (layout == .grid ? 1.25 : 1.42))
                .offset(x: layout == .grid ? size.width * 0.68 : -size.width * 0.78,
                        y: layout == .grid ? size.height * 0.43 : size.height * 0.48)
            VStack(alignment: layout == .grid ? .leading : .trailing) {
                HStack {
                    Text("LAPSE").font(CarbonFont.stockInter(size: size.height * 0.095)).tracking(2).foregroundStyle(design.ink)
                    Spacer()
                    if layout != .grid {
                        Text(catalogNumber).font(CarbonFont.zenKakuBlack(size: size.height * 0.24)).foregroundStyle(design.ink)
                    }
                }
                Spacer()
                if layout == .grid {
                    Text(catalogNumber).font(CarbonFont.zenKakuBlack(size: size.height * 0.28))
                        .foregroundStyle(StockCardDesign.contrastInk(for: design.block))
                }
                Text(preset.displayName.uppercased()).font(CarbonFont.zenKakuBlack(size: size.height * 0.17))
                    .foregroundStyle(design.ink).lineLimit(2).minimumScaleFactor(0.52)
                    .frame(maxWidth: size.width * 0.64, alignment: layout == .grid ? .leading : .trailing)
            }
            .frame(width: size.width * 0.52)
            .frame(maxHeight: .infinity, alignment: layout == .grid ? .leading : .trailing)
            .padding(size.width * 0.07)
        }.clipped()
    }

    /// No Fusion keeps a distinct print-label voice, now with bespoke color, scale,
    /// stable numbering, editorial crops and the same foil-paper material.
    private func noFusion(_ size: CGSize) -> some View {
        let palette = design
        let blockInk = StockCardDesign.contrastInk(for: palette.block)
        return ZStack(alignment: .topLeading) {
            palette.ground
            switch layout {
            case .grid:
                VStack(spacing: 0) { HStack(spacing: 0) { palette.block; palette.ground }; HStack(spacing: 0) { palette.ground; palette.block } }
                    .frame(height: size.height * 0.42)
            case .header:
                palette.block.frame(height: size.height * 0.23)
            case .split:
                palette.block.frame(width: size.width * 0.38).frame(maxWidth: .infinity, alignment: .trailing)
            case .bars:
                VStack(spacing: 0) { palette.block.frame(height: size.height * 0.22); Spacer(); palette.block.frame(height: size.height * 0.18) }
            case .bleed:
                Rectangle().fill(palette.block).frame(width: size.width * 0.52, height: size.height * 0.72)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            case .offset:
                Rectangle().fill(palette.block).frame(width: size.width * 0.48, height: size.height * 0.58)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            VStack(alignment: .leading, spacing: 0) {
                if layout == .grid { Spacer().frame(height: size.height * 0.44) }
                HStack(alignment: .top) {
                    Text("NO FUSION").font(CarbonFont.interTightBlack(size: size.height * 0.10)).tracking(1)
                        .foregroundStyle(layout == .header ? blockInk : palette.ink)
                    Spacer(minLength: 1)
                    Text(catalogNumber).font(CarbonFont.interTightBlack(size: size.height * 0.14))
                        .foregroundStyle(layout == .header ? blockInk : palette.ink)
                }
                Rectangle().fill(palette.accent).frame(height: 3).padding(.vertical, size.height * 0.045)
                Spacer(minLength: 0)
                Text(preset.displayName.uppercased()).font(CarbonFont.interTightBlack(size: size.height * 0.25))
                    .tracking(-size.height * 0.01).foregroundStyle(palette.ink).lineLimit(2).minimumScaleFactor(0.42)
                    .frame(maxWidth: size.width * 0.44, alignment: .leading)
                    .frame(maxWidth: size.width * 0.58, alignment: .leading)
            }.padding(size.width * 0.065)
        }.clipped()
    }

    private var catalogNumber: String { String(format: "%02d", min(99, preset.catalogNumber)) }
}
