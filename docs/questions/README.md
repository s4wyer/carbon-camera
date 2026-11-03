# Question escalation: blocked reference behaviors

This directory holds escalated questions where a ticket depends on a reference behavior the
technical documents do not fully determine. See roadmap §3.

Each file has the ticket ID in its name, numbered q1, q2, etc. for multiple questions per ticket.

## Questions filed for M0/M1 work

| File | Ticket | Status | What we need |
|---|---|---|---|
| `CARBON-U07-q1.md` | U07 | Open | Composition guide geometry: thirds/golden/rabatment coordinates, line widths, safe-area handling. Halide §6 has types but no drawing bodies. |
| `CARBON-C07-q1.md` | C07 | Open | Flash default. Halide §8 "state not recovered"; Lapse §1 has request mapping but no default state. |
| `CARBON-R08-q1.md` | R08 | Open | Image Lab exposure slider range/mapping. Halide §1 has `CIRAWFilter` exposure fields; slider UI mapping not recovered. |
| `CARBON-R07-q1.md` | R07 | Open | Film tab slider bounds. Halide §3 has filter defaults; user-facing min/max/step not recovered. |
| `CARBON-SET12-q1.md` | SET12 | Open | Per-Look persisted custom effect values. Halide §2/§3 has LUT payloads; Look-specific custom overrides not recovered. |
| `CARBON-U09-q1.md` | U09 | Open | Volume-shutter dedup window/event mapping. Halide §7 has callback plumbing; callback body/dedup logic not recovered. |
| `CARBON-R05-q1.md` | R05 | Open | NF render order for grain relative to `StyleFilter` in every mode. NF §3 shows `StyleFilter` chain; grain may be separate, not yet resolved. |
| `CARBON-SET12-q2.md` | SET12 | Open | NF preset LUT binaries + `.lutbin` layout. NF §4 has hash references and dimension declarations; byte format not recovered. |
| `CARBON-SET11-q1.md` | SET11 | Open | NF HEIF+ encoder quality table. NF §1 has quality-indexed Double; table values not recovered. |
| `CARBON-SET11-q2.md` | SET11 | Open | NF selected default preset/format (clean install). NF §9 "most defaults unresolved." |
| `CARBON-C10-q1.md` | C10 | Open | Lapse zoom ramp-rate policy. Lapse §1 "ramp-rate policy was not recovered." |
| `CARBON-SET11-q3.md` | SET11 | Open | Lapse "new instants" flag default. Lapse §3 has two CI Instants branches; flag default unrecovered. |
| `CARBON-C05-q1.md` | C05 | Open | Burst specifics (count, spacing, selection criteria). Halide §1 "not recovered." |
| `CARBON-C06-q1.md` | C06 | Open | Pre-shutter RAW frame availability. Halide §1; roadmap C04 notes exclusions. |
| `CARBON-U10-q1.md` | U10 | Open | Camera Control integration detail. Halide §7 "marked not recovered." |

## Questions deferred (not blocking Part 1)

- Live Photo assembly internals (M4)
- Depth model handoff (M5)
- Private negative container schema (M2, but not blocking single-user alpha)

## Process (from roadmap §3)

1. Write a precise question to `docs/questions/[TICKET-ID]-q[n].md` naming the document, the section, the screen or mode, the exact behavior needed, why the current document is insufficient, and what you would build if forced to guess (so independent work can continue).
2. Mark that sub-behavior **Blocked (question)** inside the ticket.
3. Complete everything else independent in the ticket and continue.
4. The principal answers; incorporate the answer into the same ticket before marking it Verified.

No guessing. The principal holds the reference material and will extract any behavior you name.
