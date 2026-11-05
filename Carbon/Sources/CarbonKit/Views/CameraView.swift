// U01, C10, U07, C07, U02, U03, R08, B10 — Full-Screen Camera Interface
// Optical-style layout based on the supplied viewfinder improvement mockup.

import SwiftUI
import AVFoundation
import CoreMotion

/// Photo-first viewfinder with a tactile shutter, prime selector, and exposure control.
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
                // Quiet header: preset, flash, and settings stay outside the image.
                HStack(alignment: .center) {
                    Button(action: { showPresetMenu = true }) {
                        HStack(spacing: 9) {
                            Text(activePreset.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color("Receipt"))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color("Receipt").opacity(0.62))
                        }
                    }
                    .accessibilityIdentifier("preset-name-button")
                    Spacer()
                    HStack(spacing: 20) {
                        Button(action: { cameraManager.cycleFlashMode() }) {
                            Image(systemName: flashIcon)
                                .font(.system(size: 21, weight: .medium))
                                .foregroundColor(cameraManager.activeFlashMode == .on ? Color("Safelight") : Color("Receipt").opacity(0.9))
                                .frame(width: 30, height: 40)
                        }
                        Button(action: { showSettings = true }) {
                            Image(systemName: "circle.dashed")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(Color("Receipt").opacity(0.9))
                                .frame(width: 34, height: 40)
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("settings-button")
                    }
                }
                .padding(.horizontal, 38)
                .padding(.top, 10)
                .padding(.bottom, 12)

                // Rounded optical-style viewfinder with a restrained double rim.
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
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { val in
                                    let deltaEV = Float(-val.translation.height / 150.0)
                                    exposureEV = max(-2.0, min(2.0, deltaEV))
                                    cameraManager.setExposureBias(exposureEV)
                                }
                        )
                        .onTapGesture { location in
                            cameraManager.setFocusAndExposure(at: location)
                        }

                    if levelDetector.isLevel {
                        Rectangle()
                            .fill(Color.white.opacity(0.72))
                            .frame(width: 28, height: 1)
                            .transition(.opacity)
                    }
                }
                .aspectRatio(cameraManager.activeAspectRatio.portraitRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                .padding(5)
                .background {
                    RoundedRectangle(cornerRadius: 47, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(Color.black.opacity(0.9), lineWidth: 5)
                        .padding(5)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 20)
                .layoutPriority(1)

                Spacer(minLength: 14)

                // Focal length strip and aspect-ratio shortcut.
                HStack(alignment: .center) {
                    HStack(spacing: 22) {
                        focalButton(24)
                        focalButton(35)
                        focalButton(50)
                    }
                    Spacer()
                    Button {
                        cameraManager.activeAspectRatio = cameraManager.activeAspectRatio == .twoByThree ? .threeByFour : .twoByThree
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait")
                                .font(.system(size: 18, weight: .regular))
                            Text(cameraManager.activeAspectRatio.rawValue)
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(Color("Receipt"))
                    }
                    .accessibilityLabel("Aspect ratio \(cameraManager.activeAspectRatio.rawValue)")
                    .accessibilityIdentifier("aspect-ratio-button")
                }
                .padding(.horizontal, 44)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Compact capture deck: latest frame, tactile shutter, exposure.
                HStack(alignment: .center) {
                    Button(action: { coordinator.navigateTo(.rolls) }) {
                        ZStack(alignment: .bottomTrailing) {
                            if let thumb = lastShotThumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 54, height: 68)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .fill(Color.white.opacity(0.09))
                                    .frame(width: 54, height: 68)
                                    .overlay {
                                        Image(systemName: "film")
                                            .font(.system(size: 24, weight: .light))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                            }
                            if let active = RollStore.shared.activeRoll, active.frameCount > 0 {
                                Text("\(active.frameCount)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(Color("Remjet"))
                                    .frame(minWidth: 34, minHeight: 34)
                                    .background(Color("Receipt"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .offset(x: 4, y: 4)
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        }
                    }
                    .accessibilityIdentifier("rolls-button")
                    .accessibilityValue(lastShotThumbnail == nil ? "No photo" : "Photo available")
                    .frame(width: 104, alignment: .leading)

                    Spacer(minLength: 12)
                    Button(action: { triggerShutter() }) {
                        ZStack {
                            Circle()
                                .stroke(Color("Receipt"), lineWidth: 4)
                                .frame(width: 84, height: 84)
                            Circle()
                                .fill(Color("Receipt"))
                                .frame(width: 70, height: 70)
                        }
                        .contentShape(Circle())
                    }
                    .accessibilityLabel("Take photo")
                    .accessibilityIdentifier("shutter-button")

                    Spacer(minLength: 12)
                    VStack(spacing: 8) {
                        ExposureEVControl(value: $exposureEV) { newEV in
                            cameraManager.setExposureBias(newEV)
                        }
                        Text(exposureEVText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(exposureEV == 0 ? Color("Receipt").opacity(0.55) : Color("Brass"))
                    }
                    .frame(width: 74)
                }
                .padding(.horizontal, 38)
                .padding(.bottom, 16)
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
    
    private func focalButton(_ mm: Double) -> some View {
        let isSelected = selectedFocal == mm
        return Button(action: {
            selectedFocal = mm
            cameraManager.setFocalLength(mm)
        }) {
            VStack(spacing: 4) {
                Text("\(Int(mm))")
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color("Receipt") : Color("Receipt").opacity(0.42))
                Circle()
                    .fill(isSelected ? Color("Receipt") : Color.clear)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 62, height: 42)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(Int(mm)) millimeter lens")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView(frame: .zero)
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    /// A backing preview layer follows bounds changes when the format changes.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
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
        Button {
            // Tap to reset exposure to 0.
            if value != 0 {
                value = 0
                onChange(0)
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .regular))
                .foregroundColor(value != 0 ? Color("Brass") : Color("Receipt"))
                .frame(width: 46, height: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == 0 ? "Exposure compensation, neutral" : "Reset exposure compensation")
    }
}

// MARK: - Preset Selector Sheet (SET13b "Stolen Goods" Menu)


