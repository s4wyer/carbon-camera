// U01, C10, U07, C07, U02, U03, R08, B10 — Full-Screen Camera Interface
// Matches Screen 02 mockup pixel-for-pixel

import SwiftUI
import AVFoundation

/// 02 CAMERA: Photo-first viewfinder with tactile shutter, prime selector, and rotary MOOD dial
struct CameraView: View {
    @ObservedObject var coordinator: AppCoordinator
    @StateObject private var cameraManager = CameraManager()
    
    // UI state
    @State private var selectedFocal: Double = 35.0
    @State private var moodExposure: Float = 0.0 // -2.0 to +2.0 EV
    @State private var warmthStep: Int = 1       // WARM 01..05
    @State private var showPresetMenu = false
    
    var body: some View {
        ZStack {
            // Remjet background (#0E0E10)
            Color("Remjet")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top header bar (over preview)
                HStack {
                    Button(action: { showPresetMenu = true }) {
                        Text("NATURAL")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .tracking(1.5)
                    }
                    
                    Spacer()
                    
                    // Flash / Warmth toggle
                    HStack(spacing: 8) {
                        Button(action: {
                            cameraManager.cycleFlashMode()
                        }) {
                            Image(systemName: flashIcon)
                                .font(.system(size: 12))
                                .foregroundColor(cameraManager.isCapacitorReady ? Color("Safelight") : .white.opacity(0.5))
                        }
                        
                        Text("WARM \(String(format: "%02d", warmthStep))")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .tracking(1.0)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Viewfinder area (dominant photographic center)
                ZStack {
                    CameraPreviewView(session: cameraManager.session)
                        .clipped()
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { val in
                                    // Vertical preview swipe adjusts Mood EV bias (U02)
                                    let deltaEV = Float(-val.translation.height / 150.0)
                                    moodExposure = max(-2.0, min(2.0, deltaEV))
                                    cameraManager.setExposureBias(moodExposure)
                                }
                        )
                    
                    // Corner brightlines (U07)
                    CornerBrightlinesView()
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Bottom control deck
                VStack(spacing: 24) {
                    // Focal length selector: 24 / (35) / 50 pills (C10)
                    HStack(spacing: 32) {
                        focalButton(24)
                        focalButton(35)
                        focalButton(50)
                    }
                    .padding(.top, 8)
                    
                    // Shutter deck row
                    HStack(alignment: .center) {
                        // Left: Last photo thumbnail shortcut to Library (L01, N05)
                        Button(action: {
                            coordinator.navigateTo(.library)
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .frame(width: 60)
                        
                        Spacer()
                        
                        // Center: 72pt tactile shutter button (C04)
                        Button(action: {
                            triggerShutter()
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 3.5)
                                    .frame(width: 74, height: 74)
                                
                                Circle()
                                    .fill(Color("Receipt"))
                                    .frame(width: 62, height: 62)
                            }
                        }
                        
                        Spacer()
                        
                        // Right: Rotary MOOD dial (-2 to +2 EV) (U02, R08)
                        VStack(spacing: 4) {
                            RotaryMoodDial(value: $moodExposure) { newEV in
                                cameraManager.setExposureBias(newEV)
                            }
                            
                            Text("MOOD")
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .tracking(1.0)
                        }
                        .frame(width: 60)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showPresetMenu) {
            PresetSelectorSheet()
        }
    }
    
    // MARK: - Helpers
    
    private var flashIcon: String {
        switch cameraManager.activeFlashMode {
        case .auto: return "bolt.badge.a"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        @unknown default: return "bolt.badge.a"
        }
    }
    
    @ViewBuilder
    private func focalButton(_ mm: Double) -> some View {
        let isSelected = selectedFocal == mm
        Button(action: {
            selectedFocal = mm
            cameraManager.setFocalLength(mm)
        }) {
            Text("\(Int(mm))")
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .default))
                .foregroundColor(isSelected ? .white : .white.opacity(0.55))
                .frame(width: 42, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        }
    }
    
    private func triggerShutter() {
        // Haptic feedback (B10)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        cameraManager.capturePhoto()
    }
}

// MARK: - Viewfinder Preview

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        
        DispatchQueue.main.async {
            layer.frame = view.bounds
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

// MARK: - Corner Brightlines (U07)

private struct CornerBrightlinesView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let bracketLength: CGFloat = 16
            let lineWidth: CGFloat = 1.0
            let inset: CGFloat = 8
            
            Path { path in
                // Top-Left
                path.move(to: CGPoint(x: inset, y: inset + bracketLength))
                path.addLine(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset + bracketLength, y: inset))
                
                // Top-Right
                path.move(to: CGPoint(x: w - inset - bracketLength, y: inset))
                path.addLine(to: CGPoint(x: w - inset, y: inset))
                path.addLine(to: CGPoint(x: w - inset, y: inset + bracketLength))
                
                // Bottom-Left
                path.move(to: CGPoint(x: inset, y: h - inset - bracketLength))
                path.addLine(to: CGPoint(x: inset, y: h - inset))
                path.addLine(to: CGPoint(x: inset + bracketLength, y: h - inset))
                
                // Bottom-Right
                path.move(to: CGPoint(x: w - inset - bracketLength, y: h - inset))
                path.addLine(to: CGPoint(x: w - inset, y: h - inset))
                path.addLine(to: CGPoint(x: w - inset, y: h - inset - bracketLength))
            }
            .stroke(Color.white.opacity(0.85), lineWidth: lineWidth)
        }
    }
}

// MARK: - Rotary MOOD Dial (U02, R08)

private struct RotaryMoodDial: View {
    @Binding var value: Float
    let onChange: (Float) -> Void
    
    var body: some View {
        ZStack {
            // Metallic dial face
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.35), Color(white: 0.15)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 24
                    )
                )
                .frame(width: 46, height: 46)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            // Radial tick marks
            ForEach(0..<12) { i in
                Rectangle()
                    .fill(Color.white.opacity(i % 3 == 0 ? 0.6 : 0.25))
                    .frame(width: 1, height: i % 3 == 0 ? 5 : 3)
                    .offset(y: -18)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            
            // Notch needle indicator
            Rectangle()
                .fill(Color("Receipt"))
                .frame(width: 2, height: 8)
                .offset(y: -14)
                .rotationEffect(.degrees(Double(value) * 45)) // -90° to +90°
        }
        .gesture(
            DragGesture()
                .onChanged { g in
                    let delta = Float(g.translation.width / 40.0)
                    let newEV = max(-2.0, min(2.0, delta))
                    value = newEV
                    onChange(newEV)
                }
        )
    }
}

// MARK: - Preset Selector Sheet (SET13b "Stolen Goods" Menu)

private struct PresetSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Carbon Originals")) {
                    ForEach(PresetLibrary.presets(in: .ours)) { preset in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.displayName)
                                    .font(.headline)
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if preset.displayOrder == 0 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color("CarbonInk"))
                            }
                        }
                    }
                }
                
                Section(
                    header: Text("Stolen Goods"),
                    footer: Text("Recovered from other camera apps with cheeky attribution (D-024).")
                ) {
                    ForEach(PresetLibrary.presets(in: .stolen)) { preset in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.displayNameWithAttribution)
                                .font(.subheadline)
                            if let attribution = preset.attributionText {
                                Text(attribution)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
