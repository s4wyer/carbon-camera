#!/usr/bin/env python3
"""Asset and preset integrity checks for Carbon CI.

Validates, without a Swift toolchain or device:

1. Every preset `lutID` in `PresetCatalog.swift` resolves to a bundled LUT file.
2. Every bundled Halide `.ccube` is reachable from the Swift Halide lookup table.
3. No Fusion preset catalog entries match the recovered authoritative
   `nofusion-recovered/preset_lut_map.csv` (LUT hash + lutIntensity).
4. Every No Fusion `.lutbin` byte length matches its declared cube dimension.
5. The `LUT-MANIFEST.md` No Fusion table matches the authoritative CSV.

These checks exist because two real defects shipped undetected: 19/20 No Fusion
presets pointed at non-existent LUT names, and `chroma-noir-display-sdr` mapped
to a doubled "display" filename. Both are caught here.

Exit code 0 = all checks pass; 1 = at least one failure.
"""

from __future__ import annotations

import csv
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PRESET_CATALOG = os.path.join(REPO, "Carbon/Sources/CarbonKit/Models/PresetCatalog.swift")
LUT_RESOURCES = os.path.join(REPO, "Carbon/Sources/CarbonKit/Rendering/LUTResources.swift")
LUT_DIR = os.path.join(REPO, "Carbon/Resources/LUTs")
HALIDE_DIR = os.path.join(LUT_DIR, "halide")
NOFUSION_DIR = os.path.join(LUT_DIR, "nofusion")
MANIFEST = os.path.join(LUT_DIR, "LUT-MANIFEST.md")
PRESET_LUT_MAP = os.path.join(REPO, "nofusion-recovered/preset_lut_map.csv")

CUBE_BYTES = {25: 25 ** 3 * 16, 32: 32 ** 3 * 16, 33: 33 ** 3 * 16}


class Failures(list):
    def check(self, ok: bool, message: str) -> bool:
        if not ok:
            self.append(message)
        return ok


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def parse_catalog_lut_ids(source: str) -> list[str]:
    """All non-empty lutID literals in the preset catalog."""
    return [x for x in re.findall(r'lutID: "([^"]*)"', source) if x]


def parse_halide_map(source: str) -> dict[str, str]:
    """The explicit `"halide-...": ".ccube basename"` table in LUTResources."""
    return dict(re.findall(r'"(halide-[a-z0-9-]+)":\s*"([A-Za-z0-9]+)"', source))


def parse_nofusion_presets(source: str) -> dict[str, dict[str, str]]:
    """Map preset file ID (e.g. K1) -> {lutID, lutIntensity} from the catalog.

    Matches each `nofusion{ID} = PresetDefinition(...)` block and pulls the
    `nofusion-{hash}` LUT and optional `lutIntensity:` override.
    """
    blocks = re.findall(
        r"private static let nofusion([A-Z0-9]+) = PresetDefinition\((.*?)\n    \)",
        source,
        re.S,
    )
    result: dict[str, dict[str, str]] = {}
    for preset_id, body in blocks:
        lut = re.search(r'lutID: "nofusion-([0-9a-f]+)"', body)
        intensity = re.search(r"lutIntensity:\s*([0-9.]+)", body)
        result[preset_id] = {
            "hash": lut.group(1) if lut else "",
            "intensity": intensity.group(1) if intensity else "1.0",
        }
    return result


def parse_manifest_nofusion(markdown: str) -> dict[str, str]:
    """Map preset ID -> declared `.lutbin` filename from the manifest table."""
    section = markdown.split("## No Fusion LUTs", 1)
    if len(section) != 2:
        return {}
    body = section[1].split("## Provenance", 1)[0]
    rows = re.findall(r"\| ([A-Z]+\d*) \([^)]*\) \| ([0-9a-f]{64}\.lutbin) \|", body)
    return dict(rows)


def load_preset_lut_map() -> dict[str, dict[str, str]]:
    with open(PRESET_LUT_MAP, encoding="utf-8", newline="") as handle:
        return {row["id"]: row for row in csv.DictReader(handle)}


def run() -> int:
    failures = Failures()
    catalog = _read(PRESET_CATALOG)
    resources = _read(LUT_RESOURCES)

    halide_files = {n[:-6] for n in os.listdir(HALIDE_DIR) if n.endswith(".ccube")}
    nofusion_files = {n[:-7] for n in os.listdir(NOFUSION_DIR) if n.endswith(".lutbin")}
    halide_map = parse_halide_map(resources)

    # 1. Every catalog lutID resolves to a bundled file.
    for lut_id in parse_catalog_lut_ids(catalog):
        if lut_id.startswith("halide-"):
            target = halide_map.get(lut_id)
            failures.check(
                target in halide_files,
                f"catalog lutID '{lut_id}' -> {target!r}.ccube is not bundled",
            )
        elif lut_id.startswith("nofusion-"):
            failures.check(
                lut_id[len("nofusion-"):] in nofusion_files,
                f"catalog lutID '{lut_id}' has no bundled .lutbin",
            )
        else:
            failures.append(f"catalog lutID '{lut_id}' has no recognized source prefix")

    # 2. Halide lookup table and bundled files agree both ways.
    for lut_id, target in halide_map.items():
        failures.check(target in halide_files, f"halideMap '{lut_id}' -> missing {target}.ccube")
    for name in sorted(halide_files - set(halide_map.values())):
        failures.append(f"bundled .ccube '{name}' is unreachable from halideMap")

    # 3. No Fusion catalog entries match the authoritative CSV.
    csv_rows = load_preset_lut_map()
    catalog_nf = parse_nofusion_presets(catalog)
    failures.check(
        len(catalog_nf) == len(csv_rows),
        f"catalog defines {len(catalog_nf)} No Fusion presets; CSV has {len(csv_rows)}",
    )
    for preset_id, csv_row in sorted(csv_rows.items()):
        entry = catalog_nf.get(preset_id)
        if not failures.check(entry is not None, f"preset {preset_id} missing from catalog"):
            continue
        expected_hash = csv_row["lut_file"][:-len(".lutbin")]
        failures.check(
            entry["hash"] == expected_hash,
            f"preset {preset_id} LUT hash mismatch: catalog {entry['hash'][:12]}… "
            f"!= CSV {expected_hash[:12]}…",
        )
        expected_intensity = float(csv_row["lut_intensity"])
        actual_intensity = float(entry["intensity"])
        failures.check(
            abs(actual_intensity - expected_intensity) < 1e-6,
            f"preset {preset_id} lutIntensity {actual_intensity} != CSV {expected_intensity}",
        )

    # 4. Every No Fusion .lutbin byte length matches its cube size.
    for name in sorted(nofusion_files):
        path = os.path.join(NOFUSION_DIR, name + ".lutbin")
        size = os.path.getsize(path)
        failures.check(
            size in CUBE_BYTES.values(),
            f"{name}.lutbin has {size} bytes; expected one of {sorted(CUBE_BYTES.values())}",
        )

    # 5. Manifest table matches the authoritative CSV.
    manifest_rows = parse_manifest_nofusion(_read(MANIFEST))
    failures.check(
        len(manifest_rows) == len(csv_rows),
        f"manifest lists {len(manifest_rows)} No Fusion rows; CSV has {len(csv_rows)}",
    )
    for preset_id, csv_row in sorted(csv_rows.items()):
        declared = manifest_rows.get(preset_id)
        failures.check(
            declared == csv_row["lut_file"],
            f"manifest {preset_id} lists {declared!r} but CSV says {csv_row['lut_file']!r}",
        )

    if failures:
        print(f"Asset checks FAILED ({len(failures)} problem(s)):", file=sys.stderr)
        for item in failures:
            print(f"  - {item}", file=sys.stderr)
        return 1

    print("Asset checks passed:")
    print(f"  {len(halide_files)} Halide .ccube files, all mapped")
    print(f"  {len(nofusion_files)} No Fusion .lutbin files, all matched to catalog + CSV + manifest")
    print(f"  {len(parse_catalog_lut_ids(catalog))} catalog LUT references resolve")
    return 0


if __name__ == "__main__":
    sys.exit(run())