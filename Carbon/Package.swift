// swift-tools-version: 5.9
// SET01 — Reproducible native iOS project.
// Baseline: iOS 18.0 (planning assumption validated in SET03), Swift 5.9, Xcode 16.
// No third-party dependencies. Everything below is Apple SDK only.
import PackageDescription

let package = Package(
    name: "Carbon",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "CarbonKit", targets: ["CarbonKit"]),
        .executable(name: "carbon-verify", targets: ["CarbonVerify"])
    ],
    targets: [
        .target(
            name: "CarbonKit",
            path: "Sources/CarbonKit",
            resources: [
                .copy("Resources/presets.json"),
                .copy("Resources/camera-default-config.json")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .unsafeFlags(["-strict-concurrency=complete"], .when(configuration: .debug))
            ]
        ),
        // Host-side (macOS/Linux) verifier. Runs the deterministic pipeline math
        // without AVFoundation so CI can check contract and recipe reproducibility.
        .executableTarget(
            name: "CarbonVerify",
            dependencies: ["CarbonKit"],
            path: "Sources/CarbonVerify"
        ),
        .testTarget(
            name: "CarbonKitTests",
            dependencies: ["CarbonKit"],
            path: "Tests/CarbonKitTests"
        )
    ]
)