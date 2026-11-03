# Recovered No Fusion LUT assets

Recovered **20 original LUT binaries and 20 original presets** from:

`no-fusion-2.5.61-dev-build.ipa`

IPA SHA-256: `2d790239c1d3c09db2653ce4812c06ce26b03c716d47a76f2d6b8c023909bb48`

Original archive directory: `Payload/No Fusion.app/Frameworks/NFAsset.framework/`

## Files

- `originals/NFAsset.framework/`: exact original `.lutbin` and `.preset` bytes.
- `presets_xml/`: decoded XML property lists; all values match the originals.
- `presets_json/`: readable JSON representations.
- `preset_lut_map.csv`: complete preset-to-LUT filenames and actual SHA-256 hashes.
- `manifest.json`: provenance, hashes, sample ranges, references, and checks.

## Verified binary structure

Every LUT consists entirely of little-endian IEEE-754 float32 quadruples.
The first three components lie in [0, 1]; every fourth component is 1.0.
Together with the cube dimensions stored by each preset, this supports an RGBA
interpretation. All samples decode and re-encode to the exact original bytes.
There is no additional header or trailer under this layout.

The exact length is `size ** 3 * 4 * 4`:

| Cube dimension | Bytes |
|---:|---:|
| 25 | 250000 |
| 32 | 524288 |
| 33 | 574992 |

The preset's `lutData.reference.id` selects `<id>.lutbin`. Its `size` gives
the cube dimension, and `byteCount` exactly matches the file length.
All 20 references resolve, and no recovered LUT is unreferenced.

**Preserve the original filenames:** although `contentHash` equals `id`, none
of the 20 names equals SHA-256 of the raw `.lutbin` bytes. The identifier's
generation algorithm has not been established. The actual raw hashes are
recorded separately in the manifest and CSV.

## Recreating or reusing assets

For the shipped looks, use the recovered originals directly. Keep each
`.preset` filename and referenced `.lutbin` filename when adding the resources
to a rebuilt framework. Some stored preset `name` values differ from the
filename and `id`; those differences are preserved below.

To serialize an existing ordered sequence of four-component samples in Python:

```python
data = b"".join(struct.pack("<4f", r, g, b, a) for r, g, b, a in samples)
assert len(data) == size ** 3 * 16
```

The original `.preset` files are `bplist00` binary property lists. Read them
with `plistlib.loads(data)` and write editable dictionaries with
`plistlib.dumps(preset, fmt=plistlib.FMT_BINARY)`. Re-serialization preserves
values but need not reproduce the original plist encoding byte for byte;
the files in `originals` do preserve those exact bytes.

Preset `lutIntensity`, `mono`, and other adjustment values remain in the
decoded files. Preserve these when reconstructing each complete preset.

## Presets

| Preset file | Stored name | Description | Size | Intensity |
|---|---|---|---:|---:|
| BW1.preset | L4 | Eternal | 32 | 1 |
| BW2.preset | BW1 | Mono Hi Contrast | 32 | 1 |
| BW3.preset | BW2 | Mono | 32 | 1 |
| BW4.preset | BW3 | Sepia | 32 | 1 |
| CC.preset | CC | Fuji Classic Chrome | 32 | 1 |
| F1.preset | HS | Hasselblad X5 Sanner Blue/Yellow | 33 | 1 |
| F2.preset | L1 | Classic | 32 | 1 |
| F3.preset | L2 | Chrome | 32 | 0.910000026 |
| F4.preset | L3 | Contemporary | 32 | 1 |
| GR.preset | G1 | GR Negative | 33 | 1 |
| H1.preset | G3 | GR Blue | 33 | 1 |
| H2.preset | K1 | Kodak Portra 400 | 33 | 1 |
| K1.preset | K2 | Kodak Portra 400 Yellow | 25 | 1 |
| K2.preset | K3 | Kodak Ultramax 400 | 25 | 0.910000026 |
| K3.preset | K4 | Kodak Pro Image 100 | 25 | 1 |
| K4.preset | K5 | Kodak Portra 200 Gold | 32 | 1 |
| K5.preset | K6 | Kodak 5207 | 33 | 1 |
| LC.preset | G2 | GR Positive | 33 | 0.910000026 |
| NC.preset | NC | Fuji Neutral Classic | 32 | 1 |
| NN.preset | NN | Fuji Nostalgic Negative | 32 | 0.831043541 |

## Evidence and limits

REA archive inventory Evidence: `ev_f28b92aa67beacd9f722b8fed0975881626fb7276f511843bdbea8a62cb87988`.
REA artifact inspection Evidence: `ev_eb28001b00fc56c8ff97a48131b4629ff3f30c089de19ce6a6d328eae76cd8f7`.
The full REA ledger is exported as `rea-evidence.json` alongside this report.
The recovery script supplies the member-level byte, plist, reference, size,
range, and roundtrip checks recorded in `manifest.json`.

This was static archive and data analysis. Axis ordering, shader channel
interpretation, interpolation, working color space, rendering order, and
identifier-generation code were not established from executable analysis or
runtime observation. No app code was executed, and the source IPA was not
modified. Reusing the original files requires no reconstruction of their data.
