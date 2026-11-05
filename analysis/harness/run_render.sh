#!/bin/bash
# Render reference images through Carbon's real PhotoRenderer on macOS.
#
# Usage: bash analysis/harness/run_render.sh <in_dir> <out_dir>
set -euo pipefail

IN_DIR=${1:?input directory required}
OUT_DIR=${2:?output directory required}

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
PKG=$(mktemp -d)
trap 'rm -rf "$PKG"' EXIT
mkdir -p "$PKG/Sources/Harness"

cat > "$PKG/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CarbonHarness",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Harness", path: "Sources/Harness")
    ],
    swiftLanguageModes: [.v5]
)
SWIFT

# Copy production sources into the single executable target so internal
# types (PhotoRenderer, CIContextProvider) are in the same module.
for f in Models/Contracts Models/PresetParameters Models/MediaTimeCoding \
         Models/PresetCatalog Models/PresetLibrary \
         Rendering/ToneChain Rendering/CIContextProvider Rendering/LUTLoader \
         Rendering/LUTResources Rendering/PhotoGeometry Rendering/RenderWorker \
         Rendering/PhotoRenderer; do
    cp "$ROOT/Carbon/Sources/CarbonKit/$f.swift" "$PKG/Sources/Harness/"
done

# Optional: if the subagent has added LapseRenderer.swift, copy it too.
if [ -f "$ROOT/Carbon/Sources/CarbonKit/Rendering/LapseRenderer.swift" ]; then
    cp "$ROOT/Carbon/Sources/CarbonKit/Rendering/LapseRenderer.swift" "$PKG/Sources/Harness/"
fi

# Bundle.main -> filesystem path under the repo root.
python3 - "$PKG/Sources/Harness/LUTResources.swift" "$ROOT" <<'PY'
import sys
path, root = sys.argv[1], sys.argv[2]
src = open(path).read()
src = src.replace(
    'guard let url = Bundle.main.url(forResource: ccubeFilename, withExtension: "ccube", subdirectory: "LUTs/halide") else {',
    f'guard let url = URL(fileURLWithPath: "{root}/Carbon/Resources/LUTs/halide/" + ccubeFilename + ".ccube"), FileManager.default.fileExists(atPath: url.path) else {{')
src = src.replace(
    'guard let url = Bundle.main.url(forResource: hash, withExtension: "lutbin", subdirectory: "LUTs/nofusion") else {',
    f'guard let url = URL(fileURLWithPath: "{root}/Carbon/Resources/LUTs/nofusion/" + hash + ".lutbin"), FileManager.default.fileExists(atPath: url.path) else {{')
# Fail loudly if a Bundle.main lookup survives (e.g. a new LUT family was added).
if 'Bundle.main' in src:
    raise SystemExit("LUTResources still references Bundle.main; extend run_render.sh")
open(path, 'w').write(src)
PY

cat > "$PKG/Sources/Harness/Harness.swift" <<'SWIFT'
import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

@main
struct HarnessMain {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            FileHandle.standardError.write("usage: Harness <in_dir> <out_dir>\n".data(using: .utf8)!)
            exit(2)
        }
        let inDir = URL(fileURLWithPath: args[1])
        let outDir = URL(fileURLWithPath: args[2])
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let ctx = CIContextProvider.shared
        let space = CIContextProvider.outputColorSpace

        func load(_ url: URL) -> CIImage? {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
            return CIImage(cgImage: cg)
        }

        func writePNG(_ image: CIImage, extent: CGRect, to url: URL) {
            // Crop to input extent in case bloom/halation grew the bounds.
            let cropped = image.cropped(to: extent)
            guard let cg = ctx.createCGImage(cropped, from: extent, format: .RGBA8,
                                             colorSpace: space) else { return }
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
            CGImageDestinationAddImage(dest, cg, nil)
            CGImageDestinationFinalize(dest)
        }

        guard let renderer = PhotoRenderer() else {
            FileHandle.standardError.write("PhotoRenderer unavailable (no Metal device)\n".data(using: .utf8)!)
            exit(3)
        }

        let inputs = (try? FileManager.default.contentsOfDirectory(at: inDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        guard !inputs.isEmpty else {
            FileHandle.standardError.write("no PNGs in \(inDir.path)\n".data(using: .utf8)!)
            exit(4)
        }

        var report: [[String: Any]] = []
        // "_baseline" renders neutral PresetParameters(): it isolates the stage
        // every preset shares (highlight shoulder) from each preset's own look.
        var presets: [(String, String, PresetParameters)] = [("_baseline", "Baseline", PresetParameters())]
        for p in PresetLibrary.all { presets.append((p.presetID, p.displayName, p.baseParameters)) }
        FileHandle.standardOutput.write("rendering \(presets.count) presets x \(inputs.count) scenes on Metal\n".data(using: .utf8)!)

        for (presetID, displayName, parameters) in presets {
            let dir = outDir.appendingPathComponent(presetID, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for input in inputs {
                guard let image = load(input) else { continue }
                do {
                    let out = try await renderer.renderPreview(image: image, parameters: parameters)
                    let name = "\(input.deletingPathExtension().lastPathComponent).png"
                    writePNG(out, extent: image.extent, to: dir.appendingPathComponent(name))
                    report.append(["preset": presetID, "display": displayName,
                                   "input": input.lastPathComponent, "ok": true])
                } catch {
                    report.append(["preset": presetID, "display": displayName,
                                   "input": input.lastPathComponent, "ok": false,
                                   "error": "\(error)"])
                }
            }
        }

        let manifest = outDir.appendingPathComponent("manifest.json")
        let data = try JSONSerialization.data(withJSONObject: ["renders": report], options: [.prettyPrinted])
        try data.write(to: manifest)
        let okCount = report.filter { ($0["ok"] as? Bool) == true }.count
        FileHandle.standardOutput.write("done: \(okCount)/\(report.count) renders succeeded\n".data(using: .utf8)!)
    }
}
SWIFT

swift run --package-path "$PKG" -c release Harness "$IN_DIR" "$OUT_DIR"
