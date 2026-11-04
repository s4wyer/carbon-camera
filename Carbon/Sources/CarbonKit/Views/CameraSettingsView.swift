// Camera settings sheet: flash control and credits
// Separated from preset selection per UX redesign

import SwiftUI
import AVFoundation

/// Settings sheet: flash mode and app credits
struct CameraSettingsView: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("Remjet").ignoresSafeArea()
                
                List {
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
                            Text("Carbon draws on the work of Halide, Lapse, and No Fusion — three apps that pushed what iPhone photography means. The presets in the Stolen Goods collection are honest reconstructions from their recovered assets. Some of what makes Carbon work, we learned from reading their code.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color("Receipt").opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Built with respect, not malice.")
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
