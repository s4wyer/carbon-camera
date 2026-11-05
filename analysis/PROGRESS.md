# Preset analysis: progress and handoff

Read this before continuing. It separates what is measured from what is
assumed. Do not repeat anything listed under "Disproved".

## Goal

Measure all 34 presets in `PresetLibrary.all` through Carbon's real render
path, then generate `presets.json` (single source of truth) and
`PRESETS_GUIDE.md` (generated from it) for non-photographers.

## Status: render bugs fixed, ratings and copy next

The four render bugs below are fixed on `analysis/preset-guide` and verified
on CI renders (run 42119534797). `measure.py` now reads tone, grain and
vignette from uniform flat fields (`flat_000`..`flat_100`, linear-luminance
percent) and glow from `point_light`, so vignette no longer contaminates the
tone curve. `rate.py` is still unwritten: every rating and sentence must come
from `metrics.json`, with thresholds as named constants.

## Branch and worktrees

| Worktree | Branch | Notes |
|---|---|---|
| `~/Downloads/carbon-worktrees/guide` | `analysis/preset-guide` (pushed) | analysis, harness, Lapse code, CI fixes |
| `~/Downloads/carbon-worktrees/presets` | `analysis/preset-measurements` (local) | subagent's original Lapse commits; cherry-picked into guide |
| `~/Downloads/carbon-plan` | operator's checkout | do not write here |

## Pipeline

```
python analysis/validate.py         tooling checks (passing)
python analysis/generate_scenes.py  -> analysis/refs/*.png + regions.json (committed)
push to analysis/** branch          -> CI "Preset measurement harness" (macos-15)
                                       artifact "preset-renders"
gh run download <id> -n preset-renders -D analysis/renders
python analysis/measure.py          -> analysis/.cache/metrics.json
```

The harness (`analysis/harness/run_render.sh`) compiles the production
`PhotoRenderer`, `LapseRenderer`, `LUTLoader`, `LUTResources`, `PresetCatalog`
and friends into a macOS package. It renders `_baseline` (neutral params),
all 34 presets, and `_diag-<id>-{nograin,nohalation,lutonly}` stage-isolation
variants for Natural, Process Zero, Neutral Classic, and Elysia.
`measure.py` skips every id starting with `_` when it compares presets.

## Verified

- 34 presets: 1 Carbon, 11 Halide, 20 No Fusion, 2 Lapse.
- No Fusion names come from the original `.preset` plists
  (`nofusion-recovered/preset_lut_map.csv`). File IDs differ from stored
  names (H2.preset stores K1 = Kodak Portra 400). Use descriptions.
- LUT layout is red-fastest (permutation fit 0.163 vs next best 0.353).
- The numpy LUT path matches the app: with halation off, Process Zero at
  input 0.522 renders 0.583 in-app vs 0.585 predicted; Neutral Classic
  0.554 vs 0.566.
- Lapse V4-03 cube matches lapse-camera-settings.md section 8 SHA-256.
  `.gitattributes` pins LUT line endings; `ci/check_assets.py` checks the hash.
- `strength` is never read by `PhotoRenderer`.
- No Fusion "BW1" (display name Eternal) renders full color (chart chroma
  x1.35). Its original plist has `mono = False`, so this is the source data,
  not a Carbon bug. The BW1 file ID is misleading; BW2 to BW4 are mono.

## Render bugs (fixed; flat-field centre, sRGB in -> out)

1. Natural grain. Was a black layer with noise alpha: 0.73 -> about 0.4,
   std 0.33. Now zero-mean additive grain (FilmEffects.grain, D-017 hash,
   opacity amount*0.2) and Natural's grain is 0 per D-025. 0.73 -> 0.78, std 0.002.
2. Halation. CIBloom + screen lit flat midtones (Process Zero 0.52 -> 0.91).
   Now highlight-only with D-018 thresholds and colours (FilmEffects.halation);
   Process Zero with and without halation is identical below input 0.9.
3. Halide input. Cubes now get Apple Log / Rec.2020 input
   (FilmEffects.applyHalideCube); DisplayP3-named looks are converted from P3.
   Process Zero flat fields track input within 0.06. Chroma Noir's white still
   tops out low (slope 0.31); its pre-LUT channel mix was never recovered.
4. Elysia magenta foliage. The defect is in ElysiaSDR.ccube itself (SDR and HDR,
   any input encoding). `scripts/derive_elysia_lut.py` writes ElysiaCarbonSDR.ccube,
   changing only nodes whose green hue flips by >75 degrees (2,669 of 35,937);
   green-dominant nodes rendered with green lowest: 1,821 -> 0. Skin max dE 0.006.
5. Lapse. Opacity blends scaled only alpha (1.7x brightening, Journal clipped at
   0.52); CA summed three full-alpha planes; Photo Default vignette pow(r,.09)
   darkened nearly every pixel. Fixed with dissolves, a sampler CA kernel, and
   a reconstructed Metal vignette (shader body not recovered). Journal now
   tracks input to 0.9; Photo Default is a faded curve (black 0.39, white 0.87).

## Disproved

- "Process Zero is near-identity."
- "Natural has a gentle film glow" (current render is dark and noisy).
- "Eternal is black and white."
- First-pass numbers from the deleted analyze_presets.py and old guide.

## Next steps once unblocked

1. Fix agreed bugs as separate commits; push; download new artifact.
2. Re-run `measure.py`; rebuild contact sheets (see snippet in git history
   of this file's commit message) and look at them.
3. Write `rate.py` (named thresholds, every Great/Avoid traced to a metric,
   copy composed from measured traits), `generate_guide.py`, `run_all.py`.
