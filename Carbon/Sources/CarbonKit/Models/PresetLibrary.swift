// SET13b — Reference presets menu ("Stolen Goods")
// Decision D-024: Transparently surface all reference presets with cheeky attribution.

import Foundation

/// Preset group: our own vs. recovered from other apps.
public enum PresetGroup: String, Codable {
    case ours       // Carbon's own presets (Natural, etc.)
    case stolen     // Recovered from Halide, Lapse, No Fusion (shown in submenu)
    
    var displayName: String {
        switch self {
        case .ours: return "Carbon"
        case .stolen: return "Stolen Goods"
        }
    }
    
    var subtitle: String? {
        switch self {
        case .ours: return nil
        case .stolen: return "Recovered from other camera apps — try them out"
        }
    }
}

extension PresetDefinition {
    /// The app credited for this preset, independent of its visual effects.
    public var sourceDisplayName: String {
        switch source {
        case .original: return "Carbon"
        case .halideReference: return "Halide"
        case .lapseReference: return "Lapse"
        case .nofusionReference: return "No Fusion"
        }
    }

    /// Cheeky display name with attribution (D-024).
    public var displayNameWithAttribution: String {
        switch source {
        case .halideReference, .lapseReference, .nofusionReference:
            return "\(displayName) (from \(sourceDisplayName))"
        case .original:
            return displayName  // No attribution; it's ours
        }
    }
    
    /// Grouped by source for UI.
    public var group: PresetGroup {
        switch source {
        case .original:
            return .ours
        case .halideReference, .lapseReference, .nofusionReference:
            return .stolen
        }
    }
    
    /// Long-form attribution for the preset detail view.
    public var attributionText: String? {
        switch source {
        case .original:
            return nil
        case .halideReference(let lookName, let section):
            return "This preset was extracted from Halide and recreated using Carbon's render engine (source: \(section)). Your results may differ slightly due to platform and device differences."
        case .lapseReference(let factoryName, let section):
            return "This preset was extracted from Lapse and recreated using Carbon's render engine (source: \(section)). Your results may differ slightly due to platform and device differences."
        case .nofusionReference(let fileID, let section):
            return "This preset was extracted from No Fusion and recreated using Carbon's render engine (source: \(section)). Your results may differ slightly due to platform and device differences."
        }
    }
}

// MARK: - Example preset library (M1b SET13)

public struct PresetLibrary {
    /// Filter by group.
    public static func presets(in group: PresetGroup) -> [PresetDefinition] {
        all.filter { $0.group == group }
    }
    
    /// Our default (Natural, displayOrder 0).
    public static var defaultPreset: PresetDefinition? {
        presets(in: .ours).first { $0.displayOrder == 0 }
    }
}

// MARK: - Example UI (placeholder; actual SwiftUI in M1 B04)

/*
 In the preset browser:
 
 VStack {
     ForEach(PresetLibrary.presets(in: .ours)) { preset in
         PresetCell(preset: preset)
     }
     
     DisclosureGroup("Stolen Goods", isExpanded: $showStolenGoods) {
         ForEach(PresetLibrary.presets(in: .stolen)) { preset in
             PresetCell(preset: preset, showAttribution: true)
         }
     }
     .font(.body.weight(.semibold))
     .foregroundStyle(Color("CarbonInk"))
 }
 
 In the preset detail view:
 
 if let attribution = preset.attributionText {
     Text(attribution)
         .font(.caption)
         .foregroundStyle(.secondary)
 }
 */
