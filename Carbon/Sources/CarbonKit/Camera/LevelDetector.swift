// U06 — Level haptic: subtle haptic when device is level for straight horizons
// Uses CoreMotion to detect device pitch

import SwiftUI
import CoreMotion
import UIKit

@MainActor
final class LevelDetector: ObservableObject {
    @Published private(set) var isLevel: Bool = false

    private let motionManager = CMMotionManager()
    private var lastLevelState = false

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }

            let newLevelState = abs(data.attitude.pitch) < 0.05 ||
                abs(abs(data.attitude.pitch) - .pi / 2) < 0.05

            // Avoid publishing motion values on every update; the camera only needs the transition.
            guard newLevelState != self.lastLevelState else { return }
            self.lastLevelState = newLevelState
            self.isLevel = newLevelState

            if newLevelState {
                let gen = UIImpactFeedbackGenerator(style: .light)
                gen.impactOccurred()
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        lastLevelState = false
    }
}
