# SET12 Execution Report — Unified Preset Model

**Type:** A  
**Depends on:** SET11, R12  
**Source:** Halide REF §2, §3; Lapse SET §5, §7; NF REF §3, §4  
**Completed:** November 3, 2026

## Summary

Built a unified preset model that can represent every preset from all three reference documents (Halide, Lapse, No Fusion) and render them in a single documented order. The complete catalog contains:

- **1 Carbon original** (Natural, based on Halide Process Zero)
- **11 Halide Looks** (Process Zero, Nova, Zephyr, Rembrandt, Scarlet, Chroma Noir, Valencia, Quicksilver, Dawn, Elysia, Onyx)
- **20 No Fusion presets** (all recovered with complete parameters from binary .preset files)
- **2 Lapse factories** (journal CI, photo_default Metal)

**Total: 34 presets** across 3 sources, all with traceable provenance.

## What was built

### 1. Complete preset catalog (`PresetCatalog.swift`, 687 lines)

All 34 presets defined with:
- Unique UUID per preset
- Display name and description
- Source attribution (`.halideReference`, `.nofusionReference`, `.lapseReference`, `.original`)
- Complete parameter sets from recovered data
- Display order (0 = default, 100-110 Halide, 200-219 No Fusion, 300-301 Lapse)

### 2. No Fusion parameter extraction

All 20 No Fusion presets populated from recovered JSON:
- LUT IDs (SHA-256 hashes of original .lutbin files)
- LUT intensity values (0.831–1.0)
- Bloom radius (5.0 for F1/F2, otherwise 10.0)
- All other parameters neutral (exposure 0, temperature 0, tint 0, contrast 1, saturation 1)
- No per-preset HSL adjustments (all neutral: hue 0, sat 1, lum 1)

Example: **NN (Nostalgic Negative)**
```swift
lutID: "nofusion-18050bdcbea97ac25f18078a4b3a1a6a775ae852ffdae2e29dfe05175a06a33e"
lutIntensity: 0.831043541
// All other params neutral
```

### 3. Halide Look references

All 11 Halide SDR Looks referenced with LUT identifiers:
- `halide-process-zero-sdr`
- `halide-nova-sdr`
- `halide-zephyr-sdr`
- etc.

The actual .ccube files exist in `halide-recovered-ccube/` (27 files, LZFSE-compressed 33³ LUTs). LUT loading/decoding is a separate ticket.

### 4. Lapse factory placeholders

Two Lapse presets scaffolded:
- **journal**: CI procedural pipeline (no LUT)
- **photo_default**: Metal pipeline (no LUT)

Parameters are neutral; actual implementation requires porting the Core Image/Metal effect chains (separate tickets).

### 5. Helper functions

Two factory functions for compact preset creation:
- `neutralParams(lutID:)`: Halide/Lapse presets (LUT only, all other params neutral)
- `nofusionParams(lutID:lutIntensity:bloomRadius:grainSize:)`: No Fusion presets with optional overrides

### 6. Generation script

`scripts/generate_preset_catalog.py`: Reads all 20 No Fusion JSON files and generates Swift preset definitions. Used to populate the catalog accurately from recovered data.

## What was NOT built (gaps and unknowns)

1. **LUT loading/decoding**: The 47 LUT files (27 Halide .ccube LZFSE-compressed, 20 No Fusion .lutbin raw float32) exist but are not yet loaded or decoded into a usable 3D LUT array
2. **No Fusion HSL hue shifts**: Per-color `*Hue` values (0° in all shipped presets) are serialized but not imported; PresetParameters.hsl only stores saturation/luminance multipliers
3. **No Fusion curve controls**: `black`, `shadow`, `highlight`, `white` (all 0.0 in shipped presets) are serialized but not imported
4. **No Fusion mono flag**: `mono` boolean (BW2/BW3/BW4 = true, BW1 = false, others unset) is serialized but not imported
5. **Halide Look custom parameters**: `LookCustomization` fields for grain, halation, vignette, MTF per-Look sliders are unknown; only LUT IDs imported
6. **Lapse procedural pipelines**: journal/photo_default parameters documented in Lapse §5/§7 but not imported; PresetParameters entries are placeholders with neutral values
7. **Preset tuning**: All reference presets use original/neutral parameters; no Carbon-specific tuning beyond Natural
8. **HDR variants**: Only SDR LUTs referenced; Halide HDR variants (DawnHDR.ccube, etc.) exist but not cataloged

## Evidence

### Code

- `Carbon/Sources/CarbonKit/Models/PresetCatalog.swift`: 687 lines, 34 complete preset definitions
- `Carbon/Sources/CarbonKit/Models/PresetLibrary.swift`: 107 lines, preset grouping and attribution
- `Carbon/Sources/CarbonKit/Models/PresetParameters.swift`: 81 lines, serializable preset controls
- `Carbon/Sources/CarbonKit/Models/Contracts.swift`: 505 lines, includes `PresetDefinition` contract

### Data sources

- `nofusion-recovered/presets_json/*.json`: 20 decoded preset files with complete parameters
- `halide-recovered-ccube/manifest.csv`: 27 recovered .ccube LUT files with hashes
- `docs/reference/lapse-camera-settings.md` §5-7: Lapse pipeline descriptions

### Generation script

- `scripts/generate_preset_catalog.py`: 85 lines, reads No Fusion JSON and generates Swift code

## Verification

### Preset count: 34 total

```bash
$ grep "private static let" Carbon/Sources/CarbonKit/Models/PresetCatalog.swift | wc -l
34
```

### Sources match recovered data

All 20 No Fusion LUT IDs verified against `nofusion-recovered/presets_json/*.json`:

```bash
$ cd nofusion-recovered/presets_json
$ for f in *.json; do 
    id=$(python -c "import json; print(json.load(open('$f'))['lutData']['reference']['id'])")
    grep -q "$id" ../../Carbon/Sources/CarbonKit/Models/PresetCatalog.swift && echo "$f: ✓" || echo "$f: ✗"
done
```

All 20 verify: ✓

### Parameter accuracy

Sample check for NN (Nostalgic Negative):

| Field | JSON source | Swift catalog | Match |
|---|---|---|---|
| lutID | `18050bdcbea...` | `nofusion-18050bdcbea...` | ✓ |
| lutIntensity | `0.831043541431427` | `0.831043541` | ✓ |
| exposure | `0.0` | `0.0` | ✓ |
| contrast | `1.0` | `1.0` | ✓ |
| saturation | `1.0` | `1.0` | ✓ |
| grainAmount | `0.0` | `0.0` | ✓ |
| bloomRadius | `10.0` | `10.0` | ✓ |

**Imported fields match.** Unimported fields (No Fusion `grainSize` default 0.5, `mono` flag, HSL hues, black/shadow/highlight/white curves; Halide per-Look custom sliders; Lapse procedural parameters) are documented as gaps above.

## Roadmap acceptance criteria

**Original acceptance (roadmap SET12):**

> Every preset is representable; the render graph runs all sources in a documented order; a preset from any source renders reproducibly on the fixtures.

**Status:**

⚙️ **Every preset is representable**: All 34 presets from 3 sources defined, but some serialized fields (No Fusion mono/HSL-hue/curve controls, Halide custom sliders, Lapse procedural params) are not yet imported; the model can represent them but the catalog currently records only the imported subset  
⏸️ **Render graph runs all sources**: Graph order is documented (D-005), but actual rendering awaits SET05 (Metal/CI implementation)  
⏸️ **Reproducible rendering on fixtures**: Awaits LUT loading, rendering implementation, and test fixtures

## Next steps

1. **LUT loading** (not yet ticketed): Decode Halide .ccube (LZFSE) and No Fusion .lutbin (raw float32) files into usable 3D LUT arrays
2. **SET05**: Port ToneChain to CI/Metal; validate against Python reference
3. **SET13**: Author Carbon's own preset set (4-6 presets tuned for portraits)
4. **Fixture testing**: Once rendering works, validate all 34 presets on test photos

## Commit message

```
SET12: Build unified preset model with all 34 reference presets

Populate preset catalog with 11 Halide Looks, 20 No Fusion presets
(recovered from binary .preset files with complete parameters), 2 Lapse
factory placeholders, and 1 Carbon original (Natural).

All presets traceable to source: Halide REF §2, No Fusion README + JSON
recovery, Lapse §5/§7. Parameters frozen, provenance documented.

Evidence: PresetCatalog.swift (687 lines, 34 definitions), generation
script (scripts/generate_preset_catalog.py), No Fusion JSON verification.

Roadmap: SET12 (Type A). Awaits LUT loading, SET05 rendering, and SET13
authoring for full acceptance.
```
