"""
Core library for Carbon preset analysis.

Scope note (read this first)
----------------------------
PhotoRenderer.applyToneChain runs, in order: exposure, temp/tint, highlight
shoulder (unconditional, CIHighlightShadowAdjust 0.9), halation, bloom, LUT,
contrast/saturation, curve, vibrance, HSL, vignette, grain.

For the 34 catalog presets, every one of those stages except the LUT stage is
*identical across presets* or uses neutral parameters:

  * exposure 0, temp/tint 0, contrast 1, saturation 1, vibrance 0,
    all 5 curve points 0, all 8 HSL channels neutral  -> no-op
  * halation radius 4 / intensity 1.0 for 33 presets (Natural: 0.3)
  * bloom 0 for all but Natural (0.0 radius 10)      -> no-op
  * vignette 0 for all                               -> no-op
  * grain 0 for all but Natural (0.4)                -> texture only
  * strength is never read by PhotoRenderer          -> inert

So preset-to-preset *color and tone* differences come from the LUT stage and
its `lutIntensity` mix. That stage is exactly reproducible:

    out = in*(1-k) + lut(in)*k        (CIColorCubeWithColorSpace + CIDissolveTransition)

Everything else is either a shared constant (cannot change rankings between
presets) or a texture effect (grain/bloom), which this library reports from
parameters rather than pretending to reproduce Core Image's private kernels.

The Lapse presets are the exception: their reference pipeline is a parameterised
factory (Lapse §5), not a single cube. `render_lapse_*` below implements the
documented stages that are reproducible in numpy, and `LAPSE_LIMITS` names the
stages that are not.
"""
from __future__ import annotations

import json
import struct
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Dict, Optional, Sequence, Tuple

import numpy as np

try:
    import liblzfse
except ImportError as exc:  # pragma: no cover
    raise ImportError("pyliblzfse is required: python -m pip install pyliblzfse") from exc


# ----------------------------------------------------------------------------
# Color science
# ----------------------------------------------------------------------------

def srgb_to_linear(x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, dtype=np.float64)
    return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, dtype=np.float64)
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * x ** (1 / 2.4) - 0.055)


# Rec.709 / sRGB luminance weights
LUMA_W = np.array([0.2126, 0.7152, 0.0722])


def rel_luminance(rgb_srgb: np.ndarray) -> np.ndarray:
    """Relative luminance from gamma-encoded sRGB values."""
    lin = srgb_to_linear(rgb_srgb)
    return lin @ LUMA_W


def rgb_to_oklab(rgb_srgb: np.ndarray) -> np.ndarray:
    """sRGB (gamma encoded, 0..1) -> OKLab (L, a, b). Vectorised over last axis."""
    rgb = np.clip(np.asarray(rgb_srgb, dtype=np.float64), 0.0, 1.0)
    lin = srgb_to_linear(rgb)

    m1 = np.array([
        [0.4122214708, 0.5363325363, 0.0514459929],
        [0.2119034982, 0.6806995451, 0.1073969566],
        [0.0883024619, 0.2817188376, 0.6299787005],
    ])
    m2 = np.array([
        [0.2104542553, 0.7936177850, -0.0040720468],
        [1.9779984951, -2.4285922050, 0.4505937099],
        [0.0259040371, 0.7827717662, -0.8086757660],
    ])
    lms = lin @ m1.T
    lms = np.cbrt(lms)
    return lms @ m2.T


def oklab_to_rgb(lab: np.ndarray) -> np.ndarray:
    lab = np.asarray(lab, dtype=np.float64)
    m2_inv = np.linalg.inv(np.array([
        [0.2104542553, 0.7936177850, -0.0040720468],
        [1.9779984951, -2.4285922050, 0.4505937099],
        [0.0259040371, 0.7827717662, -0.8086757660],
    ]))
    m1_inv = np.linalg.inv(np.array([
        [0.4122214708, 0.5363325363, 0.0514459929],
        [0.2119034982, 0.6806995451, 0.1073969566],
        [0.0883024619, 0.2817188376, 0.6299787005],
    ]))
    lms = (lab @ m2_inv.T) ** 3
    lin = lms @ m1_inv.T
    return linear_to_srgb(lin)


def oklch(rgb_srgb: np.ndarray) -> np.ndarray:
    """OKLab -> OKLCH: (L, C, h_degrees). Chroma is 0 where the colour is neutral."""
    lab = rgb_to_oklab(rgb_srgb)
    L = lab[..., 0]
    a = lab[..., 1]
    b = lab[..., 2]
    C = np.hypot(a, b)
    h = np.degrees(np.arctan2(b, a)) % 360.0
    return np.stack([L, C, h], axis=-1)


def hue_delta(h_out: np.ndarray, h_in: np.ndarray) -> np.ndarray:
    """Signed shortest-arc hue difference in degrees, range (-180, 180]."""
    d = (np.asarray(h_out) - np.asarray(h_in) + 180.0) % 360.0 - 180.0
    return d


# ----------------------------------------------------------------------------
# LUTs
# ----------------------------------------------------------------------------

@dataclass
class LUT:
    """A 3D LUT held as a (dim, dim, dim, 3) array indexed [b, g, r] (red fastest)."""
    table: np.ndarray
    name: str
    source: str = ""
    color_space: str = "srgb"
    encoding: str = "srgb-gamma"

    @property
    def dimension(self) -> int:
        return self.table.shape[0]

    def sample(self, rgb: np.ndarray) -> np.ndarray:
        """
        Trilinear sample for an (N, 3) array of gamma-encoded values in 0..1.

        Index is clamped before the fraction is computed, so a channel of exactly
        1.0 lands on the last node (the bug in the discarded first probe).
        """
        rgb = np.clip(np.asarray(rgb, dtype=np.float64), 0.0, 1.0)
        n = self.dimension
        f = rgb * (n - 1)
        i0 = np.minimum(np.floor(f).astype(np.int64), n - 2)
        t = f - i0
        i1 = i0 + 1

        r0, g0, b0 = i0[:, 0], i0[:, 1], i0[:, 2]
        r1, g1, b1 = i1[:, 0], i1[:, 1], i1[:, 2]
        tr, tg, tb = t[:, 0:1], t[:, 1:2], t[:, 2:3]
        T = self.table

        c000 = T[b0, g0, r0]
        c001 = T[b0, g0, r1]
        c010 = T[b0, g1, r0]
        c011 = T[b0, g1, r1]
        c100 = T[b1, g0, r0]
        c101 = T[b1, g0, r1]
        c110 = T[b1, g1, r0]
        c111 = T[b1, g1, r1]

        c00 = c000 + (c001 - c000) * tr
        c01 = c010 + (c011 - c010) * tr
        c10 = c100 + (c101 - c100) * tr
        c11 = c110 + (c111 - c110) * tr
        c0 = c00 + (c01 - c00) * tg
        c1 = c10 + (c11 - c10) * tg
        return c0 + (c1 - c0) * tb


def load_halide_ccube(path: Path) -> LUT:
    """Halide .ccube: LZFSE-compressed 33^3 half-float RGB, alpha appended as 1.0."""
    raw = liblzfse.decompress(path.read_bytes())
    expected = 33 ** 3 * 6
    if len(raw) != expected:
        raise ValueError(f"{path.name}: decompressed {len(raw)} bytes, expected {expected}")
    rgb = np.frombuffer(raw, dtype="<f2").astype(np.float64).reshape(-1, 3)
    # File order is red-fastest: index = b*n^2 + g*n + r.
    table = rgb.reshape(33, 33, 33, 3)  # [b, g, r]
    return LUT(table=table, name=path.stem, source=str(path), color_space="srgb",
               encoding="srgb-gamma")


def load_nofusion_lutbin(path: Path) -> LUT:
    """No Fusion .lutbin: raw little-endian float32 RGBA, extent from file size."""
    raw = path.read_bytes()
    n_cubed = len(raw) // 16
    n = round(n_cubed ** (1 / 3))
    if n ** 3 * 16 != len(raw):
        raise ValueError(f"{path.name}: {len(raw)} bytes is not n^3*16")
    arr = np.frombuffer(raw, dtype="<f4").astype(np.float64).reshape(-1, 4)
    if not np.allclose(arr[:, 3], 1.0):
        raise ValueError(f"{path.name}: alpha channel is not 1.0")
    table = arr[:, :3].reshape(n, n, n, 3)
    return LUT(table=table, name=path.stem, source=str(path), color_space="srgb",
               encoding="srgb-gamma")


def load_lapse_cube(path: Path) -> LUT:
    """Lapse V4 .cube: 'LUT_3D_SIZE 33' then R-fastest float triples."""
    lines = [ln.strip() for ln in path.read_text().splitlines()]
    size = None
    vals = []
    for ln in lines:
        if not ln or ln.startswith("#"):
            continue
        if ln.upper().startswith("LUT_3D_SIZE"):
            size = int(ln.split()[-1])
            continue
        if ln.upper().startswith(("TITLE", "DOMAIN_MIN", "DOMAIN_MAX")):
            continue
        parts = ln.split()
        if len(parts) == 3:
            vals.append([float(p) for p in parts])
    if size is None:
        raise ValueError(f"{path.name}: no LUT_3D_SIZE")
    arr = np.array(vals, dtype=np.float64)
    if arr.shape[0] != size ** 3:
        raise ValueError(f"{path.name}: {arr.shape[0]} rows, expected {size ** 3}")
    table = arr.reshape(size, size, size, 3)  # red fastest -> [b, g, r]
    return LUT(table=table, name=path.stem, source=str(path), color_space="srgb",
               encoding="srgb-gamma")


def identity_lut(n: int = 33) -> LUT:
    coords = np.linspace(0.0, 1.0, n)
    b, g, r = np.meshgrid(coords, coords, coords, indexing="ij")
    return LUT(table=np.stack([r, g, b], axis=-1), name="identity")


# ----------------------------------------------------------------------------
# Presets
# ----------------------------------------------------------------------------

@dataclass
class Preset:
    key: str                 # catalog presetID, e.g. "nofusion-h2"
    display: str             # user-facing name only, e.g. "Portra 400"
    family: str              # carbon | halide | nofusion | lapse
    render: str              # lut-mix | lapse-journal | lapse-photo | procedural
    lut_path: Optional[Path] = None
    lut_intensity: float = 1.0
    grain_amount: float = 0.0
    bloom_amount: float = 0.0
    vignette_intensity: float = 0.0
    extra: Dict[str, float] = field(default_factory=dict)


# ----------------------------------------------------------------------------
# Render
# ----------------------------------------------------------------------------

def apply_lut_mix(rgb: np.ndarray, lut: Optional[LUT], intensity: float) -> np.ndarray:
    """Carbon's LUT stage: CIColorCubeWithColorSpace then dissolve back to input."""
    if lut is None or intensity <= 0.0:
        return rgb
    out = lut.sample(rgb)
    k = float(intensity)
    return rgb * (1.0 - k) + out * k


def lapse_journal_render(rgb: np.ndarray, lut: LUT, scene_ev: float = 8.0) -> np.ndarray:
    """
    Cached CI journal recipe (lapse-camera-settings.md §5), restricted to stages
    that are reproducible without Core Image's private filters.

    Modelled: LUT (opacity 1) -> Gamma (0.9) -> Exposure (ev0 + sceneEV*(ev10-ev0)/10)
              -> Vibrance (0.4) -> HighlightShadow (0.95 / 0.15, modelled)
    Not modelled (see LAPSE_LIMITS): halation, FaceBalance, SkinToneTwo, vignette,
    transverse chromatic aberration, global blur, final blur, dynamic film grain.
    """
    out = lut.sample(rgb)
    # Gamma: CIGammaAdjust selects `power`; CI applies pow(input, power).
    out = np.clip(out, 0.0, 1.0) ** 0.9
    # Exposure: CIExposureAdjust, ev0=0.55, ev10=0.50, no clamp observed.
    ev = 0.55 + scene_ev * (0.50 - 0.55) / 10.0
    out = out * (2.0 ** ev)
    # Vibrance: CIVibrance level 0.4, then ColorControls saturation 1 (no-op).
    out = _vibrance(out, 0.4)
    # HighlightShadow: highlight_amount 0.95, shadow_amount 0.15 (modelled).
    out = _highlight_shadow(out, highlight=0.95, shadow=0.15)
    return np.clip(out, 0.0, 1.0)


def lapse_photo_render(rgb: np.ndarray, lut: LUT, lut_intensity: float = 0.75) -> np.ndarray:
    """
    Standard Metal `photo_default` (lapse-camera-settings.md §7), restricted to
    reproducible stages: LUT@0.75 -> masked adjustments (contrast -0.25,
    saturation -0.7, vibrance 0.95, highlights -0.4/shadow -0.45) -> vignette
    (intensity 0.9, radius 0.95) -> grain (reported, not rendered).

    Masked adjustments in the real pipeline interpolate parameters by a mask
    before the adjustment; here they are applied globally, which is the
    unmasked endpoint. Documented limitation.
    """
    out = apply_lut_mix(rgb, lut, lut_intensity)
    # Classic adjustment set (unmasked values).
    out = _contrast_saturation(out, contrast=1.0 - 0.25, saturation=1.0 - 0.7)
    out = _vibrance(out, 0.95)
    out = _highlight_shadow(out, highlight=1.0 - 0.4, shadow=0.0 + (-0.45))
    return np.clip(out, 0.0, 1.0)


def _contrast_saturation(rgb: np.ndarray, contrast: float, saturation: float) -> np.ndarray:
    """CIColorControls: contrast pivots around 0.5 in the working space."""
    out = (rgb - 0.5) * contrast + 0.5
    luma = out @ LUMA_W
    return np.clip(luma[..., None] + (out - luma[..., None]) * saturation, 0.0, 1.0)


def _vibrance(rgb: np.ndarray, amount: float) -> np.ndarray:
    """CIVibrance approximation: boost weighted by (1 - existing saturation)."""
    luma = rgb @ LUMA_W
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    sat = np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    boost = 1.0 + amount * (1.0 - sat)
    return np.clip(luma[..., None] + (rgb - luma[..., None]) * boost[..., None], 0.0, 1.0)


def _highlight_shadow(rgb: np.ndarray, highlight: float, shadow: float) -> np.ndarray:
    """
    Model of CIHighlightShadowAdjust. 1.0 = no highlight change, 0.0 = maximum
    recovery; shadow is an additive lift. This is a documented approximation, not
    Core Image's private curve. Sensitivity to it is measured in validate.py.
    """
    luma = rgb @ LUMA_W
    # Highlight recovery: compress the top end proportional to (1 - amount).
    k = 1.0 - np.clip(highlight, 0.0, 1.0)
    if k > 0:
        t = 0.55
        over = np.clip((luma - t) / (1.0 - t), 0.0, 1.0)
        scale = (1.0 - k * over ** 1.5) / np.maximum(luma, 1e-6)
        scale = np.where(luma > 1e-6, scale, 1.0)
        rgb = rgb * scale[..., None]
    if abs(shadow) > 0:
        lift = shadow * 0.25 * (1.0 - np.clip(luma, 0.0, 1.0)) ** 2
        rgb = rgb + lift[..., None]
    return np.clip(rgb, 0.0, 1.0)


LAPSE_LIMITS = {
    "journal": [
        "halation", "FaceBalance", "SkinToneTwo", "vignette (radius .15 / intensity 1.75)",
        "transverse chromatic aberration", "global blur", "final blur radius .3",
        "dynamic film grain",
    ],
    "photo": [
        "halation", "adaptive shadows", "color overlay", "chromatic aberration",
        "global blur", "final blur", "grain", "masked (per-mask) adjustment interpolation",
    ],
}


def render(preset: Preset, rgb: np.ndarray, lut_cache: Dict[str, LUT],
           scene_ev: float = 8.0) -> np.ndarray:
    """Render an (N, 3) array of sRGB values through one preset."""
    if preset.render in ("lut-mix", "procedural"):
        if preset.lut_path is None:
            return np.asarray(rgb, dtype=np.float64)
        lut = _get_lut(preset.lut_path, lut_cache)
        return apply_lut_mix(rgb, lut, preset.lut_intensity)
    if preset.render == "lapse-journal":
        return lapse_journal_render(rgb, _get_lut(preset.lut_path, lut_cache), scene_ev)
    if preset.render == "lapse-photo":
        return lapse_photo_render(rgb, _get_lut(preset.lut_path, lut_cache),
                                  preset.lut_intensity)
    raise ValueError(f"unknown render mode {preset.render}")


def _get_lut(path: Path, cache: Dict[str, LUT]) -> LUT:
    key = str(path)
    if key not in cache:
        if path.suffix == ".ccube":
            cache[key] = load_halide_ccube(path)
        elif path.suffix == ".lutbin":
            cache[key] = load_nofusion_lutbin(path)
        elif path.suffix == ".cube":
            cache[key] = load_lapse_cube(path)
        else:
            raise ValueError(f"unknown LUT extension {path.suffix}")
    return cache[key]
