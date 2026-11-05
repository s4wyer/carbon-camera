#!/usr/bin/env python3
"""
Derive Carbon's corrected Elysia LUT from Halide's ElysiaSDR.ccube.

Why: ElysiaSDR maps mid-saturation greens to magenta (1,877 of 9,455
green-dominant nodes render with green as the lowest channel; SDR and HDR
variants share the pattern, and no other Halide LUT has it). On foliage this
reads as a defect, so Carbon ships a corrected copy. The original file is kept
unmodified in Carbon/Resources/LUTs/halide/ElysiaSDR.ccube for provenance.

Domain: Halide cubes are indexed by Apple Log encoded Rec.2020 values and
output sRGB-encoded values (see analysis/PROGRESS.md). The correction is
computed in that domain so it lines up with how PhotoRenderer samples the cube.

Correction, per node, in OKLCH:
  w = green_input(h_in) * chroma_gate(C_in) * flip(|h_out - h_in|)
  corrected = (L_out, min(C_out, 1.15 * C_in), h_in + clamp(dh, -15, 15))
  out = mix(original, corrected, w) in OKLab, gamut-clipped by chroma.
Nodes with w == 0 are copied bit-for-bit.

Usage: python scripts/derive_elysia_lut.py [--check]
  --check  verify the committed output matches a fresh derivation
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "analysis"))
from lutlib import hue_delta, linear_to_srgb, load_halide_ccube, srgb_to_linear  # noqa: E402

import liblzfse  # noqa: E402

SOURCE = ROOT / "Carbon/Resources/LUTs/halide/ElysiaSDR.ccube"
OUTPUT = ROOT / "Carbon/Resources/LUTs/halide/ElysiaCarbonSDR.ccube"

# Correction constants
GREEN_HUE = (95.0, 110.0, 185.0, 200.0)   # OKLCH hue: ramp up, full, full, ramp down.
                                          # Upper edge sits past 180 because Rec.2020 greens
                                          # outside sRGB land at OKLCH hue 175-180.
CHROMA_GATE = (0.02, 0.05)                # input chroma where correction fades in
FLIP_GATE = (75.0, 105.0)                 # |hue change| where correction fades in: a hue reversal, not ordinary gamut compression
MAX_HUE_STYLE = 15.0                      # keep up to this much of Elysia's hue shift
CHROMA_CAP = 1.15                         # corrected chroma <= 1.15 x input chroma

# Apple Log (Apple, "Apple Log Profile White Paper", 2023)
R0, RT, C, B, G, D = -0.05641088, 0.01, 47.28711236, 0.00964052, 0.08550479, 0.69336945
REC2020_TO_SRGB = np.array([[1.6603627, -0.58754, -0.0728227],
                            [-0.1245635, 1.1329114, -0.0083478],
                            [-0.0181566, -0.1006017, 1.1187583]])

M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
               [0.2119034982, 0.6806995451, 0.1073969566],
               [0.0883024619, 0.2817188376, 0.6299787005]])
M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
               [1.9779984951, -2.4285922050, 0.4505937099],
               [0.0259040371, 0.7827717662, -0.8086757660]])


def applelog_inverse(y: np.ndarray) -> np.ndarray:
    yt = G * np.log2(RT + B) + D
    hi = np.exp2((y - D) / G) - B
    lo = np.sqrt(np.maximum(y, 0.0) / C) + R0
    return np.where(y >= yt, hi, lo)


def lin_to_oklab(lin: np.ndarray) -> np.ndarray:
    """Linear sRGB -> OKLab without clipping (signed cube root keeps out-of-gamut values)."""
    return np.cbrt(lin @ M1.T) @ M2.T


def oklab_to_lin(lab: np.ndarray) -> np.ndarray:
    return (lab @ np.linalg.inv(M2).T) ** 3 @ np.linalg.inv(M1).T


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def to_lch(lab):
    return np.stack([lab[..., 0], np.hypot(lab[..., 1], lab[..., 2]),
                     np.degrees(np.arctan2(lab[..., 2], lab[..., 1])) % 360], -1)


def from_lch(L, Cc, h):
    r = np.radians(h)
    return np.stack([L, Cc * np.cos(r), Cc * np.sin(r)], -1)


def gamut_clip(L, Cc, h):
    """Reduce chroma until linear sRGB is inside [0, 1]."""
    lo = np.zeros_like(Cc)
    hi = Cc.copy()
    for _ in range(30):
        mid = (lo + hi) / 2
        lin = oklab_to_lin(from_lch(L, mid, h))
        ok = np.all((lin >= -1e-6) & (lin <= 1 + 1e-6), axis=-1)
        lo = np.where(ok, mid, lo)
        hi = np.where(ok, hi, mid)
    inside = np.all((oklab_to_lin(from_lch(L, Cc, h)) >= -1e-6) &
                    (oklab_to_lin(from_lch(L, Cc, h)) <= 1 + 1e-6), axis=-1)
    return np.where(inside, Cc, lo)


def derive() -> tuple[np.ndarray, dict]:
    lut = load_halide_ccube(SOURCE)
    table = lut.table                      # [b, g, r, 3], sRGB-encoded output
    n = table.shape[0]
    c = np.linspace(0.0, 1.0, n)
    bb, gg, rr = np.meshgrid(c, c, c, indexing="ij")
    enc_in = np.stack([rr, gg, bb], -1)    # Apple Log / Rec.2020 encoded node coordinates

    lin_in = applelog_inverse(enc_in) @ REC2020_TO_SRGB.T
    lch_in = to_lch(lin_to_oklab(lin_in))
    lin_out = srgb_to_linear(np.clip(table, 0, 1))
    lab_out = lin_to_oklab(lin_out)
    lch_out = to_lch(lab_out)

    dh = hue_delta(lch_out[..., 2], lch_in[..., 2])
    h = lch_in[..., 2]
    w_hue = smooth(h, GREEN_HUE[0], GREEN_HUE[1]) * (1 - smooth(h, GREEN_HUE[2], GREEN_HUE[3]))
    w = w_hue * smooth(lch_in[..., 1], *CHROMA_GATE) * smooth(np.abs(dh), *FLIP_GATE)

    L = lch_out[..., 0]
    Cc = np.minimum(lch_out[..., 1], CHROMA_CAP * lch_in[..., 1])
    hc = (lch_in[..., 2] + np.clip(dh, -MAX_HUE_STYLE, MAX_HUE_STYLE)) % 360
    lab_corr = from_lch(L, Cc, hc)
    lab_mix = lab_out * (1 - w[..., None]) + lab_corr * w[..., None]
    lch_mix = to_lch(lab_mix)
    Cclip = gamut_clip(lch_mix[..., 0], lch_mix[..., 1], lch_mix[..., 2])
    lin_new = np.clip(oklab_to_lin(from_lch(lch_mix[..., 0], Cclip, lch_mix[..., 2])), 0, 1)
    enc_new = linear_to_srgb(lin_new)

    changed = w > 0
    result = np.where(changed[..., None], enc_new, table)

    # Verification on the cube itself
    green_in = (gg > rr + 2 / (n - 1)) & (gg > bb + 2 / (n - 1))
    # "Green rendered magenta": green is the lowest output channel by a visible
    # margin. Near-black nodes (max channel < 0.06) are excluded: there the
    # channels differ by less than one 8-bit step after encoding.
    def g_lowest(t):
        return ((t[..., 1] < t[..., 0] - 0.004) & (t[..., 1] < t[..., 2] - 0.004)
                & (t.max(-1) >= 0.06))
    stats = {
        "nodes": int(n ** 3),
        "changed_nodes": int(changed.sum()),
        "green_input_nodes": int(green_in.sum()),
        "green_input_rendered_g_lowest_before": int((green_in & g_lowest(table)).sum()),
        "green_input_rendered_g_lowest_after": int((green_in & g_lowest(result)).sum()),
        "max_abs_change_outside_weight": float(np.abs(result - table)[~changed].max()),
        "gray_diagonal_max_change": float(max(np.abs(result[i, i, i] - table[i, i, i]).max() for i in range(n))),
    }
    return result, stats


def encode(table: np.ndarray) -> bytes:
    half = table.reshape(-1, 3).astype("<f2").tobytes()
    assert len(half) == 33 ** 3 * 6
    return liblzfse.compress(half)


def main() -> int:
    table, stats = derive()
    blob = encode(table)
    # Round-trip through the same decoder the app mirrors.
    decoded = np.frombuffer(liblzfse.decompress(blob), dtype="<f2").reshape(33, 33, 33, 3)
    assert np.array_equal(decoded, table.astype("<f2")), "LZFSE round trip changed data"
    for k, v in stats.items():
        print(f"  {k}: {v}")
    if stats["green_input_rendered_g_lowest_after"] != 0:
        print("FAIL: some green inputs still render with green lowest")
        return 1
    if stats["max_abs_change_outside_weight"] != 0 or stats["gray_diagonal_max_change"] != 0:
        print("FAIL: correction touched nodes outside the green band")
        return 1
    if "--check" in sys.argv:
        current = OUTPUT.read_bytes() if OUTPUT.exists() else b""
        cur = np.frombuffer(liblzfse.decompress(current), dtype="<f2") if current else None
        same = cur is not None and np.array_equal(cur, np.frombuffer(liblzfse.decompress(blob), dtype="<f2"))
        print(f"  committed output matches derivation: {same}")
        return 0 if same else 1
    OUTPUT.write_bytes(blob)
    print(f"wrote {OUTPUT.relative_to(ROOT)} ({len(blob)} bytes, sha256 {hashlib.sha256(blob).hexdigest()})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
