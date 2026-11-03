# No Fusion IPA: IDA Deep-Dive Technical Reference

Build: `no-fusion-2.5.61-dev-build.ipa` (SHA-256 `2d790239c1d3c09db2653ce4812c06ce26b03c716d47a76f2d6b8c023909bb48`). Main executable `Payload/No Fusion.app/No Fusion`, arm64, SHA-256 `24ae7c4cfc321d9c84175f884650f71896f40b2450ddc9f918fc0f535221c11f`. Related framework: `Frameworks/NFAsset.framework/NFAsset` (arm64), with compiled `DepthModel.mlmodelc`.

## Evidence policy

Addresses below are IDA image VAs for this exact build. The binary is optimized Swift/Objective-C and some large pseudocode functions show failed local-variable allocation; method calls, constants, and branch conditions are evidence, while high-level variable meanings are inferences unless corroborated. This document replaces earlier overly broad “unknown” classifications with findings obtained from IDA. Runtime/device defaults that depend on AVFoundation capability or persisted preferences remain marked unknown.

## 1. HEIF+ and Apple RAW processing

### RAW capture acquisition

Main capture-settings routine `sub_1001FAEF4` (`0x1001FAEF4`) constructs `AVCapturePhotoSettings` and uses `AVCapturePhotoOutput.availableRawPhotoPixelFormatTypes`. It tests raw pixel formats with `isAppleProRAWPixelFormat:` and `isBayerRAWPixelFormat:`. ProRAW capture settings are created through `photoSettingsWithRawPixelFormatType:processedFormat:`. Bayer RAW config selects its RAW pixel format and DNG output through `supportedRawPhotoCodecTypesForRawPhotoPixelFormatType:fileType:`, then sets the raw file and embedded-thumbnail formats. A decoded unsupported ProRAW preference falls back to Bayer RAW.

Capture can set a preview photo pixel format using `availablePreviewPhotoPixelFormatTypes` / `setPreviewPhotoFormat:`. The app can enable Apple ProRAW capture but also implements a Bayer RAW path. Bayer RAW explicitly skips capture-time depth and mattes; post-processing depth generation remains available. Bayer RAW is documented by in-app warning text as incompatible with 48MP capture and can look different from preview.

### ProRAW compression override

`RawCompressor` implements `replacementAppleProRAWCompressionSettingsForPhoto:defaultSettings:maximumBitDepth:` at `0x100165E14`; it delegates to `sub_100166170(maximumBitDepth)`.

`sub_100166170` constructs a dictionary with:

- `AVVideoAppleProRAWBitDepthKey`: if the compressor's depth flag is true, use the supplied `maximumBitDepth`; otherwise use `min(maximumBitDepth, 8)`.
- `AVVideoQualityKey`: `1.0` for the depth-flag branch; approximately `0.998` (`0x3FEFEF9DB22D0E56`) for the capped-at-8-bit branch.

`replacementMetadataForPhoto:` (`0x100165FC0`) conditionally modifies metadata. `sub_100165E94` returns the original metadata unless the replacement preference and `shouldReplaceBuffer` state permit merging RAW preset metadata/settings. This is a real Apple ProRAW settings override; it does not prove that final HEIF+ is encoded by Apple's ProRAW codec.

### RAW rendering and calibration controls

`sub_100166A7C` creates `CIRAWFilter` from image data using `filterWithImageData:identifierHint:`. The decoded RAW preset controls include baseline exposure, optional supported color and luminance noise reduction, sharpness, local tone mapping, temperature and tint. A `GainMapCreator` stage exists in the adjacent RAW processing path.

The RAW preset apply path sets:

- `CIRAWFilter.baselineExposure` from the RAW preset value plus the input metadata baseline exposure.
- `CIRAWFilter.sharpnessAmount` from the preset sharpness value.
- `CIRAWFilter.contrastAmount = sharpnessAmount * 0.5`.
- `colorNoiseReductionAmount` and `luminanceNoiseReductionAmount` only when supported and the associated setting is nonzero.
- `localToneMapAmount` from the preset field; if local tone mapping is unsupported, the code applies a linear-space filter fallback.
- `neutralTemperature` / `neutralTint` from preset values unless that preset marks the values as inherited.

**Sharpening avoidance claim:** not recovered. The code explicitly assigns a `sharpnessAmount`; no observed branch disables or bypasses sharpening. Do not reproduce a “no sharpening” rule as an extracted fact.

### HEIF+ editor generation and output

`sub_100516980` is an editor-side HEIF+ generation path. It logs start/finish with a render-quality argument, fails if RAW is absent, and has separate failures for a nil compressed result and failed rasterization. Logs and the stage identifiers establish the broad order: RAW output/decode -> editor render/raster (`heifRaster`) -> compression -> final HEIF output. The quality value is carried into rendering/encoding.

`sub_1001CB314` builds image destination properties using `kCGImageDestinationLossyCompressionQuality`; the value is a Double selected from a settings table using a settings byte at object offset `+50`. Exact table entries and which HEIF+ variants share this path were not fully resolved. Chroma subsampling, final color primaries/transfer, bit depth, compression ratios, and all metadata policy remain unknown.

`rawCompress`, `rawPreset`, `RAWCompressionCodec`, `photoOutputAfterProRAW`, `heifPlusTempAndTint`, and `No_Fusion.RawCompressor` are observed class/state identifiers, not a complete proprietary algorithm specification.

## 2. Live Photo and Portrait/depth

### Live Photo capture and assembly

The capture-settings path (`sub_1001FAEF4`) attaches a `.mov` URL via `setLivePhotoMovieFileURL:` when Live Photo is enabled. Capture delegate callbacks include:

- `captureOutput:didFinishRecordingLivePhotoMovieForEventualFileAtURL:resolvedSettings:`
- `captureOutput:didFinishProcessingLivePhotoToMovieFileAtURL:duration:photoDisplayTime:resolvedSettings:error:`

Assembly is handled in `sub_100146568` and `LiveCreator`/`LiveVideoAssemblySession`. The path has a dispatch-group wait with a 3.6-second timeout plus a separate “without wait” mode. It coordinates stored/current and original Live movie URLs.

`LiveCreator`'s writer path (`sub_1001ACD6C`) creates an `AVAssetWriter`, audio `AVAssetWriterInput`, and `AVAssetWriterInputPixelBufferAdaptor`; it starts writing, starts a session at a source time, takes the adaptor pool, then consumes media via `requestMediaDataWhenReadyOnQueue:usingBlock:`. Audio settings are AAC FourCC `0x61616320` (`aac `), 48,000 Hz, 2 channels, 192,000 bit/s. Pixel-buffer source attributes include caller-supplied width/height and FourCC `0x34323066` (`420f`, 4:2:0 8-bit video-range YCbCr). Video writer codec, frame rate, and all callback timing were not recovered.

### Photos resource structure

The Photos save branches use `PHAssetCreationRequest`:

- `sub_1001BDC30`: `addResourceWithType:fileURL:options:` with type 9 (paired video), followed by `addResourceWithType:data:options:` type 1 (photo). Original filenames are applied through `PHAssetResourceCreationOptions`.
- `sub_1001C0B60`: type 1 photo data plus type 4 alternate-photo file URL.
- The movie metadata path writes `com.apple.quicktime.content.identifier` (QuickTime metadata key space), and code retrieves `assetResourcesForLivePhoto:`. Placeholder Photos local identifiers are retained.

Thus the motion component is a paired-video Photos resource linked by QuickTime content-identifier metadata, not merely a standalone movie hidden in app storage. Exact resource choice for every format and all UUID flow are still branch/runtime questions.

UI strings establish these constraints/features: Live Photo is offered in ProRAW, HEIF+, and 48MP modes; HEIF+RAW merge prevents Live Photo saving and the user can disable merge to retain Live Photo; a negative can keep motion data while the visible Live Photo switch is off for later restoration. This describes compatibility handling and deferred save, not proof of bypassing a specific iOS restriction.

### Portrait/depth implementation

Main capture setup enables and embeds supported semantic mattes, depth data, and portrait-effects matte. Bayer RAW is an explicit exception: capture-time depth/mattes are skipped and post-processing generation is kept available. Main app has `DepthGenerator` calls and `generatedDepth`/`portraitMatte` state.

`NFAsset.framework` exports a `DepthGenerator` that predicts from a `CIImage` and returns a `DepthResult` containing a `CIImage` and info dictionary. The compiled Core ML metadata is concrete:

- Model: Depth Anything V2 Small F16, Core ML ML Program.
- Input: `image`, RGB, 518x392; short input side is specified as 518 and the long side as a multiple of 14.
- Output: `depth`, grayscale Float16, 518x392 (`Grayscale16Half`).
- Wrapper `sub_497C`: resize input to maximum edge 768, render as BGRA CVPixelBuffer, convert to half-float disparity buffer FourCC `hdis` (`0x68646973`), multiply each half sample by `1.2998`, then package width, height, bytes-per-row, pixel format, orientation `6`, auxiliary data and CGImage metadata.

This is monocular learned depth generation packaged toward Apple disparity auxiliary data. Main-app insertion of that result into an existing photo/Photos resource, physical distance calibration, confidence values, and matte generation handoff need more tracing.

## 3. Built-in presets and rendering order

### Preset parameter model

The binary `StylePreset` property-list model includes global exposure/contrast/saturation, highlights/shadows/black/white, temperature/tint, vibrance, tone curve, HSL, LUT data/intensity, grain, bloom, vignette, prism and related effect values. Bundled `.preset` files are binary plists with neutral HSL/global controls and an identified LUT reference. Relevant key defaults in bundled files remain as detailed in the prior static resource inventory: global contrast/saturation and HSL saturation/luminance `1.0`; exposure/highlight/shadow/black/white/temp/tint/vibrance `0.0`; HSL hue `0.0`; grain amount `0.0`, grain size `0.5`; bloom amount `0.0`; vignette intensity/radius `0.0`. NN, NC, CC, GR, LC, H1/H2, K1-K5, F1-F4 and BW1-BW4 descriptions and LUT dimensions/intensities should be read from their corresponding `NFAsset.framework/*.preset` files; in particular NN LUT intensity is `0.83104354`.

### `StyleFilter` pass order

`StyleFilter.outputImage` is implemented in `sub_10050E478`. For positive effect values it runs the following chain in order:

1. Prism effect, if `prism > 0`.
2. Core Image bloom, if `bloom > 0`: radius = `bloom * 7 * max(imageWidth,imageHeight) / 1500`; intensity = `min(bloom,1)/3 + 0.15`.
3. Halation, if `halation > 0`, with the style strength passed to `HalationFilter`.
4. Vignette, if `vignette > 0`: intensity = `2 * vignette`; radius = `2 * min(width/height,height/width)`.
5. Date watermark via `CILinearDodgeBlendMode`, when present.
6. Build/apply LUT using `CIColorCubeWithColorSpace`; color space is explicitly `kCGColorSpaceSRGB`. If strength is not 1, mix original and LUT result with `MixFilter`, ratio `strength` and `luminanceOnly=false`.
7. Exposure (`CIExposureAdjust`): `EV = preset.exposure * strength`.
8. Temperature/tint (`CITemperatureAndTint`): target neutral is original white balance; new neutral temperature = `originalTemperature + preset.temperature * strength * 2000`; tint = `originalTint + preset.tint * strength * 30`.
9. Global color controls: contrast = `1 + (preset.contrast - 1) * strength`; saturation = `1 + (preset.saturation - 1) * strength`.
10. Tone curve, if any curve values nonzero: points are generated from preset curve values and scaled by `strength`; exact point equations are visible at `0x10050E478` (see below).
11. Vibrance (`CIVibrance`): amount = `preset.vibration * strength`.
12. `HSLFilter` last: red/orange/yellow/green/aqua/blue/purple/magenta each receive a vector (hue shift in x, saturation in y, luminance in z), with every adjustment scaled by strength and clamped around 0.75..1.25 for saturation/luminance.

The shown order is the `StyleFilter` core chain. Noise/grain is handled by a separate `FilmGrainFilter`; it is not one of the ordered 12 `StyleFilter` passes. A settings/UI path can route texture/grain into image generation, but exact call-site ordering for every capture/export mode is still unresolved.

### Recovered curve/HSL equations

Curve controls, all multiplied by `strength`:

- Point 0: `(0, black * strength * 0.25)`.
- Point 1: x=`0.25`, y is the preset low-tone curve adjustment scaled by `0.25*strength` around the curve's neutral value.
- Point 2: x=`0.5`, y is the average of the adjacent strength-scaled curve offsets plus the neutral `0.5` midpoint.
- Point 3: x=`0.75`, y is the corresponding high-tone offset around neutral.
- Point 4: `(1, 1 + white * strength * 0.25)`.

For each HSL color vector, channel order red, orange, yellow, green, aqua, blue, purple, magenta:

- hue = preset hue * `0.0625` * strength.
- saturation = `1 + (preset saturation - 1) * strength`.
- luminance = `1 + clamp(preset luminance - 1, -0.25, 0.25) * strength`; source branch caps at 1.25 and uses the -0.25 delta at/below 0.75.
- The vectors are assigned to separate `HSLFilter` inputs. Its result is mixed against the preceding image with ratio `strength` and `luminanceOnly=true` when color mapping is enabled.

### Effect implementations/defaults

- `FilmGrainFilter` Core Image setup is in `sub_1004FFEFC`. It no-ops when amount or size `<=0.01`. Its class initializer defaults amount `0.5`, size `0.5`; the bundled preset files override grain amount to zero and serialize size `0.5`. The pass samples a texture, applies scatter radius = `size`, brightness offset `min(amount-1,-0.4)`, opacity `amount*0.2`, then blends; a secondary overlay uses opacity `min(amount,0.6)`.
- `PrismFilter` default radius `0.5`; `sub_1005072E4` downsamples by 0.5, generates multiple displaced/blurred CIImages, blends/masks them, then upsamples by 2.0. It is distinct from bloom.
- `HalationFilter` defaults in `sub_100501548`: strength `0.5`; raw thresholdMax `0.7`, thresholdMin `0.8`; red blur min/max `8/16`; green blur min/max `5.6/10.4`; opacity min/max `0/.85`; `darkSideOnly=true`. The implementation generates red/green Gaussian blur and color-matrix channels, uses multiply and maximum compositing, optionally masks to dark side, then screen blends. Do not reorder the fields labelled min/max; their numeric values are inverted in this build.
- Bundled preset bloom radius defaults are 10, except F1/F2 at 5; amounts are zero. Bundled vignette intensity/radius are zero. No standalone effect is implied active by a nonzero radius alone.

Built-in preset names/IDs from resource plists: NN Fuji Nostalgic Negative (LUT 32, intensity .83104354); NC Fuji Neutral Classic (32, 1); CC Fuji Classic Chrome (32, 1); GR GR Negative (33,1); LC GR Positive (33,.91); H1 GR Blue (33,1); H2 Kodak Portra 400 (33,1); K1 Portra 400 Yellow (25,1); K2 Ultramax 400 (25,1); K3 Pro Image 100 (25,1); K4 Portra 200 Gold (32,1); K5 Kodak 5207 (33,1); F1 Hasselblad X5 Sanner Blue/Yellow (33,1); F2 Classic (32,1); F3 Chrome (32,.91); F4 Contemporary (32,1); BW1 Eternal (32,1); BW2 Mono Hi Contrast (32,1); BW3 Mono (32,1); BW4 Sepia (32,1). Tone curve/HSL/effect adjustments serialized in these built-ins are neutral; the look is predominantly their referenced LUT.

## 4. Custom preset/LUT import

- `.preset`: security-scoped access; lowercase extension check; read Data; decode `StylePreset` with `PropertyListDecoder`; generate a UUID identity and continue through main-actor preset storage.
- `.cube`: read text, remove CR, split lines, trim whitespace, skip blank lines, `#` comments and `TITLE` records. Parse the size declaration and RGB float triples into cube data; size is checked before conversion and the 65-size case has a dedicated `Lut65Converter` path. Domain semantics and the complete supported dimension range remain unresolved.
- LUT image: Core Image/CGImage path; import requires exactly 512x512.
- LUT generation/application: `StyleFilter.outputImage` sets cube data and dimension on `CIColorCubeWithColorSpace`, and sets `CGColorSpaceCreateWithName(kCGColorSpaceSRGB)`. The color-space argument is explicitly sRGB. The imported `.cube` output is converted to the app's internal cube data before application; binary cube layout, channel order and Core Image interpolation details remain unresolved.
- Resource/cache: content-hash keyed `LUTStore`, disk-load and cache-hit paths; preset library keeps separate built-in/custom LUT lists, visibility, order, tags/groups and active tag IDs. Built-in preset LUT references use hashes and declared dimensions 25/32/33. Batch import and batch export surfaces are present; exact external export archive layout remains unknown.
- Preset adjustment scaling in `StyleFilter` is described above; strength is a scalar, while the permitted UI slider ranges/min/max are not recovered. Hue is multiplied by 1/16; temperature by 2000K-unit scale; tint by 30; contrast/saturation are neutral-centered at 1.0.

## 5. Negative mode and saved resources

The app retains a RAW source/edit state under a capture ID and has `MasterTapeHeifPlusEditSettings` / “master tape” identifiers. Captured RAW can later be decoded with RAW 8 and rendered to HEIF+. The negative editor stores/edit-applies preset and temperature/tint changes before rasterizing output; conversion can be re-triggered without re-capturing. Main-app strings show batch RAW-to-negative and batch HEIF+ conversion, crop/rotation/straighten state, and negative save recovery.

Photos save is not the private negative format: distinct PHAsset resource paths write image data and optional alternate file; Live Photo adds paired movie separately. The exact app-private master tape byte format/database and link schema to Photos local IDs remain unknown. “Lossless” applies only when the retained source RAW exists and is decodable; raster-only imports cannot regain RAW information.

## 6. Manual exposure logic

`DeviceParameters` contains separate `apertureMode`, `exposureMode`, `isoMode`, `settingISO`, `settingShutter`, shutter duration, ISO and aperture fields. The selected Legacy or iOS27 semi-automatic controller is called with current duration/aperture/ISO and auto/manual mode flags. If unsupported, the code falls back to `setExposureModeCustomWithDuration:ISO:` or the lens-aperture-capable variant.

- ISO slider: normalized `x`; `rawISO = minISO + (maxISO-minISO)*x^3`; quantize to 5 through ISO 100, 100 through 1000, 500 through 10000, 1000 above; round to nearest step and clamp to device range.
- Shutter slider: map normalized control over configured shutter range, map to the app's shutter step, clamp to active-format min/max; display state is based on `-round(log2(seconds))` passed through the reciprocal mapping.
- Exposure-target-offset feedback is tiered: in shutter-priority/auto-ISO state it adjusts ISO in 5/20/80 increments for EV offset magnitude <=.5, <=1, and >1 respectively; positive offset reduces ISO, negative increases it. In ISO-priority/auto-shutter state it adjusts duration via a piecewise log2-stop delta (thresholds .05, .1, .2, .5, 1, 2; deltas .02/.04/.08/.2/.4/1 stops), clamps to camera format duration bounds, then requests the controller/fallback custom exposure.
- EV compensation directly clamps requested target bias to device min/max before `setExposureTargetBias:completionHandler:`.

This is the recovered compensation math. Per-device time range and ISO extrema remain runtime values; slider state updates appear in the exposure meter/model, but exact “primary level” visual behavior is not determined from the current pass.

## 7. AF/AE separate locking

`DeviceParameters` has separate `focusMode` and `exposureMode` state plus `focusExposureLock` preference. Focus-point interaction checks focus mode/point support, locks the device, applies `(x,1-y)`, sets focus mode, and toggles subject-area monitoring. Exposure-point interaction independently checks exposure point and mode support, applies `(x,1-y)` or center `(0.5,0.5)`, refreshes semi-auto controller and sets mode. Separate manual focus path clamps lens position 0..1 and invokes `setFocusModeLockedWithLensPosition:`. Each device change is lock/unlock protected. The precise UI gesture that calls the separate routines remains unknown; long-press strings found elsewhere are for controls/effects and do not prove the system-camera long-press implementation is reused.

## 8. Focus peaking

Sobel-based `SobelFilter` default color `(1,1,1)`, default threshold `.5`; `MetalViewHolder` overrides both from shared configuration. Output nil falls back to original preview. Kernel uses a Core Image kernel with input image/color/threshold; exact edge-gradient and threshold formula requires kernel body inspection. Default color/threshold are constructor defaults, not proven app preference defaults.

## 9. Defaults and configuration

The IPA has a bundled `CvAbstractCamera` helper with these constructor defaults, but they are not proven to be the main No Fusion still-capture configuration:

- `-[CvAbstractCamera init]` (`0x10094EB1C`): camera position `2` (back), video orientation `4` (portrait), FPS `15`, session preset `AVCaptureSessionPreset352x288`, no parent view, preview layer disabled.
- `-[CvAbstractCamera initWithParentView:]` (`0x10094EC40`): camera position `2`, orientation `4`, FPS `15`, session preset `AVCaptureSessionPreset640x480`, parent view supplied, preview layer enabled.

The app has its own `AVCaptureSession`/photo-output bootstrap and `DeviceParameters`; these helper constructor values do not establish still photo format, still dimensions, selected camera, or persisted defaults. The IPA contains no clean-install UserDefaults snapshot.

Recoverable resource defaults: bundled StylePreset plists are neutral except their LUT/intensity; `isFavorite=false`; grain/bloom/vignette amount zero, grain size .5, bloom radius 10 except F1/F2=5. Class defaults: StyleFilter `strength=1`; FilmGrainFilter amount/size=.5; Prism radius=.5; Halation defaults are listed above. Preset application overrides relevant class filter parameters.

Unresolved app-selected defaults: selected RAW/HEIF format, preset, flash, Live Photo toggle, high-resolution mode, capture ratio, exposure mode, initial ISO/shutter/EV, focus-peaking enable/color and adjustable-setting min/max. Those require the main app's session bootstrap and a clean-install preference state; selector names and unrelated helper defaults are not sufficient.

## Evidence locations

- Main capture settings: `sub_1001FAEF4` (`0x1001FAEF4`).
- HEIF+ generation: `sub_100516980` (`0x100516980`).
- ProRAW override: `0x100165E14`; ProRAW settings dictionary `sub_100166170` (`0x100166170`).
- RAW preset `CIRAWFilter`: `sub_100166A7C` (`0x100166A7C`).
- Live Photo capture assembly: `sub_100146568` (`0x100146568`); writer `sub_1001ACD6C` (`0x1001ACD6C`); resource savers `sub_1001BDC30`, `sub_1001C0B60`.
- Depth auxiliary generation: NFAsset `sub_497C`; format conversion `sub_4F7C`; depth Core ML model metadata `DepthModel.mlmodelc/metadata.json`.
- StyleFilter pass chain: `sub_10050E478`; StyleFilter initialization `sub_10050DC84`.
- FilmGrain render: `sub_1004FFEFC`; defaults `-[FilmGrainFilter init]` (`0x100501108`) and `setDefaults` (`0x1004FF5D8`).
- Prism: `sub_1005072E4`; defaults `-[PrismFilter init]` (`0x1005071E8`).
- AF/AE handlers: `sub_10016E3E0`, `sub_10016E6BC`, manual ISO `sub_10016EAAC`, shutter `sub_10016ED74`, exposure offset `sub_100170F3C`.

Static analysis does not establish runtime results on iPhone hardware. No capture was executed. The current tooling session is Windows; live camera/device validation and actual Photos resource readback remain required before treating device-specific behavior as complete.
