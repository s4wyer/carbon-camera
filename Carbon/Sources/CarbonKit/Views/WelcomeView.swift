// B01, B06, B07, B08, O01, O02, O03, O04 — Welcome Screen & Onboarding
// Sourced from carbon-build-plan.docx §3, screen 01 mockup, and NF REF §10

import SwiftUI
import AVFoundation

/// 01 WELCOME: First launch screen with tactile hero and itemized permission receipt
struct WelcomeView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var showPermissionReceipt = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Receipt canvas background (#F6F3EC)
            Color("Receipt")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                
                // Header: lowercase serif wordmark + quiet supporting line
                VStack(spacing: 8) {
                    Text("carbon")
                        .font(.system(size: 46, weight: .regular, design: .serif))
                        .foregroundColor(Color("Remjet"))
                        .tracking(-0.5)
                    
                    Text("A camera worth carrying.")
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(Color("SecondaryInk"))
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
                
                Spacer(minLength: 12)
                
                // Tactile Hero Artwork: canister, curling blue transfer paper, negative strip
                Image("WelcomeHero")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 340, maxHeight: 360)
                    .offset(y: dragOffset * 0.2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height < 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height < -60 {
                                    showPermissionReceipt = true
                                }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                    )
                
                Spacer(minLength: 24)
                
                // Action: Blue "Open camera" pill button
                Button(action: {
                    showPermissionReceipt = true
                }) {
                    Text("Open camera")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color("CarbonInk"))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 14)
                
                // Quiet promise
                Text("No account. Just pictures.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color("SecondaryInk").opacity(0.8))
                    .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showPermissionReceipt) {
            PermissionReceiptSheet {
                coordinator.requestCameraAccess()
            }
        }
    }
}

// MARK: - O04 Itemized Permission Receipt Sheet

/// Tactile receipt itemizing why Carbon requests camera access (NF REF §10, build plan §3)
struct PermissionReceiptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAccept: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Receipt notch/header
            RoundedRectangle(cornerRadius: 2)
                .fill(Color("SecondaryInk").opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("PERMISSION RECEIPT")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(Color("SecondaryInk"))
                    Spacer()
                    Text("ITEM 01 / 01")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(Color("SecondaryInk"))
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Camera Access")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundColor(Color("Remjet"))
                    
                    Text("Required to capture photos. Carbon runs entirely on your device. Zero telemetry, zero cloud sync, zero accounts.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color("SecondaryInk"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("• Photos saved to:")
                        Spacer()
                        Text("Local Documents")
                            .font(.system(size: 13, design: .monospaced))
                    }
                    HStack {
                        Text("• Cloud upload:")
                        Spacer()
                        Text("None (0 KB)")
                            .font(.system(size: 13, design: .monospaced))
                    }
                    HStack {
                        Text("• Tracking:")
                        Spacer()
                        Text("None")
                            .font(.system(size: 13, design: .monospaced))
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(Color("SecondaryInk"))
                .padding(12)
                .background(Color("Remjet").opacity(0.04))
                .cornerRadius(8)
                
                Divider()
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button(action: {
                dismiss()
                onAccept()
            }) {
                Text("Allow camera & continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color("CarbonInk"))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color("Receipt"))
        .presentationDetents([.height(440)])
    }
}
