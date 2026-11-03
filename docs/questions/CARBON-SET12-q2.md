# Question CARBON-SET12-q2: No Fusion LUT binaries and byte layout

**Ticket:** SET12  
**Sources:** No Fusion §4; recovered asset README, manifest, and preset-to-LUT map  
**Status:** Answered for asset availability and serialized byte layout  
**Status reviewed:** 2026-11-03

## Question

Are the original No Fusion preset LUT binaries available, and what is the
serialized `.lutbin` layout?

## Answer and explanation

The [recovered asset package](../../nofusion-recovered/README.md) contains
**20 original `.lutbin` files and 20 original `.preset` files** under
`nofusion-recovered/originals/NFAsset.framework/`, plus decoded presets,
`manifest.json`, and `preset_lut_map.csv`.

The recovery report establishes:

- Little-endian IEEE-754 float32 quadruples, with the first three components in
  [0, 1] and every fourth component equal to 1.0, supporting an RGBA interpretation.
- No additional header or trailer under this layout; all samples round-trip
  to the original bytes.
- Cube dimensions 25, 32, or 33, as stored in the corresponding preset;
  exact file length is `size^3 * 16` bytes.
- All 20 preset references resolve to the original LUT filenames, and each
  preset's byte count matches its LUT. Actual SHA-256 hashes are recorded
  separately; the filenames are not SHA-256 hashes of the raw files.

This supersedes the original missing-binaries/unknown-byte-format entry.

The approved [D-025](../decisions/D-025-amateur-camera-defaults.md#set12-q2-lut-resources) policy is to use the recovered originals, verify interpretation before exposing presets, and load the selected look first so the full library does not delay camera startup.

## Remaining verification

Static asset recovery does not establish cube axis ordering, executable channel
interpretation, interpolation, or rendering parity. The recovery report also
does not establish working color space or render order; those need separate
executable/runtime evidence. Resource integration and device comparison remain
implementation work, so SET12 is not marked verified by this answer.
