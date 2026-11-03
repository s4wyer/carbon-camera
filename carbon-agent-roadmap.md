# Unified Camera App — Feature-by-Feature Roadmap (v4)

November 2 2026

Use this roadmap with the current build plan (`carbon-build-plan.md`), the design doc (`carbon-build-plan.docx`), and the three technical reference documents:

- `HALIDE-IPA-TECHNICAL-PACKAGE.md` — Halide Process Zero pipeline, film Look parameter sets, focus aids, manual-control degradation, composition guides, hardware capture, default camera config
- `lapse-camera-settings.md` — Lapse capture settings, capture metadata, processing engine selection, Core Image and Metal pipeline recipes, LUT reproduction, default camera config
- `NO_FUSION_TECHNICAL_REFERENCE.md` — No Fusion HEIF+ pipeline, Live Photo/Portrait, preset system, LUT import, negative mode, manual exposure logic, AF/AE locking, focus peaking, default camera config

The app is assembled from the recovered behaviors, filter parameters, pipeline orders, and defaults documented in those three reference documents, plus our own work on the areas none of them cover. This roadmap tells the agent what to pull from each reference document, what to build ourselves, and in what order.

**Relationship to v3:** Ticket IDs, Type A/B discipline, and the milestone structure carry forward. New in v4: a product-goal section that governs silent decisions, a preset-design section that governs naming and surfacing, source references that point at the actual three technical documents instead of abstract "§n" markers, and milestone exit gates that test the out-of-the-box people-photo experience and preset legibility.

---

## 1 Input authority

Five inputs, in order of precedence for their domain:

1. **Technical reference documents** (Halide, Lapse, No Fusion) — authority for reference behavior, parameters, and defaults
2. **This roadmap** — authority for execution order, Type, and acceptance
3. **Design doc** (`carbon-build-plan.docx`) — authority for visual language, layout, and copy
4. **Build plan** (`carbon-build-plan.md`) — authority for the feature ledger and phase intent
5. **Product goal** (§2 below) — authority for anything the above four do not decide

Where the three reference documents disagree on the same concern, record the disagreement in `docs/reference/comparison.md` with the decision and rationale. Do not average them. Lapse's camera settings are the baseline for `CameraDefaultConfig`; Halide and No Fusion override individual fields only where their pipeline requires it, documented per override.

The three technical documents contain both recovered implementation and explicitly marked unknowns. Where a document marks a behavior as "unknown," "not recovered," or "cannot be recovered," treat it as missing evidence and file a question (see §3). Do not invent a value from the surrounding description.

---

## 2 Product goal and design bias

Carbon exists for amateurs who want to take good photographs of people without learning camera jargon. Two consequences govern every decision:

**It must work out of the box.** A first-time user who grants camera access and taps the shutter must get a good photograph of a person with zero configuration. Correct exposure on faces, pleasing skin tones, natural color, and a flattering focal length are the default state, not something the user dials in. Defaults are the product. Advanced controls exist for the curious; they must never be required for a good result.

**It is primarily a people camera.** Optimize for faces, skin, groups, and candid moments. When choosing between a setting that flatters a landscape and one that flatters a person, choose the person. Skin-tone accuracy across the full range is a first-class quality bar, not a polish item. Focal defaults, flash behavior, exposure bias, subject-distance guidance, and preset design all lean toward people.

**Design bias — where the roadmap is silent.** If the roadmap, build plan, design doc, and reference documents do not specify a behavior, setting, default, threshold, or interaction, do not stop and do not ask. Make the choice that best serves an amateur taking pictures of people, implement it, and record the choice and reasoning in `docs/decisions/`. This applies to defaults, edge-case behavior, error copy, empty states, control placement within the approved layout, animation timing, and similar unspecified detail.

This latitude does not extend to anything the roadmap explicitly specifies, anything the design doc visually specifies, anything a technical reference document determines, or anything on the retired-mechanics list. Those are fixed. Latitude covers the gaps, not the decisions.

**Preset design.** Presets are the one place an amateur will experiment, so they must be legible at a glance:

- The name says what it does. A user must predict the result from the name without opening it. Plain descriptions beat film-stock trivia, in-jokes, or codenames. Playful naming may appear as a subtitle or in metadata, never as the primary label.
- One obvious visual promise per preset. If you cannot state what it does in one short sentence, it is doing too much or is not worth shipping.
- Ordered by usefulness to a beginner, with the safest, most flattering option first and selected by default.
- A visible preview or immediate result so the user sees what they are choosing.
- Intensity is adjustable in plain language (one strength control), not a bank of technical parameters. Technical parameters may exist underneath; they are not the surface.
- At least one preset is tuned specifically for portraits and skin, and is what a first-time user lands on.

While our presets derive their parameters from the reference apps, the naming, grouping, ordering, and surfacing are ours and follow the rules above even where a source app names things differently.

---

## 3 Question escalation — ask, do not guess

The principal holds the reference material and can extract any behavior you name. Therefore:

- If a ticket depends on a reference behavior the technical document does not fully determine, do not invent a parameter value, default, ordering, or threshold. Write a precise question to `docs/questions/[TICKET-ID]-q[n].md` naming the document, the section, the screen or mode, the exact behavior needed, why the current document is insufficient, and what you would build if forced to guess (so independent work can continue).
- Mark that sub-behavior **Blocked (question)** inside the ticket, complete everything independent in the ticket, and continue.
- The principal will answer; incorporate the answer into the same ticket before marking it Verified.
- Treat an incomplete section the same as a missing one: ask. A question is cheap; a hallucinated imaging parameter is expensive and will be rejected at review.
- Note the boundary: ask about reference behavior the documents do not cover; decide for yourself about product behavior the roadmap does not cover. The first is missing evidence. The second is your job.

---

## 4 Type A vs Type B

Every ticket is one of two shapes.

**Type A — reference-then-build.** The ticket has a named reference document and section. Read it, implement against it, and verify against the parameter values and pipeline order it describes. Acceptance requires both the reference citation and the working feature.

**Type B — build-own.** No reference document covers this. Record in `docs/decisions/` why no source document applies, then build against the design doc and the product goal. Acceptance requires the working feature and the rationale.

Where a reference document already contains the needed detail, Type A work is "implement against the existing section" — no re-extraction required.

---

## 5 Environment and handoff

Repository artifacts:

| Artifact | Purpose |
|---|---|
| `docs/product/` | Current design and build-plan references, this roadmap, retired-scope register |
| `docs/design/` | Immutable approved splash reference, asset manifest, fonts, screen comparisons |
| `docs/reference/halide/` | Copy or symlink of `HALIDE-IPA-TECHNICAL-PACKAGE.md`, plus any section extracts the agent produces |
| `docs/reference/lapse/` | Copy or symlink of `lapse-camera-settings.md` |
| `docs/reference/nofusion/` | Copy or symlink of `NO_FUSION_TECHNICAL_REFERENCE.md` |
| `docs/reference/comparison.md` | Three-way disagreement table and decisions |
| `docs/decisions/` | Engineering choices, capability decisions, build-own rationales, design-bias choices |
| `docs/questions/` | Escalated behavior questions awaiting an answer |
| `docs/presets/` | Our preset definitions, each traceable to a source document or marked original |
| `docs/roadmap-progress.md` | Ticket status, evidence links, commit IDs, blockers, next eligible ticket |
| `docs/capabilities/` | Device, OS, active camera, format, requested mode, observed support, timing |
| `tests/fixtures/` | Real source media, reference outputs, provenance |
| `tests/fixtures/halide-baseline/` | Halide outputs on the shared test photos (people in frame) |
| `tests/fixtures/nofusion-baseline/` | No Fusion outputs on the shared test photos |
| `tests/fixtures/lapse-baseline/` | Lapse outputs on the shared test photos |

Execution environment: Mac with current Xcode, plus a physical iPhone for camera validation. Simulator validates layout and local state only. Missing credentials are reported separately from compile success.

---

## 6 Shared contracts

Established as typed records in SET02. v3 contracts carry forward unchanged. Two additions:

| Record | Minimum information and invariants |
|---|---|
| **CameraDefaultConfig** | The shipped default camera configuration. Baseline from Lapse (`lapse-camera-settings.md` §1, §2) where recovered; overridden fields cite their Halide (`HALIDE-IPA-TECHNICAL-PACKAGE.md` §8) or No Fusion (`NO_FUSION_TECHNICAL_REFERENCE.md` §9) section. Every override is justified by the amateur/people goal or by pipeline necessity and recorded in `docs/decisions/`. Immutable per app version; user changes are separate records |
| **PresetDefinition** | Immutable ID; display name that follows §2 preset rules; source (`halide-*`, `nofusion-*`, `lapse-*`, `original`); base parameter set sourced from the corresponding technical document section; our overrides; engine version. Renaming never changes rendering |

Media writes use temp files, integrity checks, safe finalization, and a journal that recovers interrupted operations. A durable acknowledgment means recoverable source bytes exist. Thumbnails and final renders are derived resources and cannot silently replace the original. One coordinate contract runs from sensor orientation through preview crop, prime-equivalent framing, and final export. Keep the render working space and LUT input domain explicit. Exposure EV, warmth, and creative effect amounts must not change meaning between preview, still export, and companion video. A recipe with the same engine version, source, seed, and output settings must be reproducible.

Capability honesty: record device and OS, active camera and format, requested combination, API query results, observed result, timing, fallback. Test RAW, flash, depth, motion, manual exposure, and buffered capture in combinations. Never claim arbitrary RAW bit depth, true xenon flash, guaranteed zero shutter lag, universally available pre-shutter RAW frames, or lossless tiny-file archives. A supported fallback and an unachieved experimental target are separate facts.

---

## 7 Milestones

| Milestone | Outcome | Exit gate |
|---|---|---|
| M0 | Reproducible app, typed contracts, capability measurements, durable baseline, render harness, design assets, reference documents ingested | Setup evidence exists; unsupported behavior visible; no fake capture loop; every known reference gap filed as a question |
| M1 | Guest welcome, real camera, Natural pipeline, tactile controls, individual photo Library, local recovery | First complete local camera experience on device; every Type A ticket cites its reference section; **out-of-the-box people-photo test passes** |
| M1b | Primary output pipeline chosen; unified preset model; our preset set authored | One pipeline chosen with measured comparison weighted to portraits; presets reproducible; **preset legibility test passes** |
| M2 | Reversible Lab, Picks, review, lessons, archival packaging, contact sheets | User can recover, curate, and export personal photos reliably; presets survive archival round-trip |
| M2b | Library/asset model, edit versioning, selection/batch, import, export metadata | Device-verified |
| M3 | System entry, optional Spaces, verified cloud destinations, recipes, widgets | Private connected flows work without weakening local ownership |
| M4 | Creative capture, motion and audio, remotes, Reels, zines, postcards | Complete selection-based creative workflows with explicit compatibility choices; advanced features do not degrade the OOTB people result |
| M5 | Burst stacking, low-light blending, depth optics, geometry, cooperative light | Supported improvements measured; unverified targets distinguished from fallbacks |
| M6 | Reliability, design fidelity, accessibility, distribution candidate | Evidence and reproducible build accompany an honest coverage report; **OOTB people-photo test still passes with defaults untouched** |

---

## 8 Detailed tickets

Source abbreviations: `Halide REF` = `HALIDE-IPA-TECHNICAL-PACKAGE.md`; `Lapse SET` = `lapse-camera-settings.md`; `NF REF` = `NO_FUSION_TECHNICAL_REFERENCE.md`.

### M0 Foundation

| Step | Ticket | Type | Source | Notes |
|---|---|---|---|---|
| 001 | SET01 Reproducible native iOS project | B | — | v3 spec unchanged |
| 002 | SET02 Freeze product boundaries and engineering contracts | B | — | v3 spec unchanged, plus §6 records |
| 003 | SET03 Measure camera capabilities on actual devices | B | — | v3 spec unchanged |
| 004 | SET04 Prove durable capture and local recovery | B | — | v3 spec unchanged |
| 005 | SET05 Deterministic rendering and quality harness | B | — | v3 spec unchanged |
| 006 | SET06 Prepare immutable approved design assets | B | — | v3 spec unchanged |
| 006b | SET06b Ingest reference documents | B | — | New; see below |
| 006c | SET06c Capture mode and timing reference | A | Lapse SET §1, §2 | New; see below |

#### Step 006b SET06b Ingest reference documents
**Type:** B. **Depends on:** SET02.

**Behavior.** Give the repository one consistent reading of the three reference documents before any dependent feature is built.

**Implementation detail.** Place or symlink the three technical documents under `docs/reference/`. Build the three-way comparison table for every concern where they disagree (sharpening, tone curve, default format, exposure behavior, preset structure, metadata handling). Record a decision per disagreement naming the winning source and the reason, with the amateur/people goal as the tie-breaker where the documents do not. Establish Lapse's camera settings as the baseline for `CameraDefaultConfig` and enumerate every planned Halide or No Fusion override with its amateur/people rationale. List every reference gap — a behavior a ticket will need that the documents do not cover — in `docs/questions/` with the ticket that needs it.

**Acceptance.** Every reference item has a document and section path; every disagreement has a recorded decision; baseline and overrides are enumerated; every known gap is filed as a question.

#### Step 006c SET06c Capture mode and timing reference
**Type:** A. **Source:** Lapse SET §1 (session configuration, focus/exposure defaults, frame rate, photo dimensions, photo output settings, quality prioritization, orientation and stabilization), §2 (capture metadata tuple).

**Behavior.** Turn Lapse's capture configuration into first-class records we can build against.

**Implementation detail.** Document each element of Lapse's session configuration as fields of `CaptureModePreset` or `CameraDefaultConfig`. Preserve the session preset, audio session flags, centered continuous AF/AE defaults, low-light boost and smooth autofocus flags, dimension-selection rule, HEVC preference, quality-prioritization logic, orientation/mirroring/stabilization split, and the capture metadata tuple (temperature, tint, ISO, duration, scene EV) as the primary reference. Where Halide REF §8 or NF REF §9 has a different or better default for our product goal, override that field and cite the section.

**Acceptance.** Every documented Lapse capture setting is representable; the capture metadata tuple is documented; every override cites its reference section and its rationale.

### M1 Core camera

| Step | Ticket | Type | Source |
|---|---|---|---|
| 007 | B01 App identity | B | — |
| 008 | B06 Material and color system | B | — |
| 009 | B07 Editorial and technical type | B | — |
| 010 | B08 Approved welcome film artwork | B | — |
| 011 | O01 Immediate guest camera | B | — |
| 012 | O04 Itemized permission receipt | B | NF REF §10 (permission-denial handling) |
| 013 | O02 Approved welcome | B | — |
| 014 | U01 Photo-first camera layout | B | — |
| 015 | L01 Local photo ownership | B | — (see M2b) |
| 016 | R11 Recovery metadata and originals | A | NF REF §5 (negative mode / master tape) |
| 017 | C04 Responsive shutter and queue | A | Halide REF §1 |
| 018 | N05 Immediate photo access | B | — (see M2b) |
| 019 | N02 Chronological Library | B | — (see M2b) |
| 020 | R01 Real background development | A | Halide REF §1; Lapse SET §3 engine selection |
| 021 | L05 Per-photo development | B | — |
| 022 | C01 Natural Lens Bayer capture | A | Halide REF §1 |
| 023 | C02 Coverage safety capture | A | Halide REF §1 |
| 024 | C03A Low-light fallback | A | Lapse SET §1 (quality prioritization, low-light boost); Halide REF §1 |
| 025 | R02 Highlight shoulder | A | Halide REF §2 (LUT tone curve; LUT byte payloads) |
| 026 | R03 Scene-aware color science | A | Halide REF §2 (LUT payloads, `EditorFilter.outputImage` branch order); NF REF §3 (preset fields: temperature, tint, HSL, LUT intensity) |
| 027 | R04 Halation and bloom | A | Halide REF §2 (`HalationFilter.init` cutoff/radius/gains, downsample/blur/scale/color-match path); Lapse SET §7 (Metal halation luma/red thresholds, sigmas, colors, intensities) |
| 028 | R05 Luminance grain | A | Halide REF §2 (`GrainSimulationFilter` kernel, per-pixel grain); Lapse SET §6/§7 (CI grain `1 - 0.05*sceneEV`; Metal seeded integer-hash grain) |
| 029 | C10 Prime focal lengths | A | Halide REF §8 (lens preset enum: 28/35/42/50/200); Lapse SET §1 (zoom clamp) |
| 030 | U07 Brightline outside margin | A | Halide REF §6 (guide types — ask for geometry detail); Lapse SET §4 (aspect-fill geometry) |
| 031 | C07 Disposable flash rendering | A | Lapse SET §1 (flash-on/off request bytes, auto red-eye, virtual fusion); Halide REF §8 (flash state not recovered — ask) |
| 032 | U13 Capacitor status | A | Halide REF §8 |
| 033 | U12 Film Box End-Flap | B | — |
| 034 | U02 Mood exposure swipe | A | NF REF §6 (exposure bias clamp, semi-automatic controller); Lapse SET §2 (scene EV) |
| 035 | N01 Unrestricted capture and Mood dial | B | — |
| 036 | U03 Warmth thumb wheel | A | NF REF §6 (WB offset); Lapse SET §2 (temperature/tint fallbacks) |
| 037 | R08 Develop Exposure dial | A | Halide REF §1 (`CIRAWFilter` exposure, baseline exposure, boost, boost-shadow) |
| 038 | U09 Physical shutter buttons | A | Halide REF §7 (`HLDVolumeControl` singleton, `MPMusicPlayerController` volume path) |
| 039 | U06 Level haptic | B | — |
| 040 | B10 Mechanical feedback | B | — |
| 041 | O03 Trace to reveal | B | — |
| 042 | B02 App vocabulary | B | — |
| 043 | B03 Inspiration credits | B | Cites Halide, Lapse, No Fusion |

**M1 exit gate.** First complete local camera experience works on device. Every Type A ticket cites its reference section and carries a comparison fixture against that app's output on the same scene, evaluated with people in frame. `CameraDefaultConfig` matches the Lapse baseline with every override documented and justified. **Out-of-the-box people-photo test:** hand the app to a user who has never seen it, with no instruction, and have them photograph a person. The result must be good. Record the test.

### M1b Pipeline choice and preset foundation

#### Step 043a SET11 Choose primary output pipeline
**Type:** A. **Depends on:** C01, R03, C07. **Source:** Halide REF §1, §2; Lapse SET §3, §5, §7, §8; NF REF §1.

**Behavior.** Pick one primary and one fallback pipeline before preset work depends on it.

**Implementation detail.** Document the three pipelines side by side: input format, processing steps, sharpening behavior, output container, file size, latency. Halide's `EditorFilter.outputImage` branch order and LUT payloads from Halide REF §2. Lapse's `photo_default` and `instant_default` Metal pipelines, `journal` CI pipeline, and LUT reproduction from Lapse SET §5, §7, §8. No Fusion's `CIRAWFilter` + HEIF+ encode path from NF REF §1. Run all three on the shared fixture set with people in frame. Blind-review weighted toward portraits and skin. Record the choice, reasons, and fallback.

**Acceptance.** Written comparison with measured latency, file size, and a blind quality review weighted to portraits and skin; one primary pipeline chosen; fallback documented.

#### Step 043b SET12 Build the unified preset model
**Type:** A. **Depends on:** SET11, R12. **Source:** Halide REF §2, §3; Lapse SET §5, §7; NF REF §3, §4.

**Behavior.** One preset model that can represent every preset from all three reference documents and render them in a single documented order.

**Implementation detail.** Define `PresetDefinition` and `PresetOverride`. Import Halide's LUT-driven Looks (Zephyr, Rembrandt, Chroma Noir, Valencia, Nova, DAWN, Quicksilver, from Halide REF §2 LUT payloads; custom-effect parameters from `LookCustomization` in §3). Import Lapse's `photo_default`/`instant_default` Metal pipelines and CI journal pipelines (Lapse SET §7, §5) as base presets. Import No Fusion's 20 built-in presets from NF REF §3 (fields: contrast, saturation, exposure, highlight, shadow, black, white, temperature, tint, vibrance, per-color HSL, LUT intensity, grain amount/size, bloom amount/radius, vignette intensity/radius) with their LUT byte references from §4. Tag each with its source. Define the render order so all three sources map into one graph without silent reinterpretation. Where a source parameter has no equivalent, ask rather than approximate.

**Acceptance.** Every preset is representable; the render graph runs all sources in a documented order; a preset from any source renders reproducibly on the fixtures.

#### Step 043c SET13 Author our own presets on top
**Type:** B. **Depends on:** SET12, SET11.

**Behavior.** Ship a small, legible preset set that follows the §2 preset rules.

**Implementation detail.** Author 4–6 presets. Each is either a documented delta from a reference base or marked `original` with rationale. Naming follows the §2 rules (plain description, one obvious promise, no codenames). Order by usefulness to a beginner; the portrait/skin preset is first and default. One strength control per preset. Tune on the shared fixture set across skin tones and lighting, weighted to people.

**Acceptance.** Each preset renders reproducibly; its delta or original rationale is documented; blind review confirms each preset is at least as good as its base on the fixtures; **preset legibility test passes** — a user unfamiliar with the app, shown the preset list, can predict what each one does.

**M1b exit gate.** One primary pipeline chosen (blind review weighted to portraits); unified preset model shipped; our preset set authored and reviewed; preset legibility test passes; Lapse capture-mode presets available as capture-side defaults.

### M2 Lab curation and portable output

| Step | Ticket | Type | Source |
|---|---|---|---|
| 044 | B04 Preset naming | A | Halide REF §2 (Look names for reference); Lapse SET §7 (pipeline names); NF REF §3 (preset descriptions). Rename per §2 rules |
| 045 | G06 Stars and ratings | B | — |
| 046 | N03 Picks view | B | — |
| 047 | L09 Subtle processing feedback | B | — |
| 048 | R09 Reversible film and warmth | A | NF REF §5 (negative re-edit); Halide REF §1 (`CIRAWFilter` redevelop path) |
| 049 | R07 Photo and batch Lab Options | A | Halide REF §3 (`CustomParameters` toggles and scalar fields); Lapse SET §7 (per-effect scalar ranges) |
| 050 | R06 Disposable lens character | A | Halide REF §2 (`MTFFilter`, vignette defaults) |
| 051 | G13 Removable stamp and borders | B | — |
| 052 | R12 Carbon Copy recipe authoring | A | NF REF §4 (preset serialization, LUT import) |
| 053 | G04 Carbon Credits metadata | B | — |
| 054 | B05 Tape and stamped labels | B | — |
| 055 | G11 Tangible print detail | B | — |
| 056 | B09 Surface effects | B | — |
| 057 | G05 Light Table review | B | — |
| 058 | U04 Sunburn Glow | A | Halide REF §1 (clipping indicators — ask for details) |
| 059 | U05 Rangefinder focus patch | A | Halide REF §4 (`FocusPeakingFilter` pipeline: sampled source, Gaussian blur subtract, luminance, `inputPower = 5/11`, color matrix overlay, crop, gamma, add; `FocusLoupeFilter` transform) |
| 060 | U08 Distance coaching | B | — |
| 061 | C18 Skin-protected color | A | Halide REF §2 (Rembrandt Look parameters); Lapse SET §5 (FaceBalance, SkinToneTwo stages) |
| 062 | U14 Ten-day lessons | B | — |
| 063 | SET08 Validate archival packaging | A | NF REF §5 (negative storage); Halide REF §1 (DNG export) |
| 064 | R10 One logical HEIF and RAW asset | A | NF REF §1 (HEIF+ path) |
| 065 | G02 Printable contact sheets | B | — |
| 066 | N06A Selection-based keepsakes | B | — |

**M2 exit gate.** Single-user beta with archive and export round-trips. Every Type A ticket cites its reference section. Our preset set survives archival round-trip.

### M2b Library, versioning, batch, import, export

Unchanged from v3 — N07, R14, N08, N09, G15 with the same acceptance checks. The only change is the G15 source citation:

| Step | Ticket | Type | Source |
|---|---|---|---|
| 066e | G15 Export metadata and round-trip | A | Lapse SET §9 (metadata handling); NF REF §9 (metadata writing) |

### M3 System integration and optional sharing

| Step | Ticket | Type | Source |
|---|---|---|---|
| 067 | U15 Fast system entry | A | Halide REF §7 (`LockedCameraCapture` framework symbols) |
| 068 | U10 Camera Control integration | A | Halide REF §7 (ask for Camera Control integration detail — marked not recovered) |
| 069 | R13 Scan to clone recipes | A | NF REF §4 (`StylePreset` serialization, LUT reference policy) |
| 070 | L02 iCloud backup and sync | B | — |
| 071 | L03 Google Photos destination | B | — |
| 072 | N04 Optional Spaces view | B | — (net-new) |
| 073 | SET07 Remote service contract | B | — (net-new) |
| 074 | L11 Private social scope | B | — (net-new) |
| 075 | L07 Optional shared Spaces | B | — (net-new) |
| 076 | G07 CC Home Screen widget | B | — |
| 077 | G12 Print back information | A | NF REF §5 + Halide REF §1 |

### M4 Creative capture and keepsakes

| Step | Ticket | Type | Source |
|---|---|---|---|
| 078 | C05 Three-frame safety selection | A | Halide REF §1 (burst behavior — ask for specifics) |
| 079 | C08 Party Drag | A | Halide REF §1, §8; Lapse SET §1 (flash/EV combination) |
| 080 | C09 Black and white Snap Focus | A | Halide REF §2 (Mono Street parameters — ask); NF REF §6 (manual focus path) |
| 081 | C14 Super 8 motion capture | A | NF REF §2 (Live Photo assembly, 3.6s wait budget, AAC audio settings, paired asset resource types 1 + 9) |
| 082 | G14 Moving print playback | A | NF REF §2 |
| 083 | G10 Voice Backings | B | — |
| 084 | C12 Local double exposure | B | — |
| 085 | C13 Remote double exposure | B | — |
| 086 | C15 Shake accidents | B | — |
| 087 | C16 Reversible edge light leak | B | — |
| 088 | C19 Fake-Out candid | B | — |
| 089 | C20 Posing micro-prompts | B | — |
| 090 | C21 Eye-Catch cue | B | — |
| 091 | C22 Matchbox Softbox | B | — |
| 092 | SET09 Nearby pairing | B | — |
| 093 | C25 Friend phone remote | B | — |
| 094 | C24 Apple Watch remote | B | — |
| 095 | G03 Reel montage | B | — |
| 096 | G08 Monthly Carbon Zine | B | — |
| 097 | SET10 Print provider | B | — |
| 098 | G09 Postcard packs and ordering | B | — |
| 099 | N06B Selection-based keepsakes | B | — |

**M4 exit gate.** Creative capture works with explicit compatibility choices. Live Photo and Portrait paths validated against NF REF §2. Out-of-the-box people-photo result from Part 1 is unchanged with defaults untouched.

### M5 Advanced imaging experiments

| Step | Ticket | Type | Source |
|---|---|---|---|
| 100 | C06 Raw burst stacking | A | Halide REF §1 (burst — ask for specifics) |
| 101 | C03B Low-light blending | A | NF REF §1 (`CIRAWFilter` config, gain map); Halide REF §1 |
| 102 | C11 Vintage Glass bokeh | A | NF REF §2 (Depth Anything V2 Small F16 model, 518×392 grayscale output, `hdis` packaging, 1.2998 multiplier, resized to max edge 768) |
| 103 | C17 Group face geometry | B | — |
| 104 | C23 Co-Op Flash | B | — |

### M6 Release qualification

| Step | Ticket | Type | Source |
|---|---|---|---|
| 105 | REL01 Reliability and performance qualification | B | — |
| 106 | REL02 Design fidelity and accessible complete flows | B | — |
| 107 | REL03 Reproducible distribution candidate | B | — |

**M6 exit gate.** No lost acknowledged originals; state recovery passes; approved splash intact; every key action has an accessible route; no retired mechanic or nonfunctional control exposed; reproducible build with an honest coverage report; **out-of-the-box people-photo test still passes with defaults untouched**.

---

## 9 Coverage register

Unchanged from v3 except that every "Source" cell now uses the shorthand `Halide REF §n`, `Lapse SET §n`, `NF REF §n` as defined in §8. The Type column is unchanged.

---

## 10 Retired scope register

Unchanged from v3. O05, U11, L04, L06, L08, L10, G01 remain retired.

---

## 11 First instruction to the agent

```text
Read the three technical reference documents (HALIDE-IPA-TECHNICAL-PACKAGE.md, lapse-camera-settings.md, NO_FUSION_TECHNICAL_REFERENCE.md), this roadmap, the design doc, and the build plan.

Two rules govern your judgment:

1. Product goal and design bias (roadmap §2): Carbon is an amateur-first camera for photographing people. It must produce a good photograph of a person on the first shutter tap, with zero configuration, by a user who has never seen the app. Where the roadmap, build plan, design doc, and reference documents are silent, make the choice that best serves that user and record it in docs/decisions/. Where a reference document marks something as unknown, not recovered, or cannot be recovered, file a precise question in docs/questions/ and continue with independent work — do not invent parameter values.

2. The three technical reference documents are the source for reference behavior, parameters, pipeline order, filter values, and defaults. Use them.

Execute only SET01. Make routine implementation decisions autonomously, record material choices, and run the checks available in the actual environment. Do not claim camera or device verification from a simulator or mock.

When SET01 is complete, report what works, the exact build and test results, environment limitations, changed modules, any open questions, and the next eligible ticket. Update roadmap progress and stop.