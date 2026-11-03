import SwiftUI
import AVFoundation

/// 02 CAMERA: Full-screen camera with controls matching reference mockup
struct CameraView: View {
    @ObservedObject var coordinator: AppCoordinator
    @StateObject private var cameraManager = CameraManager()
    
    // UI state
    @State private var selectedFocalLength: FocalLength = .f35
    @State private var moodValue: Double = 0.0  // -2 to +2 EV
    @State private var warmthValue: Int = 1      // Warm 01, 02, etc.
    @State private var showPresetSelector = false
    @State private var showLibrary = false
    
    enum FocalLength: String, CaseIterable {
        case f24 = "24"
        case f35 = "35"
        case f50 = "50"
    }
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
            
            // Composition guides (corner brackets, D-025 / U07)
            CompositionGuidesView()
                .ignoresSafeArea()
            
            // Overlaid controls
            VStack {
                // Top bar: Preset name + Warmth indicator
                HStack {
                    Button(action: { showPresetSelector = true }) {
                        Text("NATURAL")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    Text("WARM \(String(format: "%02d", warmthValue))")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Bottom control cluster
                VStack(spacing: 24) {
                    // Focal length selector: 24 / 35 / 50
                    HStack(spacing: 16) {
                        ForEach(FocalLength.allCases, id: \.self) { focal in
                            Button(action: {
                                selectedFocalLength = focal
                                cameraManager.setZoom(for: focal)
                            }) {
                                Text(focal.rawValue)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(selectedFocalLength == focal ? .white : .white.opacity(0.6))
                                    .frame(width: 44, height: 32)
                                    .background(selectedFocalLength == focal ? Color.white.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 999))
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 999))
                    
                    // Main shutter row
                    HStack(spacing: 0) {
                        // Left: Last photo thumbnail (taps to library)
                        Button(action: { coordinator.navigateTo(.library) }) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.white.opacity(0.6))
                                )
                        }
                        
                        Spacer()
                        
                        // Center: Shutter button (large circle)
                        Button(action: { cameraManager.capturePhoto() }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 76, height: 76)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 64, height: 64)
                            }
                        }
                        
                        Spacer()
                        
                        // Right: MOOD dial (exposure adjustment, D-025 / R08)
                        MoodDialView(value: $moodValue)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

/// Camera preview using AVCaptureVideoPreviewLayer
private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

/// Composition guides: corner brackets (D-025 / U07)
private struct CompositionGuidesView: View {
    var body: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 24
            let length: CGFloat = 20
            let lineWidth: CGFloat = 1.5
            
            Path { path in
                // Top-left
                path.move(to: CGPoint(x: inset, y: inset + length))
                path.addLine(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset + length, y: inset))
                
                // Top-right
                path.move(to: CGPoint(x: geometry.size.width - inset - length, y: inset))
                path.addLine(to: CGPoint(x: geometry.size.width - inset, y: inset))
                path.addLine(to: CGPoint(x: geometry.size.width - inset, y: inset + length))
                
                // Bottom-left
                path.move(to: CGPoint(x: inset, y: geometry.size.height - inset - length))
                path.addLine(to: CGPoint(x: inset, y: geometry.size.height - inset))
                path.addLine(to: CGPoint(x: inset + length, y: geometry.size.height - inset))
                
                // Bottom-right
                path.move(to: CGPoint(x: geometry.size.width - inset - length, y: geometry.size.height - inset))
                path.addLine(to: CGPoint(x: geometry.size.width - inset, y: geometry.size.height - inset))
                path.addLine(to: CGPoint(x: geometry.size.width - inset, y: geometry.size.height - inset - length))
            }
            .stroke(Color.white.opacity(0.8), lineWidth: lineWidth)
        }
    }
}

/// MOOD dial: rotary exposure control (-2 to +2 EV, D-025 / R08)
private struct MoodDialView: View {
    @Binding var value: Double
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Dial body
                Circle()
                    .fill(Color(hex: "#2A2A2A"))
                    .frame(width: 48, height: 48)
                
                // Notch indicator
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 10)
                    .offset(y: -16)
                    .rotationEffect(.degrees(value * 45)) // -90 to +90 degrees
                
                // Tick marks
                ForEach(0..<8) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1, height: 4)
                        .offset(y: -20)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let delta = gesture.translation.width / 50.0
                        value = max(-2.0, min(2.0, delta))
                    }
            )
            
            Text("MOOD")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

/// Minimal camera manager (scaffold)
@MainActor
private class CameraManager: ObservableObject {
    let session = AVCaptureSession()
    
    func startSession() {
        // Will configure AVCaptureSession on device
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    func setZoom(for focal: CameraView.FocalLength) {
        // Zoom ramp logic (D-025 / C10)
    }
    
    func capturePhoto() {
        // Capture logic
    }
}
