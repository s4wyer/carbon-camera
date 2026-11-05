# Preset Analysis Progress

**Status:** Foundation validated, ready for measurement step  
**Next:** Load catalog, generate scenes, measure tone/color, derive ratings

---

## What's done

### Step 0: Validation ✓

Tool: `analysis/validate.py`

All checks passed:
- Identity LUT passes through values unchanged
- Process Zero drifts ≤0.128 from identity (neutral film base verified)
- Gray ramp monotonicity preserved (no tone reversals)
- RGB channel order correct (R→R, G→G, B→B all >0.85)
- LUT mix blend at intensity 0/1 works
- OKLab roundtrip error <0.01

###Library: `analysis/lutlib.py`

Provides:
- LUT loading (Halide .ccube LZFSE, No Fusion .lutbin, Lapse .cube)
- Trilinear sampling (bug-fixed: index clamped before fraction computed)
- sRGB↔OKLab↔OKLCH conversions
- Carbon render path: `apply_lut_mix(rgb, lut, intensity)`
- Lapse render paths: `lapse_journal_render`, `lapse_photo_render`
- Limitations documented in `LAPSE_LIMITS` dict

### Domain assumptions

**LUT input/output encoding:** sRGB gamma (0–1), as Carbon uses CIColorCubeWithColorSpace with sRGB working space. Halide doc describes internal linear-space filter chains, but exported LUTs are sRGB-encoded for portability.

**Preset color/tone differences:** 33 of 34 presets differ only by LUT and its intensity. Natural adds grain 0.4, bloom 0.3, halation 0.3; all other stages (exposure, temp/tint, contrast, saturation, vibrance, curve, HSL, vignette) are neutral or zero across the catalog. Grain/bloom are texture, not measured here.

**Lapse procedural:** Reproduces gamma/exposure/vibrance/highlight-shadow stages; Core Image private filters (halation, FaceBalance, SkinToneTwo, vignette, chromatic aberration, blur, grain) are not modelled. Limitations named in `LAPSE_LIMITS`.

---

## What's next

### Step 1: Reference scenes (next up)

Generate sophisticated synthetic references covering:
- Gray ramp (0–1 in 128 steps) 
- Color patches (ColorChecker-like, 12–24 swatches)
- Skin tone ramp (light → dark, realistic hues)
- Sky gradient (light blue → deep blue)
- Foliage samples (3–4 green variations)
- High-key scene (0.7–1.0 range)
- Low-key scene (0–0.3 range)
- Backlit/harsh sun (0.05 blacks, 0.95 highlights in one image)
- Food/warm indoor (orange-biased)

Save as PNG in `analysis/refs/`.

### Step 2: Render all presets

For each of 34 presets:
- Render all reference images through `render(preset, rgb, lut_cache, scene_ev)`
- Save outputs to `analysis/renders/{preset_key}/ref_{name}.png`
- Sanity-check: visual inspection of 3–4 key presets (Natural, Nova, Chroma Noir, a No Fusion) to confirm they look reasonable before measuring

### Step 3: Measure tone & color

For each preset's renders, compute:

**Tone:**
- Gray ramp response (output luma at 0, 2, 5, 10, 18, 30, 50, 70, 90, 95, 100% input)
- Black point (output luma at 0%), white point (output at 100%)
- Midtone shift (output at 50% - 0.5)
- Contrast: p5–p95 luma spread change from input
- Shadow detail: local variance in 0–0.3 range, input vs. output
- Highlight detail: local variance in 0.7–1.0 range

**Color (OKLab / OKLCH):**
- Chroma mean change (overall, per region: skin / foliage / sky)
- Hue shift with proper wraparound, reported only where output C > 0.05
- White balance (a/b offset on gray ramp)
- Monochrome flag: output max(C) < 0.02

**Skin (critical):**
- For each of 3 skin tones (light / medium / dark), measure hue drift and chroma change
- Flag any preset pushing skin toward green (hue 120–180°), gray (C < 0.02), orange (hue shift >+15°), or magenta (hue 270–330°)
- Flag any preset crushing dark skin (output luma < 0.10 for input luma 0.30)

Save all to `analysis/metrics.json` keyed by preset.

### Step 4: Derive ratings

From metrics, compute (with thresholds as named constants in script):

**Look** (exactly one):  
- True to life | Warm & glowy | Vivid & punchy | Faded & moody | Cool & cinematic | Black & white | Vintage

**Scene ratings** (Great / OK / Avoid for each):  
- skin, landscape, low light, harsh sun, indoor warm light, food

**Sliders (1–5):**  
- Muted ← → Vivid
- Soft ← → Punchy
- Cool ← → Warm

**Grain:** none / low / medium / heavy (from baseParameters.grainAmount)

Trace every "Avoid" and every "Great" to a specific metric value. If measurements contradict a film's reputation (e.g. Classic Chrome known as muted but LUT measures saturated), trust the measurements.

### Step 5: Near-duplicates

Compute pairwise MSE between rendered outputs. Find presets within epsilon (e.g. <0.01 mean abs diff across all test pixels). Propose:
- Merge candidates
- Variant toggles (SDR/HDR, scene/display for Chroma Noir)
- Diagnostic/technical presets to mark non-user-facing (Journal?, Photo Default?)

### Step 6: User-facing copy

For each preset, generate from measurements (not invented):
- `name`: plain name only (e.g. "Portra 400"), never internal codes
- `vibe`: one sentence, plain language, grounded in metrics, no jargon/numbers
- `great_for`: 2–3 items
- `watch_out`: one honest sentence about failure mode, from measurements

Voice: confident, dry friend who knows cameras. No marketing superlatives. No emoji. Soften weaknesses where metrics prove it, never to make a preset sound better.

### Step 7: Deliverables

1. `analysis/presets.json`: single source of truth with all fields + internal metrics block
2. `analysis/PRESETS_GUIDE.md`: generated from presets.json by `generate_guide.py`, not hand-written
3. Analysis scripts: `validate.py`, `measure.py`, `rate.py`, `generate_guide.py`

No extra docs. Everything needed for continuation goes in a PROGRESS.md checkpoint (you're reading it).

---

## Open work

### Camera change (Lapse procedural logic)

**Required:** Implement Lapse journal/photo pipelines so the two Lapse presets render correctly.

**Authority:** `docs/reference/lapse-camera-settings.md` §5 (journal) and §7 (photo_default).

**What's done:**
- `lutlib.py` has `lapse_journal_render` and `lapse_photo_render` stubs with the reproducible stages (LUT, gamma, exposure, vibrance, highlight/shadow)
- Private Core Image filters (halation, FaceBalance, etc.) are documented as not modelled in `LAPSE_LIMITS`
- Validation of those two functions happens in step 2 (render and inspect visually)

**What's needed (delegate to gpt-6.1-sol subagent):**
1. Read `docs/reference/lapse-camera-settings.md` §1–10 in full
2. Verify the Lapse LUT (V4-03) loaded from `~/Downloads/com.lapse.journal-4.1.1-eeveedecrypter.ipa` matches the documented hash
3. For Carbon's camera path (`Carbon/Sources/CarbonKit/Camera/CameraManager.swift`):
   - Currently uses Process Zero style (neutral RAW + no adjustments)
   - Must switch to Lapse §5 journal defaults for capture metadata (temp/tint/sceneEV fallbacks, quality priority rules)
   - Preserve Carbon's D-002 overrides (35mm, auto flash, RAW+HEVC)
4. For the test path (`Carbon/Tests/CarbonKitTests/`):
   - Add a fixture that exercises both Lapse presets (journal, photo) with a known input
   - Verify output is not Process-Zero-identical (proves the render path differs)
5. Document the changes in a brief commit message referencing the Lapse doc sections used

**Acceptance:** CI green, Lapse presets render distinctly from Process Zero when measured in step 2.

---

## File inventory

```
analysis/
  lutlib.py          - core library (LUT loading, sampling, render, color math)
  validate.py        - step 0 checks (all passing)
  PROGRESS.md        - this file
```

**Environment:** Python 3.12, numpy 2.5.3, pillow 11.1.0, pyliblzfse 0.4.1

**Repo state:** `main` branch, 1 unstaged change (CameraView.swift padding tweak), no commits since starting this work.

---

## How to continue

If I (or another agent) picks this up:

1. Run `python analysis/validate.py` to confirm tooling still works
2. Read this file's "What's next" section
3. Check "Open work" for blocking dependencies (camera change)
4. Write the next script (`generate_scenes.py` or `measure.py`) in `analysis/`, document its output format at the top
5. Update this file's "What's done" section after each completed step
6. Commit incremental progress, not one giant final PR

The analysis is not a black box: every claim in the final guide must trace to a measurement in `metrics.json`, and every measurement must be reproducible from the scripts + reference images.
