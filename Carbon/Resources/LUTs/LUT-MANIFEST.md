# LUT Resources Manifest

**Total LUTs:** 46 files (25 Halide .ccube, 20 No Fusion .lutbin, 1 Lapse .cube)

## Halide LUTs (25 files, 33³ LZFSE-compressed half-float RGB)

| Preset | SDR LUT | HDR LUT |
|---|---|---|
| Process Zero | p0sdr.ccube | p0hdr.ccube |
| Nova | NovaSDR.ccube | NovaHDR.ccube |
| Zephyr | ZephyrDisplayP3SDR.ccube | ZephyrDisplayP3HDR.ccube |
| Rembrandt | RembrandtSDR.ccube | RembrandtHDR.ccube |
| Scarlet | ScarletSDR.ccube | ScarletHDR.ccube |
| Chroma Noir (Scene) | ChromaNoirSceneSDR.ccube | ChromaNoirSceneHDR.ccube |
| Chroma Noir (Display) | ChromaNoirDisplaySDR.ccube | ChromaNoirDisplayHDR.ccube |
| Valencia | ValenciaDisplayP3SDR.ccube | ValenciaDisplayP3HDR.ccube |
| Quicksilver | QuicksilverSDR.ccube | QuicksilverHDR.ccube |
| Dawn | DawnSDR.ccube | DawnHDR.ccube |
| Elysia (original, not referenced by the catalog) | ElysiaSDR.ccube | ElysiaHDR.ccube |
| Elysia (Carbon correction, used by the catalog) | ElysiaCarbonSDR.ccube | - |
| Onyx | OnyxSDR.ccube | OnyxHDR.ccube |

**Format:** 33³ × 3 half-floats (RGB), LZFSE-compressed → 215,622 bytes decoded  
**Usage:** `LUTLoader.loadHalideCCube(data:)` decompresses and appends alpha 1.0

## No Fusion LUTs (20 files, raw float32 RGBA)

| Preset | LUT file | Dimension | Bytes |
|---|---|---:|---:|
| NN (Nostalgic Negative) | 18050bdcbea97ac25f18078a4b3a1a6a775ae852ffdae2e29dfe05175a06a33e.lutbin | 32 | 524,288 |
| NC (Neutral Classic) | 822d19ac28e6c421761039993fd843b076e232b9b90bbb2adf110ef159ff1673.lutbin | 32 | 524,288 |
| CC (Classic Chrome) | e2c341b28e5e7de6a886e731c51ed88208979e8d19371555ef8dc7db458d620a.lutbin | 32 | 524,288 |
| GR (GR Negative) | 685ed5807f1632c601976cfe6ebff38845d2fa1648daa0a9ce66729e6041242b.lutbin | 33 | 574,992 |
| LC (GR Positive) | 1f0a2e71be20d72bbdb134a7181b921caf6f21cf1b217b8f0346005ecbec5e8f.lutbin | 33 | 574,992 |
| H1 (GR Blue) | 70a7e54e51d03e11ce5833944df379e4b4218e13170f69210e1f100f55a762e4.lutbin | 33 | 574,992 |
| H2 (Portra 400) | 0156edbce8ce9f3668dc0b7a703139dc3a35f4f8e014bdabaa13385913c5fcc5.lutbin | 33 | 574,992 |
| K1 (Portra 400 Yellow) | 02198abeb11dd57e39be43e92b3455ecd6505bb6e22a2b60feeb25e53d8f2ab9.lutbin | 25 | 250,000 |
| K2 (Ultramax 400) | b356cc9c1eaae54b9de3d58c4aea5f7a780a96133dbe213b735d69a89099773a.lutbin | 25 | 250,000 |
| K3 (Pro Image 100) | b9246fa3f057253c66021c1ee9afd798c7351b2b73f4ae0744db9d4df79d3b14.lutbin | 25 | 250,000 |
| K4 (Portra 200 Gold) | a75d5f375443e699c1f4b48cb6f5cafc914abf5934d6764fa3461c770f278b75.lutbin | 32 | 524,288 |
| K5 (Kodak 5207) | 8a14ae6faaddc31b4ea373f45c9dc7ffdd5377af2dd503bf23f34a7b16b6130b.lutbin | 33 | 574,992 |
| F1 (Hasselblad X5) | 246df6bf673a0b576495931c898d5eba079bd9d595715eb46555914eeae8a9f6.lutbin | 33 | 574,992 |
| F2 (Classic) | 6fb657704d167f9095ac4d703d2ea8ef2d0180139ce16512a33a372aa8c0cf2e.lutbin | 32 | 524,288 |
| F3 (Chrome) | 8b9d1d4f5399f0ca880be86880eebb336c4952864ed7eba94ea6d20e162c4e85.lutbin | 32 | 524,288 |
| F4 (Contemporary) | 9fab23387aa2c5fe6024a54dab4cf2d9b3549152cdd489011b0e19051e335c5e.lutbin | 32 | 524,288 |
| BW1 (Eternal) | 25b746015f41ff91387c2676383bb370ba67fc6f50db90eaa03ab36f1e26a83a.lutbin | 32 | 524,288 |
| BW2 (Mono Hi Contrast) | 41743664a9e8bbabd4e1c84ecd16d81b772215f7526a8797e5217acddabe282c.lutbin | 32 | 524,288 |
| BW3 (Mono) | 8a2a46d974182d531d4ae80c2ff0900d215dc987ca4cfac55100569c9e408a7f.lutbin | 32 | 524,288 |
| BW4 (Sepia) | b19bcf382607739a7c0ab2b89e57e9b98632bc0b90cc57a659011b1be2cd9d8a.lutbin | 32 | 524,288 |

**Format:** dimension³ × 4 float32 (RGBA), little-endian, no header  
**Usage:** `LUTLoader.loadNoFusionLutbin(data:dimension:)` reads raw floats

## Lapse LUTs (1 file, 33³ cube)

| Preset | LUT file | SHA-256 |
|---|---|---|
| Journal / Photo Default | `lapse/Lapse-V4-03.cube` | `6e9a03e7d1c9c32779feba4e74addc809797a8dfb2f6b02cd985972f6d7ca239` |

**Format:** Original Lapse V4-03 33³ cube text, copied verbatim from Lapse 4.1.1.

## Provenance

- **Halide 3.3.1 Dev IPA:** `halide-recovered-ccube/`
- **No Fusion 2.5.61 Dev IPA:** `nofusion-recovered/originals/NFAsset.framework/`
- **Evidence:** See `docs/reference/HALIDE-IPA-TECHNICAL-PACKAGE.md` §2, `nofusion-recovered/README.md`

All LUT files are copied verbatim from the original IPAs, with one exception: `halide/ElysiaCarbonSDR.ccube` is derived from `ElysiaSDR.ccube` by `scripts/derive_elysia_lut.py`. It replaces only the nodes where a green input renders magenta (a hue reversal over 75 degrees); every other node, including the gray axis, is bit-identical to the original. Halide cubes are indexed by Apple Log encoded Rec.2020 values (see `FilmEffects.applyHalideCube`).

## License & Attribution

The principal has provided these materials and accepts responsibility for provenance, licensing, and permitted use. Carbon's implementation uses the LUT data to recreate the reference presets as documented in the technical references. See `docs/decisions/D-024-reference-presets-menu.md` for attribution policy (cheeky "Stolen Goods" menu with transparent source labeling).
