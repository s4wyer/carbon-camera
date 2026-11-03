# D-024: Reference presets menu — cheeky attribution

**Decision ID:** D-024  
**Ticket:** SET13b (new)  
**Concerns:** Transparency + brand voice + user education  
**Date:** 2024-11-03  
**Authority:** Roadmap §2 preset rules + build plan §9 (inspire artists, credit inspiration plainly)

## Feature request (from principal)

Include the presets from the three reference apps (Halide, Lapse, No Fusion) behind a menu, with cheeky names that reference their origins. Do not hide them; surface them transparently with attribution.

## Why this matters

1. **Honesty:** The principal asserts the materials are properly licensed; we should not hide that we're building on top of recovered reference behavior.
2. **User education:** Amateurs can see *exactly* what Halide's Zephyr, Lapse's journal, No Fusion's Nostalgic Negative look like on their photo.
3. **Credibility:** "We learned from the best" builds trust, not suspicion.
4. **Brand voice:** Carbon's tone is "shameless copy" (roadmap build-plan §9, retired-scope register). Playful attribution fits.

## Design (per roadmap §2 preset rules)

### Surfacing

**Main preset list (always visible):**
- Our "Natural" (default, displayOrder 0)
- Our 3–5 other presets (displayOrder 1–5)

**Submenu or badge-marked section:**
- Label: **"Stolen Goods"** or **"The Heist"** (playful, matches brand voice)
- Subtitle: "Recovered from other camera apps — try them out"
- Inside: All representable presets from Halide (7 Looks), Lapse (2–3 factories), No Fusion (20 built-ins), properly grouped and attributed

### Naming (per roadmap §2)

Each reference preset **keeps its original name BUT adds attribution:**

**Halide Looks:**
- "Zephyr (from Halide)" — plain, references source
- "Rembrandt (from Halide)" — same
- Etc. (Process Zero already renamed "Natural" by us; skip it here)

**Lapse factories:**
- "Journal (from Lapse)" — their default CI look
- "Instant Color (from Lapse)" — their instant-tweaks variant
- Etc.

**No Fusion:**
- "Nostalgic Negative / NN (from No Fusion)" — their default
- "Portra 400 (from No Fusion)" — recognizable to photographers
- Etc. (20 total presets, all gettable)

**Why this naming:**
- Original names are recognizable to photographers who know those apps
- Attribution makes origin crystal-clear
- No false claim that we *created* Zephyr; we *represent* it
- No shame in recovering and surfacing them

### User expectation management

When a user taps a "Stolen Goods" preset:

1. **Toast/inline label:** "Recovered from [app name]. Tap to try." (first time only)
2. **In preset detail/info view:** "This preset was extracted from [App Name] v[version] and recreated using Carbon's render engine. Your results may differ slightly due to platform and device differences."
3. **Export metadata:** If the user exports a photo developed with a reference preset, the JSON sidecar includes `"presetSource": "halide-zephyr"` (or equivalent), so if they later share it or open it in another tool, the lineage is clear.

## Implementation (M1b, after SET12 unified preset model exists)

1. Define `PresetGroup` enum: `.ours`, `.stolen` (or .halide, .lapse, .nofusion as nested groups)
2. In `PresetDefinition`, tag each with `source: .halideReference(lookName: "Zephyr", ...)` etc.
3. In the preset browser UI:
   - Filter `.ours` presets into the main list
   - Group `.halide`, `.lapse`, `.nofusion` into a collapsible "Stolen Goods" section
   - Show the app name + version in the preset cell or tap-to-expand detail
4. When rendering with a reference preset, prepend a metadata comment: "Developed with [Preset Name] recovered from [App Name]"

## Rationale (not a silent decision)

- **Transparency:** The roadmap explicitly says "credit inspiration plainly" (build-plan §9). This does that.
- **Not appropriation:** We're not claiming these are ours or hiding their origin. The opposite.
- **User benefit:** Photographers know Halide Zephyr and No Fusion Portra 400 are *good*. They'll be delighted to see them work here.
- **Brand fit:** "Shameless copy" is Carbon's voice; this is shameless and honest.
- **No scope expansion:** This is just surfacing work that's already representable in SET12. SET12 imports all three sources; SET13b just makes them discoverable instead of hidden.

## What stays the same

- Our default set (Natural + 4–6 ours) is still the primary list
- First-time users still land on Natural by default
- The out-of-the-box people-photo test still passes (Natural is good enough)
- All presets are equally tunable (one strength control)

## Not in scope (deferred)

- Modifying the reference presets' parameters (they render as recovered; we tune only our own)
- Claiming we *improved* them (we didn't; we faithfully implemented them)
- Hiding them behind a paywall or requiring attribution opt-in (they're visible, attributed, free)

## Ticket definition (SET13b)

**Type:** B (build-own; no reference document specifies UI surface)  
**Depends on:** SET12 (unified preset model must exist first)  
**Complexity:** Low (just grouping + labeling work that SET12 already does)  
**Acceptance:** 
- Reference presets grouped and labeled in the UI
- Attribution present and clear (no ambiguity about origin)
- Exports include preset source in metadata
- Blind review confirms presets are usable and names are predictable
- **Legibility test passes:** user unfamiliar with the app can read "Zephyr (from Halide)" and understand it's Halide's preset, not Carbon's invention

## Message when shipping

"We learned the hard way from Halide, Lapse, and No Fusion — they set the bar for what a great people camera should do. Carbon recovers their presets exactly and lets you try them side by side with ours. They're in the 'Stolen Goods' menu."
