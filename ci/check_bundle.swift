// Check the staged device bundle through the Foundation API used by Feather.
import Foundation

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Bundle validation failed: \(message)\n", stderr)
        exit(1)
    }
}

require(CommandLine.arguments.count == 2, "Expected an app bundle path")
let url = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
guard let bundle = Bundle(url: url) else {
    fputs("Bundle validation failed: Foundation cannot open \(url.path)\n", stderr)
    exit(1)
}
require(bundle.bundleIdentifier == "app.carbon.Carbon", "Cannot read Carbon's bundle identifier")
for key in ["CFBundleDisplayName", "CFBundleShortVersionString", "CFBundleExecutable"] {
    let value = bundle.object(forInfoDictionaryKey: key) as? String
    require(value?.isEmpty == false && value?.contains("$(") == false, "Cannot read \(key)")
}
require(bundle.executableURL.map { FileManager.default.fileExists(atPath: $0.path) } == true,
        "Foundation cannot locate the app executable")
let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
let files = primary?["CFBundleIconFiles"] as? [String]
require(files?.isEmpty == false, "Cannot read primary app icon filenames")
print("Foundation bundle import validated: \(bundle.bundleIdentifier!)")
