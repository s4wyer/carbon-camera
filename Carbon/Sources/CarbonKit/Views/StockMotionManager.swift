import SwiftUI
import CoreMotion
import QuartzCore

/// One browser-owned CoreMotion source shared by every visible card.
@MainActor
final class StockMotionManager: ObservableObject {
    static let shared = StockMotionManager()

    @Published private(set) var tilt: CGSize = .zero
    @Published private(set) var isMotionAvailable = false
    private let motionManager = CMMotionManager()
    private var lastPublish = 0.0

    private init() {}

    func start() {
        guard !motionManager.isDeviceMotionActive else { return }
        #if targetEnvironment(simulator)
        return
        #else
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        isMotionAvailable = true
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            MainActor.assumeIsolated {
                let now = CACurrentMediaTime()
                guard now - self.lastPublish >= 1.0 / 30.0 else { return }
                self.lastPublish = now
                let roll = CGFloat(data.attitude.roll) * 20
                let pitch = CGFloat(data.attitude.pitch) * 14
                self.tilt = CGSize(width: self.tilt.width * 0.82 + roll * 0.18,
                                   height: self.tilt.height * 0.82 + pitch * 0.18)
            }
        }
        #endif
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isMotionAvailable = false
        lastPublish = 0
        tilt = .zero
    }
}
