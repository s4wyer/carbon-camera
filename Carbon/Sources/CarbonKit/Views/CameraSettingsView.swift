// Camera settings sheet: aspect ratio, flash control, and credits
// Separated from preset selection per UX redesign

import SwiftUI
import AVFoundation

/// Settings sheet: photo format, flash mode, and app credits
struct CameraSettingsView: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Remjet").ignoresSafeArea()
                
                List {
                    Section {
                        Picker("Aspect ratio", selection: $cameraManager.activeAspectRatio) {
                            ForEach(PhotoAspectRatio.allCases) { ratio in
                                Text(ratio.rawValue).tag(ratio)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("aspect-ratio-picker")
                        .listRowBackground(Color("Receipt").opacity(0.06))
                    } header: {
                        Text("Aspect ratio")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color("Brass"))
                            .textCase(.uppercase)
                            .tracking(1.2)
                    }

                    // Flash control
                    Section {
                        ForEach([AVCaptureDevice.FlashMode.auto, .on, .off], id: \.self) { mode in
                            Button(action: {
                                cameraManager.setFlashMode(mode)
                            }) {
                                HStack {
                                    Image(systemName: flashIcon(mode))
                                        .frame(width: 24)
                                        .foregroundStyle(mode == .on ? Color("Safelight") : Color("Receipt"))
                                    Text(flashLabel(mode))
                                        .foregroundStyle(Color("Receipt"))
                                    Spacer()
                                    if cameraManager.activeFlashMode == mode {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color("Brass"))
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .listRowBackground(Color("Receipt").opacity(0.06))
                        }
                    } header: {
                        Text("Flash")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color("Brass"))
                            .textCase(.uppercase)
                            .tracking(1.2)
                    }
                    
                    // Credits
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Carbon owes a lot to Halide, Lapse, and No Fusion. They spent years figuring out what good iPhone photos look like. We spent a few evenings taking their apps apart. The evidence is in Stock.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("Receipt").opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Thanks for the presets. See you in court.")
                                .font(.system(size: 13, weight: .medium))
                                .italic()
                                .foregroundStyle(Color("Brass"))
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Inspiration")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color("Brass"))
                            .textCase(.uppercase)
                            .tracking(1.2)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color("Brass"))
                }
            }
            .toolbarBackground(Color("Remjet"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
    
    private func flashIcon(_ mode: AVCaptureDevice.FlashMode) -> String {
        switch mode {
        case .auto: return "bolt.badge.a"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        @unknown default: return "bolt.badge.a"
        }
    }
    
    private func flashLabel(_ mode: AVCaptureDevice.FlashMode) -> String {
        switch mode {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        @unknown default: return "Auto"
        }
    }
}
