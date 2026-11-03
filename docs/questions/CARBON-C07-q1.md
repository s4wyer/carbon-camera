# Question CARBON-C07-q1: Flash default

**Ticket:** C07  
**Sources:** Halide §8; Lapse §1; D-002 Overrides → Flash; comparison C11 (D-012)  
**Status:** Answered for Carbon's shipped default  
**Status reviewed:** 2026-11-03

## Question

What flash state should Carbon select by default when Halide's default is not
recovered and Lapse provides request mapping without a launch default?

## Answer and explanation

Carbon defaults to **`.auto`**. This is already an explicit product decision in
[D-002](../decisions/D-002-camera-default-config.md), reiterated in
[comparison C11](../reference/comparison.md) under D-012. The recorded rationale
is Carbon's goal of producing a good people photo on the first tap with zero
configuration.

The principal reaffirmed this in [D-025](../decisions/D-025-amateur-camera-defaults.md#c07-flash-default): keep Auto / On / Off accessible and use a tested capture fallback when RAW/flash cannot work together, with accurate provenance and a usable photograph taking priority.

This answers Carbon's configuration question through a documented override.
It does not establish Halide's default, which remains unrecovered. Lapse's
request-byte mapping (1/2 → on, 0/3 → off) does not establish an Auto default.

## Remaining verification

Confirm supported flash modes and define/test the fallback for each device and
capture combination. This answer does not mark C07 implemented or verified.
