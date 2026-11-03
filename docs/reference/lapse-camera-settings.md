# Lapse Camera Settings and Reproduction Guide

This is the retained camera-settings document for Lapse 4.4.1. It is based on the supplied decrypted development IPA:

- File: `lapse-4.4.1-decrypted-dev-build.ipa`
- SHA-256: `d9fe5aeb64eb6cd15c5f7fcfcd34b836bb80a9d4df4944673fba1a2b31e85b34`
- REA archive Evidence: `ev_c90c1a42a60f76d1a1142057774755d432388b41817ceb2612ae0af5484ca3d4`
- REA archive inventory: 1,164/1,164 entries, zero integrity contradictions
- Native extraction Evidence used by the investigation: `ev_6b540bbdd079137c0275951e15b5df96931cd54133d6ee9d865900f65320cbca`
- Core Image framework Evidence: `ev_62435dc6e3df658de906bc456a7af92c875bb31ba4b134aeeb48352a622fef42`

The IPA was statically analyzed. No iOS camera or GPU capture was run. Values below are therefore either shipped defaults, static control flow, or explicit reconstruction formulas. Runtime-selected routes, scene values, device formats, custom files, and Apple ISP behavior remain inputs.

## 1. Camera capture settings

### Session

Create `AVCaptureSession` with:

- `sessionPreset = AVCaptureSessionPresetInputPriority`
- `usesApplicationAudioSession = true`
- `automaticallyConfiguresApplicationAudioSession = false`
- `automaticallyConfiguresCaptureDeviceForWideColor = false`
- Version-gated `configuresApplicationAudioSessionToMixWithOthers = true`
- The conditional second session uses the same values.

The app selects an active device format separately. Do not replace this with a universal `.photo` or `.high` session preset.

### Focus, exposure, and frame rate

At initialization and after subject-area reset, use normalized point `(0.5, 0.5)` and continuous modes when supported:

```text
if focusPointOfInterestSupported && focusModeSupported(.continuousAutoFocus):
    focusPointOfInterest = (0.5, 0.5)
    focusMode = .continuousAutoFocus
if exposurePointOfInterestSupported && exposureModeSupported(.continuousAutoExposure):
    exposurePointOfInterest = (0.5, 0.5)
    exposureMode = .continuousAutoExposure
if lowLightBoostSupported:
    automaticallyEnablesLowLightBoostWhenAvailable = true
if smoothAutoFocusSupported:
    isSmoothAutoFocusEnabled = true
isSubjectAreaChangeMonitoringEnabled = false
```

Before the centered continuous setup, the app conditionally sets one-shot focus/exposure and enables face-driven AF/AE. Preserve that initialization order if matching behavior.

A user point-focus operation uses the supplied point with one-shot autofocus/autoexposure and enables subject-area monitoring. The examined format setup requests:

```text
activeVideoMinFrameDuration = 1/30 second
activeVideoMaxFrameDuration = 1/30 second
```

This is a setup request, not a guarantee that every delivered frame is 30 fps.

### Zoom

Clamp requested zoom as follows:

```text
zoom = max(device.minAvailableVideoZoomFactor,
           min(requestedZoom,
               min(device.maxAvailableVideoZoomFactor, 20.0)))
```

Set it under `lockForConfiguration` and unlock afterward. Initial lens setup uses `minAvailableVideoZoomFactor`. The app also has a ramping setter and cancellation helper; the complete ramp-rate policy was not recovered.

### Photo dimensions

The device supplies packed `(width,height)` pairs. Keep entries satisfying:

```text
abs(float32(width) / float32(height) - float32(1.3333333730697632))
    < float32(0.009999999776482582)
```

For ordinary stills, store the matching list and use its **last** element as `AVCapturePhotoOutput.maxPhotoDimensions`. For burst, use the **first** stored element. Do not hardcode 4032x3024 or another megapixel count.

### Photo output and shot settings

Create `AVCapturePhotoOutput` and set:

- `isDepthDataDeliveryEnabled = false`
- `isLivePhotoCaptureEnabled = false`
- `maxPhotoQualityPrioritization = .quality` (raw value 3)

For ordinary per-shot settings:

1. If `availablePhotoCodecTypes` contains HEVC, create settings with `AVVideoCodecKey = AVVideoCodecTypeHEVC`; otherwise use the plain settings initializer.
2. Disable depth delivery and portrait-effects matte delivery.
3. Set semantic-segmentation matte types to an empty array.
4. Set `photoQualityPrioritization` from the adaptive caller value.
5. Enable auto red-eye reduction and virtual-device fusion only when priority is not `.speed` (raw value 1), if supported.
6. Use the first available preview pixel format. When `hiResPreviewRequired` is true, request preview width and height 2016.
7. Copy `maxPhotoDimensions` from the photo output.
8. If flash-on is supported, source request bytes 1 and 2 select hardware flash raw value 1; source bytes 0 and 3 select off raw value 0.

Burst settings differ: HEVC is still preferred, quality priority is `.speed` (raw 1), the first stored photo dimension is used, preview format is nil, semantic mattes are empty, auto red-eye/fusion are disabled, and flash is off.

Per-shot quality can return raw values 1/speed, 2/balanced, or 3/quality. A recovered final branch is:

```text
if captureConfigByte_0x28 == 2:
    priority = .balanced
else if computedEV > 6.0:
    priority = .balanced
else:
    priority = .quality
```

Earlier flag branches are not completely resolved. Do not claim that every shot uses quality priority.

### Orientation, mirroring, stabilization

For photo and video-data connections:

- Request portrait video orientation (raw value 1) where supported.
- Disable automatic mirroring.
- Set `videoMirrored = true` for front-camera position (raw device position 2).

The examined video-data connection requests stabilization raw value 1. Another preview connection requests stabilization raw value 4. Keep those paths separate.

## 2. Capture metadata passed into processing

Before processing, read these values from the active capture device:

| Offset | Type | Meaning |
|---:|---|---|
| `+0x00` | float32 | temperature |
| `+0x04` | float32 | tint |
| `+0x08` | float32 | ISO |
| `+0x0c` | 24-byte `CMTime` | exposure duration |
| `+0x24` | float32 | computed scene EV |

Compute EV as:

```text
EV = log2(aperture * aperture / ((ISO / 100) * exposureSeconds))
```

If exposure duration or ISO is zero, use EV `8.0`. Do not use the processing exposure adjustment as the capture EV.

Convert device white-balance gains into temperature/tint. If gains are invalid (`gain >= maxWhiteBalanceGain` or `gain < 1`), conversion fails, or the callback is absent, use temperature `4000.0` and tint `0.0`. These are processing metadata fallbacks; they do not lock the physical camera white balance.

Carry temperature, tint, ISO, duration, EV, flash state, camera position, orientation, source dimensions, codec, and original encoded image data into the image-processing layer.

## 3. Processing engine selection

Lapse contains three separate processing engines:

- `coreImage`: `LapseImage.framework/LapseImage`
- `metal(.default)`: `LapseImageExtended.framework/LapseImageExtended` standard pipeline
- `metal(.custom)`: Extended pipeline loaded from persisted custom configuration

The build-local Swift routing enum is encoded as byte 0 = standard Metal, 1 = custom Metal, 2 = Core Image. This byte is not a public file format.

Custom Metal uses these shipped base configurations:

```text
photo  -> pipeline_photo_v1
instant -> pipeline_instant_v1
```

The default custom-pipeline directory is the app Documents directory plus `custom_pipelines`. The IPA cannot reveal files or overrides saved there.

For Instants, the Core Image branch uses `instantsWithNewCompressedLut(instantTweaks: false)` when the new-instants flag is selected, and the older CI Instants pipeline otherwise. The standard/custom Metal branches are separate. For ordinary stills, the cached CI constructor is:

```text
journal(
    branding: false,
    applyLightLeaks: false,
    applyDust: false,
    useGlobalBlur: true,
    useAdaptiveShadowColorVary: false,
    lutConfig: .v4
)
```

No single global runtime route was recovered. Keep route selection as an explicit input.

## 4. Shared geometry

### Orientation

The CI data entry creates an oriented `CIImage` with orientation application enabled. Apply EXIF orientation exactly once before crop and effects. Do not apply the same orientation again during export.

### Aspect-fill scale and crop

Use `CILanczosScaleTransform` followed by centered `CICrop`, then translate the origin to zero:

```text
scale = max(targetWidth / inputWidth, targetHeight / inputHeight)
cropX = (inputWidth * scale - targetWidth) / 2
cropY = (inputHeight * scale - targetHeight) / 2
```

Convert `scale` to float32 before passing it to Core Image. Recovered CI processing size pairs are:

```text
(3024,4032), (1080,1920), (1512,2016), (1080,1080), (756,1008)
```

These are processing targets, not sensor capture dimensions. Named CI pipelines reject images below 700x700.

## 5. Core Image recipes

All stages below are ordered. Only include stages that are enabled for the selected factory and flags.

### New Instants, `instantTweaks=false`

```text
LandscapeComposition
ScaleAndCrop
Blur(radius=1.5)
Vignette(radius=0.2, intensity=2)
Exposure(ev0=0.75, ev10=0.91, flash=0.62)
FaceBalance(origI=0.1, origQ=0.01, strength=0.36, warmth=0.15)
TeethWhitening(hue=0, saturation=0.75, lightness=1, feather=10)
ColorOverlay(random=false, colorBlend=false, RGB=(60.44,30,165), alpha=0.1)
Vibrance(level=0.05) -> ColorControls(saturation=1)
LUT(V4, opacity=1)
PhotoEffect(enabled=false, opacity=0.5)
TemperatureAndTint(enabled=false, neutral=3200, target=3200, tints=0)
FilmGrainDynamic
```

The blue overlay value 165 exceeds its stored blue range `[0,135]`; preserve the literal and do not clamp it.

### New Instants, `instantTweaks=true`

```text
LandscapeComposition
ScaleAndCrop
Blur(radius=1.5)
Vignette(radius=0.2, intensity=2)
Exposure(ev0=1.0, ev10=0.75, flash=0.62)
FaceBalance(origI=0.1, origQ=0.01, strength=0.5, warmth=1)
ColorOverlay(random=false, colorBlend=false, RGB=(60.44,30,165), alpha=0.1)
Vibrance(level=0.1) -> ColorControls(saturation=1)
LUT(V4, opacity=1)
FilmGrainDynamic
```

This branch omits teeth whitening, PhotoEffect, and TemperatureAndTint.

### Cached CI Journal

```text
LandscapeComposition
ScaleAndCrop
Halation
LUT
Gamma
Exposure
Color
FaceBalance
SkinToneTwo
Vibrance
HighlightShadow
Vignette
TransverseChromaticAberration
GlobalBlur
Blur
FilmGrainDynamic
```

The recovered cached constructor disables branding, light leaks, dust, and adaptive shadow-color variation, and enables global blur. Its scalar values are:

| Setting | Value |
|---|---:|
| Exposure EV0 / EV10 / flash | `0.55 / 0.50 / 0.50` |
| Gamma power / flash power | `0.9 / 1.0` |
| Vibrance / saturation | `0.4 / 1.0` |
| Vignette radius / intensity | `0.15 / 1.75` |
| Final blur radius | `0.3` |
| Chromatic blur | `16` |
| Chromatic RGB offsets | `(0, 6, 12.75)` |
| Chromatic falloff / samples / scale | `0.6 / 80 / 1.45` |
| Highlight amount / shadow amount | `0.95 / 0.15` |
| Highlight-shadow radius / saturation / brightness | `0.5 / 0.95 / -0.35` |
| Highlight shift hue / saturation / brightness | `0 / 1 / 0.75` |
| Highlight-shadow opacity | `0.4` |
| Global blur opacity / regular radius / darken radius | `0.3 / 0.5 / 4` |

Optional journal dust defaults, when the flag is enabled, are enabled, whiten factor `7`, stretch `1`, opacity `1`, brightness `-0.8`, contrast `2`, radius `0.99`. Optional light-leak placement is randomized; its shipped defaults cannot determine one photo's draw.

### Other CI factories

`colorNegative` and `colorPositive` do not construct a LUT. Both contain halation, HSV, color, gamma, exposure, face balance, skin tone, vibrance, highlight/shadow, vignette, chromatic aberration, blur, disabled temperature/tint, and grain. Their order differs:

- Negative: `LandscapeComposition -> ScaleAndCrop -> Halation -> HSV -> ToneCurve -> Color -> Gamma -> Exposure -> FaceBalance -> SkinToneTwo -> Vibrance -> HighlightShadow -> Vignette -> ChromaticAberration -> Blur -> disabled TemperatureAndTint -> Grain -> optional branding`
- Positive: `LandscapeComposition -> ScaleAndCrop -> Halation -> HSV -> Color -> Gamma -> Exposure -> HighlightShadow -> FaceBalance -> SkinToneTwo -> Vibrance -> Vignette -> ChromaticAberration -> Blur -> disabled TemperatureAndTint -> Grain -> optional branding`

Monochrome is:

```text
LandscapeComposition -> ScaleAndCrop -> Halation -> Gamma -> Exposure ->
ChromaticAberration -> Blur -> MonochromeUtility -> HighlightShadow ->
Vignette -> TemperatureAndTint -> FilmGrainDynamic -> optional branding
```

The three shared color/monochrome factories use chromatic aberration blur `16`, offsets `(0,6,12.75)`, falloff `.6`, samples `80`, scale `1.45`; their exact tone-curve and HSV literals are not needed for the default camera route unless that factory is selected.

## 6. Core Image effect behavior

- Exposure uses `CIExposureAdjust`. If flash is true, use `flashExposure`; otherwise use `ev0 + sceneEV*(ev10-ev0)/10`. No clamp was observed.
- Gamma uses `CIGammaAdjust`, selecting normal or flash power.
- Vibrance uses `CIVibrance`, then `CIColorControls` saturation.
- Vignette centers the source in a white square of side `max(width,height)`, applies `CIVignette`, reverses the translation, and crops to the original extent.
- Face balance instantiates `CIFaceBalance` with the four recovered inputs. This does not prove the internals of Apple's filter.
- Teeth whitening requests `kCIImageAuxiliarySemanticSegmentationTeethMatte`, aligns it with the same geometry helper, adjusts an orange band, feathers the mask, and uses `CIBlendWithRedMask`. Missing matte returns the original image. The examined camera settings disable semantic-matte delivery.
- CI global blur creates regular and darken Gaussian-blurred images, combines them with `CIDarkenBlendMode`, scales the blur layer alpha, composites over the original, and crops.
- Highlight/shadow uses `CIHighlightShadowAdjust` with `highlightAmount = 1 - storedHighlightAmount`, then color controls, red-band HSL shift, luminosity blend, opacity, and source-over.
- CI film grain changes generated-noise intensity to `1 - 0.05*sceneEV` with no observed clamp. Noise begins from a `3024/grainSize` by `4032/grainSize` canvas, is Lanczos-scaled, then cropped through output geometry.

## 7. Standard Metal defaults

These are Extended defaults when no custom parameters provider overrides them. The compiled `default.metallib` should be reused for closest parity.

### `photo_default`

Order:

```text
LUT -> masked adjustments -> masked selective color -> global blur -> halation ->
color overlay -> adaptive shadows -> vignette -> chromatic aberration -> blur -> grain
```

Recovered values:

- LUT intensity `.75`.
- Masked adjustments: exposure `0`, contrast `-.25`, saturation `-.7`, vibrance `.95`, temperature/tint `0`, shadows `-.45`, highlights `-.4` unmasked and `-.3` masked. Adaptive exposure is enabled; stored adaptive endpoints are `.5` and `.3` in the original field order.
- Global blur radius `1`, opacity `.4`.
- Halation luma threshold `.92..95`; red threshold `.93..99`; back/front blur sigma `20/15`; back color `(.9,.001,0,1)` intensity `.65`; front color `(.99,.69,.24,1)` intensity `1`.
- Color overlay `(.56,.51,.45,1)`, intensity `.13`, `isColorBlend=false`.
- Adaptive shadows color `(.2,.2,0)`, intensity `0`, adaptive endpoints `1/.4` in original field order.
- Vignette intensity `.9`, power `.09`, radius `.95`.
- Chromatic aberration samples `20`, start `.42`, blur `.02`, offsets `(0,.006,.01275)`, scale `1.05`.
- Blur radius `.5`.
- Grain enabled: small/big `.5/.65`, blur `.35`, random noise and adaptive intensity enabled.
- Dust, low-res, min/max, and branding disabled.

### `instant_default`

Order:

```text
Blur -> global blur -> halation -> classic adjustments -> classic selective color ->
adaptive shadows -> color grading -> LUT -> vignette -> color overlay -> grain
```

Recovered values:

- Blur radius `1.25`; global blur radius `2.5`, opacity `.45`.
- Halation luma `.92..95`; red `.93..99`; sigma `20/15`; back color `(.95,.65,.65,1)` intensity `.8`; front color `(.98,.91,.63,1)` intensity `1`.
- Classic adjustments: exposure `.1`, contrast `0`, saturation `-.35`, vibrance `.3`, temperature `-.3`, tint `.1`, shadows `-1`, highlights `-.1`. Adaptive exposure is enabled with endpoints `1/.4` in original field order.
- Adaptive shadows color `(.2,.2,0)`, intensity `0`, adaptive endpoints `1/.4`.
- Color grading shadows `(.3,0,.5,1)` intensity `.8`; highlights `(1,.74,.36,1)` intensity `.3`.
- LUT intensity `1`.
- Vignette intensity `.35`, power `.4`, radius `1`.
- Overlay `(.63,.53,.48,1)`, intensity `.15`, `isColorBlend=false`.
- Grain enabled: small/big `.5/1`, blur `0`, random noise and adaptive intensity enabled.
- Dust, low-res, min/max, chromatic aberration, and branding disabled.

## 8. LUT and shader reproduction

Recovered LUT resources are 33 x 33 x 33 with 35,937 RGB rows and no domain declaration. The V4-03 compressed resource is 301,376 bytes, SHA-256 `41a01365001d6ceedff26fe776ccd5c14c7c48216eea746e5bce7f5ea8716272`. Zlib decompression reproduces the V4-03 cube text byte-for-byte. V4-03 cube SHA-256 is `6e9a03e7d1c9c32779feba4e74addc809797a8dfb2f6b02cd985972f6d7ca239`; V4-02 cube SHA-256 is `e8b6de0f8c51edc48bcf8471c81f0d8aa26f9118408cfb359ca41ba026f9115f`.

For Core Image:

```text
parse LUT_3D_SIZE = 33
preserve row order
for each RGB row:
    append float32(r), float32(g), float32(b), float32(1.0)
create Device RGB color space
create CIColorCubeWithColorSpace with dimension 33
```

For Metal, the LUT kernel samples normalized RGB coordinates from a 3D texture and mixes source with the sampled value by intensity while preserving source alpha. Reuse the original texture format and sampler state; a CPU `rgb*(N-1)` implementation is not proven equivalent.

Important shader differences:

- CI grain is additive RGB-like noise with RMS-style luminance, noise offset `.28`, and RGB clamp `[0,2]`.
- Metal grain is seeded integer-hash noise with tone-dependent normalized-L adjustment. It is not CI grain.
- CI chromatic aberration uses Core Image destination coordinates; Metal uses normalized UV coordinates.
- Metal vignette uses pixel-center UVs and `q = clamp(radius * (uv - .5), -.5, .5)`. Radius is a coordinate multiplier, not a denominator.
- Metal halation composites host-created blurred masks; the kernels do not create the blur.
- Metal masked adjustments interpolate parameter values by mask before nonlinear adjustment. Do not blend two finished images as a substitute.
- Metal selective color is a different algorithm from CI `MultibandHSV`.

## 9. Output and metadata

The CI renderer uses a caller-provided `CIContext`; the framework does not establish one universal working color space. Data export can copy source properties, apply caller-supplied lossy quality, remove orientation keys after pixels are oriented, and write capture parameters into EXIF `UserComment`. JPEG and HEIF paths exist. No universal JPEG quality, fallback codec, or byte-identical output across iOS versions was recovered.

## 10. Reproduction checklist

1. Start with the original encoded photo and apply orientation once.
2. Configure the camera using the session, focus/exposure, 30 fps request, dimension, codec, flash, quality-priority, mirroring, and stabilization rules above.
3. Record the capture tuple: temperature, tint, ISO, exposure duration, scene EV, flash state, lens position, source dimensions, and route flags.
4. Select exactly one engine and one preset/config. Do not combine CI and Metal defaults.
5. Apply the exact ordered enabled stages and route-specific geometry.
6. Use the original LUT and metallib resources where available. Preserve float32/half precision, alpha handling, coordinate units, masks, crop, and clamp behavior.
7. Render with the matching CIContext or Metal texture/sampler setup, then export metadata separately from pixels.
8. Validate on the same iOS version/device with controlled fixtures: LUT color ramp, portrait and square crop grids, bright red/white edges for halation and aberration, EV 0/5/10 gray patches with flash on/off, and masked/unmasked color patches.

## 11. Cannot be recovered from this IPA alone

- Which engine, feature flags, and preset were selected for an individual capture.
- Custom pipeline files or overrides in Documents `custom_pipelines`.
- Actual device lens/format, ISO, shutter, white balance, sensor frame rate, and scene EV for a particular shot.
- Camera ISP output, Apple's `CIFaceBalance` internals, OS-specific Core Image behavior, and semantic-matte availability at runtime.
- The source/background state of the legacy CI `CIHueBlendMode` intermediary.
- Random seeds and placement for dust/light leaks.
- Exact HEVC fallback behavior, final codec/quality, and byte-for-byte output across OS versions.

These are runtime or external-state gaps, not missing built-in constants. The built-in camera and processing settings recovered from the shipped IPA are documented above.
