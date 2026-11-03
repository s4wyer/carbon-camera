// U06 — Level haptic: subtle haptic when device is level for straight horizons
// Uses CoreMotion to detect device pitch

import SwiftUI
import CoreMotion
import UIKit

@MainActor
final class LevelDetector: ObservableObject {
    @Published var isLevel: Bool = false
    @Published var pitch: Double = 0.0
    
    private let motionManager = CMMotionManager()
    private var lastLevelState = false
    
    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            
            self.pitch = data.attitude.pitch
            
            // Level when pitch is near 0 (phone vertical) or near ±90 (phone flat)
            let wasLevel = self.isLevel
            self.isLevel = abs(data.attitude.pitch) < 0.05 ||
                           abs(abs(data.attitude.pitch) - .pi/2) < 0.05
            
            // U06: Haptic only on transition into level
            if self.isLevel && !wasLevel {
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            }
        }
    }
    
    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
