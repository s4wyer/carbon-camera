# Preset analysis: progress and handoff

Read this before continuing. It separates what is measured from what is
assumed. Do not repeat anything listed under "Disproved".

## Goal

Measure all 34 presets in `PresetLibrary.all` through Carbon's real render
path, then generate `presets.json` (single source of truth) and
`PRESETS_GUIDE.md` (generated from it) for non-photographers.

## Status: blocked on render bugs

Measurement works end to end, but the renders contain bugs that would end up
described as "looks". Ratings and copy are not written. `rate.py` was drafted
with hand-written copy based on film reputation and was deleted on purpose;
rewrite it so every rating and sentence comes from `metrics.json`.

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

## Render bugs found (gray-ramp means, input -> output)

1. Natural grain. Natural: 0.522 -> 0.291 with pixel std 0.334.
   Same preset with grain 0: 0.522 -> 0.890, std 0.000. Grain is the cause.
   Code read: `PhotoRenderer.applyGrain` builds a black layer whose alpha is
   the noise value (`inputAVector` x=1 copies the noise red channel into
   alpha) and source-overs it, so the image is darkened by a random
   per-pixel amount near 50 %. Likely intent: low-opacity noise. Not fixed.
2. Shared halation brightens midtones on every LUT preset. Process Zero
   0.522 -> 0.910 with halation, 0.583 without. Neutral Classic 0.763 vs
   0.554. This happens on flat gray, so it is not a highlight-only effect,
   which contradicts D-018's luma thresholds .92-.95. 33 of 34 presets use
   intensity 1.0 (Natural 0.3). Not fixed.
3. Halide input encoding. Even with halation off, Process Zero crushes to 0
   below about 0.15 and clips above about 0.75. Apple Log input fits Process
   Zero far better than sRGB (mean error 0.035 vs 0.123) but this is a fit,
   not proof. Carbon feeds sRGB-encoded values. Elysia renders landscape
   foliage magenta; the cause is not isolated.
4. Lapse renderer (Core Image reconstruction, not validated against Lapse).
   Journal: 0.388 -> 0.918, everything at or above 0.522 clips to 1.0.
   Photo Default: compresses to about 0.2-0.58 and is non-monotonic
   (0.780 -> 0.518 is darker than 0.522 -> 0.576). Causes not isolated; add
   per-stage diagnostics for LapseRenderer before guessing.

## Decisions needed from the operator

- Fix bugs 1, 2 (and 4) before measuring, or document current behavior?
- Bug 3: change Carbon's Halide input encoding, or ship the current look?

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
