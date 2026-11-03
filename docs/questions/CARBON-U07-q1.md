# Question CARBON-U07-q1: Composition guide geometry

**Ticket:** U07 — Brightline outside margin  
**Source doc:** Halide §6  
**Status:** Answered for Carbon by principal-approved product decision
**Date filed:** 2024-11-03

## Approved answer (2026-11-03)

[D-025](../decisions/D-025-amateur-camera-defaults.md#u07-composition-guides)
sets guides off by default, with optional rule-of-thirds lines at 1/3 and 2/3
of the actual photo crop, using thin translucent white lines. Guides must align
with exported composition; UI safe areas must not shift them. Golden-ratio and
rabatment guides belong in advanced options with geometry specified separately
before implementation. Validate alignment across orientations and crops.

This is an approved Carbon decision, not recovered Halide geometry. It supersedes
the historical provisional implementation, basic-grid blocker, and extraction
request below. Advanced geometry and device verification remain pending.

## Historical reference question

For U07 ("Brightline outside margin"), the roadmap requires composition guide geometry from Halide:

> U07 Brightline outside margin / P1 / Halide REF §6 (guide types — ask for geometry detail); Lapse SET §4 (aspect-fill geometry)

Halide §6 says:
> IDA confirms a `GuideView` type with a `Mode` enum and separate `GoldenRatioView` and `RabatmentView` types. The settings model has a `GuideMode` enum. A `LensGuideView` also exists. The recovered functions were enum accessors, SwiftUI/UIKit type metadata, and unimplemented initializer stubs; the actual body/path drawing methods and mode-to-view dispatch were not recovered.
>
> Still unknown: rule-of-thirds coordinates, golden-ratio constant and line construction, uniform-grid subdivisions, Rabatment geometry, safe-area/orientation handling, aspect-fill transforms, line widths, and drawing primitives. Do not infer geometry from guide names.

## What the current document provides

- Enum cases exist (`GuideView.Mode`, `GuideMode`).
- Type names: `GoldenRatioView`, `RabatmentView`, `LensGuideView`.
- Halide has a concept of multiple guide types (rule-of-thirds, golden ratio, rabatment, lens/grid).

## What it does not provide

- Coordinates for the brightlines (rule-of-thirds: 1/3, 2/3? Golden: φ-based split?)
- Line widths (hairline? 1pt? 2pt?)
- Safe-area inset handling (do the lines avoid notch/home indicator?)
- Aspect-fill transforms (Lapse §4 has aspect-fill geometry; Halide's interaction with it is unresolved)
- Drawing method: Core Graphics paths? UIBezierPath? SwiftUI Shape?

## Why this is insufficient

The roadmap specifies U07 as Type A, with Halide §6 as the reference. Without the actual line coordinates and drawing behavior, we cannot implement the brightlines as Halide does them. We could guess "rule of thirds = 1/3, 2/3" and "golden ratio = 0.382, 0.618", but the document explicitly says "Do not infer geometry from guide names."

## What we would build if forced to guess (so independent work can continue)

**Provisional implementation** (to unblock U07):

1. **Rule of thirds:** Horizontal lines at y = 1/3, 2/3 of the preview frame height; vertical lines at x = 1/3, 2/3.
2. **Golden ratio:** Horizontal at y = 0.382, 0.618; vertical at x = 0.382, 0.618 (φ - 1 ≈ 0.618).
3. **Line width:** 1 pt hairline, white with 50% alpha, slightly thicker (2 pt) in low-light.
4. **Safe area:** Inset the guide frame by the system safe-area insets before drawing.
5. **Aspect-fill:** Use Lapse §4's `scale = max(targetW/inputW, targetH/inputH)`, then center-crop; apply the same transform to the guide canvas.

Mark this behavior as **provisional** in the code and in docs/decisions/. The final implementation replaces it once the principal provides the Halide drawing body or a screenshot comparison set.

## Dependency

This blocks the full U07 implementation. The ticket can proceed with a provisional guide (documented as such) and revisit when answered.

## Request to principal

Please provide:
1. Rule-of-thirds line positions (1/3, 2/3, or other?)
2. Golden-ratio constant or positions (φ = 1.618...?)
3. Rabatment geometry (square inscribed in the frame?)
4. Line widths and colors (pt, alpha)
5. Safe-area handling (inset, or draw full frame?)
6. Or: screenshots of Halide's guide overlays in each mode, on a known device, so we can measure the coordinates from the visual reference.
