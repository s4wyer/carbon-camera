import SwiftUI
import UIKit

/// Collectible Stock artwork. The four families share material and interaction,
/// but each retains a deliberately different graphic language.
struct PresetBoxArtView: View {
    let preset: PresetDefinition
    let isSelected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let motion: StockMotionManager
    let viewportHeight: CGFloat
    @State private var dragTilt: CGSize = .zero
    @State private var cachedArtwork: UIImage?

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
                Group {
                    if let cachedArtwork {
                        Image(uiImage: cachedArtwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        art(size: proxy.size)
                            .environment(\.dynamicTypeSize, .large)
                    }
                }
                .offset(y: reduceMotion ? 0 : parallax(proxy.frame(in: .named("stockScroll")).midY))
                .task(id: artworkKey(for: proxy.size)) {
                    let key = artworkKey(for: proxy.size)
                    cachedArtwork = nil
                    // Yield once so the first grid frame can be committed before
                    // ImageRenderer performs its one-time typography/layout work.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    let image = await StockArtworkCache.shared.render(
                        key: key,
                        size: proxy.size,
                        content: art(size: proxy.size).environment(\.dynamicTypeSize, .large)
                    )
                    guard !Task.isCancelled, artworkKey(for: proxy.size) == key else { return }
                    cachedArtwork = image
                }
                StockSheenView(motion: motion, strength: reduceMotion ? 0.10 : (isSelected ? 0.30 : (design.metallic ? 0.28 : 0.17)), fallbackTilt: dragTilt, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
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

    private func artworkKey(for size: CGSize) -> String {
        let scale = Int(UIScreen.main.scale.rounded())
        let width = Int((size.width * CGFloat(scale)).rounded())
        let height = Int((size.height * CGFloat(scale)).rounded())
        let paletteSignature = [design.ground, design.block, design.secondary, design.ink, design.accent]
            .map(colorSignature).joined(separator: "-")
        return StockArtworkCache.cacheVersion + ":" + preset.presetID + ":" + preset.displayName + ":" + preset.description + ":" + preset.engineVersion + ":" + preset.sourceDisplayName + ":" + String(preset.catalogNumber) + ":" + String(design.metallic) + ":" + paletteSignature + ":" + String(width) + "x" + String(height)
    }

    private func colorSignature(_ color: Color) -> String {
        let value = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        value.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return "\(Int(red * 255))-\(Int(green * 255))-\(Int(blue * 255))-\(Int(alpha * 255))"
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
                HStack(alignment: .firstTextBaseline) {
                    Text("carbon").font(CarbonFont.stockInter(size: size.height * 0.075)).foregroundStyle(ink)
                    Spacer(minLength: 4)
                    Text("STOCK / \(catalogNumber)").font(CarbonFont.spaceMono(size: size.height * 0.045))
                        .foregroundStyle(ink.opacity(0.72)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Rectangle().fill(Color(hex: "F0401F")).frame(width: size.width * 0.19, height: 2)
                    .padding(.top, 4).padding(.bottom, 4)
                Text(preset.displayName.lowercased())
                    .font(CarbonFont.stockInter(size: size.height * 0.062)).foregroundStyle(ink)
                    .lineLimit(2).minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(ink.opacity(0.12), lineWidth: max(2, size.height * 0.025))
                        .padding(size.height * 0.035).offset(x: 2, y: -2)
                    Circle().stroke(.white.opacity(0.48), lineWidth: max(2, size.height * 0.025))
                        .padding(size.height * 0.035).offset(x: -2, y: 2)
                    Circle().fill(ink.opacity(0.82)).padding(size.height * 0.07)
                }
                .frame(width: min(size.width * 0.50, size.height * 0.58), height: size.height * 0.53)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, size.width * 0.07).padding(.top, size.height * 0.07).padding(.bottom, size.height * 0.04)
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
        let diameter = size.height * 1.12
        return ZStack(alignment: .topLeading) {
            design.ground
            Circle().fill(design.block.opacity(0.84)).frame(width: diameter, height: diameter)
                .offset(x: -size.width * 0.22, y: -size.height * 0.22)
                .blendMode(.multiply)
            Circle().fill(design.secondary.opacity(0.84)).frame(width: diameter, height: diameter)
                .offset(x: size.width * 0.48, y: size.height * 0.20)
                .blendMode(.multiply)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("LAPSE").font(CarbonFont.stockInter(size: size.height * 0.085)).tracking(2).foregroundStyle(design.ink)
                    Spacer()
                    Text(catalogNumber).font(CarbonFont.zenKakuBlack(size: size.height * 0.23)).foregroundStyle(design.ink)
                }
                Spacer()
                Text(preset.displayName.uppercased()).font(CarbonFont.zenKakuBlack(size: size.height * 0.15))
                    .foregroundStyle(design.ink).lineLimit(2).minimumScaleFactor(0.52)
                    .frame(maxWidth: size.width * 0.68, alignment: .leading)
            }
            .padding(size.width * 0.07).padding(.vertical, size.height * 0.07)
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
