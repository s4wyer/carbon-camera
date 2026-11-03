# D-002: Baseline camera configuration (Lapse + overrides)

**Decision ID:** D-002  
**Concerns:** Roadmap comparison C01, C23; ticket SET06c  
**Date:** 2024-11-03  
**Authority:** Roadmap §1 mandates Lapse as baseline; Halide/No Fusion override individual fields only where their pipeline requires it or the product goal demands it.

## Base (from Lapse `§1`)

```swift
// AVCaptureSession
sessionPreset = .inputPriority  // NOT .photo or .high
usesApplicationAudioSession = true
automaticallyConfiguresApplicationAudioSession = false
automaticallyConfiguresCaptureDeviceForWideColor = false
configuresApplicationAudioSessionToMixWithOthers = true  // version-gated

// Active device (initialization, subject-area reset)
focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)  // if supported
focusMode = .continuousAutoFocus                 // if supported
exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)  // if supported
exposureMode = .continuousAutoExposure          // if supported
automaticallyEnablesLowLightBoostWhenAvailable = true  // if supported
isSmoothAutoFocusEnabled = true                 // if supported
isSubjectAreaChangeMonitoringEnabled = false

// Frame rate
activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)

// Zoom
videoZoomFactor = device.minAvailableVideoZoomFactor
// Clamp requested zoom: max(device.minAvailableVideoZoomFactor,
//                           min(requestedZoom,
//                               min(device.maxAvailableVideoZoomFactor, 20.0)))

// Photo output
isDepthDataDeliveryEnabled = false
isLivePhotoCaptureEnabled = false
maxPhotoQualityPrioritization = .quality  // raw 3

// Per-shot settings
// Prefer HEVC codec when available
// Disable depth delivery, portrait-effects matte, semantic-segmentation mattes (empty array)
// Quality prioritization:
//   if captureConfigByte_0x28 == 2: .balanced
//   else if computedEV > 6.0: .balanced
//   else: .quality
// Auto red-eye reduction: enabled when priority != .speed and supported
// Virtual device fusion: enabled when priority != .speed and supported
// Preview format: first available; hiResPreviewRequired → 2016x2016
// maxPhotoDimensions: last stored 4:3 pair for regular stills; first for burst
// Flash: request bytes 1,2 → .on (raw 1); bytes 0,3 → .off (raw 0)

// Orientation, mirroring, stabilization
// Photo connection: .portrait orientation (raw 1) if supported, no auto mirroring,
//   videoMirrored = true for front camera (device position raw 2)
// Video-data connection: stabilization raw 1
// Preview connection: stabilization raw 4
```

## Overrides

| Field | Override to | Why | Source |
|---|---|---|---|
| Default output | HEVC-coded still (Lapse), **but** retain RAW source + recipe for re-development | Amateur shareability (HEVC/HEIF small/fast) + durable re-edit requirement (roadmap §6) | Comparison C02; D-003 |
| Flash | `.auto` by default | Product goal: good people photo out of the box. Auto flash is safer than off/on for amateurs. | D-012 |
| RAW sharpening | **Disable** sharpening in the primary path (use Halide pure-RAW options: `sharpening: false`, `noiseReductionSharpnessAmount: 0`, `contrastAmount: 0`) | Process Zero is the base film; sharpening is an effect, not a default. | Comparison C03; D-004 |
| Prime focal length | Default to **35mm-equivalent** where the device supports useful crop | Product goal: flattering for people. 35mm is the people-friendly compromise. | D-006-focal; build plan §1 |

## Product-goal justification (roadmap §2)

"It must work out of the box. A first-time user ... must get a good photograph of a person with zero configuration. Correct exposure on faces, pleasing skin tones, natural color, and a flattering focal length are the default state." → `.auto` flash, 35mm, and Natural preset tuned for skin.

"It is primarily a people camera." → Skin-tone accuracy, face exposure, flattering focal length (35mm, not 24mm wide). When choosing between a setting that flatters a landscape and one that flatters a person, choose the person.

## Lapse behaviors we keep exactly

- Centered continuous AF/AE defaults → allows the amateur to point and shoot
- Low-light boost + smooth AF → safer out-of-the-box for amateurs
- Subject-area monitoring off by default → no surprise focus jumps
- Quality prioritization logic → balances speed above EV 6.0, quality below → natural
- HEVC preference → smaller share files
- Red-eye reduction when not in speed mode → good for people, no visible cost

## Not overridden from Lapse

- Session preset: `.inputPriority` is correct for RAW-capable
- Frame rate request: 30 fps is fine; it's a request, not a guarantee
- Zoom clamp (max 20.0): reasonable; we'll provide discrete prime choices
- Dimension selection (last 4:3 pair): fine
- Orientation/mirroring: no reason to change

## Halide behaviors we adopt

- Process Zero as the film base (Halide default Look for prime camera `H§8`)
- Pure-RAW options (disable sharpening/noise-reduction-sharpness/contrast `H§1`)
- Focus peaking pipeline (`H§4`)
- Focus loupe transform (`H§4`)
- Volume-shutter plumbing (we adapt the concept, not the undocumented callback)

## No Fusion behaviors we adopt

- Manual ISO mapping (`N§6`: cubic, tiered quantization)
- Exposure bias clamp to device range (`N§6`)
- Separate AF/AE lock state (`N§7`)
- LUT sRGB working space (`N§3` explicit declaration)
- Preset strength scalar semantics (`N§3`: one control scales all)

## Result

`CameraDefaultConfig` is:
- Lapse session/focus/exposure/format/quality stack
- Auto flash (ours)
- 35mm default prime (ours, from product goal)
- RAW sharpening disabled (Halide pure-RAW)
- HEVC still + retained RAW source (Lapse + ours)

Every override justified by product goal or pipeline necessity. No silent expansion; no averaging.
