#if DEBUG
import SwiftUI
import UIKit

/// Explicitly opted-in fixture renderer. Production views render in a real
/// window; simctl takes the final screen image, including native sheets.
@MainActor
struct ScreenshotHarnessView: View {
    static var isEnabled: Bool {
        SampleShotFixture.isEnabled && ProcessInfo.processInfo.arguments.contains("--capture-harness")
    }

    @StateObject private var driver = ScreenshotHarnessDriver()
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var settingsManager = CameraManager()
    @State private var preset = PresetLibrary.defaultPreset ?? PresetLibrary.all[0]

    var body: some View {
        Group {
            if driver.scene == .welcome {
                WelcomeView(onOpenCamera: {})
            } else if driver.scene == .rolls {
                RollsView(coordinator: coordinator)
            } else {
                CameraView(coordinator: coordinator)
            }
        }
        .sheet(item: $driver.sheet) { sheet in
            switch sheet {
            case .presets:
                PresetBrowserView(activePreset: $preset, isPresented: $driver.sheetPresented)
            case .settings:
                CameraSettingsView(cameraManager: settingsManager, isPresented: $driver.sheetPresented)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .task { await driver.run(coordinator: coordinator) }
    }
}

@MainActor
private final class ScreenshotHarnessDriver: ObservableObject {
    enum Scene: String, Codable {
        case welcome, camera, presets, rolls, settings
        case stockMiddle = "stock-middle"
        case stockBottom = "stock-bottom"

        var stockPosition: CGFloat? {
            switch self {
            case .presets: return 0
            case .stockMiddle: return 0.5
            case .stockBottom: return 1
            default: return nil
            }
        }
    }

    enum Sheet: String, Identifiable {
        case presets, settings
        var id: String { rawValue }
    }

    struct Request: Codable { let token: String; let scene: Scene }
    struct Ready: Codable {
        let token: String
        let scene: Scene
        let scrollPosition: Double?
        let error: String?
    }

    @Published var scene: Scene = .welcome
    @Published var sheet: Sheet?
    var sheetPresented: Bool {
        get { sheet != nil }
        set { if !newValue { sheet = nil } }
    }

    func run(coordinator: AppCoordinator) async {
        guard ScreenshotHarnessView.isEnabled else { return }
        // Only static fixture renders suppress animation. Normal launches and
        // XCTest's real transition/reduce-motion checks keep production behavior.
        UIView.setAnimationsEnabled(false)
        coordinator.cameraPermissionStatus = .authorized
        coordinator.currentScreen = .camera
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenshotHarness", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let requestURL = directory.appendingPathComponent("request.json")
        let readyURL = directory.appendingPathComponent("ready.json")
        var lastToken: String?

        // Seed() has finished before this view mounts. Decode the roll cover
        // before acknowledging any frame so lazy thumbnail work cannot lag it.
        let fixtureReady: Bool
        if let shot = SampleShotFixture.shot {
            fixtureReady = await PhotoThumbnailCache.shared.thumbnail(for: shot) != nil
        } else {
            fixtureReady = false
        }

        while !Task.isCancelled {
            if let data = try? Data(contentsOf: requestURL),
               let request = try? JSONDecoder().decode(Request.self, from: data),
               request.token != lastToken {
                lastToken = request.token
                scene = request.scene
                if request.scene.stockPosition != nil {
                    sheet = .presets
                } else {
                    sheet = request.scene == .settings ? .settings : nil
                }
                var error: String?
                var position: Double?
                if !fixtureReady {
                    error = "Sample photo or roll thumbnail is unavailable"
                } else {
                    (position, error) = await settle(scene: request.scene)
                }
                let ready = Ready(token: request.token, scene: request.scene,
                                  scrollPosition: position, error: error)
                if let data = try? JSONEncoder().encode(ready) {
                    try? data.write(to: readyURL, options: .atomic)
                }
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func settle(scene: Scene) async -> (Double?, String?) {
        // Let SwiftUI mount the requested production view and its sheet first.
        try? await Task.sleep(nanoseconds: 750_000_000)
        var previous: Data?
        var stableFrames = 0
        var position: Double?
        for _ in 0..<60 {
            guard !Task.isCancelled else { return (nil, "Capture cancelled") }
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }),
               let root = window.rootViewController {
                window.layoutIfNeeded()
                let expectsSheet = scene.stockPosition != nil || scene == .settings
                let sheetReady = (root.presentedViewController != nil) == expectsSheet
                var scrollReady = true
                if let fraction = scene.stockPosition {
                    if let view = root.presentedViewController?.view,
                       let scroll = verticalScrollViews(in: view).max(by: { $0.bounds.height < $1.bounds.height }) {
                        let lower = -scroll.adjustedContentInset.top
                        let upper = max(lower, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x,
                                                       y: lower + (upper - lower) * fraction), animated: false)
                        scroll.layoutIfNeeded()
                        position = upper > lower ? Double((scroll.contentOffset.y - lower) / (upper - lower)) : 0
                        scrollReady = upper > lower && abs(CGFloat(position ?? -1) - fraction) < 0.02
                    } else {
                        scrollReady = false
                    }
                }
                if sheetReady && scrollReady, let pixels = fingerprint(window: window) {
                    stableFrames = pixels == previous ? stableFrames + 1 : 0
                    previous = pixels
                    if stableFrames >= 2 { return (position, nil) }
                } else {
                    stableFrames = 0
                }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return (position, "View, sheet, or scroll position did not settle")
    }

    private func verticalScrollViews(in view: UIView) -> [UIScrollView] {
        var found = view.subviews.flatMap { verticalScrollViews(in: $0) }
        if let scroll = view as? UIScrollView,
           scroll.bounds.height > 100, scroll.contentSize.height > scroll.bounds.height + 10 {
            found.append(scroll)
        }
        return found
    }

    // A small UIKit snapshot only detects settling. Final PNGs come from the
    // Simulator compositor, avoiding offscreen SwiftUI/CA rendering limitations.
    private func fingerprint(window: UIWindow) -> Data? {
        let scale = 96 / max(1, window.bounds.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        var rendered = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 96, height: window.bounds.height * scale),
                                           format: format).image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        return rendered ? image.pngData() : nil
    }
}
#endif
