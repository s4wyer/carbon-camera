# Question CARBON-U09-q1: Volume shutter events

**Ticket:** U09

**Source:** Halide §7

**Status:** Answered for Carbon by principal-approved product decision

**Status reviewed:** 2026-11-03

## Question

How should Carbon map physical button events and avoid duplicate captures?

## Approved answer and explanation

Either volume button takes one photo per completed native ended event through one capture coordinator. Ignore cancellations; no arbitrary cooldown or hold-to-burst. Safety capture requests a three-frame group only when enabled. Validate readiness, cancellation, rapid input, and one active event path.

Authority: [D-025](../decisions/D-025-amateur-camera-defaults.md#u09-volume-shutter), approved by the principal to serve a novice photographing people with zero setup.

This answers Carbon's product behavior without establishing unknown reference-app behavior. It does not mark the feature implemented or device-verified. See D-025 for the rationale and remaining validation.

