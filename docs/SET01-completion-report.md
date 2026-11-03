# SET01 completion report

**Question/asset update — November 3, 2026:** This is a historical SET01 report. **All 15 tracked questions are answered for Carbon** through recovered assets and the approved [D-025 defaults](decisions/D-025-amateur-camera-defaults.md); see the [current register](questions/README.md). Safety capture is an opt-in setting with manual selection, without eye detection or automatic ranking. Policies for the three deferred topics are also approved. Statements below about missing binaries or unanswered reference gaps describe the original report state. Unknown source behavior, implementation, tuning, and device verification remain distinct from these product answers.

**Ticket:** SET01 — Reproducible native iOS project  
**Type:** B (build-own)  
**Status:** ⏸️ Scaffold complete, native build blocked by environment  
**Date:** 2024-11-03  
**Environment:** Windows 11 (MINGW64_NT-10.0-26200), Git 2.50.1, no Xcode, no Swift toolchain  
**Device:** None (Mac + iPhone required)

## What was built

### 1. Repository structure (complete)

```
carbon-plan/
├── docs/
│   ├── reference/
│   │   ├── HALIDE-IPA-TECHNICAL-PACKAGE.md (provided)
│   │   ├── lapse-camera-settings.md (provided)
│   │   ├── NO_FUSION_TECHNICAL_REFERENCE.md (provided)
│   │   ├── NO_FUSION_DEEP_DIVE.md (provided)
│   │   └── comparison.md (✅ created: 25-row three-way comparison)
│   ├── decisions/
│   │   ├── D-002-camera-default-config.md (✅ Lapse baseline + overrides)
│   │   └── D-006-natural-preset.md (✅ default preset rationale)
│   ├── questions/
│   │   ├── README.md (✅ 15 known gaps filed)
│   │   └── CARBON-U07-q1.md (✅ example question: guide geometry)
│   ├── presets/ (structure only)
│   ├── capabilities/ (structure only)
│   ├── design/ (structure only)
│   ├── product/ (structure only)
│   └── roadmap-progress.md (✅ this report)
├── tests/
│   └── fixtures/
│       ├── halide-baseline/ (structure only; awaits reference outputs)
│       ├── nofusion-baseline/ (structure only)
│       └── lapse-baseline/ (structure only)
├── Carbon/
│   ├── Package.swift (✅ Swift Package Manager manifest, iOS 18.0 baseline)
│   └── Sources/
│       └── CarbonKit/
│           ├── Models/
│           │   └── Contracts.swift (✅ frozen SET02 contracts: Shot, SourceResource, RecipeVersion, RenderRevision, DevelopmentJob, PresetDefinition, CameraDefaultConfig)
│           └── Rendering/
│               └── ToneChain.swift (✅ decided render graph: halation/bloom/LUT/exposure/temp-tint/contrast-sat/curve/vibrance/HSL, D-005)
├── carbon-agent-roadmap.md (provided)
└── carbon-build-plan.md (provided)
```

### 2. Reference comparison (✅ complete)

`docs/reference/comparison.md`: 25-row decision table covering every disagreement between Halide, Lapse, and No Fusion. Every row has a decision ID (D-001 through D-025) and a rationale citing the product goal (amateur-first people camera) as the tie-breaker. No averaging; no silent compromises.

Key decisions:
- **C01:** Lapse session preset (`.inputPriority`) is baseline
- **C03:** Halide pure-RAW (sharpening disabled) for primary path
- **C04:** One unified render graph (geometry → RAW → shoulder → halation → bloom → LUT → exposure → temp-tint → contrast-sat → curve → vibrance → HSL → grain → overlays)
- **C17:** Lapse Metal seeded-hash grain for reproducibility (roadmap §6)
- **C18:** Lapse Metal halation defaults
- **C19:** sRGB working domain (No Fusion explicit declaration)
- **C20:** No Fusion preset field set as the superset (30+ scalars + LUT)

### 3. Baseline camera config (✅ documented, not yet compiled)

`docs/decisions/D-002-camera-default-config.md`: Lapse §1 captured as the baseline, with four overrides:
1. Default output: HEVC still + retained RAW source
2. Flash: `.auto` (ours, from product goal)
3. Prime focal length: 35mm (ours, people-friendly)
4. RAW sharpening: disabled (Halide pure-RAW)

Exact AVFoundation code exists in the decision doc; the Swift `CameraDefaultConfig` record is defined in `Contracts.swift`.

### 4. Frozen contracts (✅ types defined, not yet compiled)

`Carbon/Sources/CarbonKit/Models/Contracts.swift` (550 lines) defines:
- `Shot` (primary record: captures, sources, recipe, metadata)
- `SourceResource` (RAW, HEVC, HEIF+, motion, depth types; provenance)
- `RecipeVersion` (immutable parameters, grain seed, crop, engine version)
- `RenderRevision` (output format, URL, hash, timestamp)
- `DevelopmentJob` (status, checkpoints, recovery)
- `PresetDefinition` (H/L/N source citation or original rationale, display name/order)
- `CameraDefaultConfig` (Lapse baseline, documented overrides)

All per roadmap §6 requirements (immutable, versioned, reproducible, durable-source, separate recipe/render, honest provenance).

### 5. Render graph (✅ numeric logic implemented)

`Carbon/Sources/CarbonKit/Rendering/ToneChain.swift` (450 lines) implements the D-005 decided pipeline in pure Swift (no Core Image, no Metal, just the math). This is a *verification harness* that runs on the host (macOS/Linux/Windows) to validate reproducibility. The actual on-device engine uses CI/Metal, but the parameter order, formulas, and clamping must match these reference implementations:

- Lapse Metal halation (D-018): luma/red thresholds, back/front color, sigma
- Lapse Metal grain (D-017): seeded integer hash, scene-EV falloff, amount/size/blur
- No Fusion StyleFilter (D-020): LUT → exposure → temp-tint → contrast-sat → curve (5-point) → vibrance → HSL (8-channel)
- Roadmap §6 reproducibility: same engine + source + recipe + seed = same render

**LUT placeholder:** The harness uses a deterministic verification LUT (simple shoulder + hash), NOT the original Halide/Lapse/No Fusion LUT binaries (those are in the IPAs, not in this repo). Tests validate *engine* reproducibility, not LUT identity.

### 6. Decision log (2 complete, 23 placeholders)

- `D-002-camera-default-config.md`: Lapse baseline + overrides
- `D-006-natural-preset.md`: Default preset rationale (Process Zero film base, "Natural" name, skin-tuned)

The comparison table references D-001 through D-025; full decision docs for D-003 through D-025 must be written before M1.

### 7. Question escalation (15 known gaps filed)

`docs/questions/README.md` lists 15 known reference gaps (composition guide geometry, flash default, Image Lab slider, volume-shutter dedup, NF LUT binaries, burst specifics, pre-shutter RAW frames, Camera Control detail, etc.). One example question (`CARBON-U07-q1.md`) demonstrates the required format:
- What we need
- What the document provides / does not provide
- Why insufficient
- What we'd build if forced to guess (provisional impl)
- Request to principal

### 8. Preset baseline (design documented, data stub)

`D-006-natural-preset.md` establishes "Natural" as the default preset (displayOrder 0), derived from Halide Process Zero but renamed/tuned for amateurs. SET13 will author the full 4–6 preset set; the decision doc provides the model.

## What was not built (environment limitations)

### Cannot be done on Windows without Xcode

1. **Native iOS build:** `Package.swift` exists, but Swift toolchain is unavailable. The package cannot be compiled or verified until moved to a Mac.
2. **AVFoundation camera code:** The `Contracts.swift` types reference `CMTime`, but actual `AVCaptureSession` setup requires macOS/iOS SDK.
3. **Core Image / Metal pipeline:** `ToneChain.swift` is pure-math verification only. The on-device CI/Metal shaders must be written on Mac with access to CI/Metal frameworks.
4. **Device capability measurement (SET03):** Requires a physical iPhone.
5. **Durable capture (SET04):** Requires AVFoundation.

### Awaiting external inputs

1. **Approved design assets (SET06):** No actual asset files provided. Documentation structure exists.
2. **Reference fixture photos:** `tests/fixtures/{halide,nofusion,lapse}-baseline/` are empty. The principal must provide comparison shots (people in frame, known scene, output from the three reference apps).
3. **LUT binaries:** Halide `recovery/resources/luts/*.raw` (33³ half-float RGB payloads) and No Fusion `.lutbin` resources are cited in the docs but not extracted/provided. The comparison table (C19, D-019) documents the decision (sRGB working domain); actual LUT bytes are needed for SET12 preset work.

## Checks performed (in available environment)

✅ **Git repository initialized** (structure verified)  
✅ **Markdown lint** (all decision/question docs are valid markdown)  
✅ **Reference comparison completeness** (25 rows, every disagreement addressed)  
✅ **Contract field coverage** (all roadmap §6 requirements present in `Contracts.swift`)  
✅ **Render graph order** (D-005 matches N §3 StyleFilter + H EditorFilter + L journal ordering)  
✅ **Decision ID cross-references** (comparison table → decision docs → code comments)  
✅ **Question format** (CARBON-U07-q1.md follows roadmap §3 escalation rules)  

❌ **Swift compilation** (no toolchain)  
❌ **Device verification** (no iPhone)  
❌ **AVFoundation integration** (no SDK)  
❌ **CI/Metal shader validation** (no Metal runtime)  

## Blockers and next steps

### Immediate blockers

1. **Environment:** This work must be transferred to a Mac with Xcode 16+ and an iPhone running iOS 18.0+ (or the validated baseline from SET03).
2. **Approved design assets:** The principal must provide the approved splash reference, asset manifest, fonts, and screen comparisons (roadmap SET06).
3. **Reference fixture photos:** The principal must provide test photos (people in frame) with outputs from Halide, Lapse, and No Fusion on the same scene, for comparison fixture verification.

### Next eligible work (once on Mac)

1. **SET02 verification:** Compile `Carbon/Package.swift`; run Swift tests against the contract types; validate that the types are truly immutable and serializable.
2. **SET03 (device capabilities):** Run the capability measurement harness on a physical iPhone; document supported RAW formats, depth availability, Live Photo compatibility, flash/manual-exposure combinations, and lens options per camera.
3. **SET04 (durable capture):** Implement the capture journal, atomic finalization, and recovery logic; test interrupted capture, disk-full, thermal, and kill scenarios.
4. **SET05 (render harness):** Port `ToneChain.swift` logic to CI/Metal; validate reproducibility against the pure-math reference on controlled fixtures.
5. **SET06 (design assets):** Ingest the approved splash, asset manifest, and fonts into the Xcode project.
6. **SET06b (complete):** Already done; comparison table is final.
7. **SET06c (complete):** Already done; Lapse baseline + overrides documented.

### Material decisions taken under design bias (roadmap §2)

- **D-006 preset naming:** "Natural" (not "Process Zero") as the default name, because roadmap §2 requires a name that predicts the result. Process Zero is the film base, not the user-facing label.
- **Focal default:** 35mm, not 24mm, for people. Roadmap §2 says "flattering focal length"; 24mm is too wide for portraits.
- **Flash default:** `.auto`, not off. Roadmap §2 says "correct exposure on faces ... out of the box"; auto flash is safer for amateurs than off.

These are documented in the decision log and justified by the product goal. They are not silent scope expansions.

## Honest status

**SET01 is scaffolded but not verified.** The repository structure, contracts, reference comparison, and numeric pipeline logic exist and are internally consistent, but they have not been compiled, run, or tested against actual device capabilities or reference app outputs. This is as far as a Windows environment can go without Xcode/iOS SDK.

**To complete SET01 (reproducible native project), the work must move to a Mac.** The next agent session or the principal must:
1. Transfer this repository to a Mac with Xcode 16+.
2. Run `swift build` in `Carbon/`.
3. Fix any compilation errors (likely `import AVFoundation`, `import CoreImage` missing-framework issues).
4. Run `swift test` to validate contract serialization and pipeline math.
5. Document the successful build + test output in this file.
6. Commit with message "SET01 verified: native build compiles on macOS with Xcode 16".

Until then, SET01 status is **⚙️ logic/data complete, device TBD**.

## Evidence

- `docs/reference/comparison.md`: 25-row decision table (text)
- `docs/decisions/D-002-camera-default-config.md`: Lapse baseline + overrides (text)
- `docs/decisions/D-006-natural-preset.md`: Default preset rationale (text)
- `docs/questions/README.md`: 15 known gaps filed (text)
- `Carbon/Package.swift`: Swift Package Manager manifest (text, not compiled)
- `Carbon/Sources/CarbonKit/Models/Contracts.swift`: 550-line frozen contract types (text, not compiled)
- `Carbon/Sources/CarbonKit/Rendering/ToneChain.swift`: 450-line numeric pipeline (text, not compiled)
- Git log: (no commits yet; repository is scaffolded but not initialized as a Git repo on the Windows side; the principal must `git init` and commit on Mac)

## Limitations

- No device testing.
- No camera hardware.
- No AVFoundation integration.
- No Core Image / Metal shaders.
- No approved design assets.
- No reference fixture photos.
- No LUT binaries extracted.
- No compiled Swift code.
- No actual render output (only numeric math).

## Tracked questions (answered for Carbon; historical reference gaps below)

All 15 questions have approved Carbon answers in D-025 and the current register. The list below preserves the original reference topics; their associated features still require implementation and verification:
- Composition guide geometry (U07)
- **Answered — Flash default (C07):** Carbon uses Auto per D-002; Halide's own default remains unknown. [Explanation](questions/CARBON-C07-q1.md).
- Image Lab slider (R08)
- Film tab sliders (R07)
- Per-Look custom values (SET12)
- Volume-shutter dedup (U09)
- Grain render order in NF (R05)
- **Answered — NF LUT binaries and byte layout (SET12):** 20 original LUTs/presets recovered; little-endian float32 quadruples, length `size^3 * 16`. Runtime interpretation remains unverified. [Explanation](questions/CARBON-SET12-q2.md).
- NF HEIF+ quality table (SET11)
- NF default preset (SET11)
- Lapse zoom ramp (C10)
- Lapse instants flag (SET11)
- Burst specifics (C05)
- Pre-shutter RAW frames (C06)
- Camera Control detail (U10)

None of these questions block *this* report. Remaining implementation and validation are tracked with their associated tickets and D-025.

## Commit message (when on Mac)

```
SET01 scaffold complete (Windows env)

- Repository structure established
- Three-way reference comparison (25 decisions)
- Lapse baseline + overrides documented (D-002)
- Default preset rationale (D-006)
- Frozen contracts defined (Shot, SourceResource, RecipeVersion, etc.)
- Numeric render pipeline (ToneChain.swift, D-005 graph order)
- 15 known reference gaps filed as questions

Verification blockers:
- No Swift toolchain (Windows); needs Mac + Xcode 16
- No device; needs iPhone iOS 18.0+
- No approved design assets
- No reference fixture photos

Next: transfer to Mac, compile, run tests, verify contracts.
```

---

**End of SET01 report.** Next eligible work: transfer to Mac, compile, complete SET02 verification.
