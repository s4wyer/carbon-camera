import SwiftUI
import UIKit
import AVFoundation

/// Owned above navigation, so replacing the welcome scene cannot tear down the
/// leak. The camera mounts on tap; the welcome cover retires only at full cover.
struct WelcomeCameraTransition<Content: View>: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var welcomeVisible: Bool
    @State private var startedAt: Date?
    @State private var revealStartedAt: Date?
    @State private var transitioning = false
    @State private var welcomeOpacity = 1.0
    @State private var haptic = UIImpactFeedbackGenerator(style: .soft)
    @ViewBuilder let content: () -> Content

    init(coordinator: AppCoordinator, @ViewBuilder content: @escaping () -> Content) {
        self.coordinator = coordinator
        self.content = content
        _welcomeVisible = State(initialValue: coordinator.currentScreen == .welcome)
    }

    var body: some View {
        ZStack {
            Color("Remjet").ignoresSafeArea()
            content()
                .accessibilityHidden(welcomeVisible || transitioning)
                .allowsHitTesting(!welcomeVisible && !transitioning)
            if welcomeVisible {
                WelcomeView(onOpenCamera: openCamera)
                    .opacity(welcomeOpacity)
                    .allowsHitTesting(!transitioning)
                    .accessibilityHidden(transitioning)
                    .zIndex(1)
            }
            if let startedAt, transitioning, !usesReducedMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                    // Hold opaque exposure until the scene swap has committed.
                    // A cold camera must never outrun an independent wall clock.
                    LightLeak(progress: leakProgress(at: timeline.date, since: startedAt))
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .zIndex(2)
            }
            #if DEBUG
            if let progress = previewProgress {
                LightLeak(progress: progress)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(3)
            }
            #endif
        }
        .onAppear {
            haptic.prepare()
            #if DEBUG
            if let progress = previewProgress {
                coordinator.currentScreen = .camera
                welcomeVisible = progress < 0.46
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                coordinator.cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
        .task(id: startedAt) {
            guard let startedAt else { return }
            do {
                if usesReducedMotion {
                    try await Task.sleep(for: .milliseconds(300))
                } else {
                    let untilPeak = max(0, 0.52 - Date().timeIntervalSince(startedAt))
                    try await Task.sleep(for: .seconds(untilPeak))
                    welcomeVisible = false
                    haptic.impactOccurred(intensity: 0.65)
                    // Let the underlying SwiftUI transaction finish while the
                    // renderer stays on its opaque plateau, then start reveal.
                    try await Task.sleep(for: .milliseconds(40))
                    revealStartedAt = Date()
                    try await Task.sleep(for: .milliseconds(600))
                }
                welcomeVisible = false
                transitioning = false
                self.startedAt = nil
                revealStartedAt = nil
            } catch {
                // Cancellation must not strand an opaque overlay or cream cover.
                welcomeVisible = false
                transitioning = false
                self.startedAt = nil
                revealStartedAt = nil
            }
        }
        #if DEBUG
        .task {
            // Simulator video harness only; production always waits for a tap.
            guard SampleShotFixture.isEnabled,
                  ProcessInfo.processInfo.arguments.contains("--welcome-testing"),
                  ProcessInfo.processInfo.arguments.contains("--welcome-autoplay") else { return }
            do {
                try await Task.sleep(for: .seconds(2))
                openCamera()
            } catch { }
        }
        #endif
    }

    private func leakProgress(at date: Date, since start: Date) -> Double {
        if let revealStartedAt {
            return 0.5 + min(0.5, max(0, date.timeIntervalSince(revealStartedAt)) / 1.2)
        }
        return min(0.5, max(0, date.timeIntervalSince(start)) / 1.04)
    }

    private var usesReducedMotion: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--welcome-reduce-motion") { return true }
        #endif
        return reduceMotion
    }

    #if DEBUG
    private var previewProgress: Double? {
        guard ProcessInfo.processInfo.arguments.contains("--welcome-testing"),
              SampleShotFixture.isEnabled,
              let value = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--welcome-frame=") }),
              let progress = Double(value.dropFirst("--welcome-frame=".count)) else { return nil }
        return min(1, max(0, progress))
    }
    #endif

    private func openCamera() {
        guard !transitioning, coordinator.currentScreen == .welcome else { return }
        transitioning = true
        startedAt = Date()
        coordinator.requestCameraAccess()
        if usesReducedMotion {
            withAnimation(.easeInOut(duration: 0.3)) { welcomeOpacity = 0 }
        }
    }
}

/// GPU-friendly gradient fills, with no blur or image texture. Only the 1.16s
/// transition has an animation clock; grain is a sparse, deterministic path.
struct LightLeak: View {
    let progress: Double
    private let red = Color("WelcomeAccent")
    private let deepRed = Color(red: 0.44, green: 0.015, blue: 0.008)

    var body: some View {
        Canvas { context, size in
            let p = min(1, max(0, progress))
            let bloom = smoothstep(0, 0.43, p)
            let recession = smoothstep(0.57, 1, p)
            let exposure = bloom * (1 - recession)
            let cover = smoothstep(0.22, 0.43, p) * (1 - recession)
            let extent = max(size.width, size.height)
            let center = CGPoint(x: size.width * (1.12 - p * 1.45),
                                 y: size.height * (0.88 - p * 0.65))
            let bounds = Path(CGRect(origin: .zero, size: size))
            // Screen alone cannot overwhelm cream. Supply actual optical
            // coverage; the exposure plateau fully hides the underlying swap.
            context.fill(bounds, with: .color(red.opacity(cover)))
            context.drawLayer { light in
                light.blendMode = .screen
                light.opacity = exposure
                light.fill(bounds, with: .radialGradient(
                    Gradient(stops: [.init(color: red, location: 0),
                                     .init(color: red.opacity(0.95), location: 0.25),
                                     .init(color: deepRed.opacity(0.7), location: 0.62),
                                     .init(color: .black.opacity(0), location: 1)]),
                    center: center, startRadius: 0,
                    endRadius: extent * (0.16 + bloom * 1.1 - recession * 0.8)))
                light.blendMode = .plusLighter
                light.opacity = exposure * 0.4
                light.fill(bounds, with: .linearGradient(
                    Gradient(colors: [.clear, red.opacity(0.1), red, deepRed.opacity(0.5), .clear]),
                    startPoint: CGPoint(x: center.x - size.width * 0.45, y: 0),
                    endPoint: CGPoint(x: center.x + size.width * 0.2, y: size.height)))
            }
            let tick = Int(p * 1.16 * 24)
            var seed = UInt64(tick + 1) &* 2_654_435_761
            context.opacity = exposure * 0.065
            context.blendMode = .plusLighter
            var grain = Path()
            for _ in 0..<850 {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1
                let x = CGFloat(seed % 10_000) / 10_000 * size.width
                seed = seed &* 6_364_136_223_846_793_005 &+ 1
                let y = CGFloat(seed % 10_000) / 10_000 * size.height
                grain.addRect(CGRect(x: x, y: y, width: 1, height: 1))
            }
            context.fill(grain, with: .color(.white))
        }
    }

    private func smoothstep(_ low: Double, _ high: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - low) / (high - low)))
        return t * t * (3 - 2 * t)
    }
}
