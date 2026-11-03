# Question CARBON-C06-q1: Pre-shutter RAW availability

**Ticket:** C06

**Source:** Halide §1; roadmap C04/C06

**Status:** Answered for Carbon by principal-approved product decision

**Status reviewed:** 2026-11-03

## Question

Should Carbon depend on pre-shutter RAW frames?

## Approved answer and explanation

No. Treat them as an optional measured capability. Use supported responsive capture after capability checks and validate RAW, flash, manual, and other combinations separately. Camera operation and advanced stacking must have supported fallbacks; no universal zero-lag promise.

Authority: [D-025](../decisions/D-025-amateur-camera-defaults.md#c06-pre-shutter-raw), approved by the principal to serve a novice photographing people with zero setup.

This answers Carbon's product behavior without establishing unknown reference-app behavior. It does not mark the feature implemented or device-verified. See D-025 for the rationale and remaining validation.

