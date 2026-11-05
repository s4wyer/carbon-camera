#!/bin/bash
# Exercise the production RAW decoder on macOS, independently of the iOS app.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE=$(mktemp -d)
trap 'rm -rf "$PACKAGE"' EXIT
mkdir -p "$PACKAGE/Sources/CarbonKit" "$PACKAGE/Tests/CarbonKitTests"
cat > "$PACKAGE/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CarbonRAWTests",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CarbonKit"),
        .testTarget(name: "CarbonKitTests", dependencies: ["CarbonKit"])
    ],
    swiftLanguageModes: [.v5]
)
SWIFT

for source in Models/Contracts Models/PresetParameters Models/FilmEffectParameters Models/MediaTimeCoding \
    Rendering/CIContextProvider Rendering/RAWDevelopment Rendering/PhotoGeometry; do
    cp "$ROOT/Carbon/Sources/CarbonKit/$source.swift" "$PACKAGE/Sources/CarbonKit/"
done
for test in SyntheticRAWFixture RAWDevelopmentTests; do
    cp "$ROOT/Carbon/Tests/CarbonKitTests/$test.swift" "$PACKAGE/Tests/CarbonKitTests/"
done
swift test --package-path "$PACKAGE"
