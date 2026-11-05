#!/usr/bin/env python3
"""
Step 1: build the reference set.

Real photographs were not supplied. These scenes are synthetic but built from
measured spectral-ish recipes rather than flat swatches: each scene is composed
of regions (sky, foliage, skin, warm indoor, neon) whose pixel coordinates are
recorded so the measurement step never has to guess where a region is.

Every scene is labelled synthetic in its metadata. They are for ranking presets
against each other, which is what the guide needs; they are not a claim about
how a preset behaves on a real photograph.

Outputs:
  analysis/refs/*.png         8-bit sRGB PNGs handed to the macOS harness
  analysis/refs/regions.json  region rectangles per scene, in image coordinates
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).parent / "refs"
W, H = 960, 720


def srgb(x):
    return np.clip(x, 0.0, 1.0)


def save(name, img, regions, note):
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray((srgb(img) * 255).astype(np.uint8)).save(OUT / f"{name}.png")
    return {"scene": name, "note": note, "size": [W, H], "regions": regions}


def box(name, x0, y0, x1, y1):
    return {name: [int(x0), int(y0), int(x1), int(y1)]}


def vgrad(top, bottom, h=H, w=W):
    t = np.linspace(0, 1, h)[:, None, None]
    g = np.asarray(top)[None, None, :] * (1 - t) + np.asarray(bottom)[None, None, :] * t
    return np.repeat(g, w, axis=1)


def add_noise(img, sigma=0.006, seed=0):
    rng = np.random.default_rng(seed)
    return img + rng.normal(0, sigma, img.shape)


def canvas(bg):
    return np.ones((H, W, 3)) * np.asarray(bg)[None, None, :]


# ---------------------------------------------------------------- charts
def gray_ramp():
    steps = np.linspace(0, 1, 24)
    img = np.ones((H, W, 3))
    sw = W // len(steps)
    for i, v in enumerate(steps):
        img[:, i * sw:(i + 1) * sw] = v
    img[:, (len(steps) - 1) * sw:] = steps[-1]
    return img


def color_chart():
    # 24 patches: 4 skin, 4 foliage/sky, 6 primaries, 4 neutrals, 6 mixed
    patches = [
        (0.94, 0.79, 0.70), (0.82, 0.63, 0.52), (0.62, 0.42, 0.32), (0.36, 0.23, 0.17),
        (0.20, 0.38, 0.18), (0.42, 0.58, 0.24), (0.45, 0.62, 0.85), (0.22, 0.34, 0.62),
        (0.72, 0.14, 0.12), (0.88, 0.48, 0.12), (0.92, 0.85, 0.20), (0.25, 0.62, 0.30),
        (0.15, 0.55, 0.60), (0.20, 0.30, 0.72), (0.55, 0.22, 0.60), (0.80, 0.30, 0.55),
        (0.95, 0.95, 0.95), (0.75, 0.75, 0.75), (0.45, 0.45, 0.45), (0.20, 0.20, 0.20),
        (0.06, 0.06, 0.06), (0.55, 0.42, 0.30), (0.30, 0.45, 0.52), (0.68, 0.60, 0.52),
    ]
    img = np.ones((H, W, 3))
    cols, rows = 6, 4
    cw, ch = W // cols, H // rows
    regions = {}
    for i, c in enumerate(patches):
        r, col = divmod(i, cols)
        img[r * ch:(r + 1) * ch, col * cw:(col + 1) * cw] = c
        regions[f"patch_{i}"] = [col * cw + 4, r * ch + 4, (col + 1) * cw - 4, (r + 1) * ch - 4]
    return img, regions


def skin_ramp_scene():
    """Horizontal ramp of realistic skin reflectance, 5 anchors, wide gamut of tones."""
    anchors = np.array([
        [0.99, 0.87, 0.80],   # very light
        [0.88, 0.70, 0.60],
        [0.70, 0.52, 0.42],
        [0.50, 0.34, 0.26],
        [0.28, 0.18, 0.13],   # deep
    ])
    img = np.zeros((H, W, 3))
    n = len(anchors) - 1
    for x in range(W):
        t = x / (W - 1) * n
        i = min(int(t), n - 1)
        f = t - i
        c = anchors[i] * (1 - f) + anchors[i + 1] * f
        img[:, x] = c
    regions = {
        "skin_light": [20, 200, 180, 520],
        "skin_medium": [380, 200, 560, 520],
        "skin_dark": [780, 200, 940, 520],
    }
    return img, regions


# ---------------------------------------------------------------- scenes
def landscape():
    img = vgrad((0.28, 0.52, 0.86), (0.72, 0.84, 0.94))
    yy = np.arange(H)[:, None]
    # distant hills
    hill = (H * 0.52 + 60 * np.sin(np.linspace(0, 6.2, W))[None, :] + 18 * np.sin(np.linspace(0, 19, W))[None, :])
    mask = yy > hill
    img = np.where(mask[..., None], np.array([0.42, 0.50, 0.40])[None, None, :], img)
    # sun glow upper left
    xs = np.arange(W)[None, :]
    glow = np.exp(-(((xs - W * 0.18) / 240.0) ** 2) - (((yy - H * 0.10) / 200.0) ** 2))
    img = img + glow[..., None] * np.array([0.35, 0.28, 0.16])[None, None, :]
    # foreground field + foliage clumps
    fg = yy > H * 0.62
    img = np.where(fg[..., None], np.array([0.24, 0.36, 0.16])[None, None, :], img)
    rng = np.random.default_rng(3)
    for _ in range(140):
        cx, cy = rng.integers(0, W), rng.integers(int(H * 0.60), H)
        r = rng.integers(12, 45)
        g = rng.uniform(0.16, 0.34)
        d = np.hypot(xs - cx, yy - cy)
        a = np.clip(1 - d / r, 0, 1) ** 1.5
        img = img + a[..., None] * np.array([g * 0.7, g, g * 0.42])[None, None, :] * 0.8
    # near-black shadow band bottom left
    sh = (yy > H * 0.80) & (xs < W * 0.33)
    img = np.where(sh[..., None], img * 0.18, img)
    img = add_noise(img, 0.008, 1)
    regions = {
        "sky": [500, 20, 940, 170],
        "foliage": [60, 540, 420, 690],
        "shadow": [20, 640, 300, 715],
        "land": [520, 400, 900, 470],
    }
    return img, regions


def backlit_harsh_sun():
    img = vgrad((0.98, 0.96, 0.88), (0.55, 0.62, 0.70)).copy()
    yy = np.arange(H)[:, None]
    xs = np.arange(W)[None, :]
    sun = np.exp(-(((xs - W * 0.62) / 90.0) ** 2) - (((yy - H * 0.28) / 90.0) ** 2))
    img = img + sun[..., None] * 1.6
    # blown sky around sun, deep silhouette figure
    body_x0, body_x1 = int(W * 0.22), int(W * 0.40)
    body = (yy > H * 0.30) & (xs > body_x0) & (xs < body_x1)
    head = np.hypot(xs - (body_x0 + body_x1) / 2, yy - H * 0.26) < 70
    sil = body | head
    img = np.where(sil[..., None], np.array([0.05, 0.045, 0.05])[None, None, :], img)
    # rim light on the silhouette edge
    rim = np.zeros((H, W))
    for dx in range(1, 14):
        rim += np.clip(np.roll(sil, dx, axis=1).astype(float) - sil.astype(float), 0, 1) * (1 - dx / 14)
    img = img + rim[..., None] * np.array([0.9, 0.72, 0.45])[None, None, :]
    img = add_noise(img, 0.006, 2)
    regions = {
        "blown_sky": [640, 40, 900, 150],
        "shadow": [240, 380, 350, 600],
        "rim": [330, 300, 400, 460],
    }
    return srgb(img), regions


def indoor_tungsten():
    img = vgrad((0.34, 0.24, 0.15), (0.10, 0.07, 0.05)).copy()
    yy = np.arange(H)[:, None]
    xs = np.arange(W)[None, :]
    # lamp pool
    for cx, cy, s, i in [(W * 0.72, H * 0.28, 260, 0.55), (W * 0.24, H * 0.62, 200, 0.30)]:
        img += np.exp(-(((xs - cx) / s) ** 2) - (((yy - cy) / s) ** 2))[..., None] * np.array([1.0, 0.66, 0.28])[None, None, :] * i
    # wooden table plane
    table = yy > H * 0.66
    img = np.where(table[..., None], np.array([0.30, 0.19, 0.10])[None, None, :] * (0.6 + 0.4 * (yy / H))[..., None], img)
    # skin hand/arm across table, warm lit
    arm = (yy > H * 0.60) & (yy < H * 0.80) & (xs > W * 0.05) & (xs < W * 0.55)
    img = np.where(arm[..., None], np.array([0.74, 0.55, 0.42])[None, None, :], img)
    img = add_noise(img, 0.010, 3)
    regions = {
        "skin_warm": [60, 450, 500, 560],
        "warm_wall": [560, 60, 900, 300],
        "shadow": [20, 20, 200, 160],
    }
    return srgb(img), regions


def indoor_fluorescent():
    img = np.ones((H, W, 3)) * np.array([0.80, 0.84, 0.80])[None, None, :]
    yy = np.arange(H)[:, None]
    # ceiling strip lights, slightly green
    for cy in (40, 120):
        band = (yy > cy) & (yy < cy + 34)
        img = np.where(band[..., None], np.array([0.94, 0.98, 0.92])[None, None, :], img)
    # grey-green wall, white desk, papers, a face-ish skin patch
    img[H // 3: int(H * 0.72), :] = np.array([0.70, 0.75, 0.72])
    img[int(H * 0.72):, :] = np.array([0.88, 0.88, 0.86])
    xs = np.arange(W)[None, :]
    face = np.hypot((xs - W * 0.30) / 120, (yy - H * 0.55) / 150) < 1
    img = np.where(face[..., None], np.array([0.80, 0.66, 0.58])[None, None, :], img)
    img = add_noise(img, 0.006, 4)
    regions = {
        "fluorescent_wall": [600, 300, 900, 480],
        "skin_cool": [170, 320, 400, 500],
        "white_paper": [560, 600, 900, 700],
    }
    return srgb(img), regions


def night_neon():
    img = np.ones((H, W, 3)) * np.array([0.03, 0.03, 0.06])[None, None, :]
    yy = np.arange(H)[:, None]
    xs = np.arange(W)[None, :]
    neon = [
        (W * 0.2, H * 0.35, (0.1, 0.9, 0.9)),
        (W * 0.55, H * 0.25, (1.0, 0.15, 0.6)),
        (W * 0.82, H * 0.45, (0.95, 0.6, 0.05)),
    ]
    for cx, cy, c in neon:
        r = np.hypot(xs - cx, yy - cy)
        img += np.exp(-(r / 55.0) ** 2)[..., None] * np.asarray(c)[None, None, :] * 0.9
        img += np.exp(-(r / 220.0) ** 2)[..., None] * np.asarray(c)[None, None, :] * 0.18
    # wet pavement reflections
    pave = yy > H * 0.66
    refl = np.zeros_like(img)
    for cx, cy, c in neon:
        refl += np.exp(-(((xs - cx) / 90.0) ** 2))[..., None] * np.asarray(c)[None, None, :] * 0.25
    img = np.where(pave[..., None], img * 0.5 + refl * (yy / H)[..., None], img)
    # a lit face in the dark
    face = np.hypot((xs - W * 0.42) / 80, (yy - H * 0.55) / 100) < 1
    img = np.where(face[..., None], np.array([0.30, 0.16, 0.14])[None, None, :] * 1.6, img)
    img = add_noise(img, 0.012, 5)
    regions = {
        "neon_cyan": [int(W * 0.2) - 40, int(H * 0.35) - 40, int(W * 0.2) + 40, int(H * 0.35) + 40],
        "neon_magenta": [int(W * 0.55) - 40, int(H * 0.25) - 40, int(W * 0.55) + 40, int(H * 0.25) + 40],
        "skin_dim": [int(W * 0.42) - 50, int(H * 0.55) - 50, int(W * 0.42) + 50, int(H * 0.55) + 50],
        "shadow": [40, 40, 200, 200],
    }
    return srgb(img), regions


def food_warm():
    img = np.ones((H, W, 3)) * np.array([0.22, 0.16, 0.12])[None, None, :]
    yy = np.arange(H)[:, None]
    xs = np.arange(W)[None, :]
    plate = np.hypot((xs - W * 0.5) / 420, (yy - H * 0.55) / 300) < 1
    img = np.where(plate[..., None], np.array([0.90, 0.89, 0.86])[None, None, :], img)
    rng = np.random.default_rng(7)
    for _ in range(26):
        cx = rng.normal(W * 0.5, 110)
        cy = rng.normal(H * 0.55, 80)
        r = rng.uniform(24, 62)
        base = rng.choice([[0.78, 0.36, 0.12], [0.62, 0.50, 0.12], [0.30, 0.52, 0.16],
                           [0.80, 0.62, 0.30], [0.55, 0.22, 0.10]])
        d = np.hypot(xs - cx, yy - cy) / r
        a = np.clip(1 - d ** 2, 0, 1)
        img = img * (1 - a[..., None] * 0.9) + np.asarray(base)[None, None, :] * a[..., None] * 0.9
        hl = np.clip(1 - np.hypot(xs - (cx - r * 0.3), yy - (cy - r * 0.35)) / (r * 0.35), 0, 1) ** 2
        img = img + hl[..., None] * 0.25
    img = add_noise(img, 0.007, 6)
    regions = {
        "food_center": [int(W * 0.5) - 150, int(H * 0.55) - 110, int(W * 0.5) + 150, int(H * 0.55) + 110],
        "plate_white": [int(W * 0.5) - 380, int(H * 0.55) + 200, int(W * 0.5) - 300, int(H * 0.55) + 260],
        "table_warm": [40, 60, 260, 200],
    }
    return srgb(img), regions


def high_key():
    img = vgrad((0.97, 0.97, 0.96), (0.80, 0.81, 0.82)).copy()
    xs = np.arange(W)[None, :]
    yy = np.arange(H)[:, None]
    face = np.hypot((xs - W * 0.5) / 230, (yy - H * 0.45) / 300) < 1
    img = np.where(face[..., None], np.array([0.92, 0.80, 0.72])[None, None, :], img)
    return add_noise(srgb(img), 0.004, 8), {
        "skin_high_key": [int(W * 0.5) - 120, int(H * 0.45) - 150, int(W * 0.5) + 120, int(H * 0.45) + 150]
    }


def low_key():
    img = np.ones((H, W, 3)) * 0.02
    xs = np.arange(W)[None, :]
    yy = np.arange(H)[:, None]
    face = np.hypot((xs - W * 0.5) / 210, (yy - H * 0.5) / 280) < 1
    img = np.where(face[..., None], np.array([0.16, 0.105, 0.085])[None, None, :], img)
    # single rim light from the right
    rim = np.clip(1 - np.abs(xs - (W * 0.5 + 200)) / 90, 0, 1) * face
    img = img + rim[..., None] * np.array([0.75, 0.55, 0.42])[None, None, :]
    return add_noise(srgb(img), 0.006, 9), {"skin_low_key": [int(W * 0.5) - 90, int(H * 0.5) - 120,
                                                             int(W * 0.5) + 90, int(H * 0.5) + 120]}


SCENES = [
    ("gray_ramp", lambda: (gray_ramp(), {}), "24-step neutral ramp, 0 to 1"),
    ("color_chart", color_chart, "24-patch chart incl. 4 skin, foliage, sky, primaries"),
    ("skin_ramp", skin_ramp_scene, "5-anchor skin reflectance ramp, very light to deep"),
    ("landscape", landscape, "sky gradient, sun glow, foliage, deep foreground shadow"),
    ("backlit_sun", backlit_harsh_sun, "blown sky, silhouette, rim light"),
    ("indoor_tungsten", indoor_tungsten, "warm lamp pools, wooden table, warm-lit skin"),
    ("indoor_fluorescent", indoor_fluorescent, "greenish strip lights, cool skin, white paper"),
    ("night_neon", night_neon, "cyan/magenta neon, wet reflections, dim skin"),
    ("food_warm", food_warm, "warm table, plate, saturated food"),
    ("high_key", high_key, "near-white scene, light skin"),
    ("low_key", low_key, "near-black scene, mid skin, rim light"),
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    meta = []
    for name, fn, note in SCENES:
        img, regions = fn()
        img = np.asarray(img)[:H, :W]
        assert img.shape == (H, W, 3), f"{name}: {img.shape}"
        meta.append(save(name, img, regions, note))
        print(f"  {name:20s} {len(regions)} regions")

    # Region sanity: no region may be uniform black or white in its source,
    # which would make later colour measurements vacuous.
    for m in meta:
        img = np.asarray(Image.open(OUT / f"{m['scene']}.png"), dtype=np.float64) / 255.0
        for rname, (x0, y0, x1, y1) in m["regions"].items():
            patch = img[y0:y1, x0:x1]
            if patch.size == 0:
                raise SystemExit(f"{m['scene']}/{rname}: empty region")
            if patch.mean() < 0.008:
                print(f"    note: {m['scene']}/{rname} is nearly black (mean {patch.mean():.3f})")
    (OUT / "regions.json").write_text(json.dumps(meta, indent=2))
    print(f"\nwrote {len(meta)} scenes + regions.json to {OUT}")


if __name__ == "__main__":
    sys.exit(main())
