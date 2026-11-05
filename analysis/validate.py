"""
Step 0: Validate the measurement tooling before trusting any numbers.

Run this first. If any check fails, fix lutlib before measuring presets.
"""
import sys
from pathlib import Path

import numpy as np

# Add parent to path for local imports
sys.path.insert(0, str(Path(__file__).parent))
from lutlib import (
    identity_lut, load_halide_ccube, load_nofusion_lutbin, load_lapse_cube,
    apply_lut_mix, rel_luminance, rgb_to_oklab
)

BASE = Path(__file__).parent.parent


def test_identity():
    """Identity LUT should pass all values through unchanged."""
    print("  - identity LUT")
    lut = identity_lut(33)
    test_vals = np.array([
        [0.0, 0.0, 0.0],
        [1.0, 1.0, 1.0],
        [0.5, 0.5, 0.5],
        [1.0, 0.0, 0.0],  # edge case that was broken in the old script
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0],
        [0.18, 0.18, 0.18],
        [0.95, 0.95, 0.95],
    ])
    out = lut.sample(test_vals)
    err = np.abs(out - test_vals).max()
    if err > 0.001:
        raise AssertionError(f"identity LUT failed: max error {err:.6f} at {test_vals[np.argmax(np.abs(out - test_vals), axis=0)[0]]}")
    print(f"    ok {len(test_vals)} test points, max error {err:.6f}")


def test_axis_order():
    """
    Layout check that does not assume any LUT is near-identity: compare Process
    Zero against all 6 axis permutations of an identity cube. The red-fastest
    [b, g, r] layout must fit clearly better than every alternative.
    """
    import itertools
    print("  - axis order (permutation fit)")
    p0 = load_halide_ccube(BASE / "halide-recovered-ccube/LuxFilters.framework/p0sdr.ccube")
    n = p0.dimension
    c = np.linspace(0, 1, n)
    b_, g_, r_ = np.meshgrid(c, c, c, indexing="ij")
    axes = {"r": r_, "g": g_, "b": b_}
    errs = {}
    for perm in itertools.permutations("rgb"):
        ident = np.stack([axes[perm[0]], axes[perm[1]], axes[perm[2]]], -1)
        errs["".join(perm)] = float(np.abs(p0.table - ident).mean())
    runner_up = sorted(errs.values())[1]
    if min(errs, key=errs.get) != "rgb" or runner_up < 1.5 * errs["rgb"]:
        raise AssertionError(f"axis order ambiguous or swapped: {errs}")
    print(f"    ok rgb fits best ({errs['rgb']:.3f}); next best {runner_up:.3f}")


def report_process_zero_gray():
    """
    Finding, not a pass/fail check: Process Zero is NOT near-identity on
    sRGB-gamma input. Print its gray response so nobody repeats that claim.
    """
    print("  - Process Zero gray response on sRGB-gamma input (finding)")
    p0 = load_halide_ccube(BASE / "halide-recovered-ccube/LuxFilters.framework/p0sdr.ccube")
    xs = np.array([0.0, 0.1, 0.15, 0.2, 0.3, 0.5, 0.7, 0.8, 0.9, 1.0])
    out = p0.sample(np.repeat(xs[:, None], 3, 1)).mean(1)
    print("    in : " + " ".join(f"{x:4.2f}" for x in xs))
    print("    out: " + " ".join(f"{y:4.2f}" for y in out))
    print("    -> toe crushed to 0 below ~0.15, clipped to 1 above ~0.8."
          " Input encoding for Halide LUTs is UNRESOLVED.")


def test_gray_ramp_monotonic():
    """All presets should preserve gray-ramp monotonicity (not reverse tones)."""
    print("  - gray ramp monotonicity")
    p0_path = BASE / "halide-recovered-ccube/LuxFilters.framework/p0sdr.ccube"
    if not p0_path.exists():
        print("    ! Process Zero not found, skipping")
        return
    p0 = load_halide_ccube(p0_path)
    grays = np.linspace(0, 1, 128).reshape(-1, 1)
    grays = np.repeat(grays, 3, axis=1)
    out = p0.sample(grays)
    luma = rel_luminance(out)
    diffs = np.diff(luma)
    if np.any(diffs < -0.001):
        raise AssertionError(f"Process Zero reverses gray ramp ({np.sum(diffs < 0)} inversions)")
    flat = int(np.sum(np.abs(diffs) < 0.001))
    print(f"    ok no inversions; {flat}/127 steps are flat (crushed or clipped)")


def test_channel_order():
    """Sample pure primaries to confirm RGB axis order (not BGR or another swap)."""
    print("  - RGB channel order")
    p0_path = BASE / "halide-recovered-ccube/LuxFilters.framework/p0sdr.ccube"
    if not p0_path.exists():
        print("    ! Process Zero not found, skipping")
        return
    p0 = load_halide_ccube(p0_path)
    primaries = np.array([
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0],
    ])
    out = p0.sample(primaries)
    # Neutral film should keep red->red, green->green, blue->blue.
    for i, color in enumerate(["red", "green", "blue"]):
        if out[i, i] < 0.85:
            raise AssertionError(
                f"Process Zero {color} {primaries[i]} -> {out[i]}: "
                f"{color} channel {out[i, i]:.3f} < 0.85. Axes may be swapped."
            )
    print(f"    ok R->R {out[0,0]:.3f}, G->G {out[1,1]:.3f}, B->B {out[2,2]:.3f}")


def test_lut_mix():
    """LUT mix at intensity 0 should be identity, at 1.0 should be the LUT."""
    print("  - LUT mix blend")
    lut = identity_lut(33)
    inp = np.array([[0.3, 0.5, 0.7]])
    out0 = apply_lut_mix(inp, lut, 0.0)
    out1 = apply_lut_mix(inp, lut, 1.0)
    if not np.allclose(out0, inp, atol=1e-6):
        raise AssertionError(f"LUT mix at 0.0 returned {out0}, expected {inp}")
    if not np.allclose(out1, lut.sample(inp), atol=1e-6):
        raise AssertionError(f"LUT mix at 1.0 returned {out1}, expected {lut.sample(inp)}")
    print(f"    ok intensity 0.0 -> input, intensity 1.0 -> LUT output")


def test_oklab_roundtrip():
    """sRGB -> OKLab -> sRGB should round-trip within epsilon."""
    print("  - OKLab roundtrip")
    test_vals = np.array([
        [0.0, 0.0, 0.0],
        [1.0, 1.0, 1.0],
        [0.5, 0.5, 0.5],
        [0.8, 0.3, 0.1],
        [0.2, 0.7, 0.9],
    ])
    from lutlib import oklab_to_rgb
    lab = rgb_to_oklab(test_vals)
    back = oklab_to_rgb(lab)
    err = np.abs(back - test_vals).max()
    if err > 0.01:
        raise AssertionError(f"OKLab roundtrip error {err:.6f} > 0.01")
    print(f"    ok max roundtrip error {err:.6f}")


def main():
    print("\n" + "="*70)
    print("VALIDATION: Measurement tooling")
    print("="*70 + "\n")

    try:
        test_identity()
        test_axis_order()
        test_gray_ramp_monotonic()
        report_process_zero_gray()
        test_channel_order()
        test_lut_mix()
        test_oklab_roundtrip()
        print("\nok All checks passed. Tooling is ready.\n")
        return 0
    except Exception as e:
        print(f"\nX Validation failed: {e}\n", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
