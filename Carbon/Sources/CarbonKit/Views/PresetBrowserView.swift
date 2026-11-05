// Full-screen preset gallery with card-based layout, favorites, and filters
// Replaces the combined stock+flash FilmFlapView sheet

import SwiftUI

/// Preset browser: card gallery with source filters and favorites
struct PresetBrowserView: View {
    @Binding var activePreset: PresetDefinition
    @Binding var isPresented: Bool
    @StateObject private var favorites = PresetFavorites.shared
    @StateObject private var stockMotion = StockMotionManager.shared
    
    @State private var selectedFilter: PresetFilter = .all
    @State private var showingPresetDetail: PresetDefinition?
    
    enum PresetFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case favorites = "Favorites"
        case carbon = "Carbon"
        case halide = "Halide"
        case lapse = "Lapse"
        case nofusion = "No Fusion"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Remjet").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(PresetFilter.allCases) { filter in
                                filterChip(filter)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .background(Color("Remjet"))
                    
                    Divider()
                        .background(Color("Receipt").opacity(0.15))
                    
                    // Preset grid
                    GeometryReader { viewport in
                        ScrollView {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16)
                                ],
                                spacing: 16
                            ) {
                                ForEach(filteredPresets) { preset in
                                    presetCard(preset, viewportHeight: viewport.size.height)
                                }
                            }
                            .padding(20)
                        }
                        .coordinateSpace(name: "stockScroll")
                    }
                }
            }
            .navigationTitle("Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "F6F3EC"))
                }
            }
            .toolbarBackground(Color("Remjet"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear { stockMotion.start() }
        .onDisappear { stockMotion.stop() }
        .sheet(item: $showingPresetDetail) { preset in
            PresetDetailView(preset: preset, activePreset: $activePreset, isPresented: $isPresented, motion: stockMotion)
        }
    }
    
    // MARK: - Subviews
    
    private var filteredPresets: [PresetDefinition] {
        let all = PresetLibrary.all
        switch selectedFilter {
        case .all:
            return all
        case .favorites:
            return all.filter { favorites.isFavorite($0) }
        case .carbon:
            return all.filter { $0.group == .ours }
        case .halide:
            return all.filter {
                if case .halideReference = $0.source { return true }
                return false
            }
        case .lapse:
            return all.filter {
                if case .lapseReference = $0.source { return true }
                return false
            }
        case .nofusion:
            return all.filter {
                if case .nofusionReference = $0.source { return true }
                return false
            }
        }
    }
    
    @ViewBuilder
    private func filterChip(_ filter: PresetFilter) -> some View {
        let isSelected = selectedFilter == filter
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        }) {
            HStack(spacing: 6) {
                if filter == .favorites {
                    Image(systemName: isSelected ? "heart.fill" : "heart")
                        .font(CarbonFont.stockInter(size: 11))
                }
                Text(filter.rawValue)
                    .font(CarbonFont.stockInter(size: 13))
            }
            .foregroundColor(isSelected ? Color(hex: "171817") : Color(hex: "F6F3EC"))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "F6F3EC") : Color(hex: "F6F3EC").opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color(hex: "F6F3EC").opacity(0.35), lineWidth: 1)
            )
        }
    }
    
    private func effectTags(for preset: PresetDefinition) -> [String] {
        var tags: [String] = []
        if preset.baseParameters.grainAmount > 0.15 { tags.append("GRAIN") }
        if preset.baseParameters.halationIntensity > 0.1 || preset.baseParameters.bloomAmount > 0.1 { tags.append("GLOW") }
        return tags
    }

    @ViewBuilder
    private func presetCard(_ preset: PresetDefinition, viewportHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Box art (tap to select preset)
            Button(action: {
                activePreset = preset
                isPresented = false
            }) {
                PresetBoxArtView(preset: preset, isSelected: activePreset.presetID == preset.presetID, motion: stockMotion, viewportHeight: viewportHeight)
            }
            .buttonStyle(.plain)
            
            // Caption row: name + source on the left, favorite heart on the right (like preset-card-concepts.html)
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Button(action: { showingPresetDetail = preset }) {
                        Text(preset.displayName)
                            .font(CarbonFont.stockInter(size: 14))
                            .foregroundColor(Color(hex: "F6F3EC"))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Details for \(preset.displayName)")
                    
                    Text(preset.sourceDisplayName)
                        .font(CarbonFont.stockInter(size: 11))
                        .foregroundColor(Color(hex: "F6F3EC"))
                        .lineLimit(1)
                    if !effectTags(for: preset).isEmpty {
                        Text(effectTags(for: preset).joined(separator: "  ·  "))
                            .font(CarbonFont.stockInter(size: 10))
                            .foregroundColor(Color(hex: "F6F3EC"))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Favorite heart toggle (clean icon button, no background circle)
                Button(action: {
                    favorites.toggleFavorite(preset)
                }) {
                    Image(systemName: favorites.isFavorite(preset) ? "heart.fill" : "heart")
                        .font(CarbonFont.stockInter(size: 16))
                        .foregroundColor(Color(hex: "F6F3EC"))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Preset Detail Sheet

private struct PresetDetailView: View {
    let preset: PresetDefinition
    @Binding var activePreset: PresetDefinition
    @Binding var isPresented: Bool
    let motion: StockMotionManager
    @StateObject private var favorites = PresetFavorites.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Remjet").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Hero box art
                        PresetBoxArtView(preset: preset, isSelected: activePreset.presetID == preset.presetID, motion: motion)
                            .frame(height: 160)
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text(preset.displayName)
                                .font(CarbonFont.stockInter(size: 24))
                                .foregroundColor(Color("Receipt"))
                            
                            Text(preset.description)
                                .font(CarbonFont.stockInter(size: 15))
                                .foregroundColor(Color("Receipt").opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Attribution
                        if let attribution = preset.attributionText {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Attribution")
                                    .font(CarbonFont.stockInter(size: 11))
                                    .foregroundColor(Color(hex: "F6F3EC"))
                                    .textCase(.uppercase)
                                    .tracking(1.2)
                                
                                Text(attribution)
                                    .font(CarbonFont.stockInter(size: 13))
                                    .foregroundColor(Color("Receipt").opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(Color("Receipt").opacity(0.04))
                            .cornerRadius(6)
                        }
                        
                        // Technical details
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Effect Parameters")
                                .font(CarbonFont.stockInter(size: 11))
                                .foregroundColor(Color(hex: "F6F3EC"))
                                .textCase(.uppercase)
                                .tracking(1.2)
                            
                            VStack(spacing: 8) {
                                paramRow("Grain", value: preset.baseParameters.grainAmount)
                                paramRow("Halation", value: preset.baseParameters.halationIntensity)
                                paramRow("Bloom", value: preset.baseParameters.bloomAmount)
                                paramRow("Contrast", value: preset.baseParameters.contrast)
                                paramRow("Saturation", value: preset.baseParameters.saturation)
                                paramRow("Temperature", value: preset.baseParameters.temperatureOffsetK, unit: "K")
                                if let lutID = preset.baseParameters.lutID, !lutID.isEmpty {
                                    paramRow("LUT Intensity", value: preset.baseParameters.lutIntensity)
                                }
                            }
                        }
                        
                        // Metadata
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Metadata")
                                .font(CarbonFont.stockInter(size: 11))
                                .foregroundColor(Color(hex: "F6F3EC"))
                                .textCase(.uppercase)
                                .tracking(1.2)
                            
                            Text("Preset ID: \(preset.presetID)")
                                .font(CarbonFont.spaceMono(size: 11))
                                .foregroundColor(Color("Receipt").opacity(0.6))
                            
                            Text("Engine: \(preset.engineVersion)")
                                .font(CarbonFont.spaceMono(size: 11))
                                .foregroundColor(Color("Receipt").opacity(0.6))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color("Receipt"))
                }
                
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        favorites.toggleFavorite(preset)
                    }) {
                        Image(systemName: favorites.isFavorite(preset) ? "heart.fill" : "heart")
                            .font(CarbonFont.stockInter(size: 16))
                            .foregroundColor(Color(hex: "F6F3EC"))
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(activePreset.presetID == preset.presetID ? "Selected" : "Use") {
                        activePreset = preset
                        dismiss()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "F6F3EC"))
                    .disabled(activePreset.presetID == preset.presetID)
                }
            }
            .toolbarBackground(Color("Remjet"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private func paramRow(_ label: String, value: Float, unit: String = "") -> some View {
        HStack {
            Text(label)
                .font(CarbonFont.spaceMono(size: 12))
                .foregroundColor(Color("Receipt").opacity(0.75))
            Spacer()
            Text(unit.isEmpty ? String(format: "%.2f", value) : String(format: "%.0f%@", value, unit))
                .font(CarbonFont.spaceMono(size: 12, bold: true))
                .foregroundColor(Color("Receipt"))
        }
    }
}
