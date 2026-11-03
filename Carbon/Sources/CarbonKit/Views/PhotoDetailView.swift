// G11 — Print detail view: full-screen photo with metadata and controls
// Tap to view, double-tap to flip back, swipe to reject or archive

import SwiftUI
import CoreImage

/// Full-screen photo detail view with editing shortcuts
struct PhotoDetailView: View {
    let shot: Shot
    @Environment(\.dismiss) var dismiss
    @State private var fullImage: UIImage?
    @State private var isFlipped = false
    @State private var scale: CGFloat = 1.0
    @State private var showExportConfirmation = false
    
    var body: some View {
        ZStack {
            Color("Remjet")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with close
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(20)
                
                // Photo viewer
                ZStack {
                    if isFlipped {
                        // Back of print: metadata
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Shot Details")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color("Receipt"))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                metadataRow("Date", shot.timestamp.formatted(date: .abbreviated, time: .standard))
                                metadataRow("ISO", "\(Int(shot.captureMetadata.iso))")
                                metadataRow("Exposure", "\(Int(shot.captureMetadata.exposureDuration.seconds * 1000))ms")
                                metadataRow("Flash", shot.captureMetadata.flashState.rawValue)
                                metadataRow("Preset", shot.currentRecipe.recipeID)
                            }
                            
                            Spacer()
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color("Receipt"))
                        .cornerRadius(12)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Front: photo
                        if let fullImage = fullImage {
                            Image(uiImage: fullImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                        } else {
                            ProgressView()
                                .tint(Color("CarbonInk"))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            self.scale = scale
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isFlipped.toggle()
                    }
                }
                
                // Bottom controls
                HStack(spacing: 20) {
                    Button(action: {}) {
                        Image(systemName: "star")
                            .font(.system(size: 18))
                            .foregroundColor(Color("CarbonInk"))
                    }
                    
                    Button(action: { exportPhoto() }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(Color("CarbonInk"))
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color("CarbonInk"))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .foregroundColor(Color("Safelight"))
                    }
                }
                .padding(20)
            }
        }
        .alert("Exported", isPresented: $showExportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Photo saved to your library.")
        }
        .task {
            // Load full-resolution image
            if let url = shot.sources.first?.mediaURL,
               let ciImage = CIImage(contentsOf: url) {
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    fullImage = UIImage(cgImage: cgImage)
                }
            }
        }
    }
    
    private func exportPhoto() {
        Task {
            do {
                try await PhotoExporter.shared.export(shot: shot)
                showExportConfirmation = true
            } catch {
                print("Export error: \(error.localizedDescription)")
            }
        }
    }
    
    @ViewBuilder
    private func metadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(Color("SecondaryInk"))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Color("Remjet"))
        }
    }
}
