#!/usr/bin/env python3
"""Generate complete preset catalog from recovered No Fusion preset data."""

import json
import glob
import os

def load_nofusion_presets():
    """Load all 20 No Fusion presets from JSON."""
    presets = []
    json_dir = "nofusion-recovered/presets_json"
    
    for filepath in sorted(glob.glob(f"{json_dir}/*.json")):
        with open(filepath) as f:
            data = json.load(f)
            presets.append({
                'fileID': data['id'],
                'name': data['name'],
                'description': data['description'],
                'lutID': data['lutData']['reference']['id'],
                'lutIntensity': data['lutIntensity'],
                'bloomRadius': data.get('bloomRadius', 10.0),
                'grainSize': data.get('grainSize', 0.5),
            })
    
    return sorted(presets, key=lambda x: x['fileID'])

def generate_swift_definition(preset, display_order):
    """Generate Swift PresetDefinition code for a No Fusion preset."""
    file_id = preset['fileID']
    name = preset['name']
    desc = preset['description']
    lut_id = preset['lutID']
    lut_int = preset['lutIntensity']
    bloom = preset['bloomRadius']
    
    # Use compact helper if parameters are neutral
    is_neutral = (abs(lut_int - 1.0) < 0.001 and abs(bloom - 10.0) < 0.001)
    
    if is_neutral:
        params = f'nofusionParams(lutID: "nofusion-{lut_id}")'
    else:
        params = f'nofusionParams(lutID: "nofusion-{lut_id}", lutIntensity: {lut_int}'
        if abs(bloom - 10.0) >= 0.001:
            params += f', bloomRadius: {bloom}'
        params += ')'
    
    uuid_suffix = f"{display_order:02x}"
    
    return f'''    private static let nofusion{file_id} = PresetDefinition(
        id: UUID(uuidString: "20000000-0000-0000-0000-0000000000{uuid_suffix}")!,
        presetID: "nofusion-{file_id.lower()}",
        displayName: "{name}",
        description: "{desc}",
        source: .nofusionReference(presetFileID: "{file_id}", section: "README"),
        baseParameters: {params},
        carbonDeltas: [],
        engineVersion: "1.0",
        displayOrder: {200 + display_order}
    )'''

def main():
    presets = load_nofusion_presets()
    
    print("// Generated No Fusion preset definitions\n")
    print("// MARK: - No Fusion presets (20 total, recovered from .preset JSON)\n")
    
    for i, preset in enumerate(presets):
        print(generate_swift_definition(preset, i))
        print()
    
    print("\n// Helper factory for No Fusion presets (most use neutral params + LUT only)")
    print("""    private static func nofusionParams(
        lutID: String,
        lutIntensity: Float = 1.0,
        bloomRadius: Float = 10.0,
        grainSize: Float = 1.0
    ) -> PresetParameters {
        PresetParameters(
            strength: 1.0,
            lutID: lutID,
            lutIntensity: lutIntensity,
            exposureEV: 0.0,
            temperatureOffsetK: 0.0,
            tintOffset: 0.0,
            contrast: 1.0,
            saturation: 1.0,
            vibrance: 0.0,
            curveBlack: 0.0,
            curveShadow: 0.0,
            curveMidtone: 0.0,
            curveHighlight: 0.0,
            curveWhite: 0.0,
            hsl: Array(repeating: HSLAdjustment(hue: 0, saturation: 1.0, luminance: 1.0), count: 8),
            grainAmount: 0.0,
            grainSize: grainSize,
            halationRadius: 4.0,
            halationIntensity: 1.0,
            bloomAmount: 0.0,
            bloomRadius: bloomRadius,
            vignetteIntensity: 0.0,
            vignetteRadius: 0.0
        )
    }""")
    
    print("\n// Preset list for PresetLibrary.all")
    print("        // No Fusion (20 presets)")
    for preset in presets:
        print(f"        nofusion{preset['fileID']},")

if __name__ == "__main__":
    main()
