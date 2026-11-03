# Question CARBON-C05-q1: Safety capture setting

**Ticket:** C05

**Source:** Halide §1; principal correction on 2026-11-03

**Status:** Answered for Carbon by principal-approved product decision

**Status reviewed:** 2026-11-03

## Question

How should Carbon provide safety capture without automatic frame selection?

## Approved answer and explanation

A persisted Safety capture setting, off by default. When enabled, one press requests three nearby frames where supported. Group successful originals as one shot; use the first successful frame as the initial cover and let the user choose manually. No eye detection, face scoring, sharpness/motion ranking, or automatic activation. Measure timing; preserve partial groups and show actual count. C02 paired recovery capture is separate; this feature remains M4.

Authority: [D-025](../decisions/D-025-amateur-camera-defaults.md#c05-safety-capture-setting), approved by the principal to serve a novice photographing people with zero setup.

This answers Carbon's product behavior without establishing unknown reference-app behavior. It does not mark the feature implemented or device-verified. See D-025 for the rationale and remaining validation.

