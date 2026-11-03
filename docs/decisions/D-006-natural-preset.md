# D-006: Default preset — Natural

**Decision ID:** D-006  
**Concerns:** Roadmap comparison C05; SET13  
**Date:** 2024-11-03  
**Authority:** Roadmap §2 preset rules; product goal (amateur-first people camera)

## Requirement (roadmap §2)

> Presets are the one place an amateur will experiment, so they must be legible at a glance:
> - The name says what it does. A user must predict the result from the name without opening it.
> - One obvious visual promise per preset.
> - Ordered by usefulness to a beginner, with the safest, most flattering option first and selected by default.
> - At least one preset is tuned specifically for portraits and skin, and is what a first-time user lands on.

## The three documents' defaults

| Source | Default |
|---|---|
| Halide §8 | `processZero` for prime camera (Look) |
| Lapse | journal CI defaults (not a named user preset; see §5) |
| No Fusion §9 | bundled presets exist; selected default unknown (unrecovered) |

None of these is what a first-time amateur lands on in **our** app. Halide's Process Zero is the base *film*, but it's not a user-facing preset name (it's a technical term). Lapse's journal is the closest to "natural," but it's not named or surfaced as a preset. No Fusion's default is unrecovered.

## Decision

**Preset 1 (default, displayOrder 0):**

- **Name:** "Natural"
- **Description:** "Lifelike color and smooth skin tones."
- **Source:** `original(rationale: "D-006: Roadmap §2 requires a plain-language, portrait-tuned default. Process Zero (Halide) is the film base, but 'Natural' is our user-facing name.")`
- **Base:** Halide Process Zero LUT (H §2, `p0sdr`/`p0hdr` resources, decoded 33³ half-float RGB payloads retained in `recovery/resources/luts/`), **but** with:
  - `filmStrength = 0.85` (not 1.0) — slightly softer for amateurs
  - `halation` from Lapse Metal defaults (D-018)
  - `grain` from Lapse Metal seeded hash (D-017), default amount 0.4 (not 0.0)
  - Face-balance/skin-tone protection (L §5 `FaceBalance`, `SkinToneTwo`; H §2 Rembrandt

 parameters)
  - Temperature/tint: neutral (4000 K fallback if invalid WB, per L §2)

**Justification:**
1. "Natural" is legible; "Process Zero" is not.
2. The preset is tuned for portraits and skin (roadmap requirement).
3. It's the safest, most flattering option → default.
4. Film base is Halide Process Zero (technical authority), surfacing is ours (product authority).

## Why not just "Process Zero" as the name?

Roadmap §2 says the preset name must be predicted by a first-time user. "Process Zero" is a technical term that only makes sense if you know Halide's marketing. "Natural" says what it does.

Halide's Process Zero *is* the film; our "Natural" preset applies it with the product-goal tuning (skin protection, softened strength, Lapse grain for determinism).

## Other presets (SET13)

To be authored in SET13. Expected set (4–6 presets):
1. **Natural** (default, people-tuned)
2. **Warm Film** (H Rembrandt or L journal with +500 K)
3. **Black & White** (N BW3 Mono or L monochrome)
4. **Vivid** (N "Contemporary" F4 or L instant)

Each will be documented with its source citation or original rationale.
