# D-025: Approved defaults for an amateur people camera

**Decision ID:** D-025

**Date:** 2026-11-03

**Authority:** Principal approval of the proposed question answers, with the explicit correction that safety capture is a setting and does not perform automatic frame selection.

**Status:** Approved product behavior; implementation and device verification pending.

Carbon opens ready to photograph people with automatic settings and a restrained
Natural preset. Advanced controls and creative capture are optional. These
answers govern Carbon's behavior; they do not recover unknown reference-app
behavior. They supersede conflicting earlier product proposals, including
Natural's added-grain default and automatic safety-frame ranking.

The numeric exposure range, zoom duration, and encoder quality below are approved
starting values for validation, not measured results. Changes after testing must
be documented. SET11's measured primary/fallback pipeline comparison is still
required. This decision does not mark any feature implemented or verified.

## U07: Composition guides

Off by default. Offer a rule-of-thirds grid at one-third and two-thirds of the
actual photo crop, using thin translucent white lines. Guides follow the photo
geometry; UI safe areas must not shift them away from the exported composition.
Keep golden-ratio and rabatment guides in advanced options, with their geometry
specified separately before implementation. Unknown Halide geometry is not a
reason to block Carbon's basic grid or to claim reference parity.

## C07: Flash default

Auto, with Auto / On / Off easy to reach, consistent with D-002. Use a tested
capture fallback when the chosen RAW/flash combination is unsupported; preserve
accurate capture provenance. Getting a usable photograph takes priority over
retaining a particular capture format. Halide's own flash default remains unknown.

## R08: Develop exposure

Label the control **Brightness**. Start at zero, offer continuous adjustment from
-2 to +2 exposure stops, a center snap, and one-tap reset. Keep the original for
reversible development. This is the development control; capture-time exposure
bias remains a separate stage and is limited by the active device.

## R07: Film controls

Show one **Strength** control from 0–100%. Zero removes the creative treatment
while retaining basic photo correction; 100 applies the authored preset. Separate
grain, glow, and vignette controls belong in an optional editing panel. Their
maximum values require visual testing rather than assumed reference slider
ranges. Retain neutral values and reset behavior.

## SET12-q1: Per-Look custom values

Preserve known source values. Missing values do not justify undocumented extra
effects. Any authored replacement is a **Carbon adaptation**, with its own
versioned recipe and attribution, rather than a claim of exact source parity.
Natural uses restrained color and no deliberate skin smoothing. Its existing
film strength of 0.85 remains the starting recipe unless validation changes it.

## U09: Volume shutter

Either volume button takes one photo per completed press through native capture
events, using the ended phase. Ignore cancelled events; holding a button does
not start an unexpected burst. Route hardware and on-screen input through a
single capture coordinator with one request per gesture. Prefer one active
event source per gesture over parallel native/legacy observers. Do not add an
arbitrary cooldown that discards intentional rapid presses. Use readiness and
bounded in-flight work. When Safety capture is enabled, a press explicitly
requests one three-frame group under C05.

## R05: Grain order and default

Apply creative grain after color adjustments, before text, borders, and final
encoding. Save its seed and keep apparent size consistent between preview and
export. Natural starts with **grain amount 0.0**, replacing the earlier 0.4
proposal; other film presets may add grain. This defines Carbon's graph, not
No Fusion's unknown per-mode call order.

## SET12-q2: LUT resources

Use recovered original LUTs and their documented serialized layouts. Verify
cube orientation, channel interpretation, and colors before exposing a preset.
Load the selected look first; do not delay opening the camera to load the full
collection. See the dedicated question file for recovered counts and byte layout.

## SET11-q1: Output encoding quality

Use one high-quality HEIF default. Start testing the encoder quality parameter
at **0.95**, then compare skin detail, gradients, file size, and latency. This
parameter is not a percentage of image quality or a recovered No Fusion quality
table. Do not ask beginners to configure compression. Retain captured originals
separately from derived output.

## SET11-q2: Launch preset and format

Launch with **Natural**, automatic exposure and white balance, and ordinary HEIF
output. Retain RAW when supported by the active capture combination; use a
supported processed fallback otherwise and record provenance. Offer JPEG for
compatibility exports. Keep RAW/HEIF+ terminology out of first use. No Fusion's
clean-install defaults do not determine Carbon's defaults.

## C10: Zoom transitions

Framing taps settle quickly and predictably. Start testing a roughly **200 ms**
transition without overshoot. A shutter press must not wait for a decorative
animation; use a consistent preview/capture coordinate contract so the photo
matches the framing visible at capture. Measure actual device ramp behavior.

## SET11-q3: Instants routing

Instants is an optional creative preset with one tested, versioned route. Choose
that route through portrait comparisons. Do not expose an old/new processing
switch. Natural stays the launch default. The route selection remains validation
work; this does not establish Lapse's unrecovered flag value.

## C05: Safety capture setting

**Safety capture** is a user setting, **off by default**, persisted locally.
Suggested explanation: "Take three photos per press so you can choose your favorite."

When enabled, one shutter press requests three nearby frames as quickly as the
active configuration supports. Keep them together as one logical shot, retain
all successfully captured originals, and let the user choose a frame manually.
Use the first successfully captured frame as the initial cover, without a quality
claim. Do not detect open eyes, score faces, rank sharpness/motion, select a
"best" frame automatically, or turn the setting on based on scene analysis.

Measure actual spacing rather than promising a fixed rate or pre-shutter RAW.
If a configuration cannot capture three frames, retain successful frames and
show the actual count; make the limitation clear. Do not block a usable single
photo. C02's paired RAW/processed recovery image is a separate capability and
is not this setting. This feature remains scheduled under C05 in M4.

## C06: Pre-shutter RAW

Treat pre-shutter RAW as an optional measured capability. The camera must work
without it. Use supported responsive capture features after capability checks;
validate RAW, flash, manual exposure, and other combinations separately. Do not
promise universal RAW prebuffer access or zero shutter lag. Advanced stacking
still requires its own measurements and fallbacks.

## U10: Camera Control

A full click takes a photo through the shared shutter handler. Offer supported
framing adjustment without accidentally changing exposure or presets. Extra
gestures are optional and must not be required for a good photo. Respect OS and
device availability, and avoid duplicate capture-event observers.

## Deferred features: Approved product policy

- **Live Photos (M4):** Off initially, enabled through an explicit motion option.
  Preserve the still even if the motion component fails. Assembly internals and
  format compatibility remain implementation/verification work.
- **Depth handoff (M5):** Background blur is optional and reversible. Retain the
  sharp original; omit the effect when edge quality is unreliable. Depth/matte
  handoff and quality criteria remain implementation/verification work.
- **Negative container (M2):** Store the original, versioned recipe, and resource
  manifest together. Recovery and export must work offline. The detailed schema,
  migration rules, and round-trip verification remain implementation work.

## Validation and evidence

Test with first-time users photographing people across skin tones, indoor light,
backlighting, movement, and groups. Validate preview/export parity, reversible
edits, rapid intentional shutter presses, and partial safety-group recovery.
Capture hardware, OS, format, and fallback evidence before claiming support.

Sources used for the approved proposal:

- [Apple: Enhancing your camera experience with capture controls](https://developer.apple.com/videos/play/wwdc2025/253/)
- [Apple: Create a more responsive camera experience](https://developer.apple.com/videos/play/wwdc2023/10105/)
- [Apple: Image destination compression quality](https://developer.apple.com/documentation/imageio/kcgimagedestinationlossycompressionquality)
