# Three-way reference comparison and decisions

Sources (all under `docs/reference/`):

- **H** = `HALIDE-IPA-TECHNICAL-PACKAGE.md` (Halide 3.3.1)
- **L** = `lapse-camera-settings.md` (Lapse 4.4.1)
- **N** = `NO_FUSION_TECHNICAL_REFERENCE.md` (No Fusion 2.5.61) + `NO_FUSION_DEEP_DIVE.md` (same build, IDA deep pass)

Rule: disagreements are decided, never averaged. Tie-breaker where the documents do not
settle it is the product goal (amateur-first people camera, good result on first tap).
Every row carries a decision ID that is also referenced from `docs/decisions/`.

| # | Concern | H | L | N | Decision | Why |
|---|---|---|---|---|---|---|
| C01 | Capture session preset | not recovered (`§8` capture config unresolved) | `AVCaptureSessionPresetInputPriority`, app audio session on, no auto device config (`§1`) | app-owned `AVCaptureSession` (`N§9`), helper preset values explicitly not the still config | **L baseline** (`D-002`) | L is the only document with a recovered, complete session configuration. InputPriority is also what a RAW-capable app needs. |
| C02 | Default still container | Bayer RAW + DNG concepts; exact default not recovered (`H§8`) | HEVC-coded still when available, else plain settings (`§1`) | HEIF+ (RAW rasterized to HEIF-family), RAW retained (`N§1`) | **L capture container + retained RAW source** (`D-003`) | Amateur readability (fast, small share file) plus our own durable-source requirement (roadmap §6). No Fusion's HEIF+ is adopted as the *edit* representation, not as the on-disk claim. |
| C03 | Sharpening | pure-RAW options disable sharpening (`H§1` `makePureRAWOptions`) | not specified | explicitly sets `sharpnessAmount` from RAW preset, `contrast = sharpness*0.5` (`N§1`) | **H pure-RAW for the primary path; N sharpness only in the "Vintage Glass"/legacy branch** (`D-004`) | H's path is the one whose whole promise is unsharpened RAW development. We do not claim "no sharpening" globally. |
| C04 | Tone curve placement | LUT/grade last in the EditorFilter branch chain (`H§2`) | CI journal: Gamma after LUT (`§5`) | StyleFilter: LUT → exposure → temp/tint → contrast/sat → curve → vibrance → HSL (`N§3`) | **One graph: geometry → RAW/linear → highlight shoulder → halation → bloom/vignette → LUT(grade) → exposure → temp/tint → contrast/sat → curve → vibrance → HSL → grain → overlays** (`D-005`) | N is the only doc that states a full parameter-order; H's chain and L's journal chain both fit inside it with no reinterpretation. |
| C05 | Default preset | `processZero` for prime camera (`H§8`) | journal CI defaults (not a named user preset) | bundled presets, default *selected* preset unknown (`N§9`) | **Our own "Natural" preset, first and default; Process Zero is its film base** (`D-006`) | Preset rules (roadmap §2) require a plain-language default tuned for skin. |
| C06 | Exposure EV source | `CIRAWFilter` exposure/baseline/boost (`H§1`) | `EV = log2(aperture² / ((ISO/100)*seconds))`, fallback 8.0, then `ev0 + sceneEV*(ev10-ev0)/10` (`L§2`,`§6`) | preset `exposure * strength` applied after LUT (`N§3`) | **L formula for capture EV; N `exposure*strength` as the creative exposure stage; H RAW exposure as baseline** (`D-007`) | They operate at different stages; taking all three is consistent, not a compromise. |
| C07 | White balance fallback | neutral temp/tint in pure-RAW options (`H§1`) | invalid gains → temp `4000.0`, tint `0.0` (`L§2`) | `CITemperatureAndTint` offset in K units ×2000, tint ×30 (`N§3`) | **L fallback values; N offset semantics for the creative stage** (`D-008`) | L is a concrete recovered fallback; N is a concrete recovered creative mapping. |
| C08 | Quality prioritisation | not recovered | `.quality` unless config byte==2 or EV>6.0 → `.balanced` (`L§1`) | per-format quality priority in settings builder (`N§2`) | **L rule** (`D-009`) | Only recovered rule with a threshold. |
| C09 | Depth / mattes at capture | n/a | depth + Live Photo disabled, semantic mattes empty (`L§1`) | Bayer RAW skips capture-time depth; post-process depth exists (`N§2`) | **L: off at capture; post-process depth only when a mode asks** (`D-010`) | Preserves the L baseline and the honest provenance requirement. |
| C10 | Live Photo | n/a | `isLivePhotoCaptureEnabled = false` (`L§1`) | full-format Live Photo, 3.6 s assembly budget, AAC 48 kHz/2ch/192 kbit (`N§2`) | **Off by default; N's recipe when a motion companion is explicitly chosen** (`D-011`) | Default must be the fastest good still. |
| C11 | Flash | state not recovered (`H§8`) | request bytes: 1/2 → hardware flash on, 0/3 → off; auto red-eye when priority != speed (`L§1`) | not recovered | **L mapping; explicit "Auto" default is ours** (`D-012`) | Only recovered flash mapping. |
| C12 | Focus peaking | Gaussian radius 0.55 residual → luminance → polynomial power 5/11 → colour matrix (green 10.0) → power 2.2 → add (`H§4`) | n/a | Sobel, default colour (1,1,1) threshold 0.5, runtime-overridden (`N§8`) | **H pipeline** (`D-013`) | H is a complete, ordered, parameterised pipeline; N's kernel body is unrecovered. |
| C13 | Focus loupe | translate/scale 2.0/crop inset 25 % (`H§4`) | n/a | not recovered | **H transform** (`D-013`) | Only recovered transform. |
| C14 | Manual ISO mapping | not recovered | n/a | `ISO = min + (max-min)*x³`, step 5/100/500/1000 by tier (`N§6`) | **N** (`D-014`) | Only recovered mapping. |
| C15 | AF/AE locking | n/a | centred continuous AF/AE defaults, subject-area monitoring off (`L§1`) | separate focus/exposure state, `(x, 1-y)` points, lock/unlock protected (`N§7`) | **L defaults + N separate locks** (`D-015`) | Defaults and interaction lock are different concerns. |
| C16 | Exposure bias clamp | not recovered | scene EV in metadata only | clamp to device `minExposureTargetBias`/`maxExposureTargetBias` (`N§6`) | **N** (`D-016`) | Only recovered clamp. |
| C17 | Grain | procedural kernel, no exposed seed; size/strength defaults 1.0 (`H§2`) | CI grain intensity `1 - 0.05*sceneEV`; Metal seeded integer-hash grain (`L§6`,`§8`) | grain amount/size from preset, `size` = scatter radius, opacity `amount*0.2` (`N§3`) | **L Metal seeded hash for determinism; N amount/size semantics for the shipped presets** (`D-017`) | Roadmap §6 requires reproducibility, which the H kernel cannot prove. |
| C18 | Halation | cutoff 1.0, radius 4.0, gains (1.0, .35, .1), downsample .25 (`H§2`) | luma .92–.95, red .93–.99, sigma 20/15, back (.9,.001,0) .65, front (.99,.69,.24) 1 (`L§7`) | strength .5, thresholds .7/.8, blur 8/16 red, 5.6/10.4 green, opacity 0–.85, dark-side only (`N§3`) | **L Metal defaults** (`D-018`) | L is the fully-specified, shader-adjacent set and pairs with the chosen grain model. |
| C19 | LUT domain / colour space | 33³ half-float RGB, no domain declaration; display P3 / scene / display variants (`H§1`,`§2`) | 33³ cube, `CIColorCubeWithColorSpace`, Device RGB; Metal 3D texture (`L§8`) | `CIColorCubeWithColorSpace` explicitly sRGB (`N§3`,`§4`) | **Explicit: sRGB-in, sRGB-out working domain; P3 display transform only at export** (`D-019`) | N is the only doc that names the space; making the domain explicit is a roadmap §6 requirement. |
| C20 | Preset parameter model | LUT + `LookCustomization` effect flags/scalars (`H§2`,`§3`) | parameterised factory pipelines (`L§5`) | ~30 scalar fields + LUT reference + intensity + grain/bloom/vignette (`N§3`) | **N field set as the union superset; L factories and H Looks expressed as subsets of it** (`D-020`) | One model must represent all three; N's is the most granular. |
| C21 | Preset intensity | not recovered (slider bounds unknown) | LUT opacity / per-effect scalars | single `strength` scalar scaling every adjustment (`N§3`) | **N `strength` semantics exposed as one plain-language control** (`D-021`) | Matches the preset rule "one strength control". |
| C22 | Metadata writing | DNG export (`H§1`) | strips orientation after orienting pixels, writes capture params to EXIF `UserComment`, no universal quality (`L§9`) | conditional RAW metadata replacement, Photos resource types 1/4/9 (`N§2`) | **L policy + our JSON sidecar; Photos pairing only where motion exists** (`D-022`) | L is the recovered export policy; the sidecar is ours (roadmap §6 round-trip). |
| C23 | Default camera config | prime zoom 1.0, macro false, look processZero, exposure enum raw 0; rest unresolved (`H§8`) | full session/focus/exposure/format/quality stack (`L§1`,`§2`) | most defaults unresolved (`N§9`) | **L baseline, enumerated overrides in `docs/decisions/D-002-camera-default-config.md`** (`D-002`) | Roadmap §1 mandates L as the baseline. |
| C24 | Frame rate | not recovered | request min=max=1/30 s (`L§1`) | helper only (15 fps, not the still path) (`N§9`) | **L request** (`D-009`) | Request, not guarantee — recorded as such in capabilities. |
| C25 | Negative / re-edit | `CIRAWFilter` redevelop path (`H§1`) | re-render from original encoded data (`L§10`) | RAW retained under capture ID ("master tape"), re-editable (`N§5`) | **Ours: immutable `RecipeVersion` + retained source; N's re-edit promise, our schema** (`D-023`) | N does not define a schema; roadmap §6 does. |

## Reference questions and recorded answers

Status reviewed November 3, 2026: **All 15 questions below are answered for Carbon** through recovered assets and principal-approved [D-025 product decisions](../decisions/D-025-amateur-camera-defaults.md). The table preserves the original reference gaps; unknown source behavior is not claimed recovered. Safety capture is an opt-in setting with manual selection and no automatic frame ranking. Implementation and validation remain pending.
See the [question register](../questions/README.md) for current statuses and explanations.

| Original reference gap (Carbon answer recorded) | Doc + section | Question file |
|---|---|---|---|
| Composition guide geometry (thirds/golden/rabatment coordinates, line widths) | H §6 | `docs/questions/CARBON-U07-q1.md` |
| Flash default: **Answered for Carbon** (`.auto`, D-002/C11); Halide's own default remains unknown | H §8; D-002 | [CARBON-C07-q1.md](../questions/CARBON-C07-q1.md) |
| Halide Image Lab exposure slider range/mapping | H §1 | `docs/questions/CARBON-R08-q1.md` |
| Halide Film UI slider bounds | H §3 | `docs/questions/CARBON-R07-q1.md` |
| Per-Look persisted customisation values | H §2, §3 | `docs/questions/CARBON-SET12-q1.md` |
| Volume-shutter dedup window / event mapping | H §7 | `docs/questions/CARBON-U09-q1.md` |
| NF render order for grain relative to `StyleFilter` in every mode | N §3 | `docs/questions/CARBON-R05-q1.md` |
| NF preset LUT binaries + `.lutbin` layout: **Answered** (20 recovered originals; little-endian float32 quadruples); runtime interpretation remains unverified | N §4; recovered asset package | [CARBON-SET12-q2.md](../questions/CARBON-SET12-q2.md) |
| NF HEIF+ encoder quality table | N §1 | `docs/questions/CARBON-SET11-q1.md` |
| NF selected default preset/format (clean install) | N §9 | `docs/questions/CARBON-SET11-q2.md` |
| Lapse zoom ramp-rate policy | L §1 | `docs/questions/CARBON-C10-q1.md` |
| Lapse "new instants" flag default | L §3 | `docs/questions/CARBON-SET11-q3.md` |
| Safety capture: **Answered for Carbon** (setting off by default, three frames where supported, manual selection; no eye detection/ranking) | H §1 (not recovered); D-025 | [CARBON-C05-q1.md](../questions/CARBON-C05-q1.md) |
| Pre-shutter RAW frame availability | H §1, C04 note | `docs/questions/CARBON-C06-q1.md` |
| Camera Control integration detail | H §7 | `docs/questions/CARBON-U10-q1.md` |

Product policies for Live Photos, depth handoff, and the negative container are
approved in D-025; implementation details remain deferred to their milestones.
The [question register](../questions/README.md) tracks the policy and remaining work.
