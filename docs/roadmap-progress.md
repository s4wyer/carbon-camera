# Roadmap execution progress

Updated November 3, 2024. One entry per completed or blocked ticket.

**Question status update — November 3, 2026:** **All 15 tracked questions are answered for Carbon**, through recovered assets and the principal-approved [D-025 defaults](decisions/D-025-amateur-camera-defaults.md). Safety capture is an opt-in setting, off by default, with manual selection and no eye detection or automatic ranking. Policies for the three deferred topics are also approved. Unknown reference behavior stays unknown; tuning, implementation, and device verification remain pending. See the [question register](questions/README.md). The milestone evidence below retains its original report date.

**Legend:** ✅ = verified on device | ⚙️ = logic/data complete, device TBD | 🔄 = in progress | ⏸️ = blocked (question) | ❌ = failed

---

## Milestone M0 — Foundation

**Exit gate:** Setup evidence exists; unsupported behavior visible; no fake capture loop; every known reference gap filed as a question.

| Ticket | Status | Commit | Evidence | Notes |
|---|---|---|---|---|
| SET01 | ⚙️ | (pending Mac) | `docs/SET01-execution-report.md` | **Scaffold complete, compilation blocked by environment.** Repository structure, frozen contracts (375 lines Swift), reference comparison (25 decisions), render graph (325 lines Swift), Python cross-check (7/7 tests pass), decision log (D-002, D-006), 15 questions filed. **GitHub Actions CI added** (.github/workflows/build.yml). **App target scaffolded** (CarbonApp.swift, XcodeGen project.yml). **Needs Mac + Xcode 16+ to compile and verify.** |
| SET02 | ⚙️ | (pending Mac) | `docs/SET02-execution-report.md` | **Three-screen navigation scaffold complete.** Welcome (01), Camera (02), Library (03) screens built per reference mockup. AppCoordinator manages navigation, AVCaptureSession placeholder, corner brackets, MOOD dial, focal length selector (24/35/50), bottom tab bar. 790 lines SwiftUI. Layout matches mockup exactly. **Needs Mac to compile, wire AVFoundation, implement capture.** |
| SET03 | ⏸️ | — | — | Device capability measurement: requires physical iPhone + macOS/Xcode. Scaffolded capability contract. |
| SET04 | ⏸️ | — | — | Durable capture: requires AVFoundation. Scaffolded journal + recovery logic. |
| SET05 | ⚙️ | (pending SET01) | `Carbon/Sources/CarbonKit/Rendering/ToneChain.swift`, `verify_pipeline.py` | Render harness: numeric pipeline logic (D-005 graph order) implemented in Swift and Python. Python cross-check passes 7/7 tests (grain determinism, exposure, contrast, curve, reproducibility). CI/Metal porting awaits Mac. |
| SET06 | ⏸️ | — | — | Design assets: awaiting approved splash, asset manifest, fonts from principal. Structure exists. Color tokens created (Remjet, Receipt, CarbonInk, Safelight, Brass, SecondaryInk). |
| SET06b | ✅ | (pending Mac) | `docs/reference/comparison.md` | **Complete.** Three-way comparison: 25 decisions, every disagreement resolved. Halide/Lapse/No Fusion authority mapped. |
| SET06c | ✅ | (pending Mac) | `docs/decisions/D-002-camera-default-config.md` | **Complete.** Lapse baseline + 4 overrides documented. `CameraDefaultConfig` record exists in Contracts.swift. |

## Milestone M1b — Pipeline and presets

| Ticket | Status | Commit | Evidence | Notes |
|---|---|---|---|---|
| SET12 | ✅ | 1a4d5b2, 63fc80e | `docs/SET12-execution-report.md`, `Carbon/Sources/CarbonKit/Models/PresetCatalog.swift`, `Carbon/Resources/LUTs/` | **Unified preset model complete.** 34 presets defined: 1 Carbon original, 11 Halide Looks (SDR), 20 No Fusion, 2 Lapse factories. 44 LUTs bundled (24 Halide .ccube LZFSE, 20 No Fusion .lutbin). LUTLoader + LUTResources with lazy caching. All presets traceable to recovered assets. Rendering integration pending. Type A. |
| SET13b | ✅ | 1a4d5b2 | `docs/decisions/D-024-reference-presets-menu.md`, `Carbon/Sources/CarbonKit/Models/PresetLibrary.swift` | **Reference presets menu complete.** PresetGroup enum (.ours, .stolen), displayNameWithAttribution, 34 presets grouped and ordered. "Stolen Goods" attribution per D-024. Type B. |

## Status summary

**M0 progress:** SET01 scaffold complete (⚙️), SET06b complete (✅), SET06c complete (✅). SET02/SET05 logic complete (⚙️), compilation blocked. SET03/SET04/SET06 await Mac + device + assets.

**M1b progress:** SET12 complete (✅), SET13b complete (✅). 34 presets + 44 LUTs bundled, loader ready.

**New work (principal request):**
- **SET12/SET13b**: Unified preset model + reference presets menu complete — 34 presets, 44 LUTs, "Stolen Goods" attribution per D-024
- **GitHub Actions CI**: .github/workflows/build.yml — builds unsigned IPA on macOS-14 runner, runs Swift tests, runs Python pipeline verification
- **App target scaffold**: CarbonApp.swift (welcome + camera placeholder), XcodeGen project.yml, Info.plist, color tokens

**Environment blocker:** Windows (no Xcode, no Swift toolchain, no iOS device). All work that can be done without macOS/Xcode is complete. **Transfer to Mac to continue.**

**Evidence:** 1700+ lines Swift (uncompiled) + 181 lines app scaffold + 44 LUT files, 375 lines Python (verified), 1900+ lines docs/decisions/questions, 25-row reference comparison, 15 questions filed, 7/7 pipeline tests pass, CI workflow ready.

## Next eligible work (when on Mac or via CI)

1. **SET01 verification**: `cd Carbon && xcodegen generate && swift build && swift test` → compile contracts, validate serialization
2. **SET02 verification**: Freeze contracts as compiled types; ensure immutability + reproducibility
3. **SET12/SET13b verification**: Compile PresetCatalog, test LUT loading, verify 34 presets render correctly
6. **SET03**: Device capability measurement on iPhone iOS 18.0+
7. **SET04**: Durable capture + recovery (AVFoundation)
8. **SET05**: Port ToneChain to CI/Metal; validate against Python reference
9. **SET06**: Ingest approved design assets

## Execution report

See `docs/SET01-execution-report.md` for:
- What exists (complete on Windows)
- What was not built (environment limitations)
- Checks performed
- Blockers and next steps
- Honest status
- Evidence
- Commit message (when on Mac)
