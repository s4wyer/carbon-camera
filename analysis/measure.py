#!/usr/bin/env python3
"""
Step 2: measure every rendered preset.

Input
  analysis/refs/*.png, analysis/refs/regions.json      (generate_scenes.py)
  analysis/renders/<preset_id>/<scene>.png             (CI artifact "preset-renders")
  analysis/renders/manifest.json

Output
  analysis/.cache/metrics.json   raw metrics keyed by preset id; rate.py embeds
                                 it in presets.json["internal"]["metrics"].

All colour measurements are in OKLab / OKLCH computed from sRGB-encoded PNGs.
Luminance is relative (linear) luminance; "L" is OKLab lightness.
No number here is typed by hand: everything is computed from the PNGs.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from lutlib import hue_delta, linear_to_srgb, oklch, rel_luminance, rgb_to_oklab  # noqa: E402

HERE = Path(__file__).parent
REFS = HERE / "refs"
RENDERS = HERE / "renders"
OUT = HERE / ".cache" / "metrics.json"

# Measurement constants (not rating thresholds; those live in rate.py)
GRAY_POINTS = [0, 2, 5, 10, 18, 30, 50, 70, 90, 95, 100]   # percent input
CHROMA_FLOOR = 0.02        # OKLCH C below this: hue is not meaningful
BLACK_CLIP = 0.5 / 255     # pixel channel max below this is "crushed"
WHITE_CLIP = 254.5 / 255   # pixel channel min above this is "clipped"
DETAIL_SHADOW = (0.0, 0.25)   # input OKLab L band for shadow detail
DETAIL_HIGHLIGHT = (0.80, 1.0)


def load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0


def crop(img, rect):
    x0, y0, x1, y1 = rect
    return img[y0:y1, x0:x1].reshape(-1, 3)


# ------------------------------------------------------------------ tone
def tone_response(outs: dict[str, np.ndarray]) -> dict:
    """
    Read output from the centre of uniform flat-field frames. This isolates the
    preset's tone curve from vignette falloff, blur at the edges, and noise.
    Input levels are linear relative luminance in percent (FLAT_LEVELS).
    """
    pts = [0, 2, 5, 10, 18, 30, 50, 70, 90, 95, 100]
    c_slice = (slice(720 // 2 - 32, 720 // 2 + 32), slice(960 // 2 - 32, 960 // 2 + 32))
    centres = np.array([outs[f"flat_{p:03d}"][c_slice].reshape(-1, 3).mean(0) for p in pts])
    lum_o = rel_luminance(centres)
    lab_o = rgb_to_oklab(centres)
    lin_i = np.array(pts) / 100.0
    lab_i = rgb_to_oklab(linear_to_srgb(np.repeat(lin_i[:, None], 3, 1)))[:, 0]   # rgb_to_oklab takes sRGB-encoded
    # Midtone slope: dL_out / dL_in across the 18..70 % linear band.
    mid = (lin_i >= 0.18) & (lin_i <= 0.70)
    slope = float(np.polyfit(lab_i[mid], lab_o[mid, 0], 1)[0])
    # White balance on the neutral flat fields (30..90 % linear).
    wb_sel = (lin_i >= 0.30) & (lin_i <= 0.90)
    a = float(lab_o[wb_sel, 1].mean())
    b = float(lab_o[wb_sel, 2].mean())
    open_at = float(np.interp(0.01, lum_o, lin_i)) if lum_o.max() > 0.01 else None
    return {
        "input_linear_pct": pts,
        "out_luminance": lum_o.round(4).tolist(),
        "out_L": lab_o[:, 0].round(4).tolist(),
        "in_L": lab_i.round(4).tolist(),
        "black_L": round(float(lab_o[0, 0]), 4),
        "white_L": round(float(lab_o[-1, 0]), 4),
        "mid_L_shift": round(float(lab_o[4, 0] - lab_i[4]), 4),    # 18 % level
        "midtone_slope": round(slope, 3),
        "shadows_open_at_linear_input": None if open_at is None else round(open_at, 3),
        "wb_a": round(a, 4), "wb_b": round(b, 4),
        "monotonic": bool(np.all(np.diff(lab_o[:, 0]) >= -0.002)),
        "flat_steps": int(np.sum(np.abs(np.diff(lab_o[:, 0])) < 0.002)),
    }

def clipping(out: np.ndarray) -> dict:
    mx = out.max(-1)
    mn = out.min(-1)
    return {"crushed_pct": round(100 * float((mx < BLACK_CLIP).mean()), 2),
            "clipped_pct": round(100 * float((mn > WHITE_CLIP).mean()), 2)}


def spread(src: np.ndarray, out: np.ndarray) -> dict:
    li = rgb_to_oklab(src.reshape(-1, 3))[:, 0]
    lo = rgb_to_oklab(out.reshape(-1, 3))[:, 0]
    si = np.percentile(li, 95) - np.percentile(li, 5)
    so = np.percentile(lo, 95) - np.percentile(lo, 5)
    return {"p5_p95_in": round(float(si), 4), "p5_p95_out": round(float(so), 4),
            "spread_ratio": round(float(so / si), 3) if si > 1e-3 else None,
            "mean_L_in": round(float(li.mean()), 4), "mean_L_out": round(float(lo.mean()), 4)}


def local_detail(src: np.ndarray, out: np.ndarray, band) -> float | None:
    """
    Ratio of local contrast (std of L in 9x9 tiles) surviving in a given input
    L band. 1.0 = preserved, 0 = flattened (crushed or clipped).
    """
    Li = rgb_to_oklab(src)[..., 0]
    Lo = rgb_to_oklab(out)[..., 0]
    t = 9
    h, w = Li.shape
    h, w = h - h % t, w - w % t
    ti = Li[:h, :w].reshape(h // t, t, w // t, t).transpose(0, 2, 1, 3).reshape(-1, t * t)
    to = Lo[:h, :w].reshape(h // t, t, w // t, t).transpose(0, 2, 1, 3).reshape(-1, t * t)
    m = ti.mean(1)
    sel = (m >= band[0]) & (m < band[1]) & (ti.std(1) > 0.004)
    if sel.sum() < 20:
        return None
    return round(float(np.median(to[sel].std(1) / ti[sel].std(1))), 3)


# ------------------------------------------------------------------ colour
def region_color(src_px: np.ndarray, out_px: np.ndarray) -> dict:
    ci = oklch(src_px)
    co = oklch(out_px)
    Ci, Co = ci[:, 1].mean(), co[:, 1].mean()
    valid = (ci[:, 1] > CHROMA_FLOOR) & (co[:, 1] > CHROMA_FLOOR)
    dh = float(np.median(hue_delta(co[valid, 2], ci[valid, 2]))) if valid.mean() > 0.5 else None
    lab_o = rgb_to_oklab(out_px).mean(0)
    hue_out = float(np.degrees(np.arctan2(lab_o[2], lab_o[1])) % 360)
    return {
        "L_in": round(float(ci[:, 0].mean()), 4), "L_out": round(float(co[:, 0].mean()), 4),
        "C_in": round(float(Ci), 4), "C_out": round(float(Co), 4),
        "chroma_ratio": round(float(Co / Ci), 3) if Ci > CHROMA_FLOOR else None,
        "hue_in": round(float(np.degrees(np.arctan2(*rgb_to_oklab(src_px).mean(0)[[2, 1]])) % 360), 1),
        "hue_out": round(hue_out, 1) if np.hypot(lab_o[1], lab_o[2]) > CHROMA_FLOOR else None,
        "hue_shift": None if dh is None else round(dh, 1),
        "lum_in": round(float(rel_luminance(src_px).mean()), 4),
        "lum_out": round(float(rel_luminance(out_px).mean()), 4),
    }


def chart_chroma(src: np.ndarray, out: np.ndarray, regions: dict) -> dict:
    """Chroma ratio over all chromatic patches, never skipping desaturated ones."""
    ci, co = [], []
    for rect in regions.values():
        a = oklch(crop(src, rect)).mean(0)
        b = oklch(crop(out, rect)).mean(0)
        if a[1] > CHROMA_FLOOR:
            ci.append(a[1])
            co.append(b[1])
    ci, co = np.array(ci), np.array(co)
    return {"chroma_ratio_mean": round(float((co / ci).mean()), 3),
            "chroma_ratio_min": round(float((co / ci).min()), 3),
            "chroma_ratio_max": round(float((co / ci).max()), 3),
            "patches": int(len(ci))}


def monochrome_class(outs: list[np.ndarray]) -> dict:
    px = np.concatenate([o.reshape(-1, 3)[::17] for o in outs])
    lab = rgb_to_oklab(px)
    C = np.hypot(lab[:, 1], lab[:, 2])
    p99 = float(np.percentile(C, 99))
    mean_hue = float(np.degrees(np.arctan2(lab[:, 2].mean(), lab[:, 1].mean())) % 360)
    tint = float(np.hypot(lab[:, 1].mean(), lab[:, 2].mean()))
    if p99 < 0.012:
        kind = "monochrome"
    elif p99 < 0.05 and float(np.std(np.degrees(np.arctan2(lab[C > 0.005, 2], lab[C > 0.005, 1])))) < 30:
        kind = "tinted_monochrome"
    else:
        kind = "color"
    return {"kind": kind, "chroma_p99": round(p99, 4), "tint_C": round(tint, 4),
            "tint_hue": round(mean_hue, 1)}


# ------------------------------------------------------------------ skin
SKIN_REGIONS = [("skin_ramp", "skin_light"), ("skin_ramp", "skin_medium"), ("skin_ramp", "skin_dark"),
                ("indoor_tungsten", "skin_warm"), ("indoor_fluorescent", "skin_cool"),
                ("night_neon", "skin_dim"), ("high_key", "skin_high_key"), ("low_key", "skin_low_key")]


def skin_flags(r: dict, name: str) -> list[str]:
    """Flags describe where skin ends up, using OKLCH hue of the output mean."""
    f = []
    if r["C_out"] < 0.025 and r["C_in"] > 0.04:
        f.append("gray")
    h = r["hue_out"]
    if h is not None:
        if 95 <= h <= 200:
            f.append("green")
        elif 330 <= h or h < 20:
            f.append("magenta")
        elif 70 <= h < 95 and r["C_out"] > 0.10:
            f.append("orange")
    if r["hue_shift"] is not None and r["hue_shift"] > 15:
        f.append("orange")
    if name == "skin_dark" and r["lum_out"] < 0.5 * r["lum_in"]:
        f.append("dark_skin_crushed")
    return sorted(set(f))


# ------------------------------------------------------------------ texture
def texture(src_by_scene: dict, out_by_scene: dict, baseline_by_scene: dict) -> dict:
    """
    Grain: std of sRGB-encoded red on the uniform flat_050 frame (linear 50 %, midtone).
    Glow: L difference in a ring 50..90 px from the point_light white disc.
    Vignette: corner vs centre L on flat_050.
    """
    f50 = out_by_scene["flat_050"]
    c_slice = (slice(720 // 2 - 40, 720 // 2 + 40), slice(960 // 2 - 40, 960 // 2 + 40))
    grain_std = float(rgb_to_oklab(f50[c_slice].reshape(-1, 3))[:, 0].std())

    pl = out_by_scene["point_light"]
    yy, xx = np.mgrid[0:720, 0:960]
    r = np.hypot(xx - 960 / 2, yy - 720 / 2)
    ring = (r >= 45) & (r <= 75)
    far = (r >= 240) & (r <= 320)
    L_pl = rgb_to_oklab(pl.reshape(-1, 3))[:, 0].reshape(720, 960)
    glow = float(L_pl[ring].mean() - L_pl[far].mean())

    L_50 = rgb_to_oklab(f50.reshape(-1, 3))[:, 0].reshape(720, 960)
    corner = (slice(0, 60), slice(0, 60))
    corner_drop = float(L_50[c_slice].mean() - L_50[corner].mean())
    return {
        "grain_L_std": round(grain_std, 4),
        "glow_L_lift": round(glow, 4),
        "vignette_corner_L_drop": round(corner_drop, 4),
    }

# ------------------------------------------------------------------ main
def main() -> int:
    manifest = json.loads((RENDERS / "manifest.json").read_text())
    regions = {m["scene"]: m["regions"] for m in json.loads((REFS / "regions.json").read_text())}
    scenes = sorted(regions)
    src = {s: load(REFS / f"{s}.png") for s in scenes}
    failures = [r for r in manifest["renders"] if not r.get("ok")]
    presets = sorted({r["preset"] for r in manifest["renders"]})
    display = {r["preset"]: r.get("display", r["preset"]) for r in manifest["renders"]}

    def outs(pid):
        return {s: load(RENDERS / pid / f"{s}.png") for s in scenes}

    baseline = outs("_baseline")
    metrics = {"_meta": {"scenes": scenes, "render_failures": failures,
                         "chroma_floor": CHROMA_FLOOR, "gray_points": GRAY_POINTS,
                         "source": "PhotoRenderer.renderPreview on macOS Metal (CI artifact preset-renders)"}}
    for pid in presets:
        o = outs(pid)
        for s in scenes:
            if o[s].shape != src[s].shape:
                raise SystemExit(f"{pid}/{s}: shape {o[s].shape} != {src[s].shape}")
        m = {"display": display[pid]}
        m["tone"] = tone_response(o)
        m["per_scene"] = {}
        for s in scenes:
            if s.startswith("flat_") or s in ("gray_ramp", "color_chart", "skin_ramp", "point_light"):
                continue
            entry = {**clipping(o[s]), **spread(src[s], o[s]),
                     "shadow_detail": local_detail(src[s], o[s], DETAIL_SHADOW),
                     "highlight_detail": local_detail(src[s], o[s], DETAIL_HIGHLIGHT)}
            entry["regions"] = {r: region_color(crop(src[s], rect), crop(o[s], rect))
                                for r, rect in regions[s].items()}
            m["per_scene"][s] = entry
        m["chart"] = chart_chroma(src["color_chart"], o["color_chart"], regions["color_chart"])
        m["chart_patches"] = {r: region_color(crop(src["color_chart"], rect), crop(o["color_chart"], rect))
                              for r, rect in regions["color_chart"].items()}
        m["mono"] = monochrome_class(list(o.values()))
        m["skin"] = {}
        for scene, rname in SKIN_REGIONS:
            r = region_color(crop(src[scene], regions[scene][rname]), crop(o[scene], regions[scene][rname]))
            r["flags"] = skin_flags(r, rname)
            m["skin"][f"{scene}/{rname}"] = r
        m["texture"] = texture(src, o, baseline)
        metrics[pid] = m
        print(f"  {pid:24s} {m['mono']['kind']:18s} chart C x{m['chart']['chroma_ratio_mean']:.2f}"
              f"  slope {m['tone']['midtone_slope']}")

    # pairwise difference of rendered outputs (OKLab deltaE, mean over all scenes)
    ids = [p for p in presets if not p.startswith("_")]
    labs = {p: np.concatenate([rgb_to_oklab(load(RENDERS / p / f"{s}.png")[::4, ::4].reshape(-1, 3))
                               for s in scenes]) for p in ids}
    pair = {}
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            pair[f"{a}|{b}"] = round(float(np.linalg.norm(labs[a] - labs[b], axis=1).mean()), 4)
    metrics["_pairwise_deltaE_ok"] = pair
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(metrics, indent=1))
    print(f"\nwrote {OUT} ({len(presets)} presets incl. baseline, {len(failures)} render failures)")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
