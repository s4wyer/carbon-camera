// U09 — Physical volume button shutter trigger
// Uses AVAudioSession volume observation (Halide REF §7 technique)

import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class VolumeButtonObserver: ObservableObject {
    private var volumeView: MPVolumeView?
    private var initialVolume: Float = 0.5
    private var cancellable: AnyCancellable?
    
    var onShutterPress: (() -> Void)?
    
    func start() {
        // Create hidden volume view to intercept hardware button events
        volumeView = MPVolumeView(frame: .zero)
        
        // Store initial volume
        initialVolume = AVAudioSession.sharedInstance().outputVolume
        
        // Observe volume changes
        cancellable = AVAudioSession.sharedInstance()
            .publisher(for: \.outputVolume)
            .sink { [weak self] newVolume in
                guard let self = self else { return }
                
                // Volume button pressed (up or down)
                if abs(newVolume - self.initialVolume) > 0.001 {
                    self.onShutterPress?()
                    
                    // Reset volume to original to prevent actual volume change
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        MPVolumeView.setVolume(self.initialVolume)
                    }
                }
            }
    }
    
    func stop() {
        cancellable?.cancel()
        volumeView = nil
    }
}

extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                slider.value = volume
            }
        }
    }
}
