// U01, C10, U07, C07, U02, U03, R08, B10 — Full-Screen Camera Interface
// Matches Screen 02 mockup pixel-for-pixel

import SwiftUI
import AVFoundation
import CoreMotion

/// 02 CAMERA: Photo-first viewfinder with tactile shutter, prime selector, and rotary MOOD dial
struct CameraView: View {
    @ObservedObject var coordinator: AppCoordinator
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var volumeObserver = VolumeButtonObserver()
    @StateObject private var levelDetector = LevelDetector()
    @Environment(\.openURL) private var openURL
    
    // UI state
    @State private var selectedFocal: Double = 35.0
    @State private var exposureEV: Float = 0.0
    @State private var showPresetMenu = false
    @State private var showSettings = false
    @State private var activePreset: PresetDefinition = PresetLibrary.defaultPreset ?? PresetLibrary.all[0]
    @State private var lastShotThumbnail: UIImage?
    
    var body: some View {
        ZStack {
            // Remjet background (#0E0E10)
            Color("Remjet")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top header bar (over preview)
                HStack(alignment: .center) {
                    // Tapping the preset name opens the preset menu
                    Button(action: { showPresetMenu = true }) {
                        HStack(spacing: 6) {
                            Text(activePreset.displayName.uppercased())
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(Color("Receipt"))
                                .tracking(1.5)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color("Receipt").opacity(0.6))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color("Receipt").opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("preset-name-button")
                    
                    Spacer()
                    
                    // Right: Flash toggle + Settings button
                    HStack(spacing: 12) {
                        Button(action: {
                            cameraManager.cycleFlashMode()
                        }) {
                            Image(systemName: flashIcon)
                                .font(.system(size: 14))
                                .foregroundColor(cameraManager.activeFlashMode == .on ? Color("Safelight") : Color("Receipt").opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Color("Receipt").opacity(0.08))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14))
                                .foregroundColor(Color("Receipt").opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Color("Receipt").opacity(0.08))
                                .clipShape(Circle())
                        }
                        .accessibilityIdentifier("settings-button")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Viewfinder area (dominant photographic center)
                ZStack {
                    CameraPreviewView(session: cameraManager.session)
                        .overlay {
                            if !SampleShotFixture.isEnabled,
                               coordinator.cameraPermissionStatus == .denied || coordinator.cameraPermissionStatus == .restricted {
                                VStack(spacing: 12) {
                                    Text("Camera access is off").font(.headline)
                                    Text("Allow camera access in Settings to take photographs.")
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                    if coordinator.cameraPermissionStatus == .denied {
                                        Button("Open Settings") {
                                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                        }
                                        .font(.headline)
                                        .tint(Color("Receipt"))
                                    }
                                }
                                .foregroundStyle(Color("Receipt"))
                                .padding(24)
                            }
                        }
                        .overlay {
                            if SampleShotFixture.isEnabled,
                               let url = SampleShotFixture.imageURL,
                               let image = UIImage(contentsOfFile: url.path) {
                                GeometryReader { geometry in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                        .accessibilityLabel("Sample photograph")
                                        .accessibilityIdentifier("sample-shot-preview")
                                }
                            }
                        }
                        .clipped()
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { val in
                                    // Vertical preview swipe adjusts exposure bias
                                    let deltaEV = Float(-val.translation.height / 150.0)
                                    exposureEV = max(-2.0, min(2.0, deltaEV))
                                    cameraManager.setExposureBias(exposureEV)
                                }
                        )
                        .onTapGesture { location in
                            // Tap to focus and expose (U05)
                            cameraManager.setFocusAndExposure(at: location)
                        }
                    
                    // Corner brightlines (U07) + Level indicator (U06)
                    CornerBrightlinesView()
                    if levelDetector.isLevel {
                        Rectangle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 20, height: 1)
                            .transition(.opacity)
                    }
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
                        // Left: Roll shortcut (last captured thumbnail → Rolls view)
                        Button(action: {
                            coordinator.navigateTo(.rolls)
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                if let thumb = lastShotThumbnail {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 48, height: 48)
                                        .clipped()
                                        .cornerRadius(4)
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Image(systemName: "film")
                                                .font(.system(size: 16))
                                                .foregroundColor(.white.opacity(0.5))
                                        )
                                }
                                
                                // Frame count badge
                                if let active = RollStore.shared.activeRoll, active.frameCount > 0 {
                                    Text("\(active.frameCount)")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color("Remjet"))
                                        .padding(.horizontal, 3)
                                        .padding(.vertical, 1)
                                        .background(Color("Receipt"))
                                        .cornerRadius(2)
                                        .offset(x: 2, y: 2)
                                }
                            }
                        }
                        .accessibilityIdentifier("rolls-button")
                        .accessibilityValue(lastShotThumbnail == nil ? "No photo" : "Photo available")
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
                        
                        // Right: Exposure compensation control (-2 to +2 EV)
                        VStack(spacing: 4) {
                            ExposureEVControl(value: $exposureEV) { newEV in
                                cameraManager.setExposureBias(newEV)
                            }
                            
                            Text(exposureEVText)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(exposureEV == 0 ? Color("Receipt").opacity(0.6) : Color("Brass"))
                                .tracking(0.5)
                        }
                        .frame(width: 60)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .task(id: cameraManager.lastCapturedShot?.id) {
            guard let shot = cameraManager.lastCapturedShot ?? SampleShotFixture.shot else {
                lastShotThumbnail = nil
                return
            }
            lastShotThumbnail = await PhotoThumbnailCache.shared.thumbnail(for: shot)
        }
        .onAppear {
            if coordinator.currentScreen == .camera {
                activateCamera()
            }
        }
        .onChange(of: coordinator.currentScreen) { _, screen in
            if screen == .camera { activateCamera() }
        }
        .onDisappear {
            cameraManager.stopSession()
            volumeObserver.stop()
            levelDetector.stop()
        }
        .onChange(of: coordinator.cameraPermissionStatus) { _, status in
            if status == .authorized, coordinator.currentScreen == .camera, !SampleShotFixture.isEnabled {
                cameraManager.startSession()
            }
        }
        .sheet(isPresented: $showPresetMenu) {
            PresetBrowserView(
                activePreset: $activePreset,
                isPresented: $showPresetMenu
            )
        }
        .sheet(isPresented: $showSettings) {
            CameraSettingsView(
                cameraManager: cameraManager,
                isPresented: $showSettings
            )
        }
        .onChange(of: activePreset) { _, newPreset in
            cameraManager.setActivePreset(newPreset)
        }
    }
    
    // MARK: - Helpers

    private func activateCamera() {
        if !SampleShotFixture.isEnabled, coordinator.cameraPermissionStatus == .authorized {
            cameraManager.startSession()
        }
        volumeObserver.onShutterPress = { triggerShutter() }
        volumeObserver.start()
        levelDetector.start()
    }
    
    private var exposureEVText: String {
        if exposureEV == 0 {
            return "±0 EV"
        } else if exposureEV > 0 {
            return String(format: "+%.1f EV", exposureEV)
        } else {
            return String(format: "%.1f EV", exposureEV)
        }
    }
    
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

// MARK: - Exposure EV Control

private struct ExposureEVControl: View {
    @Binding var value: Float
    let onChange: (Float) -> Void
    
    var body: some View {
        ZStack {
            // Background disc
            Circle()
                .fill(Color("Receipt").opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(value != 0 ? Color("Brass") : Color("Receipt").opacity(0.2), lineWidth: 1)
                )
            
            // Icon indicating EV compensation (+/-)
            Image(systemName: "plusminus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(value != 0 ? Color("Brass") : Color("Receipt").opacity(0.7))
        }
        .onTapGesture {
            // Tap to reset exposure to 0
            if value != 0 {
                value = 0
                onChange(0)
            }
        }
    }
}

// MARK: - Preset Selector Sheet (SET13b "Stolen Goods" Menu)


