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
            path: "Sources/CarbonKit"
        ),
        .testTarget(
            name: "CarbonKitTests",
            dependencies: ["CarbonKit"],
            path: "Tests/CarbonKitTests"
        )
    ],
    // Match the Xcode app target; tools version 6 does not require Swift 6 mode.
    swiftLanguageModes: [.v5]
)
