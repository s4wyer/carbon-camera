# Question CARBON-SET11-q1: HEIF encoder quality

**Ticket:** SET11

**Source:** No Fusion §1

**Status:** Answered for Carbon by principal-approved product decision

**Status reviewed:** 2026-11-03

## Question

What compression policy should Carbon use without the reference quality table?

## Approved answer and explanation

One high-quality HEIF default. Start encoder testing at 0.95, then compare skin detail, gradients, file size, and latency. Retain captured originals separately. This is a tuning starting point, not a percentage of image quality.

Authority: [D-025](../decisions/D-025-amateur-camera-defaults.md#set11-q1-output-encoding-quality), approved by the principal to serve a novice photographing people with zero setup.

This answers Carbon's product behavior without establishing unknown reference-app behavior. It does not mark the feature implemented or device-verified. See D-025 for the rationale and remaining validation.

