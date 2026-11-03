// Lab view placeholder — preset editing, reversible development
// Will contain preset gallery, sliders, and controls for M2

import SwiftUI
import CoreImage

struct LabView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var selectedShot: Shot?
    @StateObject private var store = LibraryStore()
    
    var body: some View {
        ZStack {
            Color("Receipt")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("lab")
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundColor(Color("Remjet"))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 6)
                
                // Screen title
                HStack {
                    Text("Lab")
                        .font(.system(size: 38, weight: .regular, design: .serif))
                        .foregroundColor(Color("Remjet"))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // L05: Per-photo development — tap a shot to edit
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tap a photo to edit its preset and rendering parameters.")
                            .font(.caption)
                            .foregroundColor(Color("SecondaryInk"))
                            .padding(.horizontal, 24)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(store.shots) { shot in
                                if let thumb = PhotoThumbnailCache.shared.thumbnail(for: shot) {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .cornerRadius(6)
                                        .onTapGesture {
                                            selectedShot = shot
                                        }
                                } else {
                                    Rectangle()
                                        .fill(Color("Remjet").opacity(0.1))
                                        .cornerRadius(6)
                                        .overlay(
                                            ProgressView()
                                                .tint(Color("SecondaryInk"))
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 16)
                }
                
                Spacer()
                
                // Bottom tab bar
                HStack(spacing: 0) {
                    bottomTabButton("Camera", active: false) {
                        coordinator.navigateTo(.camera)
                    }
                    bottomTabButton("Rolls", active: false) {
                        coordinator.navigateTo(.rolls)
                    }
                    bottomTabButton("Lab", active: true) {}
                }
                .padding(.vertical, 14)
                .background(Color("Receipt"))
                .overlay(
                    Rectangle()
                        .fill(Color("SecondaryInk").opacity(0.15))
                        .frame(height: 0.5),
                    alignment: .top
                )
            }
        }
        .task {
            await store.loadJournal()
        }
        .fullScreenCover(item: $selectedShot) { shot in
            LabEditorView(shot: shot)
        }
    }
    
    @ViewBuilder
    private func bottomTabButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: active ? .semibold : .regular))
                    .foregroundColor(Color("Remjet").opacity(active ? 1.0 : 0.55))
                
                if active {
                    Rectangle()
                        .fill(Color("Remjet"))
                        .frame(width: 40, height: 1.5)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 1.5)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// L05: Per-photo Lab editor — edit preset and sliders
struct LabEditorView: View {
    let shot: Shot
    @Environment(\.dismiss) var dismiss
    @State private var editPreset: PresetDefinition
    @State private var editExposure: Float = 0.0
    @State private var editWarmth: Float = 0.0
    @State private var editContrast: Float = 1.0
    
    init(shot: Shot) {
        self.shot = shot
        _editPreset = State(initialValue: PresetLibrary.all.first { $0.id == shot.currentRecipe.presetDefinitionID } ?? PresetLibrary.defaultPreset ?? PresetLibrary.all[0])
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Thumbnail
                if let url = shot.sources.first?.mediaURL,
                   let ciImage = CIImage(contentsOf: url) {
                    let context = CIContext()
                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                        Image(uiImage: UIImage(cgImage: cgImage))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                    }
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Preset selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stock").font(.caption.weight(.semibold)).foregroundStyle(Color("SecondaryInk"))
                            Menu {
                                ForEach(PresetLibrary.presets(in: .ours)) { preset in
                                    Button(preset.displayName) {
                                        editPreset = preset
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(editPreset.displayName)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                }
                                .foregroundStyle(Color("Remjet"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color("Remjet").opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                        
                        // Sliders
                        VStack(spacing: 12) {
                            sliderControl("Exposure", value: $editExposure, range: -2...2)
                            sliderControl("Warmth", value: $editWarmth, range: -500...500)
                            sliderControl("Contrast", value: $editContrast, range: 0.5...2.0)
                        }
                    }
                    .padding(24)
                }
                
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color("Receipt").opacity(0.5))
                        .foregroundStyle(Color("Remjet"))
                        .cornerRadius(8)
                    
                    Button("Save") {
                        // TODO: Actually re-render with new params and save
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color("CarbonInk"))
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                }
                .padding(20)
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private func sliderControl(_ label: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("SecondaryInk"))
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospaced())
                    .foregroundStyle(Color("Remjet"))
            }
            Slider(value: value, in: range)
                .tint(Color("CarbonInk"))
        }
    }
}
