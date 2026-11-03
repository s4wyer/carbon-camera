# Halide 3.3.1 Dev IPA: Technical Reference

## 1. Process Zero pipeline and Image Lab

**Recovered implementation evidence**

- `LuxFilters.EditorSystem.NativeRAWGraph.makeOutputImage(output:targetDynamicRange:)` configures a `CIRAWFilter` with orientation, exposure, baseline exposure, boost, boost-shadow, color-noise reduction, moire reduction, detail, local tone map, luminance-noise reduction, neutral temperature/tint, shadow bias, sharpness, and lens-correction. It explicitly sets extended-dynamic-range amount to `0.0` and installs a linear-space `EditorFilter` before requesting `outputImage`.
- `CIRAWFilterOption.makePureRAWOptions(applyOrientation:ev:)` constructs the pure-RAW option dictionary. Recovered defaults include boost `0.0`; boost-shadow, noise-reduction, color-noise, noise-reduction sharpness/contrast, moire, EV, and bias as `0`/`0.0`; chromatic-noise tracking, sharpening, and vendor-lens-correction disabled. Orientation is added only when `applyOrientation` is true.
- `LookupTableIO.decompress(_:dimensions:)` uses Apple `COMPRESSION_LZFSE`; the compressed stream decodes to `dimension^3 * 6` bytes, three 16-bit half-float RGB channels per texel. The shipped `.ccube` resources all expanded to `215,622` bytes, which is `33^3 * 6`. The decoder converts each half-float RGB triplet to float outputs and appends alpha `1.0` per texel for the lookup-table object. The exact compressed/decompressed hashes and raw decoded payloads are recorded in `recovery/evidence/lut-decode.json` and under `recovery/resources/luts/`; the raw files are the post-LZFSE half-float payload, not a textual `.cube` export.
- The recovered `EditorFilter.outputImage` path applies branches in this order when enabled: optional tone mapping or Exposure Fusion -> vignette -> MTF -> halation -> grain -> LUT/grade -> optional depth processing. The graph's initial source and RAW setup occur before these optional branches; settings flags and parameter values determine whether each branch executes.
- `ExposureFusionFilter` fallback defaults are: `inputTarget = 0.25` (IEEE float bits `1055286886`), `inputSigma = 0.1` (bits `1036831949`), `inputLevels = 10`, empty `inputEVs`, and `inputPeakStops = 0`. `EditorParameters.fusion` separately initializes graph-level levels to `9` and a scalar to `0.5`; graph values may override the filter fallback. The graph computes `peakStops = exp2(inputPeakStops)` before passing it to the Metal kernel. The kernel receives image, EV list, target, sigma, levels, and peak-stop parameters. The exact per-pixel kernel equation is in the compiled Metal library and was not reconstructed into source here.

**Observed modules/resources**

- Main application: `Payload/Halide.app/Halide` (arm64 Mach-O, 3,840,544 bytes).
- Camera implementation framework: `Payload/Halide.app/Frameworks/HalideCamera.framework/HalideCamera`.
- Image/filter framework: `Payload/Halide.app/Frameworks/LuxFilters.framework/LuxFilters`.
- `HalideCamera.framework` contains `ChromaNoirSceneSDR.ccube`, `ChromaNoirSceneHDR.ccube`, `ChromaNoirDisplaySDR.ccube`, `ChromaNoirDisplayHDR.ccube`, and SDR/HDR LUTs for Dawn, Elysia, Nova, Onyx, Quicksilver, Rembrandt, Scarlet, and Zephyr. It also contains Valencia SDR/HDR and Apple Log-to-PQ LUTs. `LuxFilters.framework` contains `p0sdr.ccube` and `p0hdr.ccube`.
- Swift symbols include `HalideCamera.Look.processZero` and `LuxFilters.EditorAdjustment.isRAWOnly`; UI strings name Process Zero and Image Lab-like editing functionality.

**Still not fully recovered**

- Exact AVCapture request flags proving one-frame Bayer RAW capture and disabling Smart HDR, Deep Fusion, or other computational photography. The filter side is recovered, but capture configuration lives in the camera controller/extension and was not yet traced.
- DNG container decode, sensor metadata handling, demosaic, color calibration, and the preview-development handoff. `NativeRAWGraph` and pure-RAW `CIRAWFilter` options are established; the upstream DNG-to-graph call chain is not.
- The single Image Lab exposure slider's user-facing range, exact working color space, tone curve, and complete redevelop equation. The graph exposes RAW exposure and Apple RAW controls, but not yet the slider's UI mapping.
- Tone Fusion slider bounds and exact highlight/shadow recovery equation. The fusion API boundary and defaults are recovered, but the Metal per-pixel kernel equation remains opaque.

Decoded LUT values and resource hashes are retained in `recovery/evidence/lut-decode.json`; filenames alone are no longer the only LUT evidence.

## 2. Film Looks and rendering graph

The executable's Swift metadata exposes look cases `processZero`, `systemQuality`, `nova`, `zephyr`, `valencia`, `rembrandt`, `scarlet`, and `chromaNoir`; `LuxFilters.SystemGrade` also exposes `apple`, `processZero`, and `defaultGrades`. The shipped framework resource inventory exposes LUT sets for Dawn, Elysia, Onyx, Scarlet, Quicksilver, Rembrandt, Nova, Zephyr, Valencia, and Chroma Noir. `SystemGrade.processZero` constructs the Process Zero grade and its loaders use the `p0sdr` and `p0hdr` resource identifiers. Each decoded LUT payload in this build is a 33³ table of half-float RGB triplets; the runtime lookup object appends alpha 1.0. The per-look LUT byte values are retained in `recovery/evidence/lut-decode.json` and `recovery/resources/luts/`.

| Requested Look | Directly observed resources/evidence | Recovered LUT data and remaining per-look parameters |
|---|---|---|
| Zephyr | `ZephyrDisplayP3SDR.ccube`, `ZephyrDisplayP3HDR.ccube`; `Look.zephyr` and grade identifiers | Exact decoded 33³ half-float RGB payloads are retained in `recovery/resources/luts/` with hashes in `recovery/evidence/lut-decode.json`. The source-space matrix/curve representation is not separately stored; effect values use the shared graph defaults unless a custom parameter set overrides them. |
| Rembrandt | `RembrandtSDR.ccube`, `RembrandtHDR.ccube`; `Look.rembrandt` and grade identifiers | Exact decoded LUT bytes retained; per-look persisted custom-effect values and UI mappings remain unresolved. |
| Chroma Noir | Scene and Display SDR/HDR LUT resources; `Look.chromaNoir` symbol | Exact decoded LUT bytes retained for scene/display resources; matrix/channel-mix source representation and per-look custom values remain unresolved. |
| Valencia | `ValenciaDisplayP3SDR.ccube`, `ValenciaDisplayP3HDR.ccube`; `Look.valencia` | Exact decoded LUT bytes retained; per-look custom values remain unresolved. |
| Nova | `NovaSDR.ccube`, `NovaHDR.ccube`; `Look.nova` | Exact decoded LUT bytes retained; per-look custom values remain unresolved. |
| DAWN | `DawnSDR.ccube`, `DawnHDR.ccube`; `SystemGrade` identifier | Exact decoded LUT bytes retained; exact user-facing grade mapping and per-look custom values remain unresolved. |
| QuickSilver | `QuicksilverSDR.ccube`, `QuicksilverHDR.ccube`; `GradeStore.Identifier.quicksilver` | Exact decoded LUT bytes retained; exact user-facing capitalization/mapping and per-look custom values remain unresolved. |

Recovered filter/effect implementation:

- `HalationFilter.init`: cutoff `1.0`, radius `4.0`, channel gains `(1.0, 0.35, 0.1)`. Its output path downsamples by `0.25`, applies a red/green/blue channel-isolated color filter using the gains, clamps, Gaussian-blurs with `radius * 0.25`, scales back by `4.0`, color-matches to the working space, and adds the result to the background. `EditorFilter` sets cutoff to `1.0` and scales custom channel gains by a scalar parameter.
- `GrainSimulationFilter.init`: peak white, strength, grain size, and scale all default to `1.0`. The output builds a procedural Metal grain kernel, with image extent transformed by `1 / inputScale` and then `1 / inputGrainSize`; strength is passed directly to the kernel. No seed property or deterministic seed constant was exposed in this class.
- `MTFFilter.init`: frequency, radius, and strength default to `1.0`. Its implementation gamma-adjusts with power `0.55`, blurs at the frequency, subtracts from the source, blurs the result at the radius, multiplies by `2.0`, adds it back, then gamma-adjusts with power `2.2`. `EditorFilter` supplies the custom frequency, radius, and strength fields.
- Vignette uses Core Image `vignetteEffectFilter`: intensity is the custom intensity, falloff is the custom falloff, center is the image extent midpoint, and radius is half the larger image dimension. The default geometry is therefore centered and aspect-normalized by the maximum extent dimension.
- `EditorParameters.fusion` initializes the fusion parameter object with a visible scalar `0.5` and level count `9`; the filter object itself defaults to 10 levels. The remaining fusion fields are conditional/default storage values and require the surrounding parameter struct layout to map fully.
- The recovered `EditorFilter.outputImage` path applies branches in this order when enabled: optional tone mapping or Exposure Fusion -> vignette -> MTF -> halation -> grain -> LUT/grade -> optional depth processing. The graph's initial source and RAW setup occurs before these optional branches; settings flags and parameter values determine whether each branch executes.
- `LookCustomization` fields are `film`, `texture`, `halation`, `vignette`, `mtf`, plus HDR; `CustomParameters` additionally contains enabled flags and scalar fields for grain, halation, vignette, MTF, raw sharpen, and white-balance offset.

## 3. Film tab toggles and intensity controls

The Film tab's model is recovered in the filter framework. `CustomParameters` has optional Boolean toggles `filmEnabled`, `grainEnabled`, `halationEnabled`, `vignetteEnabled`, and `mtfEnabled`; scalar fields are `grainLevel`, `halationRadius`, `vignetteIntensity`, `mtfFrequency`, `mtfRadius`, and `mtfStrength`. `LookCustomization` uses field masks/values to track whether `film`, `texture`, `halation`, `vignette`, and `mtf` are customized; it also exposes `isGrainCustomized` and `isHDREnabled`.

Recovered effect-object defaults are listed in section 2: halation cutoff/radius/gains `(1.0, 4.0, 1.0/0.35/0.1)`, grain peak-white/strength/size/scale all `1.0`, and MTF frequency/radius/strength all `1.0`. These are filter fallback defaults, not proof that each Look persists the same effective intensities. The Film UI's exact slider min/max bounds and nonlinear user-to-parameter mappings remain unknown; the `CustomParameters` names and filter defaults do not by themselves prove those UI ranges.

## 4. Focus peaking and focus loupe

Focus peaking is implemented in `LuxFilters.FocusPeakingFilter`:

1. `inputImage` is sampled nearest and clamped.
2. A Gaussian blur with radius `0.55` is subtracted from the image.
3. The difference is clamped and passed through a luminance filter.
4. The luminance result is filtered with `CIColorPolynomial` using `inputPower = 0.4545454545` (5/11) to amplify the response.
5. A `CIColorMatrix` overlays the response using the configurable `peakColor`. The initializer sets peak color to CIVector `(0.0, 10.0, 0.0, 1.0)`; this is a green overlay, with the green coefficient intentionally above 1.
6. The overlay is cropped to the source extent, then a second `CIColorPolynomial` uses `inputPower = 2.2`, and the result is added to the source.

The recovered edge threshold is therefore an implicit high-frequency residual, not a named numeric threshold. The binary does not expose a separate threshold property.

Focus loupe is implemented by `FocusLoupeFilter` with `inputImage` and `inputPoint` (`CIVector`, initialized to `(0.5, 0.5)`) and an `outputImage` method. For image extent `(x,y,w,h)` and normalized point `(u,v)`, the filter computes center `cx = w/2 - (u - 0.5) * w`, `cy = h/2 + (v - 0.5) * h`; it translates the image by `(-cx,-cy)`, scales by `2.0`, translates back by `(cx,cy)`, crops the result to the source extent inset by 25% of width and height, and source-over composites that crop against the original image. The legacy view has `loupeCenterXConstraint` and `loupeCenterYConstraint`; the code that updates those constraints and the coordinate-origin convention for the live focus point remain unresolved.

## 5. Manual-control degradation indication

The settings model exposes manual/automatic controls and `TelemeterCaptureConfiguration.CaptureConfiguration.isManualWhiteBalance`, implemented as a bit test `(flags & 0x01000000) != 0`. Manual exposure state and UI strings are also present, but the persistent visual indicator's view/update path was not fully recovered. Exact indicator rendering, lifetime, reset transitions, and whether shutter, ISO, and WB indicators share state remain unknown.

## 6. Composition-guide geometry

IDA confirms a `GuideView` type with a `Mode` enum and separate `GoldenRatioView` and `RabatmentView` types. The settings model has a `GuideMode` enum. A `LensGuideView` also exists. The recovered functions were enum accessors, SwiftUI/UIKit type metadata, and unimplemented initializer stubs; the actual body/path drawing methods and mode-to-view dispatch were not recovered.

Still unknown: rule-of-thirds coordinates, golden-ratio constant and line construction, uniform-grid subdivisions, Rabatment geometry, safe-area/orientation handling, aspect-fill transforms, line widths, and drawing primitives. Do not infer geometry from guide names.

## 7. Hardware shutter events and Camera Control

Observed app-intent strings include `com.chromanoir.halide.fire-shutter`, `com.chromanoir.halide.take-photo`, and `com.chromanoir.halide.take-manual-photo`. The capture extension is `Payload/Halide.app/Extensions/CaptureExtension.appex/CaptureExtension`; it is a separate arm64 Mach-O. Framework symbols include Apple `LockedCameraCapture` types such as `LockedCameraCaptureManager` and session-content updates.

Recovered volume-shutter path:

- `LuxCamera.VolumeShutter` is constructed through `HLDVolumeControl.shared`, passing a callback/observer object into the wrapper.
- The object has `isListening`, `state`, `audioSession`, and `observer` fields, and handlers for `audioSessionInterrupted:` and `applicationStateDidChange:`. The app creates the volume-shutter object while constructing photo-review/camera UI.
- `PhotoReviewController.init` invokes `VolumeShutter` construction and stores it in the controller setup state. This proves the physical-volume capture subsystem is wired into the review/camera path.
- `HLDVolumeControl.shared` is a singleton. Its `volume` getter reads `MPMusicPlayerController.applicationMusicPlayer.volume`; its setter writes back through `setVolume:`. The class therefore uses the system music volume as the event-control channel, with `MPVolumeView`/`outputVolume` symbols also present in the framework.
- The high-level `HalideCamera.VolumeShutter` type has explicit state, button-press, callback, host-view, and `isUsingNativeButtonDetection` fields. The callback construction is visible, but the callback implementation is in the opaque `sub_2DCD04`/related closure path.

Not yet recovered: the `HLDVolumeControl` callback body, exact volume-event-to-capture mapping, Camera Control integration/version gates, event-source precedence, debounce/deduplication keys/windows, request coalescing, or duplicate-capture prevention logic. The presence of intents and Locked Camera Capture APIs is not evidence of Camera Control behavior.

## 8. Default camera configuration

The app's main Info.plist was decoded with the local structured plist parser; bundle version is `3.3.1`, build `3263984`. IDA recovered the camera settings model and several defaults:

- `PrimeCameraConfiguration.default` is initialized by `sub_20B50C`. Its stored bytes establish `macro = false`, `zoom = Float16(0x3c00) = 1.0`, `exposure` raw value `0`, and `lookID = Look.processZero`.
- `VirtualCameraConfiguration.lookID` initializes to `Look.systemQuality`; this is the Apple/system-processing path.
- The settings model defines lens presets `standard28`, `standard35`, `standard42`, `standard50`, and `tele200`; the selected lens identity is a separate device configuration and is not proven by the generic prime default initializer.
- The launch initializer stores a two-element camera range from `sub_283C04`, sets mode word `2`, and initializes virtual/prime configuration arrays empty. Those packed fields are observed but not safely attributable to shutter, ISO, or WB without the complete field layout.
- Legacy RAW preference predicates are explicit: `useProRAW = (preference & 3) != 1`; `useNativeRAW = (preference & 3) == 1`. Capture predicates are `willCaptureProRAW = ((capture & 0x01000000) != 0) && (((capture & 1) == 0) || ((capture & 2) != 0))` and `willCaptureNativeRAW = ((capture & 0x01000003) == 0x01000001)`. `onlyRAWOrProcessed` tests `capture & 0x00010000`. These recover the mode logic, but the raw preference enum labels/default stored value and actual AVCapture output selection remain unresolved.

| Setting requested | Default recovered from IPA |
|---|---|
| Prime Look | `processZero` |
| Virtual-camera Look | `systemQuality` / Apple system look |
| Prime macro | `false` |
| Prime zoom | `1.0` (`Float16` bit pattern `0x3c00`) |
| Prime exposure enum | raw value `0` |
| Lens/prime selection | Lens preset enum exists; selected device lens remains unresolved |
| Exposure mode | Enum/storage exists; raw value `0` is recovered for the prime exposure field, but its user-facing case is unresolved |
| White balance mode | Not recovered |
| Flash | Not recovered |
| Format | RAW/ProRAW/native-RAW concepts are present; exact default output not recovered |
| Shutter speed | Not recovered |
| ISO | Not recovered |
| Exposure compensation/bias | Not recovered |
| Focus mode/distance | Focus-tool model exists; exact default not recovered |
| Film effects | Filter defaults are documented above; per-Look persisted customization defaults not mapped |

The remaining values are not inferred from names or marketing text. The legacy settings type also stores `smartestPrioritization`; camera metadata references min/max ISO and exposure duration. These identify supported concepts, not defaults or current control state. The RAW preference predicates are recovered above, but the preference enum's semantic labels/default value and the exact lens/output selection still require tracing the camera controller's device-selection path.

## Recovery boundary / next evidence needed

The IDA-backed static pass recovered the RAW/filter graph, LUT encoding and payloads, effect defaults/math, focus-peaking pipeline, volume-shutter singleton plumbing, RAW preference predicates, prime/virtual Look defaults, and the focus-loupe transform. The capture extension is a `CameraCaptureIntent` and `LockedCameraCapture` entry point that passes Halide settings to its camera view controller; this alone does not establish the final sensor request. Remaining work is the exact AVCapture request and DNG handoff, Image Lab slider mapping, the Exposure Fusion Metal per-pixel equation, per-look persisted customization values, the manual-control indicator view path, composition drawing bodies, the `HLDVolumeControl` callback/deduplication path, Camera Control integration, and device-specific lens/format defaults. Runtime confirmation of capture flags, event deduplication, and device-specific defaults requires an appropriate iOS runtime/device. The document intentionally does not invent those values.

# Halide IPA Reverse-Engineering Evidence

Target: `halide-3.3.1-dev-build.ipa`, SHA-256 `21a3b657114254ff596f635ef7a3d7cfa46c3948742441a8d825aa0b8ab80234`.

## Primary reference

- [HALIDE-IPA-TECHNICAL-REFERENCE.md](../HALIDE-IPA-TECHNICAL-REFERENCE.md): findings organized by the eight requested areas, with explicit unknowns.

## Resource evidence

- `evidence/Info.plist.json`: decoded app bundle plist, including app version/build.
- `evidence/resource-inventory.json`: copied resource sizes, hashes, magic bytes, and metallib bitcode markers.
- `evidence/lut-decode.json`: manifest for each `.ccube`: original compressed SHA-256/size, decoded SHA-256/size, table dimension, and payload format.
- `resources/<Framework>.framework/*.ccube`: original compressed grade/LUT resources copied from the IPA.
- `resources/luts/*.raw`: LZFSE-decoded half-float RGB payloads (`33^3 * 3 * 2` bytes each). These are binary arrays, not textual `.cube` files; the runtime LUT decoder converts RGB to float and appends alpha 1.0.
- `resources/*/*.metallib`: shipped Metal shader libraries. `LuxFiltersComputeKernels.metallib` contains compute kernels; the full Exposure Fusion and grain per-pixel shader equations remain un-decompiled.

## Decompiler output

The `evidence` subdirectories contain IDA-generated pseudocode excerpts grouped by framework/target:

- `evidence/filters/`: RAW development, editor graph, fusion, LZFSE/LUT decode, grade initialization, grain, halation, MTF, and Core Image filters.
- `evidence/camera/`: HalideCamera settings defaults and Look initialization.
- `evidence/camera2/`: FocusPeakingFilter pipeline.
- `evidence/camera3/`: camera UI, guide types, volume-shutter type plumbing, and related symbols.
- `evidence/camera4/`: RAW capture callbacks, RAW preference predicates, ProRAW compression hook, and focus loupe transform.
- `evidence/*-symbols.json`, `*-targets.json`: extracted symbol/function inventories.

IDA pseudocode is decompiler output, not original source. Addresses are image-relative IDA addresses for the matching framework binary. Symbol names and resource labels alone do not prove runtime execution. Findings in the primary reference distinguish recovered implementation from unresolved behavior.
