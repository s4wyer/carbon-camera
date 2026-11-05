"""
Core library for Carbon preset analysis: LUT file IO, trilinear sampling,
and sRGB / OKLab / OKLCH colour math.

This module does NOT render presets. Rendering is done by Carbon's production
PhotoRenderer on macOS (analysis/harness), because several shared stages
(CIHighlightShadowAdjust shoulder, CIBloom+screen halation, CIRandomGenerator
grain) are Core Image filters that cannot be reproduced exactly here.

LUT sampling here is used for tooling validation (validate.py) and for
cross-checking harness output, not as a substitute for the app's render.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

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
# LUT stage (cross-check only)
# ----------------------------------------------------------------------------

def apply_lut_mix(rgb: np.ndarray, lut: Optional["LUT"], intensity: float) -> np.ndarray:
    """Cube lookup on sRGB-encoded values, then linear mix back to input."""
    if lut is None or intensity <= 0.0:
        return rgb
    out = lut.sample(rgb)
    k = float(intensity)
    return rgb * (1.0 - k) + out * k
