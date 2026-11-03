// swift-tools-version: 6.0
// Carbon Swift Package — used for testing only.
// CI build uses XcodeGen + project.yml for the actual iOS app archive.
import PackageDescription

let package = Package(
    name: "Carbon",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "CarbonKit", targets: ["CarbonKit"])
    ],
    targets: [
        .target(
            name: "CarbonKit",
            path: "Sources/CarbonKit",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        .testTarget(
            name: "CarbonKitTests",
            dependencies: ["CarbonKit"],
            path: "Tests/CarbonKitTests"
        )
    ]
)
