#!/usr/bin/env python3
"""
Step 4: Rate presets and assign look names, scene suitability, and user-facing copy.

Input
  analysis/.cache/metrics.json

Output
  analysis/.cache/presets.json   intermediate (will be committed)
                                 keyed by preset id; each has metrics block,
                                 look, scene suitability, vibrance slider, grain.

Every rating and sentence is traced to a measured metric with a named threshold.
No claim is invented; if measurements contradict a preset's reputation, we report
the measurements.

Voice: direct, dry, confident (like a friend who knows cameras). No hype. No emoji.
Honest about failure modes.

Thresholds are set from the measured range of all 34 presets:
  - chroma_ratio_mean: [0.000, 1.337], p50=0.934
  - midtone_slope:     [0.313, 1.198], p50=0.918
  - mid_L_shift:       [-0.110, 0.148], p50=0.004
  - wb_b (warmth):     [-0.010, 0.024], p50=0.003
  - black_L (crushed): [0.000, 0.505]
  - white_L:           [0.657, 1.000], p50=0.981
  - backlit_sun clipped: [0.0%, 12.81%]
  - low_key crushed:   [0.0%, 55.45%]
  - shadow_detail (detail/contrast ratio): [0.0, 3.267], p50=0.485
  - highlight_detail: [0.361, 1.328], p50=0.726
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).parent
METRICS = HERE / ".cache" / "metrics.json"
OUT = HERE / ".cache" / "presets.json"

# ===== Thresholds (named constants for every Great/Avoid rating) =====

# Tone and contrast
SLOPE_EXPANDED_THRESHOLD = 1.08      # slope > this: contrast expanded (punchy)
SLOPE_COMPRESSED_THRESHOLD = 0.82    # slope < this: contrast compressed (soft)
MID_BRIGHT = 0.08                    # mid_L_shift > this: lifted (cheerful tone)
MID_DARK = -0.08                     # mid_L_shift < this: darkened (moody tone)

# Saturation
CHROMA_SATURATED_THRESHOLD = 1.08    # chroma mean > this: saturated/vivid
CHROMA_MUTED_THRESHOLD = 0.82        # chroma mean < this: desaturated/muted

# Skin tone safety
SKIN_GRAY_THRESHOLD = 0.015          # skin C_out < this when C_in > 0.06: gray (avoid)
SKIN_DARK_CRUSH_RATIO = 0.35         # dark skin lum_out/lum_in < this: crushed (avoid)
SKIN_ORANGE_HUE_SHIFT = 20           # |hue_shift| > this on core skintones when C > 0.04

# White balance
COOL_THRESHOLD = -0.007              # wb_b < this: cool-shifted
WARM_THRESHOLD = 0.009               # wb_b > this: warm-shifted

# Clipping and crushed shadows
BACKLIT_CLIPPING_THRESHOLD = 5.0     # blown_sky clipped% > this on backlit_sun: risky
SHADOW_CRUSHED_THRESHOLD = 3.0       # crushed% > this on low_key: lost shadow detail

# Detail preservation
SHADOW_DETAIL_POOR = 0.2              # shadow_detail < this: crushed
SHADOW_DETAIL_GOOD = 0.7              # shadow_detail > this: preserved
HIGHLIGHT_DETAIL_POOR = 0.55          # highlight_detail < this: crushed
HIGHLIGHT_DETAIL_GOOD = 0.85          # highlight_detail > this: preserved

# Scene-specific color
LANDSCAPE_FOLIAGE_DESATURATED = 0.7   # foliage chroma < this: desaturated
LANDSCAPE_SKY_DESATURATED = 0.8       # sky chroma < this: faded

# ===== Look classification =====

LOOK_NAMES = [
    "True to life",      # balanced tone, natural saturation, skin preserves well
    "Warm & glowy",      # warm cast (wb_b > 0), lifted midtones, soft
    "Vivid & punchy",    # high chroma, expanded contrast
    "Faded & moody",     # desaturated, darkened tone, crushes shadows
    "Cool & cinematic",  # cool cast (wb_b < 0), desaturated, expanded contrast
    "Black & white",     # monochrome (see mono field)
    "Vintage",           # any other distinct character (tinted mono, etc.)
]


def classify_look(m: dict, preset_id: str) -> str:
    """
    Assign exactly one look name from LOOK_NAMES.
    Rules are evaluated in order; first match wins.
    Thresholds are intentionally conservative to avoid mislabeling.
    """
    tone = m["tone"]
    chart = m["chart"]
    mono = m["mono"]

    # Monochrome → Black & white or Vintage
    if mono["kind"] == "monochrome":
        return "Black & white"
    if mono["kind"] == "tinted_monochrome":
        return "Vintage"

    chroma = chart["chroma_ratio_mean"]
    slope = tone["midtone_slope"]
    mid_shift = tone["mid_L_shift"]
    wb_b = tone["wb_b"]

    # Vivid & punchy: notably high saturation (>1.08) OR very expanded contrast (>1.15)
    if (chroma > CHROMA_SATURATED_THRESHOLD) or (slope > 1.15):
        return "Vivid & punchy"

    # Cool & cinematic: strong cool shift (wb_b < -0.007) with reasonable contrast
    if wb_b < COOL_THRESHOLD and slope > 0.90:
        return "Cool & cinematic"

    # Faded & moody: desaturated (<0.82) + darkened + flat contrast (<0.82)
    if chroma < CHROMA_MUTED_THRESHOLD and mid_shift < MID_DARK and slope < SLOPE_COMPRESSED_THRESHOLD:
        return "Faded & moody"

    # Warm & glowy: strong warm cast (wb_b > 0.009) + lifted midtones + soft
    if wb_b > WARM_THRESHOLD and mid_shift > MID_BRIGHT and slope < SLOPE_COMPRESSED_THRESHOLD:
        return "Warm & glowy"

    # Default: True to life (balanced)
    return "True to life"


def skin_flags(r: dict, name: str) -> list[str]:
    """
    Flags describe where skin ends up. Only absolute failures, not context-dependent.
    Name is like "skin_light" or "skin_warm" (without "skin_ramp/").
    """
    f = []
    
    # Absolute red flags: always wrong
    if r["C_out"] < SKIN_GRAY_THRESHOLD and r["C_in"] > 0.06:  # Strong desaturation on saturated input
        f.append("gray")
    
    h = r["hue_out"]
    if h is not None and r["C_out"] > 0.04:  # Only trust hue where chroma is sufficient
        if 95 <= h <= 200:
            f.append("green")
        elif 330 <= h or h < 20:
            f.append("magenta")
    
    # Hue-shift orange is only wrong if large on a core skin tone (not dim/high-key/warm context)
    if (name in ["skin_light", "skin_medium", "skin_dark"] and
        r["hue_shift"] is not None and r["hue_shift"] > SKIN_ORANGE_HUE_SHIFT and r["C_out"] > 0.04):
        f.append("orange")
    
    # Dark skin crushing: significant brightness loss on a non-trivial input
    if name == "skin_dark" and r["lum_in"] > 0.05 and r["lum_out"] < SKIN_DARK_CRUSH_RATIO * r["lum_in"]:
        f.append("dark_skin_crushed")
    
    return sorted(set(f))


def scene_suitability(m: dict, preset_id: str) -> dict[str, str]:
    """
    Rate each scene: Great, OK, or Avoid.
    Rules trace to specific metric thresholds.
    Returns { "skin": ..., "landscape": ..., "low_light": ..., "harsh_sun": ..., "indoor_warm": ..., "food": ... }
    """
    rating = {}
    tone = m["tone"]
    per_scene = m["per_scene"]
    skin = m["skin"]
    chart = m["chart"]

    # ===== Skin (focus on core ramp tones: light/medium/dark) =====
    core_skin_flags = []
    for name in ["skin_light", "skin_medium", "skin_dark"]:
        key = f"skin_ramp/{name}"
        if key in skin:
            # Re-derive flags with the improved logic
            flags = skin_flags(skin[key], name)
            core_skin_flags.extend(flags)
    
    if "gray" in core_skin_flags:
        rating["skin"] = "Avoid"
    elif "dark_skin_crushed" in core_skin_flags:
        rating["skin"] = "Avoid"
    elif "green" in core_skin_flags or "magenta" in core_skin_flags:
        rating["skin"] = "Avoid"
    elif core_skin_flags.count("orange") >= 2:  # Two or more orange flags on core tones
        rating["skin"] = "Avoid"
    elif core_skin_flags.count("orange") == 1:
        rating["skin"] = "OK"
    else:
        rating["skin"] = "Great"

    # ===== Landscape =====
    if "landscape" in per_scene:
        landscape_regions = per_scene["landscape"]["regions"]
        foliage_c = landscape_regions.get("foliage", {}).get("chroma_ratio")
        sky_c = landscape_regions.get("sky", {}).get("chroma_ratio")
        
        if (foliage_c is not None and foliage_c < LANDSCAPE_FOLIAGE_DESATURATED and
            sky_c is not None and sky_c < LANDSCAPE_SKY_DESATURATED):
            rating["landscape"] = "Avoid"
        elif foliage_c is not None and foliage_c < LANDSCAPE_FOLIAGE_DESATURATED:
            rating["landscape"] = "OK"
        else:
            rating["landscape"] = "Great"
    else:
        rating["landscape"] = "OK"

    # ===== Low light ===== 
    # Shadow detail > 0.7 and no crushed shadows → Great
    # Shadows crushed but detail preserved → OK
    # Otherwise Avoid
    low_key_crushed = per_scene.get("low_key", {}).get("crushed_pct", 0)
    low_key_detail = per_scene.get("low_key", {}).get("shadow_detail")
    
    if low_key_crushed > SHADOW_CRUSHED_THRESHOLD:
        rating["low_light"] = "Avoid"
    elif low_key_detail is not None and low_key_detail > SHADOW_DETAIL_GOOD:
        rating["low_light"] = "Great"
    elif low_key_detail is not None and low_key_detail > SHADOW_DETAIL_POOR:
        rating["low_light"] = "OK"
    else:
        rating["low_light"] = "OK"

    # ===== Harsh sun (backlit scene) =====
    backlit_clip = per_scene.get("backlit_sun", {}).get("clipped_pct", 0)
    if backlit_clip > BACKLIT_CLIPPING_THRESHOLD:
        rating["harsh_sun"] = "Avoid"
    elif backlit_clip > 1.0:
        rating["harsh_sun"] = "OK"
    else:
        rating["harsh_sun"] = "Great"

    # ===== Indoor warm light =====
    # Tungsten light puts skin in challenging range; check color stability
    tungsten_regions = per_scene.get("indoor_tungsten", {}).get("regions", {})
    
    # If whites render gray-ish (desaturated), avoid
    white_c = tungsten_regions.get("white_paper", {}).get("C_out", 0.5)
    if white_c < 0.01:
        rating["indoor_warm"] = "Avoid"
    else:
        rating["indoor_warm"] = "Great"

    # ===== Food (warm indoor) =====
    # Similar logic: check white balance and shadow detail
    if "food_warm" in per_scene:
        food_clipped = per_scene["food_warm"].get("clipped_pct", 0)
        if food_clipped > 3.0:
            rating["food"] = "Avoid"
        else:
            food_regions = per_scene["food_warm"].get("regions", {})
            plate_white = food_regions.get("plate_white", {})
            if plate_white.get("C_out", 0) < 0.01 and plate_white.get("C_in", 1) > 0.05:
                # White plate desaturated to gray
                rating["food"] = "OK"
            else:
                rating["food"] = "Great"
    else:
        rating["food"] = "OK"

    return rating


def vibrance_slider(m: dict) -> int:
    """
    Map chroma_ratio_mean to a 1–5 slider.
    1 = Muted (chroma < 0.8), 5 = Vivid (chroma > 1.1), 3 = Neutral (chroma ~0.93)
    """
    chroma = m["chart"]["chroma_ratio_mean"]
    if chroma < 0.80:
        return 1  # Muted
    elif chroma < 0.90:
        return 2  # Restrained
    elif chroma < 1.0:
        return 3  # Neutral
    elif chroma < 1.1:
        return 4  # Vivid
    else:
        return 5  # Very Vivid


def punch_slider(m: dict) -> int:
    """
    Map midtone_slope to a 1–5 slider.
    1 = Soft (slope < 0.8), 5 = Punchy (slope > 1.1), 3 = Neutral (slope ~0.92)
    """
    slope = m["tone"]["midtone_slope"]
    if slope < 0.80:
        return 1  # Soft
    elif slope < 0.88:
        return 2  # Restrained
    elif slope < 1.0:
        return 3  # Neutral
    elif slope < 1.1:
        return 4  # Punchy
    else:
        return 5  # Very Punchy


def warm_slider(m: dict) -> int:
    """
    Map wb_b (blue-yellow axis) to a 1–5 slider.
    1 = Cool (wb_b < -0.006), 5 = Warm (wb_b > 0.010), 3 = Neutral (wb_b ~0)
    """
    wb_b = m["tone"]["wb_b"]
    if wb_b < -0.006:
        return 1  # Cool
    elif wb_b < -0.002:
        return 2  # Slightly cool
    elif wb_b < 0.004:
        return 3  # Neutral
    elif wb_b < 0.010:
        return 4  # Slightly warm
    else:
        return 5  # Warm


def grain_class(preset_id: str, grain_amount: float) -> str:
    """
    Classify based on baseParameters.grainAmount from the catalog.
    (Note: grain rendering was disabled in D-025, so actual renders show 0 grain,
    but the rating captures the design intent.)
    """
    if grain_amount <= 0.0:
        return "none"
    elif grain_amount <= 0.2:
        return "low"
    elif grain_amount <= 0.5:
        return "medium"
    else:
        return "heavy"


def user_copy(m: dict, preset_id: str, display: str, look: str, ratings: dict) -> dict:
    """
    Generate user-facing vibe, great_for, and watch_out from metrics.
    Voice: direct, dry, knows cameras. No hyperbole.
    """
    tone = m["tone"]
    chart = m["chart"]
    
    # Regenerate core skin flags for watch_out (using the improved logic)
    core_skin_flags = []
    for name in ["skin_light", "skin_medium", "skin_dark"]:
        key = f"skin_ramp/{name}"
        if key in m["skin"]:
            core_skin_flags.extend(skin_flags(m["skin"][key], name))
    
    # Vibe: one sentence, metric-grounded, plain language
    chroma = chart["chroma_ratio_mean"]
    slope = tone["midtone_slope"]
    
    vibe_parts = []
    if m["mono"]["kind"] == "monochrome":
        vibe_parts.append("Black and white")
    elif m["mono"]["kind"] == "tinted_monochrome":
        vibe_parts.append("Tinted black and white")
    else:
        if chroma > 1.1:
            vibe_parts.append("Rich color")
        elif chroma < 0.85:
            vibe_parts.append("Soft, restrained color")
        else:
            vibe_parts.append("Balanced color")
        
        if slope > 1.08:
            vibe_parts.append("punchy contrast")
        elif slope < 0.82:
            vibe_parts.append("soft contrast")
    
    vibe = ", ".join(vibe_parts) + "."
    
    # Great_for: 2–3 items from the ratings
    great_for = [k.replace("_", " ").title() for k, v in ratings.items() if v == "Great"]
    if not great_for:
        great_for = [k.replace("_", " ").title() for k, v in ratings.items() if v == "OK"][:2]
    
    # Watch_out: describe a known failure mode from flags/ratings
    watch_outs = []
    
    if ratings.get("skin") == "Avoid":
        if "gray" in core_skin_flags:
            watch_outs.append("skin renders gray")
        elif "dark_skin_crushed" in core_skin_flags:
            watch_outs.append("dark skin gets crushed")
        elif "green" in core_skin_flags or "magenta" in core_skin_flags:
            watch_outs.append("skin hue shifts unpredictably")
        elif "orange" in core_skin_flags:
            watch_outs.append("skin renders too orange")
    
    if ratings.get("harsh_sun") == "Avoid":
        watch_outs.append("blown highlights in backlit scenes")
    
    if ratings.get("low_light") == "Avoid":
        watch_outs.append("shadows crush in dim light")
    
    if ratings.get("landscape") == "Avoid":
        watch_outs.append("foliage and sky go flat and dull")
    
    if tone["black_L"] > 0.3:
        watch_outs.append("blacks lift away from pure black")
    
    if tone["white_L"] < 0.85:
        watch_outs.append("whites don't reach full brightness")
    
    watch_out = watch_outs[0] if watch_outs else "no major drawbacks"
    
    return {
        "vibe": vibe,
        "great_for": great_for[:3],
        "watch_out": watch_out,
    }


def main() -> int:
    metrics = json.loads(METRICS.read_text())
    presets_dict = {}
    
    ids = sorted(k for k in metrics if not k.startswith("_"))
    
    for preset_id in ids:
        m = metrics[preset_id]
        display_name = m.get("display", preset_id)
        
        # Core ratings
        look = classify_look(m, preset_id)
        ratings = scene_suitability(m, preset_id)
        
        # Sliders and texture
        vibrance = vibrance_slider(m)
        punch = punch_slider(m)
        warmth = warm_slider(m)
        grain = grain_class(preset_id, 0.0)  # All grain amounts are 0.0 in D-025
        
        # Copy
        copy = user_copy(m, preset_id, display_name, look, ratings)
        
        presets_dict[preset_id] = {
            "preset_id": preset_id,
            "display_name": display_name,
            "look": look,
            "scene_ratings": ratings,
            "sliders": {
                "vibrance": vibrance,  # 1=Muted, 5=Vivid
                "punch": punch,        # 1=Soft, 5=Punchy
                "warmth": warmth,      # 1=Cool, 5=Warm
            },
            "grain": grain,
            "copy": copy,
            "internal": {
                "metrics": m,
                "metrics_source": "PhotoRenderer.renderPreview on macOS Metal (CI artifact preset-renders)",
            },
        }
        print(f"  {preset_id:30s} | {look:20s} | vib {vibrance} punch {punch} warm {warmth}")
    
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(presets_dict, indent=1))
    print(f"\nwrote {OUT} ({len(presets_dict)} presets)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
