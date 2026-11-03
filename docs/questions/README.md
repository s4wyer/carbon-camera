# Question escalation: blocked reference behaviors

This directory tracks questions raised where the technical documents did not
fully determine a reference behavior, plus the approved answers for Carbon.
See roadmap §3.

Each file has the ticket ID in its name, numbered q1, q2, etc. for multiple questions per ticket.

**Status reviewed November 3, 2026:** **All 15 tracked questions are answered for Carbon**, by recovered asset evidence or the principal-approved product decisions in [D-025](../decisions/D-025-amateur-camera-defaults.md). Unknown reference behavior remains unknown. An answered question does not mean the associated feature is implemented or device-verified; explicit tuning and implementation work remains below and in D-025.

## Questions filed for M0/M1 work

| File | Ticket | Status | Question / answer |
|---|---|---|---|
| [CARBON-U07-q1.md](CARBON-U07-q1.md) | U07 | Answered (Carbon decision) | Grid off by default; optional thirds lines at 1/3 and 2/3 of the actual photo crop, thin translucent white. Advanced golden/rabatment geometry requires a separate specification. |
| [CARBON-C07-q1.md](CARBON-C07-q1.md) | C07 | Answered (Carbon default) | Carbon defaults to `.auto`, an explicit product override recorded in [D-002](../decisions/D-002-camera-default-config.md), Overrides → Flash, and comparison C11 (D-012). Halide's own default remains unrecovered; it is no longer needed to decide Carbon's default. Device support and fallback behavior still require verification. |
| [CARBON-R08-q1.md](CARBON-R08-q1.md) | R08 | Answered (Carbon decision) | Brightness: -2 to +2 stops as the starting range, continuous, zero center snap, reset, reversible original. |
| [CARBON-R07-q1.md](CARBON-R07-q1.md) | R07 | Answered (Carbon decision) | One Strength control, 0–100%; zero removes creative treatment, 100 applies the authored look. Optional individual effects need visually tested maximums. |
| [CARBON-SET12-q1.md](CARBON-SET12-q1.md) | SET12 | Answered (Carbon decision) | Preserve known values; label authored replacements Carbon adaptations with versioned recipes. No undocumented added effects or deliberate skin smoothing. |
| [CARBON-U09-q1.md](CARBON-U09-q1.md) | U09 | Answered (Carbon decision) | Native completed-press events through one capture coordinator, cancellation handling, no arbitrary cooldown or hold-to-burst. Safety capture explicitly requests a group only when enabled. |
| [CARBON-R05-q1.md](CARBON-R05-q1.md) | R05 | Answered (Carbon decision) | Grain after color, before text/borders and encoding; saved seed, consistent apparent size. Natural's added grain is zero. |
| [CARBON-SET12-q2.md](CARBON-SET12-q2.md) | SET12 | Answered (assets and byte layout) | [Recovered assets](../../nofusion-recovered/README.md) include 20 original `.lutbin` files and 20 presets. Layout: little-endian float32 quadruples, fourth component always 1.0, no header/trailer, length `size^3 * 16` bytes; preset references and dimensions resolve. Axis ordering, executable channel interpretation, and runtime rendering parity remain unverified. |
| [CARBON-SET11-q1.md](CARBON-SET11-q1.md) | SET11 | Answered (Carbon decision) | One high-quality HEIF default; start encoder testing at 0.95 and tune quality, size, and latency. No compression setup for beginners; retain originals separately. |
| [CARBON-SET11-q2.md](CARBON-SET11-q2.md) | SET11 | Answered (Carbon decision) | Natural, auto exposure/WB, ordinary HEIF, RAW retained where supported, recorded processed fallback otherwise; JPEG compatibility export. |
| [CARBON-C10-q1.md](CARBON-C10-q1.md) | C10 | Answered (Carbon decision) | Start testing roughly 200 ms, no overshoot; no decorative shutter delay; preview/capture framing must agree. |
| [CARBON-SET11-q3.md](CARBON-SET11-q3.md) | SET11 | Answered (Carbon decision) | Optional Instants preset with one versioned route chosen by portrait comparison; no old/new toggle. Route validation remains pending. |
| [CARBON-C05-q1.md](CARBON-C05-q1.md) | C05 | Answered (Carbon decision) | Safety capture setting, off by default. When enabled, request three frames where supported, group successful originals, and let the user choose manually. First successful frame is the initial cover; no eye detection or automatic ranking. |
| [CARBON-C06-q1.md](CARBON-C06-q1.md) | C06 | Answered (Carbon decision) | Pre-shutter RAW is optional and measured per configuration. Camera works without it; validate responsive capture, flash, RAW, and manual combinations separately. |
| [CARBON-U10-q1.md](CARBON-U10-q1.md) | U10 | Answered (Carbon decision) | Full click uses the shared shutter handler; supported framing adjustments are optional. Extra gestures are not required; avoid duplicate event observers. |

## Deferred features (approved product policy; implementation remains)

- **Live Photos (M4):** Off initially, explicit motion option, preserve the still if motion fails. Assembly internals and compatibility require implementation/verification.
- **Depth handoff (M5):** Optional reversible blur, retain the sharp original, omit unreliable edges. Detailed handoff and quality criteria require implementation/verification.
- **Negative container (M2):** Original, versioned recipe, and resource manifest stored together; offline recovery/export. Detailed schema and migrations require implementation/verification.

These policies are approved in D-025. Additional validation includes advanced
guide geometry, individual-effect slider limits, Instants route choice, LUT
interpretation, capture combinations, and the SET11 primary/fallback comparison.

## Process (from roadmap §3)

1. Write a precise question to `docs/questions/[TICKET-ID]-q[n].md` naming the document, the section, the screen or mode, the exact behavior needed, why the current document is insufficient, and what you would build if forced to guess (so independent work can continue).
2. Mark that sub-behavior **Blocked (question)** inside the ticket.
3. Complete everything else independent in the ticket and continue.
4. The principal answers; incorporate the answer into the same ticket before marking it Verified.

No guessing. The principal holds the reference material and will extract any behavior you name.
