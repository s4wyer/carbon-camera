# Question CARBON-U10-q1: Camera Control integration

**Ticket:** U10

**Source:** Halide §7

**Status:** Answered for Carbon by principal-approved product decision

**Status reviewed:** 2026-11-03

## Question

What Camera Control behavior should Carbon provide?

## Approved answer and explanation

A full click takes a photo through the shared shutter handler. Supported framing adjustment is optional; avoid accidental exposure/preset changes and duplicate observers. Extra gestures are not required for a good photo. Validate OS/device availability and behavior.

Authority: [D-025](../decisions/D-025-amateur-camera-defaults.md#u10-camera-control), approved by the principal to serve a novice photographing people with zero setup.

This answers Carbon's product behavior without establishing unknown reference-app behavior. It does not mark the feature implemented or device-verified. See D-025 for the rationale and remaining validation.

