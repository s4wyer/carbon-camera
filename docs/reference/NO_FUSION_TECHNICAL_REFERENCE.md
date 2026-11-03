# No Fusion 2.5.61 Dev Build: Technical Reconstruction Reference

## Scope and evidence

Target: `no-fusion-2.5.61-dev-build.ipa` (SHA-256 `2d790239c1d3c09db2653ce4812c06ce26b03c716d47a76f2d6b8c023909bb48`). The package inventory covered 688 ZIP occurrences and was complete within the IPA's central directory. Main executable: `Payload/No Fusion.app/No Fusion` (arm64 Mach-O, SHA-256 `24ae7c4cfc321d9c84175f884650f71896f40b2450ddc9f918fc0f535221c11f`). The app contains `Frameworks/NFAsset.framework`, 21 `.preset` binary plists, `.lutbin` resources, `DepthModel.mlmodelc`, `metadata.heic`, and `disparity.heic`.

This is a static reconstruction from one shipped build. The IPA does not contain source, symbols sufficient to map all Swift methods, runtime traces, or camera hardware. Strings/log messages establish that code paths and concepts exist, but do not by themselves establish execution order or API semantics. “Unknown” below is intentionally not a proposed implementation.

## 1. HEIF+ pipeline

### Observed artifacts and code indicators

- The app advertises `No Fusion. Powered by ProRAW.` and contains strings for `ProRAW`, `Bayer RAW`, `HEIF+`, `rawFormat`, `enableRawPipeline`, `prorawToggle`, and `heifPlusNegative`.
- Named components/diagnostics include `No_Fusion.RawCompressor`, `rawCompress`, `rawPreset`, `RAWCompressionCodec`, `RAW decoder`, `Selected RAW decoder version=`, `Selected RAW decoder unavailable requested=`, `photoOutputAfterProRAW`, and `replacementAppleProRAWCompressionSettingsForPhoto:defaultSettings:maximumBitDepth:`.
- The negative editor has diagnostic stages `negativeGeometry stage=rawOutput`, `negativeGeometry stage=heifRaster`, and `negativeGeometry stage=processed heifPlus=`. Generation logs report `generate heif+ started quality:`, `generate heif+ finished quality:`, and failures for absent RAW, nil compressed output, or editor rasterization failure.
- A `skip HDR preview for RAW without alternate photo` message and `Limited RAW Max photo from max edge` indicate size/preview constraints exist. Bayer RAW capture logs explicitly say capture-time depth and mattes are skipped, with post-processing depth generation still available.
- IDA located generation logging in `sub_100516980` at `0x100516980` (main Mach-O VA; decompiler reports failed local-variable allocation). It includes a no-RAW-data failure path. `sub_1001CB314` at `0x1001CB314` builds image destination options containing `kCGImageDestinationLossyCompressionQuality`, with a Double selected using a settings index at object offset `+50`; concrete quality table values and association with every HEIF+ output remain unresolved.
- `RawCompressor` implements `replacementAppleProRAWCompressionSettingsForPhoto:defaultSettings:maximumBitDepth:`. It delegates to `sub_100166170(maximumBitDepth)` and returns a dictionary. `replacementMetadataForPhoto:` conditionally modifies metadata, gated by a runtime flag and `shouldReplaceBuffer`.
- `sub_100166170` emits `AVVideoAppleProRAWBitDepthKey` and `AVVideoQualityKey`. If the compressor depth flag is set, it uses the caller-provided `maximumBitDepth` and quality `1.0`; otherwise it uses `min(maximumBitDepth, 8)` and quality approximately `0.998` (IEEE-754 value `0x3FEFEF9DB22D0E56`).
- `sub_100166A7C` creates a Core Image `CIRAWFilter` from RAW `Data` via `filterWithImageData:identifierHint:`. The recovered processing includes baseline exposure adjustment, conditional color/luminance noise reduction when supported, sharpness amount from a RAW preset field, contrast set to half that sharpness value, local tone map amount from another preset field, neutral temperature/tint values, and `setLinearSpaceFilter:` when local tone mapping is unsupported. There is a `GainMapCreator` stage in the surrounding processing path. This is not evidence of sharpening avoidance: the code explicitly sets a RAW sharpness amount, and no disable-sharpening guard/constant was recovered.

### Reproduction guidance (what evidence supports)

The minimum supported reconstruction is a path that retains a RAW resource, decodes/renders it into a raster for editing, then compresses/rasterizes that edited representation as an HEIF-family output. Logs identify raw output and HEIF raster stages. The binary has an Apple ProRAW branch that selects a supported raw pixel format and constructs `AVCapturePhotoSettings` with `photoSettingsWithRawPixelFormatType:processedFormat:`; the Bayer RAW branch chooses the `isBayerRAWPixelFormat:` path and supplies a DNG raw file format/codec. Keep RAW acquisition, decode, editor raster, and HEIF encode as distinct stages so errors and dimensions can be tracked independently.

For RAW decoding, use Apple's Core Image RAW decoder (`CIRAWFilter`) as observed, and preserve the app's per-RAW-preset controls for baseline exposure, noise reduction, sharpness, contrast, local tone mapping, temperature and tint. Do not emulate a sharpening-avoidance rule as a recovered behavior: current disassembly shows a sharpness parameter being set, not disabled.

The binary references Apple's ProRAW/RAW processing facilities and includes an override-shaped selector named `replacementAppleProRAWCompressionSettingsForPhoto:defaultSettings:maximumBitDepth:`. It is evidence of interaction with Apple's ProRAW compression settings, not evidence that the entire final HEIF+ image is encoded by Apple ProRAW. The app/framework also ships custom RAW compression code/resources. Calling the format “Apple ProRAW combined with proprietary calibration/compression” as a precise algorithm is not independently established by these artifacts.

### Not extractable from this build's static evidence

- Exact RAW acquisition API and output pixel format for every device/mode; RAW vs Bayer RAW selection conditions.
- Exact demosaicing internals remain Apple's `CIRAWFilter` behavior and are not recovered from this app binary. The app configures baseline exposure, optional color/luminance noise reduction, sharpness, contrast, local tone mapping, temperature/tint and a gain-map stage, but all preset field values and per-device calibration constants are not fully extracted. No sharpening-avoidance logic was found; observed behavior explicitly sets sharpness amount.
- Whether proprietary processing occurs before/after Apple's processing, or the exact call sequence and fallback logic.
- HEIF codec implementation, bit depth, chroma subsampling, transfer function, color primaries, quantization, and compression ratio remain unknown. At least one path uses `kCGImageDestinationLossyCompressionQuality`; its Double comes from a settings-indexed table, but concrete values and exact path mapping are unresolved.
- Meaning of “HEIF+” at the container/brand level and whether RAW is embedded in every output. Separate combined RAW+HEIF logs below show at least one paired-save path, not a universal container structure.

## 2. Full-format Live Photo and Portrait

### Live Photo evidence

The executable contains `Live Photo`, `portraitWithLive`, `live photo assembly completed without a rendered video`, `live photo timeout`, `live photo without wait timeout`, `Texture Styles Live Photo metadata failed frame=`, and `Live Photo audio ...` diagnostics. There are explicit save/recovery messages around RAW and combined RAW+HEIF, including “skipped RAW because raw data is missing,” “skipped combined RAW+HEIF because required data is missing,” “Photo save RAW succeeded,” and “Photo save combined RAW+HEIF succeeded.”

IDA decompilation of `sub_1001FAEF4` (`0x1001FAEF4`) shows `AVCapturePhotoSettings` construction, RAW pixel-format selection, optional preview format, `.mov` URL assignment to `setLivePhotoMovieFileURL:` when Live Photo is enabled, quality-prioritization configuration, and depth/semantic matte request and embedding for eligible formats. The iPhone Duo Bayer RAW branch skips the quality-prioritization setter. `sub_100146568` (`0x100146568`) waits on a `DispatchGroup`, coordinates the LiveCreator stored and original movie URLs, and contains a 3.6-second wait budget plus an alternate no-wait path.

UI copy says Live Photo is available with ProRAW, HEIF+, and 48MP modes; it also states HEIF+RAW merge prevents Live Photo saving and offers disabling merge to preserve Live Photo. Another setting says negative capture may retain Live Photo data while the Live Photo switch is off for later editor restoration. These observations establish explicit compatibility constraints and deferred-negative behavior, not a system-restriction bypass.

### Portrait/depth evidence

- The framework ships `DepthModel.mlmodelc` (compiled Core ML model resources) and sample `metadata.heic` / `disparity.heic` assets.
- Runtime/error strings include `Depth generation failed:`, `Depth generation preload failed:`, `generatedDepth`, `portraitMatte`, `Skipped capture-time depth and mattes for Bayer RAW; post-processing depth generation remains available`, and `Smart Style kept portrait matte enabled from portrait settings`.
- The framework's `DepthGenerator` decompiles to a Core ML prediction path. Its generated wrapper passes a `CIImage` through `MLFeatureProvider`/pixel-buffer input and `predictionFromFeatures:options:error:`; a `DepthResult` returns a `CIImage` plus an info dictionary. The shipped model metadata identifies `Depth Anything V2 Small F16`, with a required RGB input named `image` at 518×392 and an estimated grayscale depth output named `depth`, also 518×392, `Grayscale16Half`. The input short description specifies the shorter input dimension as 518 and the larger dimension as a multiple of 14. In `sub_497C`, the input is resized to a maximum edge of 768, rendered through BGRA, converted to a half-float disparity buffer (`0x68646973`, `hdis`), and each half sample is multiplied by `1.2998`; the result is packaged with width, height, bytes-per-row, pixel-format, orientation, data, and Core Graphics auxiliary-data metadata. This confirms learned monocular image depth is converted toward an Apple-style disparity auxiliary map; the main-app insertion call, physical depth calibration, and exact portrait-matte handoff remain unresolved.

### Reproduction guidance

Model the still and motion components as separate capture products linked by a common capture identifier; assemble only after both components are available, and retain timeout/failure paths because the binary logs them. In the still path preserve the source RAW and an editor/rendered raster independently. For portrait mode, preserve the original still and any native depth/matte auxiliary data when present; if absent, run a separate depth-generation operation and record that it is generated rather than captured.

### Unknowns

- Exact runtime callback ordering and device-executed sequence across branches, paired-video session configuration, all delegate handling, and the OS/device restriction the UI is designed around.
- The claimed system-restriction bypass, affected OS/device restriction, and entitlement/private API mechanism. IDA static evidence does not prove a bypass; reproduce only via supported public APIs unless independent evidence identifies otherwise.
- The Live Photo assembler uses `AVAssetWriter`, an audio `AVAssetWriterInput`, and an `AVAssetWriterInputPixelBufferAdaptor`. Audio output settings observed in `sub_1001ACD6C` are AAC (`AVFormatIDKey` FourCC `0x61616320`, `aac `), 48 kHz, 2 channels, and 192,000 bit/s. It starts writing, begins a session at a source time, gets the adaptor pixel-buffer pool, and requests media data when ready. Its source pixel buffer uses dimensions passed into the assembly path and format FourCC `0x34323066` (`420f`; CoreVideo 4:2:0 8-bit video-range YCbCr). Video encoder settings/frame rate remain unverified.
- Photos persistence has a paired video asset resource path: `sub_1001BDC30` creates `PHAssetCreationRequest`, adds resource type 9 (paired video) from a movie file URL, then resource type 1 (photo) from image data. A second path `sub_1001C0B60` adds type 1 photo data plus type 4 (alternate photo) from file URL. The saver sets `PHAssetResourceCreationOptions.originalFilename` for the photo/video resources and writes `com.apple.quicktime.content.identifier` into Live Video metadata. Photos placeholder local identifiers are returned and tracked. This establishes Photos resource pairing, but not the app-private negative/motion cache schema or every capture-mode branch's exact pairing.
- `NFAsset.framework`'s `DepthGenerator` runs a Core ML model from a `CIImage`; the model input is RGB and its output image is `Grayscale16Half`, both at 518×392. `sub_497C` converts/resizes the predicted map and packages Core Graphics auxiliary data. For conversion it resizes to a maximum edge of 768, renders through BGRA, converts to `kCVPixelFormatType_DisparityFloat16` (`hdis`), and multiplies half samples by `1.2998`. It includes auxiliary dictionary fields for width, height, bytes-per-row, pixel format, orientation `6`, data, and metadata. This indicates a monocular predicted depth/disparity map is packaged as Apple-style auxiliary depth data. The main-app insertion call and semantic calibration/distance units are not resolved.

## 3. Built-in film preset system

### Preset serialization

Each `.preset` is a binary property list. Shared keys include `contrast`, `saturation`, `exposure`, `highlight`, `shadow`, `black`, `white`, `temperature`, `tint`, `vibration`, per-color `Hue`/`Saturation`/`Luminance` (red, orange, yellow, green, aqua, blue, purple, magenta), `lutData`, `lutIntensity`, `grainAmount`, `grainSize`, `bloomAmount`, `bloomRadius`, `vignetteIntensity`, and `vignetteRadius`. The serialized defaults in the shipped built-ins are generally: contrast/saturation and each HSL saturation/luminance `1.0`; exposure/highlight/shadow/black/white and temperature/tint/vibration `0.0`; HSL hue `0.0`; grain amount `0.0`, grain size `0.5`; bloom amount `0.0`; vignette intensity/radius `0.0`. Bloom radius is usually `10.0`, with `F1` and `F2` at `5.0`. These are plist values, not UI slider ranges.

No separate tone-curve points or effect-specific soft-glow, prism, or texture parameters were observed in the preset plists. Bloom is present; do not equate it with soft glow without shader evidence. The LUT payload is referenced by content hash and size, and has an associated binary `.lutbin` resource.

### Identifiable built-ins

| File ID | Serialized description | LUT size | LUT intensity |
|---|---|---:|---:|
| `NN` | Fuji Nostalgic Negative | 32 | 0.83104354 |
| `NC` | Fuji Neutral Classic | 32 | 1.0 |
| `CC` | Fuji Classic Chrome | 32 | 1.0 |
| `GR` | GR Negative | 33 | 1.0 |
| `LC` | GR Positive | 33 | 0.91 |
| `H1` | GR Blue | 33 | 1.0 |
| `H2` | Kodak Portra 400 | 33 | 1.0 |
| `K1` | Kodak Portra 400 Yellow | 25 | 1.0 |
| `K2` | Kodak Ultramax 400 | 25 | 1.0 |
| `K3` | Kodak Pro Image 100 | 25 | 1.0 |
| `K4` | Kodak Portra 200 Gold | 32 | 1.0 |
| `K5` | Kodak 5207 | 33 | 1.0 |
| `F1` | Hasselblad X5 Sanner Blue/Yellow | 33 | 1.0 |
| `F2` | Classic | 32 | 1.0 |
| `F3` | Chrome | 32 | 0.91 |
| `F4` | Contemporary | 32 | 1.0 |
| `BW1` | Eternal | 32 | 1.0 |
| `BW2` | Mono Hi Contrast | 32 | 1.0 |
| `BW3` | Mono | 32 | 1.0 |
| `BW4` | Sepia | 32 | 1.0 |

`BW2`, `BW3`, and `BW4` serialize `mono=true`; `BW1` serializes `mono=false`. `isFavorite=false` in these bundled defaults. Other visible built-in metadata: label colors and names (`NN`, `NC`, etc.) are serialized separately from descriptions. The `.preset` LUT reference hashes match content-addressed names of shipped `.lutbin` resources.

### Rendering order and color meaning

The plist establishes available controls and defaults only. It does not specify whether HSL/global controls precede or follow LUT application, whether LUT interpolation is trilinear/tetrahedral, whether effects run in linear or display-referred space, or whether grain/bloom/vignette are GPU or CPU passes. Exact render order, curve coefficients, HSL ranges, default effect strengths beyond serialized values, and per-preset parameter deltas beyond LUT/intensity are unknown from static resources.

## 4. Custom preset and LUT import

### Observed format clues

- Bundled LUT resources use `.lutbin`; sizes observed include 250,000 bytes, 524,288 bytes, and 574,992 bytes. Preset plists reference LUT content by hash and declare LUT grid sizes 25, 32, or 33.
- The app contains `LUT_([0-9A-Z]+)_.* ([0-9]+)`, `LUT disk load hash=`, `LUT cache hit hash=`, `LUT idle cache cleared`, `Filter thumbnail LUT failed id=`, and a URL `https://nofusion.app/lut`.
- This supports hash-keyed LUT resources and a custom import/help surface. IDA shows import UI accepts `.cube`, LUT images, and `.preset`; `.preset` data is decoded with `PropertyListDecoder` as `StylePreset`. LUT image import requires exactly 512x512 pixels, with distinct unsupported-format and unsupported-size errors. `CubeDataGenerator` and `Lut65Converter` are present. This does not reveal every import grammar or exact binary encoding.
- Imported cube data is applied via `CIColorCubeWithColorSpace`, with cube data and dimension fields. The actual color-space selection is unresolved. Bundled `.lutbin` byte sizes are insufficient to infer channel order, numeric representation, headers, or color-space mapping.

### Reproduction boundary

A compatible implementation needs a preset record with an ID/name/group, adjustable parameter fields, and an external LUT reference/content digest; it needs to preserve the imported LUT bytes and validate dimensions before rendering. This is a design recommendation, not a recovered parser contract.

### Unknowns

- `.cube` parser skips blank/comment (`#`) and `TITLE` lines, trims whitespace, splits the remaining rows, and parses numeric RGB triples into cube data. The parser extracts a cube-size integer and has a dedicated `Lut65Converter` path. The exact supported dimension bounds are not fully established in the recovered call path; do not treat the built-in preset grid sizes (25/32/33) or the converter's “65” name as a complete parser limit. `DOMAIN_MIN` / `DOMAIN_MAX`, 1D LUT semantics, and title metadata beyond skipping `TITLE` are not established. Image LUT imports require exactly 512×512.
- `.lutbin` header/layout, value type, channel order, row/slice ordering, normalization, interpolation, alpha handling, and input/output primaries or transfer functions. The presence of `CIColorCubeWithColorSpace` does not reveal which color space is selected.
- User-created preset slider ranges, clamping, units, serialization schema/versioning, and migration rules.
- Group/category model, export packaging, naming collision behavior, favorite handling, and LUT embedding versus reference policy.

## 5. Negative mode (底片模式)

### Observed behavior indicators

The executable has messages for `Queueing negative save captureID=`, `Negative saved captureID=`, `Negative save failed captureID=`, `Importing locked camera negative`, `Negative crop rotation reset to zero by double tap`, `Negative cropper preserved live straighten=`, `Negative Film filter group restored: all`, and `Negative Film LUT load failed id=`. RAW conversion logs include `convert raw to master tape start`, `RAW-to-Negative decoder default=RAW 8`, `convert raw to master tape saved`, and `raw conversion skipped because its primary image cannot be decoded`. Editor rendering has `negativeGeometry stage=processed heifPlus=` and export messages `export raw to file` / `generate heif+`.

Photos writes are separate from the app-private edit/negative representation. In addition to the type-9 paired-video path documented in section 2, the binary has a type-1 photo-data + type-4 alternate-photo path. Main-app strings and models include `MasterTapeHeifPlusEditSettings`, `heifPlusImage`, `raw data`, and capture-ID keyed negative saving. That supports an editable source plus derivative resources, but does not prove the exact private negative container or transactional linkage.

This is direct evidence of a persistent “negative” concept, RAW-to-negative conversion, capture-ID keyed asynchronous save, and a multi-filter negative editor. “Master tape” appears in logs; its on-disk format is not established by that string.

### Reproduction boundary

To preserve lossless re-editability, keep a source representation separate from the processed Photos-library image and store editing parameters (preset/LUT identity, adjustment values, crop/rotation/straighten, and output-format choice) as a recipe. Render the gallery derivative from this source/recipe on demand. The shipped evidence supports retaining RAW data and re-generating HEIF+; it does not prove that all negative records are RAW/DNG or that the gallery export is paired with a sidecar in a particular schema.

### Unknowns

- Private negative storage location/container/schema (including the “master tape” encoding), exact association between capture IDs, RAW bytes, edit settings, and Photos asset local identifier, and retention/deletion/backup policy.
- Whether processed Photos output is JPEG/HEIF/HEIF+ and how Photos asset identifiers link back to negatives.
- Exact re-edit path for changing filters, color temperature, and format conversion; “lossless” is not proven for every source/mode.
- Import/export, transaction/recovery semantics, and whether `master tape` is a file-format name or merely an internal label.

## 6. Manual exposure logic

### Evidence

The binary contains `ManualISOIntroductionAnimation.swift`, `ManualISOQuickDragAnimation.swift`, strings `ISO`, `shutterSpeed`, `lensRawValues`, `priority exposure`, `exposureTargetBias`, `exposureTargetOffset`, `adjustingExposure`, `minExposureSeconds`, `maxExposureSeconds`, `Photo automatic exposure state captureID=`, and a vertical exposure meter. It logs that priority exposure is unsupported for an active device type and has an aperture-range fallback to legacy exposure compensation. IDA also recovered distinct `LegacySemiAutomaticExposureController` and `IOS27SemiAutomaticExposureController` types; the iOS 27 controller declares a `PriorityMode` enum. `DeviceParameters.exposureTargetOffsetChangedWithExposureTargetOffset:` is an observed callback.

This supports separate ISO/shutter controls and UI feedback for automatic exposure state, with version-specific controller implementations. The state updater `sub_100171978` passes current shutter duration, aperture, ISO, and aperture/exposure/ISO mode flags to the selected semi-automatic controller. If the controller returns false (unsupported), it falls back to `setExposureModeCustomWithDuration:ISO:`. Thus one variable can be user-prioritized while the controller selects a compensating second variable within device limits.

IDA recovers concrete slider/control calculations:

- ISO selector `sub_10016EAAC`: normalized input `x` maps as `ISO = minISO + (maxISO - minISO) * x^3`. Quantization step depends on the preliminary ISO: `5` at/below `100`, `100` at/below `1000`, `500` at/below `10000`, and `1000` above `10000`; it rounds to that step and clamps to `[minISO, maxISO]`. It updates stored ISO then asks the semi-automatic exposure controller to compute an exposure duration; if unsupported, it applies current duration plus chosen ISO with custom exposure.
- Shutter selector `sub_10016ED74`: normalized input maps across the configured shutter range, rounds through the app's shutter-index conversion, then clamps to active-format minimum/maximum exposure duration. It asks the controller for a compensating ISO; if unsupported, it applies the clamped duration plus ISO through custom exposure. Stored shutter-speed display is updated from `-round(log2(duration))` and converted back through the shutter mapping.
- `exposureTargetOffsetChangedWithExposureTargetOffset:` calls `sub_100170F3C`. In the manual-shutter/auto-ISO branch it maps the signed offset into step changes of 5 ISO at `|offset|≤0.5`, 20 ISO at `0.5<|offset|≤1`, and 80 ISO at `|offset|>1`; positive offsets reduce ISO, negative offsets increase it, then the value is clamped to the active format's minimum/maximum ISO. In the manual-ISO/auto-shutter branch, thresholds include `0.05`, `0.1`, `0.2`, `0.5`, `1`, and `2`; signed adjustment amounts include `0.02`, `0.04`, `0.08`, `0.2`, `0.4`, and `1.0` stop-like units, applied as `exp2` duration multipliers and clamped to active-format min/max exposure duration. It updates only if the computed value differs from current exposure and then requests compensation through the semi-automatic controller, falling back to custom duration/ISO settings when unsupported. This is an exposure-target-offset response, not a general claim that every independent-control change preserves exposure automatically.
- `sub_10016E9A0` clamps exposure bias against device `minExposureTargetBias` / `maxExposureTargetBias` before calling `setExposureTargetBias:completionHandler:`.

The “primary-level” feedback is represented in the system by observed exposure-target offset and app-owned shutter/ISO state. Exact UI text/layout and how the exposure meter presents the fixed primary-level indicator are not completely recovered.

### Unknowns

- Exact calibrated slider range values per camera/device, full quantization table for all ISO tiers, and precise conversion in the shared shutter-index helper; those depend on runtime format/device ranges.
- Meaning and value of “priority exposure” and “primary level,” and the UI feedback/EV compensation equation.
- Default exposure mode and per-device defaults. No inferred values are supplied here.

## 7. Separate AF/AE locks

The app has a `focusExposureLock` preference/state key and two distinct state/configuration paths in `DeviceParameters`:

- Focus interaction `sub_10016E3E0` maintains a focus-mode state, checks focus-point and focus-mode support, locks the device configuration, sets the focus point as `(x, 1-y)` when applicable, sets the requested focus mode, and unlocks. Its mode-toggle branch disables subject-area monitoring while locked and posts a notification when returning to the unlocked/automatic state.
- Exposure interaction `sub_10016E6BC` maintains separate exposure-mode and ISO-mode state. It chooses continuous-auto vs locked exposure mode based on the requested transition, checks `isExposurePointOfInterestSupported` / `isExposureModeSupported:`, locks device configuration, updates exposure point `(x,1-y)` (or center `(0.5,0.5)` for non-point operations), asks the semi-automatic exposure controller to refresh, sets exposure mode, then unlocks.
- A direct manual focus path `sub_10016F3B8` sets continuous autofocus, clears the focus-mode state, clamps lens position to `[0,1]`, then calls `setFocusModeLockedWithLensPosition:completionHandler:`. This path is distinct from the tap-point interaction.

The core behavior is independent focus/exposure mode state rather than one unified AVFoundation long-press mode. State updates are separate and capability-checked, while device mutations are protected by `lockForConfiguration` / `unlockForConfiguration`. The focus interaction controls subject-area monitoring as the focus mode changes; exposure mode changes are synchronized with the semi-automatic exposure controller. API stubs also exist for `lockFocus`, `unlockFocus`, `lockExposure`, and `unlockExposure` in a bundled camera component, but the main app's exact gesture-to-lock API call is not conclusively linked in this disassembly.

Unknown: exact UI gesture-to-operation mapping, lock icon presentation, state persistence across camera/lens changes, and whether every device uses the same reset behavior. A generic `focusExposureLock` state key exists, but the exact interaction controller's full UI state machine is not yet resolved.

## 8. Focus peaking

The rendering path updates `SobelFilter` with a selected `CIColor`, threshold, and preview image; when the filter returns nil it falls back to the preview. Therefore edge detection is Sobel-based. `SobelFilter.init` at `0x10050B4DC` initializes its color vector to `(1,1,1)` and its Float threshold to `0.5` (IEEE-754 bit pattern `1056964608`). `MetalViewHolder` at `sub_100204A88` overwrites both using shared runtime configuration (`dword_100DD6FC0`, `qword_100DD6FB8`), so those are class defaults and not necessarily active settings.

Unknown: the Core Image kernel implementation (`sub_10050B2D0`), gradient magnitude/threshold comparison, mask and overlay compositing, active configured color/threshold, opacity, and UI setting ranges. The initializer defaults must not be represented as guaranteed runtime defaults.

## 9. Default camera configuration

The provided static evidence does not establish the requested complete default matrix (capture format, preset, exposure mode, flash, resolution, Live Photo, Portrait, adjustable settings). Bundled preset defaults are listed in section 3, but they are not necessarily the app's selected camera defaults. App strings such as `rawFormat`, `prorawToggle`, and `hasShownBayerRAWAlert` are state-key hints, not their default values.

Known default values recoverable from bundled preset files: all listed presets have `isFavorite=false`; global preset adjustments serialize to neutral values shown in section 3; LUT intensities are in the table. These are resource defaults only.

Unknown: selected default preset and format; default flash/torch/Live Photo; default resolution/ratio; default manual/auto exposure; ISO/shutter/EV; focus-peaking enabled/color/threshold; timer/grid/level; RAW decoder mode; negative retention; and all adjustable setting min/max/step/default values. These require examining persisted app preferences on a clean install or identifying their initialization assignments in disassembled code.

## IDA findings: code locations and recovered order

The following addresses are IDA image VAs for the main executable in this IPA. Pseudocode for large optimized Swift functions has incomplete local-variable recovery; retain that limitation when reproducing behavior.

| Feature | Location | Static observation |
|---|---|---|
| HEIF+ editor generation | `sub_100516980` (`0x100516980`) | Editor-side path logs quality and explicit missing-RAW failure. |
| HEIF compression quality option | `sub_1001CB314` (`0x1001CB314`) | Image destination dictionary sets `kCGImageDestinationLossyCompressionQuality` from a settings-indexed Double (index at object offset `+50`). Values unresolved. |
| ProRAW settings override | `RawCompressor` at `0x100165E14`; helper `sub_100166170` (`0x100166170`) | Sets `AVVideoAppleProRAWBitDepthKey` and `AVVideoQualityKey`: maximum bit depth with quality 1.0 when depth flag is set; otherwise `min(maximumBitDepth, 8)` with quality about 0.998. Metadata replacement is conditional. |
| RAW decode/preset processing | `sub_100166A7C` (`0x100166A7C`), called through RAW modifier path | Instantiates `CIRAWFilter` from data; applies baseline exposure, optional supported color/luminance NR, sharpness from RAW preset and contrast = sharpness/2, local tone mapping, temperature/tint; uses linear-space filter fallback when local tone mapping is unsupported. |
| Capture settings | `sub_1001FAEF4` (`0x1001FAEF4`) | Creates `AVCapturePhotoSettings`; selects available RAW format and ProRAW/Bayer path; sets preview format when available; conditionally adds `.mov` Live Photo URL; configures quality priority (special-case skip for iPhone Duo Bayer RAW); configures RAW DNG codec/thumbnail where applicable; requests supported semantic mattes/depth/portrait effects matte and embeds them. Bayer RAW excludes capture-time depth/mattes. |
| Live Photo assembly | `sub_100146568` (`0x100146568`) | Waits on dispatch group; reads LiveCreator stored/original movie URLs; wait constant 3.6 seconds; timeout and no-wait branches. |
| Focus-peaking update | `sub_100204A88` (`0x100204A88`) | Supplies image, color, threshold to SobelFilter; nil output retains the preview. |
| Focus-peaking defaults | `SobelFilter.init` (`0x10050B4DC`) | Color vector `(1,1,1)`, Float threshold `0.5`; active values can be overwritten at runtime. |
| LUT import dispatch | `sub_10017BBFC` (`0x10017BBFC`) | Security-scoped URL; extension dispatch. `.preset` uses `Data` + `PropertyListDecoder` into `StylePreset`; `.cube` is read as text and converted through importer helpers. |
| LUT image import | check at `0x10017C510` | Requires 512x512 image; distinct format/size errors. |
| LUT application | `CIColorCubeWithColorSpace` references near `0x100CB1D64` | Uses cube data and dimension; selected color space unresolved. |
| Semi-automatic exposure | `LegacySemiAutomaticExposureController` around `0x100174980`; `IOS27SemiAutomaticExposureController` around `0x100175208` | Two controller implementations exist; iOS 27 version defines `PriorityMode`. |

**Camera-settings partial sequence**

The recovered static order within the photo-settings construction path is: allocate `AVCapturePhotoSettings`; obtain available raw pixel formats; decide between Bayer RAW and Apple ProRAW; build processed/RAW settings as applicable; configure preview pixel format if available; attach the Live Photo movie URL when the output reports Live Photo enabled; configure quality prioritization unless in the iPhone Duo Bayer RAW exception; configure DNG codec and embedded thumbnail for RAW paths; enable/attach supported semantic mattes, depth data, and portrait-effects matte except when Bayer RAW logic skips capture-time depth/mattes. The exact order relative to all camera session/device configuration and callback execution remains unknown without runtime capture.

**Additional shipped-UI constraints**

UI strings explicitly state Live Photo can be used in ProRAW, HEIF+, and 48MP modes. They also warn that HEIF+RAW merge prevents Live Photo save and offer disabling merge to preserve Live Photo. Negative capture can retain motion data even when the visible Live Photo switch is off, for later editor restoration. This is compatibility handling, not proof of bypassing an iOS system restriction.

## Evidence assets and next probes

Extracted paths of particular interest within the app bundle:

- `Frameworks/NFAsset.framework/*.preset`
- `Frameworks/NFAsset.framework/*.lutbin`
- `Frameworks/NFAsset.framework/DepthModel.mlmodelc/`
- `Frameworks/NFAsset.framework/metadata.heic` and `disparity.heic`
- `No Fusion` (arm64 executable)
- `README.md` (contains a halation rendering note, not sufficient to establish production pipeline order)

For source-level-equivalent reconstruction, the next high-value evidence is targeted decompilation of camera configuration/capture, RAW decode/compress, HEIF encode, Live Photo assembly, depth generation, preset parsing/rendering, and preference initialization functions. Runtime testing on supported iPhones is required to establish callback sequence, device capability behavior, and actual output encoding/storage. Preserve this document's distinction between package observations and those future runtime findings.
