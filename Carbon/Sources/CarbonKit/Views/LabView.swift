// Lab view placeholder — preset editing, reversible development
// Will contain preset gallery, sliders, and controls for M2

import SwiftUI

struct LabView: View {
    @ObservedObject var coordinator: AppCoordinator
    
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
                
                Spacer()
                
                // Coming soon message
                VStack(spacing: 12) {
                    Image(systemName: "flask")
                        .font(.system(size: 48))
                        .foregroundColor(Color("SecondaryInk").opacity(0.4))
                    
                    Text("Lab opens in M2")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("SecondaryInk"))
                }
                
                Spacer()
                
                // Bottom tab bar
                HStack(spacing: 0) {
                    bottomTabButton("Camera", active: false) {
                        coordinator.navigateTo(.camera)
                    }
                    bottomTabButton("Library", active: false) {
                        coordinator.navigateTo(.library)
                    }
                    bottomTabButton("Lab", active: true) {
                        // Already on lab
                    }
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
