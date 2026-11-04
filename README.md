# Carbon — Amateur-First Camera for People

Carbon is an iPhone camera for amateurs who want memorable photographs of people without learning camera jargon. It must produce a good photograph of a person on the first shutter tap, with zero configuration.

## Build status

**Current milestone:** M0 (Foundation)  
**Progress:** SET01 scaffold complete + SET13b "Stolen Goods" preset menu + GitHub Actions CI added  
**Execution environment:** Windows 11 (no Xcode); native build blocked (CI ready on macOS runner)

**New work (Nov 3, 2024):**
- **SET13b**: Reference presets menu ("Stolen Goods") with cheeky attribution — surfaces all Halide/Lapse/No Fusion presets transparently (decision D-024, PresetLibrary.swift scaffold)
- **GitHub Actions CI**: `.github/workflows/build.yml` — uses Xcode 26.3 on `macos-15`, tests on an eligible iOS 26 iPhone simulator, builds an unsigned IPA on push to main/develop, and runs Python pipeline verification. The deployment target remains iOS 18.0; CI currently exercises iOS 26, not iOS 18.
- **App target**: CarbonApp.swift (welcome + camera placeholder), XcodeGen project spec (project.yml), Info.plist, color tokens (Remjet, Receipt, CarbonInk, etc.)

**Status detail:** `docs/SET01-execution-report.md`, `docs/roadmap-progress.md`

## Repository structure

```
carbon-plan/
├── docs/
│   ├── reference/           # Three technical reference documents + comparison
│   ├── decisions/           # Engineering choices and build-own rationales
│   ├── questions/           # Escalated reference gaps (awaiting principal)
│   ├── presets/             # Preset definitions (SET13)
│   ├── capabilities/        # Device capability measurements (SET03)
│   ├── design/              # Approved design assets (SET06)
│   ├── product/             # Roadmap and build plan
│   ├── roadmap-progress.md  # Ticket status and evidence
│   └── SET01-completion-report.md  # Current status
├── tests/fixtures/          # Reference outputs (halide/lapse/nofusion)
├── Carbon/                  # Swift Package (iOS 18.0+, Swift 5.9)
│   ├── Package.swift
│   ├── Sources/CarbonKit/
│   │   ├── Models/Contracts.swift       # Frozen SET02 contracts
│   │   └── Rendering/ToneChain.swift    # Decided render graph (D-005)
│   └── Tests/CarbonKitTests/
├── carbon-agent-roadmap.md   # Execution authority (v4)
└── carbon-build-plan.md      # Feature ledger and visual design

```

## What exists now

### Foundation (M0, partially complete)

✅ **Reference comparison** (`docs/reference/comparison.md`): 25-row three-way decision table covering every disagreement between Halide, Lapse, and No Fusion. Every decision justified by the product goal (amateur-first people camera).

✅ **Camera default config** (`docs/decisions/D-002-camera-default-config.md`): Lapse §1 as baseline, with four documented overrides (auto flash, 35mm default, sharpening disabled, HEVC+RAW).

✅ **Frozen contracts** (`Carbon/Sources/CarbonKit/Models/Contracts.swift`): `Shot`, `SourceResource`, `RecipeVersion`, `RenderRevision`, `DevelopmentJob`, `PresetDefinition`, `CameraDefaultConfig`. All immutable, versioned, reproducible (per roadmap §6).

✅ **Render graph** (`Carbon/Sources/CarbonKit/Rendering/ToneChain.swift`): Numeric implementation of the D-005 decided pipeline (geometry → RAW → shoulder → halation → bloom → LUT → exposure → temp-tint → contrast-sat → curve → vibrance → HSL → grain). Pure Swift verification harness; on-device uses CI/Metal.

✅ **Default preset rationale** (`docs/decisions/D-006-natural-preset.md`): "Natural" preset (Process Zero film base, renamed/tuned for amateurs, portrait-optimized).

✅ **Question escalation** ([register](docs/questions/README.md), reviewed November 3, 2026): **All 15 tracked questions are answered for Carbon**, through recovered assets and the principal-approved [D-025 defaults](docs/decisions/D-025-amateur-camera-defaults.md). Safety capture is an opt-in setting with manual selection and no automatic frame ranking. Implementation, tuning, and device verification remain pending.

⏸️ **Native build:** Scaffold exists, but cannot compile without Mac + Xcode.

## What's missing (blockers)

1. **Mac + Xcode 16+:** Windows environment has no Swift toolchain. Repository must be transferred to macOS for compilation and device testing.
2. **iPhone iOS 18.0+:** Device capability measurement (SET03), capture validation (SET04), and all camera work require physical hardware.
3. **Approved design assets:** Splash reference, asset manifest, fonts, screen comparisons (SET06).
4. **Reference fixture photos:** Test photos (people in frame) with Halide/Lapse/No Fusion outputs for comparison fixtures.
5. **LUT integration and verification:** Asset availability is answered: [27 original Halide `.ccube` files](halide-recovered-ccube/README.txt) and [20 original No Fusion LUTs with 20 presets](nofusion-recovered/README.md) are present. Halide files are compressed originals, not decoded `.raw` payloads. Decoding/loading and rendering parity still require verification.

## Product goal (tie-breaker for all decisions)

From roadmap §2:

> Carbon exists for amateurs who want to take good photographs of people without learning camera jargon. Two consequences govern every decision:
>
> 1. **It must work out of the box.** A first-time user who grants camera access and taps the shutter must get a good photograph of a person with zero configuration. Correct exposure on faces, pleasing skin tones, natural color, and a flattering focal length are the default state, not something the user dials in.
>
> 2. **It is primarily a people camera.** Optimize for faces, skin, groups, and candid moments. When choosing between a setting that flatters a landscape and one that flatters a person, choose the person.

Every decision in `docs/decisions/` and `docs/reference/comparison.md` cites this goal.

## Authority hierarchy (roadmap §1)

1. **Technical reference documents** (Halide, Lapse, No Fusion) — authority for reference behavior, parameters, and defaults
2. **Roadmap (`carbon-agent-roadmap.md`)** — authority for execution order, Type, and acceptance
3. **Build plan (`carbon-build-plan.md`)** — authority for feature ledger and phase intent
4. **Product goal** (roadmap §2) — authority for anything the above do not decide

Where the three reference documents disagree, the decision is recorded in `docs/reference/comparison.md` with rationale. No averaging; no silent compromises.

## Next steps (when on Mac)

### Importing a CI build into Feather

Download **Carbon-unsigned.ipa** from the artifacts of a successful
[Build Carbon IPA run](https://github.com/s4wyer/carbon-camera/actions/workflows/build.yml).
GitHub downloads artifacts as ZIP files: extract that ZIP and import the
**Carbon-unsigned.ipa inside it** into Feather. Renaming the downloaded ZIP to
`.ipa` does not work because its root contains another archive instead of `Payload/`.
Sign the imported app in Feather with your certificate before installing.
The app requires iOS 18.0 or later.

CI validates the finished IPA's ZIP structure, bundle metadata, ARM64 device
executable, primary icon PNGs, and bundled resources before uploading it.

### Building locally

1. Transfer this repository to Mac with Xcode 16+.
2. In `Carbon/`, run `xcodegen generate` (install XcodeGen with `brew install xcodegen`).
3. Run `xcodebuild test -project Carbon.xcodeproj -scheme Carbon -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` to validate contract serialization and pipeline math. Choose an installed iPhone simulator if that device is unavailable. Plain `swift test` targets the macOS host and cannot compile the iOS camera/UI code.
4. Complete SET02 verification (contracts frozen and compilable).
5. Complete SET03 (device capability measurement on physical iPhone).
6. Complete SET04 (durable capture and recovery).
7. Complete SET05 (deterministic rendering with CI/Metal).
8. Complete SET06 (approved design assets).
9. Complete SET06b (already done: reference comparison).
10. Complete SET06c (already done: Lapse baseline + overrides).
11. M0 exit gate: all SET0x tickets verified.

## Development principles

- **No silent scope expansion:** Every feature is in the roadmap or documented in `docs/decisions/` with rationale.
- **Honest capability claims:** Never claim arbitrary RAW bit depth, true xenon flash, guaranteed zero shutter lag, universally available pre-shutter RAW frames, or lossless tiny-file archives. Record device + OS + mode + observed result.
- **Reproducibility:** Same engine + source + recipe + seed = same render (roadmap §6).
- **Durable originals:** Retain RAW + recipe; thumbnails and renders are derived, not replacements.
- **Ask, don't guess:** Missing reference behavior → file a question in `docs/questions/`, continue with independent work. The principal holds the reference material.

## License and provenance (from instructions)

The principal has provided three technical reference documents (Halide, Lapse, No Fusion) and asserts the rights and permissions necessary to use those materials for this build. The principal accepts responsibility for provenance, licensing, and permitted use. Carbon's implementation, assets, presets, and code are original; the reference documents inform behavior, not code embedding.

## Contact

Agent execution: follow `carbon-agent-roadmap.md` (v4) ticket order.  
Status: `docs/roadmap-progress.md`  
Decisions: `docs/decisions/`  
Questions: `docs/questions/`

---

**Status:** M0 scaffold complete. Awaiting Mac + Xcode for SET01 native build verification.
