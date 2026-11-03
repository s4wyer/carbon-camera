# Carbon camera app build plan

November 2 2026

Build Carbon as an iPhone camera for amateurs who want memorable photographs without learning camera jargon. The product combines a restrained RAW engine, reversible film rendering, tactile camera controls, and physical-feeling keepsakes. The camera should be ready quickly; personality belongs in loading, developing, and revisiting a roll.

The full program includes every Carbon feature proposed in the conversation. Delivery phases sequence the work rather than remove features. Device-dependent concepts receive a validation task, a supported implementation, and a visible fallback. Carbon is the chosen name. The final design discussion supplies the visual direction.

Carbon is an amateur-first iPhone camera for photographing people. It must produce a good photograph of a person on the first shutter tap, with zero configuration, by a user who has never seen the app. Advanced controls exist for the curious; they are never required for a good result. Skin-tone accuracy across the full range is a first-class quality bar, not a polish item. When choosing between a setting that flatters a landscape and one that flatters a person, choose the person.


Start as a guest, offline. Ask for camera access when entering capture, then introduce other permissions only with the feature that needs them. Show each photo's usable preview promptly and improve it with background rendering. Retained originals and reversible edits protect important memories. Export remains a deliberate choice or an explicit automatic-export preference.


## 1 Product decisions

The default experience is Natural Lens, an open-ended roll, 35mm-equivalent framing where the device supports a useful crop, automatic exposure, and a restrained Carbon stock. Flash remains easy to reach. Users can shoot as a guest, offline, before creating an account or granting access to their library, microphone, contacts, notifications, or local network.

Approved November 3, 2026: [D-025](docs/decisions/D-025-amateur-camera-defaults.md) records the defaults for guides, editing, capture events, rendering, format, and advanced features. **Safety capture is an opt-in setting, off by default:** request three nearby frames where supported, keep one logical shot, and let the user choose manually. No eye detection or automatic frame ranking is required. This is separate from C02's paired RAW/processed recovery image.

Use three destinations: Camera, Rolls, and Lab. Camera is the launch destination after onboarding. Rolls holds personal envelopes. Lab holds saved Carbon Copies and learning prompts. Settings is available from the film flap and Rolls.

The complete scope is delivered in six phases. P0 validates the difficult capture combinations. P1 supplies an attractive and dependable camera. P2 completes the personal darkroom and curation. P3 adds system entry and cloud destinations. P4 adds creative capture, motion, and voice backings. P5 completes the advanced imaging program. A P3 launch is a release checkpoint; P4 and P5 remain committed scope for the full product.

Success means a novice can open Carbon, choose framing by feel, make a good picture, recover a poor exposure, and find or share the result later. The no-retakes mood is a shooting ritual; retained originals and reversible edits protect important memories.

## 2 App design language

Use an editorial darkroom direction. Photography carries the visual identity. Warm paper, carbon blue, fine technical type, and a few convincing physical objects give the interface character. Pool informs immediate usefulness, generous spacing, and one playful interaction. Carbon's canister, transfer paper, receipts, and envelopes should feel observed and touchable, with careful proportions and restrained texture.

| Token | Value | Application |
| --- | --- | --- |
| Remjet | #0E0E10 | Camera body and darkroom canvas |
| Receipt | #F6F3EC | Welcome, roll collection, print backs |
| Carbon ink | #2B4593 | Primary paper actions, routing stamps, selected recipes |
| Safelight | #FF3B1D | Flash charge, development accents, intentional light leaks |
| Brass | #B79B62 | Winder and canister material, decorative rather than small text |
| Secondary ink | #615F5A | Supporting text on paper, subject to contrast checks |

The later palette supersedes the earlier #2B4C7E blue and #FF4500 orange exploration. Keep backgrounds nearly plain. Concentrate paper fibers, wear, and shadow on the physical artifact itself. The welcome composition uses directional daylight, blue transfer paper, and one small film canister. In Rolls, photography and contact sheets set the rhythm; envelope edges and ink stamps provide occasional material cues. Offer a low-light gallery surface through semantic tokens.

Use Instrument Serif or a licensed Garamond-style face for the lowercase wordmark and selected screen titles, SF Pro for body text and actions, and JetBrains Mono for counters, receipts, dates, and technical details. Reserve large type for one focal label per screen. Starting iPhone sizes are 36-44pt for the wordmark or screen title, 17pt body and actions, 14pt mono counters, and 12-13pt supplementary labels. Keep promotional copy short and quiet. Support Dynamic Type rather than freezing these sizes.

Use an 8pt spacing rhythm, 20-24pt outer gutters, 12-16pt grouped gaps, 44pt minimum interactive targets, and 48-56pt primary buttons. A 72pt shutter should dominate the deck. Keep preview corner radii subtle at 8-12pt and paper edges nearly square. Use a compact blue pill for Open camera, fine brightline marks, and an understated indexed prime selector. The custom app icon should explore an offset carbon-copy C or two offset print sheets with one warm exposure mark.

Motion should explain a physical action. Taps settle in roughly 120-180ms, paper and camera transitions in 250-400ms, and optional envelope reveals in 500-800ms. These are design targets to tune on device. Keep the live preview responsive throughout. Disable gravity, parallax, tearing, and extra gate weave under Reduce Motion; respect silent mode and allow haptics to be disabled separately.

## 3 Screen design specification

### Welcome

Use a cream canvas, a lowercase serif carbon wordmark, and one short supporting line. The middle of the screen contains a carefully lit film canister, curling blue transfer paper, and a narrow negative strip. Use convincing materials and generous empty space around the composition. The canister is the only physics toy. Place a compact Open camera action near the bottom and keep the copying joke in the itemized receipt. The welcome line can fade in briefly; it must never delay the action. Dragging the paper reveals the same destination. The receipt invokes the native permission dialog, and the live image appears after access succeeds. Keep visible loading and denied-permission states. A successful load ends at 01 / 24; returning users enter the camera directly.

### Camera

Use a 390 by 844pt reference canvas and adapt to safe areas. Make the photograph dominant, with minimal black chrome and subtle preview corners. Reserve approximately the lower fifth for the thumb deck. Center the shutter, place a precise 24 / 35 / 50 control directly above it, and place the machined winder at the trailing edge. Use a small real roll thumbnail as the leading Rolls entry. Put the frame count at the upper left and a small film flap at the upper right. Fine capture brightlines and the optional outside margin establish framing. Expose flash through a compact charge lamp that also opens its control. Label its state for assistive technology.

Vertical preview motion changes Mood. The warmth wheel is revealed from the film flap or a labeled warmth control so it cannot conflict with exposure. Touch-and-hold activates the focus patch; release locks focus. Tap unlocks. Horizontal motions on a photo belong to print flipping, not camera settings. Winding requires deliberate movement outside the preview. The film flap lists Stock, Lab Options, Flash, Creative Mode, Lessons, and Advanced capture details using plain labels with the brand joke as a subtitle.

### Rolls and darkroom

Use a quiet cream canvas, a compact Carbon wordmark, a modest Rolls title, and a clear New roll action. Give the latest ready roll one tactile envelope with a real photograph peeking out. Show older rolls as photographic contact sheets with titles and frame counts. Keep names typeset and routing stamps small. A thin processing strip gives development status without dominating the collection. Opening that strip reveals the safelight glass, inverted thumbnails, and stage-linked contrast animation. Do not show a false percentage when the remaining work is unknown. Ready rolls offer Tear open and a conventional Open roll action. The restrained Camera, Rolls, and Lab navigation keeps Camera one tap away. Empty and failed states provide First roll and Resume developing actions.

### Light Table and print detail

Opening a finished envelope offers the contact sheet and an optional quick review. Near duplicates form a stack with manual cover selection; safety-capture groups initially show the first successful frame and let the user choose another. Manual stars remain authoritative. Flicking rejects moves them to a recoverable bin. Export selected shots only after review unless automatic export was explicitly enabled. The front of a print prioritizes the image. The back holds date, lens, recipe QR, Credits, and an audio play button when a backing exists. Use separate Flip and Play controls because horizontal swipes, pinch zoom, and holds are not universally discoverable.

### Lab and CC flows

Lab presents visual recipe cards, reversible controls, and the optional ten-day lesson track. Widget previews ask which rolls may appear on the Home Screen before enabling delivery.

## 4 Capture policy and film engine

Define the supported mode combinations before UI implementation. The modes below are product intentions; P0 must measure the actual format and device matrix.

| Mode | Intended capture | Important constraint | Fallback |
| --- | --- | --- | --- |
| Natural | Single Bayer RAW plus optional safety image | Available formats vary by camera and configuration | Supported processed capture with visible provenance |
| Night | Supported ProRAW or processed frame; later custom burst | ProRAW includes computational processing | Good single supported frame; no zero-noise promise |
| Party Drag | Slower exposure with flash aesthetic | Flash and manual shutter combinations require physical testing | Supported flash capture or explicit continuous-light effect |
| Moving Print | Still plus 1.5s companion, 18fps look | RAW, Live Photo, video, depth, and flash combinations vary | Companion video or still-only result with a clear mode choice |
| Vintage Glass | Still plus depth or matte | Depth availability and edge quality vary | Standard film rendering without synthetic bokeh |
| Street | High-contrast black and white, near-2m snap focus | Lens position is not a universal metric-distance scale | Device-calibrated preset or autofocus lock |

Keep camera capture separate from development. Input events submit camera work immediately. Once the photo callback returns, persist the original and capture manifest atomically, then schedule rendering. Use bounded in-flight work, thermal and memory limits, and camera readiness rather than an unbounded RAW buffer. Do not perform LUT work or animation preparation before submitting the capture request.

The development graph is RAW decode and linearization, demosaic or validated multi-pass development, optional alignment and merge, lens calibration, white balance and exposure, skin mask preparation, highlight shoulder, subtractive matrix and scene-referred film transform, halation and bloom, creative optics, grain, and optional stamps or borders. The imaging engineer must validate exact ordering, working color space, LUT input domains, and highlight behavior. Preserve a high-precision scene working buffer until output conversion. Burst merging may use a different early graph; it must never merge independently graded display images.

Build low-resolution previews and full-quality output from the same recipe graph. Store an immutable recipe version, calibrated stock identifier, random grain seed, source hash, crop, and engine version. Halation, grain, color, and overlays must render deterministically. Changing a recipe creates a new revision; it does not re-grade a previous JPEG. Multiple frames, RAW, motion, and voice companions remain one logical asset in Carbon.

The stock library ships a small set of presets (4–6), each sourced from the recovered parameters in the three technical reference documents (Halide LUT-driven Looks, Lapse Metal and Core Image pipelines, No Fusion `.preset` records) or authored as an original. Each preset is named per the roadmap §2 rules. The portrait/skin preset is first and default. Each preset needs daylight, tungsten, mixed-light, dark-skin, pale-skin, highlight, and deep-shadow reference images. Pair skin-protected grading with user control rather than beauty retouching.

## 5 Architecture and durable data

Build native iOS first, with an iOS 18 or later baseline as a planning assumption to validate in P0. Use Swift and SwiftUI for application structure, UIKit and AVFoundation for the camera surface and hardware interactions, Core Image and Metal for rendering, and PhotoKit for deliberate export. Use a local database such as SQLite for manifests and state, and a file store for large media. Keep the capture core reusable by the app and the locked-camera extension. Supporting adapters use Core Haptics, Core Motion, Vision segmentation, AVAudioSession, WidgetKit, App Intents, and WatchConnectivity, subject to each feature's capability checks.

| Module | Responsibility | Durable boundary |
| --- | --- | --- |
| CameraCore | Session, capabilities, hardware events, exposure and focus | Capture request and result manifest |
| FilmEngine | Versioned render graph and previews; preset definitions sourced from the three reference documents | Source hash, preset ID and version, recipe and engine revision |
| RollStore | Frames, reveal state, ratings, edit history | Transactional local database |
| MediaStore | DNG, HEIF, thumbnails, clips, ambient audio | Atomic files with checksums |
| DevelopQueue | Jobs, backpressure, checkpoints, retries | Idempotent job records |
| SyncService | Optional iCloud and Google backup, conflict resolution | Outbox, acknowledgments |
| ArtifactComposer | Contact sheets, print detail | Export manifest and source revisions |
| SystemExtensions | Lock Screen, widgets, Camera Control, Watch | Minimal permitted context and capture handoff |

Core entities are Roll, Shot, SourceResource, RecipeVersion, RenderRevision, DevelopmentJob, Favorite, AudioBacking, and ExportArtifact. A Shot owns source-resource references rather than one assumed file. Recipes are immutable and reusable; edits point to a recipe revision. Attach audio, motion, depth, and alternate frames to the same Shot.

The local roll state machine is shooting, developing, ready, and archived. A roll moves to developing when the user manually closes it or starts a new one. A failed or paused job preserves its last safe stage and original. Export status is separate from render status. The same shot can be developed and still awaiting Photos permission.

Retain originals by default with a clear storage budget. Provide a user-controlled rendered-only archive option after warning that RAW recovery will be lost. Never silently remove originals to satisfy a small-file claim. A full-resolution RAW source remains materially larger than a rendered HEIF. Export HEIF or JPEG for ordinary sharing, DNG plus JSON sidecar for archival recovery, and an optional complete roll archive. Prototype an embedded HEIF and RAW container, but verify round trips through Photos, Files, AirDrop, messaging, and cloud services before making that the sole archive format.

## 6 Privacy and system behavior

Personal shooting does not need a Carbon account. Introduce optional identity only when a user enables durable cross-device iCloud sync or cloud export. Joining widgets and ambient audio recording are separate, explicit choices.

The locked-camera extension must use its sanctioned capture handoff and expose only the capture experience. Apple documents shared-container restrictions for a locked session; old photos and editing open in the authenticated app. Widget refresh is scheduled by the system; promise eventual eligible updates, not immediate delivery to every Home Screen.

Ask for camera access on first capture entry, Photos add access on export, microphone access when Voice Backings are enabled, and notifications when a user requests ready-roll alerts. Contacts and local network access are unnecessary. Add an audio-recording indicator and per-shot removal.

## 7 Build sequence and work packages

The estimate below assumes two iOS engineers, one imaging engineer, one backend engineer, one product designer, and QA support, with part-time product ownership. It is a planning range, not a delivery commitment. Allow roughly 9-12 months for the complete scope, including advanced features. P0 measurements may change sequencing or require an imaging or video specialist.

| Phase | Planning window | Work package | Exit evidence |
| --- | --- | --- | --- |
| P0 | Weeks 1-3 | Device capability matrix, capture harness, color test set, RAW packaging, flash timing experiments, design states | Measured feasible combinations; fallback contract; approved static screen system |
| P1 | Weeks 4-10 | Guest onboarding, responsive camera, Natural engine, tactile controls, local roll store, recoverable queue | Attractive private alpha that captures and recovers a full roll offline |
| P2 | Weeks 11-16 | Reversible Lab, skin color, darkroom, envelopes, Light Table, contact sheets, print detail, lessons | Complete single-user beta with verified archive and export round trips |
| P3 | Weeks 17-23 | iCloud and Google export, recipe scan, locked entry and Camera Control | System integration with tested round trips and private access |
| P4 | Weeks 24-31 | Double exposure, accidents, moving prints, voice backings | Creative release with coherent mode choices and exportable results |
| P5 | Weeks 32-44 | 16-32-frame research, advanced bokeh, face geometry | Full-scope release with measured image improvements and documented fallbacks |

Sequence dependencies deliberately. P2 requires P1's immutable originals and recipe model. Motion capture must exist before moving print playback. Favorites and contact-sheet selection must exist before print detail. The depth pipeline precedes Vintage Glass. Prototype the P5 algorithms during P0 without blocking P1 camera delivery.

For each feature, implementation tickets should include the ledger ID, screen states, API capability check, persistence change, accessibility equivalent, failure behavior, and the completion rule. Backend work and local UI work can proceed in parallel once the local archive contract is stable. Keep a sample roll fixture containing RAW, fallback HEIF, depth, audio, motion, a rejected frame, and an interrupted job so every team member tests the same lifecycle.

## 8 Validation and release criteria

Treat the figures below as proposed engineering targets to establish and revise after the P0 baseline. They are not measured results.

| Area | Proposed release criterion |
| --- | --- |
| Launch | Warm camera preview p95 below 1s on the primary supported test device; report cold launch separately |
| Shutter | Input acknowledgment within 50ms; measure request, exposure, callback, and shot-to-shot timings separately |
| Preview | Stable 30fps or better for the default camera, with no sustained UI stalls from development |
| Durability | Zero lost acknowledged captures in kill, interruption, disk-full, thermal, and retry scenarios |
| Background | Every interrupted render resumes or restarts safely; no false ready state |
| Image quality | Blind comparisons against neutral capture and the previous engine across representative people and lighting |
| Skin and geometry | Review the full Monk range and edge-position group portraits; reject hue or identity distortion regressions |
| Export | HEIF, JPEG, DNG plus recipe, motion, and print outputs round-trip as specified; metadata stripping has a useful fallback |
| Accessibility | Complete first shot, winding, reveal, focus, flip, play, and cull with VoiceOver and reduced motion |
| Presets | Legibility test: a user unfamiliar with the app can predict what each preset does from its name; portrait/skin preset is first and default |
| Out-of-the-box | First-time user, no instruction, photographs a person: result must be good with defaults untouched |

Build a physical device matrix spanning the oldest supported OS and device, a recent base model, a recent Pro model, Camera Control hardware, and cameras lacking RAW or depth. Record actual capabilities per active camera and mode. Test low storage, camera interruptions, denied permissions, locked capture handoff, offline use, and thermal pressure across a full roll. Include fast-moving people, neon, daylight, tungsten, mixed light, low light, glasses, hair, and group faces at frame edges in image review.

Run formative design sessions with amateur photographers before finishing P1 and P2. Ask participants to take a first shot, change Mood, switch primes, find flash, load or wind a roll, recover a frame, reveal an envelope, and locate a favorite. Track task completion and mistaken gestures. Keep artistic judgment and technical sharpness as separate ratings so a clinical image does not automatically win.

P5 features graduate from experiments only when they improve the intended situation on the tested hardware. Stacking must quantify noise reduction, detail, ghosting, latency, memory, and battery. Bokeh must pass depth-edge review. If an advanced method fails, release its documented fallback and retain the unmet target in the roadmap with evidence rather than claiming it is complete.

## 9 Decisions that reconcile the transcript

| Transcript tension | Build decision |
| --- | --- |
| No artificial wait versus a 24-Hr receipt item | Real development is the default; a separate optional 24-hour reveal ritual preserves the later idea |
| Mandatory winding versus instant candid shooting | Analog mode requires a wind; auto-wind and tap alternatives preserve rapid and accessible capture |
| One small HEIF versus retained RAW headroom | One logical asset in Carbon; compact share file plus larger original and a tested archival bundle |
| Natural single RAW versus computational safety and stacking | Record distinct capture provenance; use mode and capability policy rather than claiming all shots are untouched RAW |
| Every shot has motion versus incompatible capture formats | Default motion only where supported; explain the still-only choice for incompatible high-quality modes |
| Simultaneous group unlock versus disconnected devices | One authoritative reveal event; offline devices reveal after sync |
| Xenon-style flash and synchronized phone strobe | Reproduce a visual intent using supported LED or screen light; require on-device timing validation for true pulse capture |
| Scan any photo for an exact recipe | Exact recovery needs preserved metadata or a QR; stripped screenshots can only yield a labeled approximation |
| Beautiful physics versus first-shot speed | The welcome and reveal ceremonies are optional; ordinary camera launch stays direct |
| Growing feature list versus a simple camera | Three primary deck controls, progressive film-flap disclosure, coherent creative modes, and a separate Lab |

Naming alternatives discussed before Carbon was chosen are Kitbash, Dupe, FrankenCam or Frankie, Trace, Bootleg, Splice, Knockoff, B-Roll, Ctrl+C, and Pirate ISO. Retain them in the decision record; they do not create extra app modes. The brass canister is the primary toy, with the flash cube retained as an alternate design. Pool's duck, water covers, cookbook, music player, and screenshot features are reference examples rather than new Carbon product modules. Pro waveform and Kelvin-menu examples explain what the amateur UI should translate; they do not require a separate waveform screen.

The proposed tagline, copying jokes, inspiration percentages, and contraband names are creative copy rather than a statement of affiliation or a claim that proprietary software is embedded. Preserve the playful voice in small moments and credit inspiration plainly. Use original implementation, assets, stocks, and code.

## 10 Technical references

The implementation should check these primary references again when development starts. The source transcript is the feature authority; vendor documentation defines supported platform behavior. Reference notes below describe only the constraints needed for the plan.

1. Apple AVCapturePhotoOutput documentation covers capability queries for RAW formats, ProRAW, supported codecs, and capture behavior. https://developer.apple.com/documentation/avfoundation/avcapturephotooutput
2. Apple isAppleProRAWEnabled explains that ProRAW is demosaiced and partly processed, with availability queried at runtime. https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/isappleprorawenabled
3. Apple WWDC23 Create a more responsive camera experience explains zero-shutter-lag exclusions for flash, manual exposure, and bracketed captures. https://developer.apple.com/videos/play/wwdc2023/10105/
4. Apple Creating a camera experience for the Lock Screen documents locked capture, restricted networking and shared storage, and handoff. https://developer.apple.com/documentation/lockedcameracapture/creating-a-camera-experience-for-the-lock-screen
5. Apple Enhancing your app experience with the Camera Control covers capture events and custom indexed controls. https://developer.apple.com/documentation/avfoundation/enhancing-your-app-experience-with-the-camera-control
6. Apple BGProcessingTask documents interruptible background processing. https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask
7. Apple About Apple ProRAW documents its computational basis and incompatibility with Live Photos in the described workflow. https://support.apple.com/en-us/119916
8. Apple Capturing still and Live Photos describes configuration-dependent capture options. https://developer.apple.com/documentation/avfoundation/capturing-still-and-live-photos
9. Google Photos API updates restrict general library access and sharing APIs, while preserving permitted app-created-content workflows. https://developers.google.com/photos/support/updates
10. Apple Multipeer Connectivity documentation was previously cited for nearby transport; Carbon no longer includes multi-device features, so this reference is retained only as historical context.
11. Pool's official App Store listing confirms immediate guest use and its physical artifact references. The Carbon screen system is an original interpretation of the requested inspiration. https://apps.apple.com/us/app/pool-the-screenshot-app/id6752956163

## 11 Complete feature ledger

Each record below is a build requirement. P1 through P5 locate its intended delivery; all have P0 capability or design validation as needed. Source locations refer to line numbers in carbon-full-gemini-conversation(1).md. A record can contain closely related subfeatures, all of which must satisfy its completion rule. Added engineering requirements in the main plan support delivery and do not replace any transcript feature.

### Brand and physical design

| ID | Feature | Phase | Source lines | Build and completion rule |
| --- | --- | --- | --- | --- |
| B01 | Carbon identity | P1 | 141-153 | Use Carbon as the product name; connect carbon copying, remjet halation, and archival material in the brand story and icon exploration. |
| B02 | Carbon vocabulary | P1 | 149-153 | Use Carbon Copies for saved recipes and Carbon Credits for provenance; retain the proposed shameless-copy tagline as optional brand copy. |
| B03 | The Heist and inspiration credits | P1 | 131-133, 274 | Include Stolen Goods or The Heist as a playful settings subtitle and an itemized inspiration receipt. Keep plain Settings and permission labels discoverable. |
| B04 | Preset naming | P2 | 132 | Retain the recovered preset parameter sets from the three reference documents. Name and surface them per roadmap §2: plain description, one obvious promise, ordered by usefulness to a beginner, portrait/skin first and default. Playful naming may appear as a subtitle or in metadata, never as the primary label. |
**Note on B04 and all preset tickets.** The recovered preset parameter sets (Halide LUT payloads and `LookCustomization` fields; Lapse Metal and Core Image pipeline recipes; No Fusion `.preset` binary plist fields and LUT references) are the source material. Our shipped presets derive from them, may rename and regroup them, and may modify them for the amateur/people goal with documented deltas. We should avoid this unless we have good reason though. 
| B05 | Tape and ransom lettering | P2 | 133 | Use a restrained spliced-tape or ransom-label treatment on the roll counter and Developing sticker; never compromise the legibility of frame numbers. |
| B06 | Material and color system | P1 | 153, 262 | Implement matte black, receipt cream, carbon indigo, and safelight red tokens. Preserve the earlier blue and orange values as explored alternatives; use the later palette consistently. |
| B07 | Editorial and technical type | P1 | 263 | Pair a high-contrast serif such as Instrument Serif or Garamond with stamped monospace such as JetBrains Mono; use readable system text for instructions and controls. |
| B08 | Flickable film toy | P1 | 264, 275 | Build a brass 35mm canister with drag, flick, collision, and tilt gravity. Retain the disposable flash cube as an optional alternate toy, with a static reduced-motion form. |
| B09 | Surface effects | P2 | 265, 281-283 | Create silver-halide negative sheen, indigo transfer smudges, worn yellow envelopes, grease-pencil marks, and routing stamps as subtle materials with flat accessible variants. |
| B10 | Mechanical animation and sound | P1 | 266, 275, 291 | Implement spring motion, snapping viewfinder blades, winding gear ticks, loading clunk, and flash-charge whine; respect sound, haptic, and motion preferences independently. |

### Welcome and permissions

| ID | Feature | Phase | Source lines | Build and completion rule |
| --- | --- | --- | --- | --- |
| O01 | Immediate guest camera | P1 | 48, 270, 274 | Start without login, phone number, contact upload, or mandatory invitations. A user who grants camera access can take and retain a first shot offline. |
| O02 | Carbon transfer welcome | P1 | 272 | Open on cream with tactile blue transfer paper and a restrained line-by-line welcome. Keep the longer copying joke in the permission receipt, and make Open camera immediately visible. |
| O03 | Trace to reveal | P1 | 273 | Thumb dragging leaves an indigo imprint and reveals the viewfinder after camera permission; the same destination is reachable by one tap and assistive technology. |
| O04 | Itemized permission receipt | P1 | 274 | Animate a receipt with dot-matrix haptic ticks and RAW-engine/darkroom inspiration rows. Its camera button invokes the native permission dialog and accurately reflects permission and capability states. |
| O05 | Load the first roll | P1 | 275 | Drop the film canister onto the deck; drag or tap it into the slot, close the camera back, and enter frame 01 / 24. This ceremony is skippable on subsequent launches. |

### Capture and creative camera modes

| ID | Feature | Phase | Source lines | Build and completion rule |
| --- | --- | --- | --- | --- |
| C01 | Natural Lens Bayer capture | P1 | 29, 69 | Prefer supported single-frame Bayer RAW with minimal aesthetic processing; discover actual resolution and bit depth rather than promising 12-14 bit or 12MP on every lens. |
| C02 | Coverage safety capture | P1 | 73 | Retain RAW and a processed safety image when the active configuration supports paired capture; preserve capture provenance and allow recovery without creating duplicate gallery cards. |
| C03 | Low-light fallback | P1/P5 | 73 | Automatically choose a supported processed or ProRAW night fallback and record provenance. In P5, validate blending an aligned computational safety frame with RAW development; retain the usable single-frame fallback when blending fails. |
| C04 | Responsive shutter and queue | P1 | 40 | Submit capture immediately, durably queue returned originals before heavy rendering, and permit rapid follow-up shots within tested memory and camera readiness limits. |
| C05 | Safety capture setting | P4 | 96 | Off by default. When enabled, request three nearby frames where supported, group successful originals as one logical shot, initially show the first successful frame, and let the user choose manually. No eye detection or automatic frame ranking. Preserve partial groups and show actual count. Validate timing rather than assuming RAW prebuffer access. See D-025. |
| C06 | Raw burst stacking | P5 | 218 | Research aligned 16-32-frame low-light and zoom stacks with motion rejection, bounded memory, and fewer-frame fallback. Ship only measured improvements without promising zero noise or larger-sensor equivalence. |
| C07 | Disposable flash rendering | P1 | 34 | Offer Auto, On, and Off flash with a disposable-inspired exposure and warmth profile; test roughly 1/60-1/100s on supported configurations and gracefully accept hardware limits. |
| C08 | Party Drag | P4 | 82 | Provide an intentional motion-blur and slow-sync-flash look targeting about 1/15s. Preserve a sharp-subject option or clear fallback when genuine flash timing is unavailable. |
| C09 | Black and white Snap Focus | P4 | 191 | Add high-contrast street mode with focus calibrated toward 2m or 6.5ft on supported lenses; verify real distance behavior and fall back to a preset focus range. |
| C10 | Prime focal lengths | P1 | 81, 289 | Use notched 24, 35, and 50mm-equivalent choices; select real cameras or validated crops per device. Display equivalent framing without implying every choice is an optical lens. |
| C11 | Vintage Glass bokeh | P5 | 172 | Use available depth or portrait mattes for swirly, soap-bubble, cat's-eye bokeh, f/1.4-like falloff, and soft edges. Preserve hair and glasses; provide a depth-unavailable fallback. |
| C12 | Local double exposure | P4 | 173 | Hold the first exposure non-destructively, overlay a faint ghost silhouette, and let the same user finish the second exposure on the phone. |
| C14 | Super 8 motion capture | P4 | 174 | Offer a 1.5-second motion companion targeting an 18fps aesthetic per shot; use a supported Live Photo or custom video companion and retain capture timestamps and audio preference. |
| C15 | Shake accidents | P4 | 190 | Use accelerometer input during supported exposure windows to create reversible light-leak streaks or shutter-drag effects; make shake sensitivity explicit and prevent accidental activation. |
| C16 | First frame burn | P4 | 189 | Apply an optional vertical orange-red leak to frame one of each roll; one tap restores the untouched crop and original. |
| C17 | Group face geometry | P5 | 228 | Apply subtle local de-stretching to faces near 24mm frame edges while protecting surrounding lines, neighboring people, and identity; keep the transform reversible. |
| C18 | Skin-protected color | P2 | 219 | Use face or skin segmentation to preserve natural luminance and warmth under strong grades. Calibrate across the Monk Skin Tone Scale and mixed lighting without inferring identity. |

### Viewfinder and tactile controls

| ID | Feature | Phase | Source lines | Build and completion rule |
| --- | --- | --- | --- | --- |
| U01 | Rangefinder camera layout | P1 | 50, 287-289 | Use a rounded optical-style preview with subtle parallax framing; allocate about the bottom 20 percent to shutter, prime switch, and brass winder without covering the capture area. |
| U02 | Mood exposure swipe | P1 | 79 | Vertical viewfinder swipes move between Moody or Cinema and Bright or Airy, preview the result, and return to neutral with an accessible reset. |
| U03 | Warmth thumb wheel | P1 | 80 | Translate white-balance bias into Golden Hour and Cool Shade controls; apply the calibrated adjustment before the film grade and retain a neutral reference. |
| U04 | Sunburn Glow | P2 | 71 | Show soft amber clipping warnings for bright faces, skies, or saturated channels; calibrate preview estimates against captures instead of labeling preview data as direct 14-bit sensor readings. |
| U05 | Rangefinder focus patch | P2 | 72 | Touch and hold to reveal a magnified subject patch and focus peaking while adjusting focus; release to lock. Provide tap controls for magnification, focus, and unlock. |
| U06 | Level haptic | P1 | 88 | Emit a crisp, debounced tick when the horizon reaches level; include a visible alignment indication when haptics are unavailable or disabled. |
| U07 | Brightline outside margin | P1 | 89 | Preview a small margin outside the recorded crop where the capture configuration allows it; verify that brightlines correspond to exported framing across all prime choices. |
| U08 | Distance coaching | P2 | 90 | When a close face reaches wide-angle edges, gently suggest stepping back and selecting 35 or 50mm; keep coaching optional and avoid repeated interruptions. |
| U09 | Physical shutter buttons | P1 | 50 | Support documented hardware capture events for volume or shutter buttons where available and prevent duplicate capture from a single physical press. |
| U10 | Camera Control integration | P3 | 182 | Support hardware shutter events and indexed prime or stock controls on compatible devices; validate light-press focus-lock behavior against the supported API and provide on-screen equivalents. |
| U11 | Film winding | P1 | 50, 266 | Provide a thumb-wheel swipe with ramping gear haptics that unlocks the next frame in Analog mode. Offer tap-to-wind and automatic winding for speed and accessibility. |
| U12 | Film Box End-Flap | P1 | 290 | Place secondary stock, lab, flash, creative, lesson, and advanced options in a pull-out top-corner film flap; keep the primary camera deck sparse. |
| U13 | Capacitor status | P1 | 291 | Use a tiny orange charge indicator and optional rising whine when flash becomes ready; pair environmental status with accessible labels and respect silent mode. |
| U14 | Ten-day lessons | P2 | 98 | Offer an optional interactive ten-day sequence attached to rolls, with one-sentence exercises about shadows, distance, or prime framing and a simple progress history. |
| U15 | Fast system entry | P3 | 179-181 | Add Lock Screen, Action Button, and Control Center launch paths; target subsecond warm preview where feasible. Respect authentication boundaries and preserve locked-session captures. |

### Film pipeline and reversible editing

| ID | Feature | Phase | Source lines | Build and completion rule |
| --- | --- | --- | --- | --- |
| R01 | Real background development | P1 | 41 | Run RAW decoding, multi-pass image development, and rendering through a resumable queue; checkpoint intermediate work and continue in foreground when background execution is unavailable. |
| R02 | Highlight shoulder | P1 | 30 | Apply calibrated shoulder compression in a linear working space before creative grading, with smooth bright detail and no premature hard clipping. |
| R03 | Scene-aware color science | P1 | 31 | Combine scene-referred 3D LUTs and subtractive color matrices with explicit input and output transforms; validate multiple illuminants instead of applying one display LUT indiscriminately. |
| R04 | Halation and bloom | P1 | 32 | Use thresholded red-orange scattering near bright edges and point lights, plus separate bloom control, through Core Image or Metal passes; avoid a uniform full-image haze. |
| R05 | Luminance grain | P1 | 33 | Generate procedural clustered grain with stronger midtone and shadow character and finer highlights; use stable seeds so repeated rendering does not flicker or change arbitrarily. |
| R06 | Disposable lens character | P2 | 34 | Render subtle plastic-meniscus chromatic aberration and corner vignetting as adjustable, non-destructive effects distinct from optical camera calibration. |
| R07 | Per-roll Lab Options | P2 | 42 | Apply push or pull exposure around one stop, warm or cool scanner calibration, and dusty or clean scans to an entire roll; record inherited and overridden settings. |
| R08 | Develop Exposure dial | P1 | 69 | Expose one post-shot exposure control that re-renders from retained data and can reset to the original development without accumulating edits. |
| R09 | Reversible film and warmth | P2 | 70 | After development, change film stock, white balance, and flash warmth without overwriting the source; preview changes quickly and render the selected version deterministically. |
| R10 | One logical HEIF and RAW asset | P2 | 70, 97 | Prototype combined HEIF plus RAW packaging and metadata preservation; guarantee one Carbon gallery asset backed by HEIF, DNG, and recipe sidecar when other apps cannot preserve a custom container. |
| R11 | Recovery metadata and originals | P1 | 51 | Retain original sensor or fallback data and versioned edit parameters in sidecars or supported metadata; recover exposure and remove effects within the original capture's real headroom. |
| R12 | Carbon Copy recipe authoring | P2 | 171 | Allow grain, halation, warmth, and full stock settings to be saved, named, and shared as versioned recipes; importing a recipe never changes an existing original. |
| R13 | Scan to clone recipes | P3 | 171, 283 | Read a recipe identifier, metadata, or QR from a Carbon photo and apply the exact available recipe. For stripped or photographed images, offer QR recovery or a labeled approximation. |

### Rolls storage

| ID | Feature | Phase | Source lines | Build and completion rule |
| --- | --- | --- | --- | --- |
| L01 | Local ownership | P1 | 48 | Store originals, recipes, and developed rolls locally with offline capture and review, ordinary file export, and a readable archive manifest independent of a Carbon server. |
| L02 | iCloud backup and sync | P3 | 48 | Offer opt-in personal iCloud backup or sync with visible state, conflict handling, recovery, and storage controls; distinguish Carbon archive sync from Photos library syncing. |
| L03 | Google Photos destination | P3 | 48 | Offer supported upload or export of Carbon-created media and clear backup status; use permitted Google Photos APIs and system sharing instead of assuming unrestricted library or sharing access. |
| L04 | Rolls as albums | P1 | 42, 49, 275 | Organise shots into named rolls (open-ended, no hard frame limit). Each roll has a creation date, optional name, and a state machine: shooting → developing → ready. A new roll starts automatically when the user loads a new canister or taps New roll; the active roll collects all captures until closed. |
| L05 | Compute-based darkroom | P1 | 36-42 | Reflect genuine queued, rendering, paused, ready, and failed states; reveal ready work without an invented mandatory wait and expose a retry when development fails. |
| L06 | Optional delayed reveal | P2 | 131, 274 | Retain the transcript's 24-hour darkroom idea as an explicitly selected reveal ritual separate from compute time; display the actual reveal time and allow the owner to end it. |
| L09 | Safelight processing shells | P2 | 281 | Wrap developing rolls in translucent red-orange glass; derive inverted silhouettes and growing contrast from real processing stages, with a plain textual progress alternative. |

### Reveal curation and keepsakes

| ID | Feature | Phase | Source lines | Build and completion rule |
| --- | --- | --- | --- | --- |
| G01 | Lab Envelope reveal | P2 | 193-195 | Present finished rolls as a lab delivery with a tactile open action and clear ready state; opening leads directly into the contact sheet or optional culling flow. |
| G02 | Printable contact sheet | P2 | 197 | Generate a proof grid with four columns on black negative strips, circling highest-rated shots in grease pencil. Paginate for rolls of any length; export share and print versions. |
| G04 | Carbon Credits metadata | P2 | 199, 283 | Write supported EXIF or XMP provenance and render it on the print back. Treat the example 40/30/30 inspiration breakdown as playful copy, never a measured or affiliation claim. |
| G05 | Light Table swipe cull | P2 | 242 | Offer an approximately 30-second review that groups near duplicates, recommends sharp eyes-open smiles, and lets users flick rejects to a recoverable bin before Photos export. |
| G06 | Stars and ratings | P2 | 197, 243 | Allow manual stars or ratings, preserve user choices over automatic ranking, and reuse favorites for contact-sheet circles and widgets. |
| G10 | Voice Backings | P4 | 244 | Opt in to approximately three seconds of ambient sound during a shot; retain an audio companion and play it from the print back with clear recording status and deletion control. |
| G11 | Tangible print detail | P2 | 283 | Render a two-sided photo with spring-based pinch zoom and horizontal flip; preserve crop and zoom state and provide explicit Front and Back buttons. |
| G12 | Print back information | P3 | 283 | Show stamped date, lens, stock recipe QR, Carbon Credits, and available room-audio playback on the reverse; never rely on EXIF surviving an external share. |
| G13 | Removable stamp and borders | P2 | 175 | Add optional orange quartz dates such as the proposed 26 11 02 style, sprocket holes, and lab-scan borders as removable layers; export clean or decorated variants. |
| G14 | Moving print playback | P4 | 174 | Hold a gallery photo to play its Super 8 companion with matching LUT, gate weave, and optional shutter-clack sound; provide a visible Play control and reduced-motion playback. |
