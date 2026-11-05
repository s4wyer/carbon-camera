// U12, C07, B02, B03 — Film Box End-Flap + preset picker, flash, vocabulary
// Sourced from carbon-build-plan §3 (film flap lists Stock, Lab Options, Flash)

import SwiftUI

/// Film flap overlay: Stock selector, Lab Options, Flash, Credits
struct FilmFlapView: View {
    @Binding var activePreset: PresetDefinition
    @Binding var flashMode: FlashMode
    @Binding var isPresented: Bool
    
    @State private var expandStolenGoods = false
    
    enum FlashMode: String, CaseIterable {
        case auto, on, off
        var icon: String {
            switch self {
            case .auto: return "bolt.badge.a"
            case .on:   return "bolt.fill"
            case .off:  return "bolt.slash"
            }
        }
        var label: String { rawValue.capitalized }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // ── Stock (presets) ───────────────────────────────────────
                Section {
                    ForEach(PresetLibrary.presets(in: .ours)) { preset in
                        presetRow(preset)
                    }
                } header: {
                    Text("Carbon")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color("CarbonInk"))
                        .textCase(nil)
                } footer: {
                    Text("Natural is Carbon's default everyday look. It uses Halide's Process Zero color treatment at reduced intensity, adds grain and a gentle glow around highlights, and leaves warmth, contrast, and saturation controls neutral. It does not apply skin smoothing.")
                        .font(.caption)
                        .foregroundStyle(Color("SecondaryInk"))
                }
                
                Section {
                    DisclosureGroup(
                        isExpanded: $expandStolenGoods,
                        content: {
                            ForEach(PresetLibrary.presets(in: .stolen)) { preset in
                                presetRow(preset)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 32, bottom: 4, trailing: 16))
                            }
                        },
                        label: {
                            HStack {
                                Image(systemName: "theatermasks")
                                    .foregroundStyle(Color("SecondaryInk"))
                                Text("Stolen Goods")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color("Remjet"))
                                Spacer()
                                Text("\(PresetLibrary.presets(in: .stolen).count)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(Color("SecondaryInk"))
                            }
                        }
                    )
                } header: {
                    Text("Other apps' work")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color("CarbonInk"))
                        .textCase(nil)
                } footer: {
                    Text("Recovered and recreated from Halide, Lapse, and No Fusion. Your results may differ.")
                        .font(.caption2)
                        .foregroundStyle(Color("SecondaryInk"))
                }
                
                // ── Flash ─────────────────────────────────────────────────
                Section("Flash") {
                    ForEach(FlashMode.allCases, id: \.self) { mode in
                        Button(action: {
                            flashMode = mode
                        }) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(mode == .on ? Color("Safelight") : Color("Remjet"))
                                Text(mode.label)
                                    .foregroundStyle(Color("Remjet"))
                                Spacer()
                                if flashMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color("CarbonInk"))
                                }
                            }
                        }
                    }
                }
                
                // ── Credits ───────────────────────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Carbon owes a lot to Halide, Lapse, and No Fusion. They spent years figuring out what good iPhone photos look like. We spent a few evenings taking their apps apart. The evidence is in Stock.")
                            .font(.caption)
                            .foregroundStyle(Color("SecondaryInk"))
                        
                        Text("Thanks for the presets. See you in court.")
                            .font(.caption.italic())
                            .foregroundStyle(Color("SecondaryInk"))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Inspiration")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color("CarbonInk"))
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private func presetRow(_ preset: PresetDefinition) -> some View {
        Button(action: {
            activePreset = preset
            isPresented = false
        }) {
            HStack(spacing: 12) {
                // Swatch — a small color indicator based on the preset's temperature offset
                RoundedRectangle(cornerRadius: 3)
                    .fill(swatchColor(for: preset))
                    .frame(width: 6, height: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color("Remjet"))
                    Text(preset.sourceDisplayName)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color("SecondaryInk"))
                }
                Spacer()
                if activePreset.presetID == preset.presetID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color("CarbonInk"))
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func swatchColor(for preset: PresetDefinition) -> Color {
        let t = preset.baseParameters.temperatureOffsetK
        if t > 300 { return Color(red: 0.95, green: 0.7, blue: 0.4) } // warm
        if t < -300 { return Color(red: 0.5, green: 0.65, blue: 0.9) } // cool
        return Color(red: 0.55, green: 0.55, blue: 0.55) // neutral
    }
}
