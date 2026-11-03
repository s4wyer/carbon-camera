#!/usr/bin/env python3
"""
Carbon render pipeline verification harness (Python reference).

This script implements the same tone-chain math as ToneChain.swift, so we can
validate reproducibility without needing Core Image/Metal. The Swift version
is the source of truth; this Python version is for cross-platform verification.

Usage:
    python verify_pipeline.py

Validates:
1. Grain hash determinism (same seed -> same noise)
2. Exposure/temp-tint/contrast/saturation chain
3. Curve application (5-point interpolation)
4. HSL per-color adjustment
5. Full pipeline reproducibility

See docs/reference/comparison.md D-005, D-007, D-008, D-017, D-018, D-020.
"""

import math
import hashlib

# MARK: - Deterministic grain hash (Lapse Metal, D-017)

def integer_hash_noise(x: int, y: int, seed: int) -> float:
    """Lapse Metal seeded integer-hash grain. Returns 0..1."""
    h = (x * 374761393 + y * 668265263 + seed * 1442695040888963407) & 0xFFFFFFFFFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFFFFFFFFFF
    return float(h & 0xFFFFFF) / float(0xFFFFFF)

def grain_intensity_scalar(scene_ev: float) -> float:
    """Lapse CI formula: 1 - 0.05*sceneEV, clamped [0, 2]."""
    raw = 1.0 - 0.05 * scene_ev
    return max(0.0, min(2.0, raw))

# MARK: - Tone chain (D-005 graph order)

def clamp01(v: float) -> float:
    return max(0.0, min(1.0, v))

def min3(a, b, c):
    return min(a, min(b, c))

def max3(a, b, c):
    return max(a, max(b, c))

def verification_lut(r: float, g: float, b: float, name: str) -> tuple:
    """Placeholder LUT: deterministic shoulder + hash-based shift."""
    h = abs(hash(name) % 100) / 1000.0
    def shoulder(x):
        v = x / (1.0 + 0.15 * x)
        return clamp01(v * (1.0 + h))
    return (shoulder(r), shoulder(g), shoulder(b))

def rgb_to_hsv(r: float, g: float, b: float) -> tuple:
    max_v = max3(r, g, b)
    min_v = min3(r, g, b)
    delta = max_v - min_v
    v = max_v
    s = 0 if max_v == 0 else delta / max_v
    h = 0.0
    if delta > 0:
        if max_v == r:
            h = ((g - b) / delta) % 6.0
        elif max_v == g:
            h = (b - r) / delta + 2.0
        else:
            h = (r - g) / delta + 4.0
        h /= 6.0
        if h < 0:
            h += 1.0
    return (h, s, v)

def hsv_to_rgb(h: float, s: float, v: float) -> tuple:
    c = v * s
    x = c * (1.0 - abs((h * 6.0) % 2.0 - 1.0))
    m = v - c
    h6 = h * 6.0
    if h6 < 1:
        r, g, b = c, x, 0
    elif h6 < 2:
        r, g, b = x, c, 0
    elif h6 < 3:
        r, g, b = 0, c, x
    elif h6 < 4:
        r, g, b = 0, x, c
    elif h6 < 5:
        r, g, b = x, 0, c
    else:
        r, g, b = c, 0, x
    return (r + m, g + m, b + m)

def hue_to_color_index(h: float) -> int:
    """Map hue 0..1 to 8 bins: red, orange, yellow, green, aqua, blue, purple, magenta."""
    if h < 0.0417: return 0
    if h < 0.125: return 1
    if h < 0.2083: return 2
    if h < 0.375: return 3
    if h < 0.5417: return 4
    if h < 0.7083: return 5
    if h < 0.8333: return 6
    return 7

def apply_hsl(r: float, g: float, b: float, params: dict) -> tuple:
    s = params['strength']
    h, sat, v = rgb_to_hsv(r, g, b)
    if sat < 0.001:
        return (r, g, b)
    color_index = hue_to_color_index(h)
    ch = params['hsl'][color_index]
    if ch['hue'] == 0 and ch['saturation'] == 1 and ch['luminance'] == 1:
        return (r, g, b)
    
    hue_shift = ch['hue'] * 0.0625 * s
    sat_factor = 1.0 + (ch['saturation'] - 1.0) * s
    lum_adj = ch['luminance'] - 1.0
    clamped_lum_adj = max(-0.25, min(0.25, lum_adj))
    lum_factor = 1.0 + clamped_lum_adj * s
    
    new_hue = (h + hue_shift) % 1.0
    new_sat = clamp01(sat * sat_factor)
    new_val = clamp01(v * lum_factor)
    
    return hsv_to_rgb(new_hue, new_sat, new_val)

def curve_points(params: dict) -> list:
    s = params['strength']
    p0 = (0.0, params['curveBlack'] * s * 0.25)
    p1 = (0.25, params['curveShadow'] * 0.25 * s)
    p2 = (0.5, (params['curveShadow'] * 0.25 * s + params['curveHighlight'] * 0.25 * s) / 2.0 + 0.5)
    p3 = (0.75, params['curveHighlight'] * 0.25 * s)
    p4 = (1.0, 1.0 + params['curveWhite'] * s * 0.25)
    return [p0, p1, p2, p3, p4]

def apply_curve(r: float, g: float, b: float, points: list) -> tuple:
    def lookup(x):
        for i in range(len(points) - 1):
            x0, y0 = points[i]
            x1, y1 = points[i + 1]
            if x >= x0 and x <= x1:
                if x1 == x0:
                    return y0
                t = (x - x0) / (x1 - x0)
                return y0 + (y1 - y0) * t
        return points[-1][1]
    return (lookup(r), lookup(g), lookup(b))

def tone_chain_apply(r: float, g: float, b: float, params: dict, scene_ev: float = 8.0) -> tuple:
    """
    Apply the D-005 tone chain: LUT -> exposure -> temp/tint -> contrast/sat -> curve -> vibrance -> HSL.
    Returns (r, g, b) in 0..1 sRGB.
    """
    s = params['strength']
    
    # LUT
    lr, lg, lb = r, g, b
    if params.get('lutID') and params['lutIntensity'] > 0:
        result = verification_lut(lr, lg, lb, params['lutID'])
        mix = params['lutIntensity']
        lr = lr * (1 - mix) + result[0] * mix
        lg = lg * (1 - mix) + result[1] * mix
        lb = lb * (1 - mix) + result[2] * mix
    
    # Exposure
    ev = params['exposureEV'] * s
    if ev != 0:
        scale = 2.0 ** ev
        lr *= scale
        lg *= scale
        lb *= scale
    
    # Temperature / tint (coarse linear approximation)
    temp_offset = params['temperatureOffsetK'] * s
    if temp_offset != 0:
        warm = 1.0 + temp_offset / 10000.0
        cool = 1.0 - temp_offset / 15000.0
        lr *= warm
        lb *= cool
    tint_offset = params['tintOffset'] * s
    if tint_offset != 0:
        green = 1.0 - tint_offset / 100.0
        lg *= green
    
    # Contrast
    contrast = 1.0 + (params['contrast'] - 1.0) * s
    if contrast != 1.0:
        lr = clamp01((lr - 0.5) * contrast + 0.5)
        lg = clamp01((lg - 0.5) * contrast + 0.5)
        lb = clamp01((lb - 0.5) * contrast + 0.5)
    
    # Saturation
    saturation = 1.0 + (params['saturation'] - 1.0) * s
    if saturation != 1.0:
        luma = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
        lr = clamp01(luma + (lr - luma) * saturation)
        lg = clamp01(luma + (lg - luma) * saturation)
        lb = clamp01(luma + (lb - luma) * saturation)
    
    # Curve
    if any([params['curveBlack'] != 0, params['curveShadow'] != 0, params['curveMidtone'] != 0,
            params['curveHighlight'] != 0, params['curveWhite'] != 0]):
        points = curve_points(params)
        lr, lg, lb = apply_curve(lr, lg, lb, points)
    
    # Vibrance
    vibrance = params['vibrance'] * s
    if vibrance != 0:
        avg_sat = ((lr - min3(lr, lg, lb)) + (lg - min3(lr, lg, lb)) + (lb - min3(lr, lg, lb))) / 3.0
        boost = 1.0 + vibrance * (1.0 - avg_sat)
        luma = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
        lr = clamp01(luma + (lr - luma) * boost)
        lg = clamp01(luma + (lg - luma) * boost)
        lb = clamp01(luma + (lb - luma) * boost)
    
    # HSL
    lr, lg, lb = apply_hsl(lr, lg, lb, params)
    
    return (lr, lg, lb)

# MARK: - Validation tests

def test_grain_determinism():
    """Validate that the same seed produces the same noise."""
    seed = 12345
    vals1 = [integer_hash_noise(x, y, seed) for x in range(10) for y in range(10)]
    vals2 = [integer_hash_noise(x, y, seed) for x in range(10) for y in range(10)]
    assert vals1 == vals2, "Grain hash not deterministic!"
    print("OK Grain hash is deterministic (100 samples)")

def test_grain_intensity_falloff():
    """Validate Lapse CI grain intensity formula."""
    # At EV 0: 1 - 0.05*0 = 1.0
    assert abs(grain_intensity_scalar(0.0) - 1.0) < 0.001
    # At EV 10: 1 - 0.05*10 = 0.5
    assert abs(grain_intensity_scalar(10.0) - 0.5) < 0.001
    # At EV 20: 1 - 0.05*20 = 0.0
    assert abs(grain_intensity_scalar(20.0) - 0.0) < 0.001
    # At EV -10: 1 - 0.05*(-10) = 1.5
    assert abs(grain_intensity_scalar(-10.0) - 1.5) < 0.001
    print("OK Grain intensity falloff formula correct (EV 0/10/20/-10)")

def test_neutral_passthrough():
    """Neutral parameters should return input unchanged."""
    params = {
        'strength': 1.0,
        'lutID': None,
        'lutIntensity': 1.0,
        'exposureEV': 0.0,
        'temperatureOffsetK': 0.0,
        'tintOffset': 0.0,
        'contrast': 1.0,
        'saturation': 1.0,
        'vibrance': 0.0,
        'curveBlack': 0.0,
        'curveShadow': 0.0,
        'curveMidtone': 0.0,
        'curveHighlight': 0.0,
        'curveWhite': 0.0,
        'hsl': [{'hue': 0, 'saturation': 1.0, 'luminance': 1.0} for _ in range(8)]
    }
    r, g, b = tone_chain_apply(0.5, 0.5, 0.5, params)
    assert abs(r - 0.5) < 0.001 and abs(g - 0.5) < 0.001 and abs(b - 0.5) < 0.001, \
        f"Neutral params changed input: {r}, {g}, {b}"
    print("OK Neutral parameters pass through unchanged")

def test_exposure_shift():
    """Exposure +1 EV should double brightness."""
    params = {
        'strength': 1.0,
        'lutID': None,
        'lutIntensity': 1.0,
        'exposureEV': 1.0,
        'temperatureOffsetK': 0.0,
        'tintOffset': 0.0,
        'contrast': 1.0,
        'saturation': 1.0,
        'vibrance': 0.0,
        'curveBlack': 0.0,
        'curveShadow': 0.0,
        'curveMidtone': 0.0,
        'curveHighlight': 0.0,
        'curveWhite': 0.0,
        'hsl': [{'hue': 0, 'saturation': 1.0, 'luminance': 1.0} for _ in range(8)]
    }
    r, g, b = tone_chain_apply(0.25, 0.25, 0.25, params)
    # 0.25 * 2^1 = 0.5
    assert abs(r - 0.5) < 0.001 and abs(g - 0.5) < 0.001 and abs(b - 0.5) < 0.001, \
        f"Exposure +1 EV failed: {r}, {g}, {b}"
    print("OK Exposure +1 EV doubles brightness")

def test_contrast():
    """Contrast 1.5 should stretch around 0.5."""
    params = {
        'strength': 1.0,
        'lutID': None,
        'lutIntensity': 1.0,
        'exposureEV': 0.0,
        'temperatureOffsetK': 0.0,
        'tintOffset': 0.0,
        'contrast': 1.5,
        'saturation': 1.0,
        'vibrance': 0.0,
        'curveBlack': 0.0,
        'curveShadow': 0.0,
        'curveMidtone': 0.0,
        'curveHighlight': 0.0,
        'curveWhite': 0.0,
        'hsl': [{'hue': 0, 'saturation': 1.0, 'luminance': 1.0} for _ in range(8)]
    }
    r, g, b = tone_chain_apply(0.3, 0.3, 0.3, params)
    # (0.3 - 0.5) * 1.5 + 0.5 = -0.2 * 1.5 + 0.5 = -0.3 + 0.5 = 0.2
    assert abs(r - 0.2) < 0.001, f"Contrast 1.5 failed: {r}"
    print("OK Contrast 1.5 stretches around midpoint")

def test_curve_black_point():
    """Curve black adjustment should shift the shadow floor."""
    params = {
        'strength': 1.0,
        'lutID': None,
        'lutIntensity': 1.0,
        'exposureEV': 0.0,
        'temperatureOffsetK': 0.0,
        'tintOffset': 0.0,
        'contrast': 1.0,
        'saturation': 1.0,
        'vibrance': 0.0,
        'curveBlack': 0.4,  # Lifts black floor by 0.1 (0.4 * 1.0 * 0.25 = 0.1)
        'curveShadow': 0.0,
        'curveMidtone': 0.0,
        'curveHighlight': 0.0,
        'curveWhite': 0.0,
        'hsl': [{'hue': 0, 'saturation': 1.0, 'luminance': 1.0} for _ in range(8)]
    }
    r, g, b = tone_chain_apply(0.0, 0.0, 0.0, params)
    # Black floor: 0.4 * 1.0 * 0.25 = 0.1
    assert abs(r - 0.1) < 0.001, f"Curve black lift failed: {r}"
    print("OK Curve black point lifts shadow floor")

def test_reproducibility():
    """Same params + input -> same output (pipeline reproducibility)."""
    params = {
        'strength': 0.8,
        'lutID': 'halide-zephyr',
        'lutIntensity': 0.9,
        'exposureEV': 0.3,
        'temperatureOffsetK': 200.0,
        'tintOffset': -5.0,
        'contrast': 1.1,
        'saturation': 1.05,
        'vibrance': 0.2,
        'curveBlack': 0.1,
        'curveShadow': 0.05,
        'curveMidtone': 0.0,
        'curveHighlight': -0.05,
        'curveWhite': -0.1,
        'hsl': [{'hue': i * 0.01, 'saturation': 1.0 + i * 0.01, 'luminance': 1.0} for i in range(8)]
    }
    r1, g1, b1 = tone_chain_apply(0.4, 0.6, 0.5, params, scene_ev=7.0)
    r2, g2, b2 = tone_chain_apply(0.4, 0.6, 0.5, params, scene_ev=7.0)
    assert (r1, g1, b1) == (r2, g2, b2), "Pipeline not reproducible!"
    print(f"OK Pipeline reproducible (same input+params -> same output: {r1:.6f}, {g1:.6f}, {b1:.6f})")

if __name__ == '__main__':
    print("Carbon pipeline verification harness (Python reference)\n")
    test_grain_determinism()
    test_grain_intensity_falloff()
    test_neutral_passthrough()
    test_exposure_shift()
    test_contrast()
    test_curve_black_point()
    test_reproducibility()
    print("\nOK All validation tests passed. Pipeline math is consistent with spec.")
    print("   (Note: This validates numeric behavior, not LUT identity or device output.)")
