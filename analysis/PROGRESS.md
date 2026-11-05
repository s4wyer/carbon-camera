# Preset analysis: progress and handoff

Read this first if you are picking the work up. It records what is verified,
what is assumed, and what is next. Do not repeat claims marked DISPROVED.

## Goal

Measure all 34 Carbon presets (`PresetLibrary.all`) through the app's real
render path and generate `presets.json` (single source of truth) and
`PRESETS_GUIDE.md` (generated from it) for non-photographers.

## Branches and worktrees

| Worktree | Branch | Owner | Purpose |
|---|---|---|---|
| `~/Downloads/carbon-worktrees/guide` | `analysis/preset-guide` | analysis | this folder, harness, CI workflow |
| `~/Downloads/carbon-worktrees/presets` | `analysis/preset-measurements` | camera/Lapse subagent | Lapse capture + `LapseRenderer.swift` |
| `~/Downloads/carbon-plan` | (other work) | operator | do not write here |

Both analysis branches start at `main` 90a1608. The Lapse branch is merged
into this one before the final measurement run so Journal / Photo Default are
measured through the real Lapse render path.

## Pipeline

```
python analysis/generate_scenes.py        -> analysis/refs/*.png + regions.json   (done)
CI: .github/workflows/preset-harness.yml  -> artifact "preset-renders"           (built, first run pending)
    runs analysis/harness/run_render.sh on macos-15: compiles production
    PhotoRenderer, LUTLoader, LUTResources, PresetCatalog into a macOS package
    and renders _baseline + 34 presets x 11 scenes via renderPreview.
python analysis/measure.py                -> internal metrics                    (todo)
python analysis/rate.py                   -> ratings, duplicates, copy          (todo)
python analysis/generate_guide.py         -> PRESETS_GUIDE.md                    (todo)
```

## Verified

- Catalog count is 34: 1 Carbon, 11 Halide, 20 No Fusion, 2 Lapse
  (parsed from the `all` array in `PresetCatalog.swift`).
- No Fusion name mapping comes from the original `.preset` plists via
  `nofusion-recovered/preset_lut_map.csv`; it matches the lutIDs in
  `PresetCatalog.swift`. Note the files' stored `name` differs from the file
  ID (e.g. H2.preset stores K1 = Kodak Portra 400). Use descriptions, not codes.
- LUT layout is red-fastest for Halide and No Fusion: identity-permutation fit on
  Process Zero is 0.163 for rgb vs 0.353 for the next best (`validate.py`).
- Lapse V4-02 / V4-03 cubes in `~/Downloads/com.lapse.journal-4.1.1-eeveedecrypter.ipa`
  match the SHA-256 values in `docs/reference/lapse-camera-settings.md` §8.

## Findings that change the guide

- DISPROVED: "Process Zero is near-identity." On sRGB-gamma input it crushes
  everything below ~0.15 to 0 and clips above ~0.8 (`validate.py` prints it).
- All 11 Halide LUTs share that flat toe; No Fusion LUTs do not.
- Fitting Process Zero for identity behaviour: Apple Log input gives mean error
  0.035 with no flat steps, sRGB gamma gives 0.123 with 69 flat steps. The
  Halide cubes most likely expect Apple Log (scene) input. UNPROVEN: residual is
  not zero and gamut was not confirmed.
- Carbon feeds those cubes sRGB-encoded values (`CIColorCubeWithColorSpace`
  with sRGB). So the app's current Halide looks are darker and harsher than
  Halide's. The guide must describe what Carbon renders; the encoding mismatch
  is reported to the operator as a likely bug, not fixed here.
- Natural in `PresetCatalog.swift`: grain 0.4, halation intensity 0.3,
  bloom 0.0. D-025 says Natural grain should be 0. Conflict reported; the
  measurement uses the catalog.
- `strength` is never read by `PhotoRenderer`; it has no effect on renders.
- On main, every LUT preset except Natural has halation intensity 1.0
  (CIBloom radius 4, screen-blended). This is a strong shared effect; the
  `_baseline` render exists to separate it from each look.

## Not reproducible off-device

CIHighlightShadowAdjust, CIBloom, CIRandomGenerator grain, and the Lapse
private filters. That is why rendering runs on macOS CI and Python only
measures pixels.

## Next steps

1. Push this branch; confirm the first harness run compiles and renders.
2. `measure.py`: tone curve, clipping, contrast, chroma/hue by region, white
   balance, skin drift, texture, all in OKLab/OKLCH from the downloaded renders.
3. Merge the Lapse branch, rerun the harness, re-measure.
4. `rate.py`, duplicates, copy; `generate_guide.py`; one `run_all.py` entry.
