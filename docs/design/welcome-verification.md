The welcome screen uses the existing `Receipt` (#F6F3EC) and `Remjet`
(#0E0E10) assets, plus `WelcomeAccent` (#F0401F). Other screens retain their
existing styling. The original WelcomeHero PNG files are unchanged.

The photo uses its full width and original aspect ratio. Its outer edge colors
extend into the remaining canvas and blend into their sampled average outside
the photograph. The measured card height keeps the canister and film strip
above the card. At accessibility text sizes, the copy scrolls inside the card
and the large button remains visible. The button is bold, scales with Dynamic
Type, and has an 18pt minimum. Its cream/accent contrast is 3.4718:1, exceeding
the 3:1 AA threshold for large bold text.

The card enters with a 0.56-second critically damped spring and a light stagger.
The camera preview prepares under the welcome cover without starting capture.
On the first tap, the camera route activates and the system permission request
starts immediately. A 1.16-second Canvas effect uses layered radial/linear gradients,
screen/plus-lighter compositing and sparse animated grain. An opaque exposure
plateau covers the welcome's removal at 520ms, with one soft haptic. The plateau
holds until the underlying scene swap commits before starting the reveal. Reduce
Motion uses a 300ms crossfade. Permission denial reaches the dark camera with
a Settings action. The coordinator and transition both guard repeated taps.

Native simulator verification runs through the isolated `ci/welcome-redesign`
branch because the editing host runs Windows. The production branch and the
local build workflow are not changed by the verification snapshot.

To repeat on macOS with Xcode and XcodeGen:

```sh
bash ci/verify_welcome.sh com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation se
bash ci/verify_welcome.sh com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max pro-max
python3 ci/package_welcome_screenshots.py Carbon/build/Welcome-se-screenshots screenshots/welcome se
python3 ci/package_welcome_screenshots.py Carbon/build/Welcome-pro-max-screenshots screenshots/welcome pro-max
```

The UI tests capture resting, start, peak before/after the scene swap, resolving,
and final camera frames using the production renderer, plus large text,
permission denial, Reduce Motion and repeated taps. The script also records
the actual timed transition as a simulator video. All preview/autoplay launch
arguments are gated to DEBUG builds and the explicit UI-testing fixture.

Verified November 4, 2026: [macOS CI run 41924076885](https://github.com/s4wyer/carbon-camera/actions/runs/41924076885),
snapshot `59ed51fa83f6d69f8fd9db6bd1da7ada8e9c0288`. Both iPhone SE (3rd generation,
375 × 667pt) and iPhone 16 Pro Max (440 × 956pt) passed all three handoff unit
tests and all five UI tests: 16 passing tests across the two simulators. Both
native builds introduced zero compiler diagnostics compared with main at
`8003a3e151eaaebc2037ee2a0db50ddbc0c0dd39`.

Visual review covered both resting layouts, the largest accessibility text size
before/after scrolling, permission denial, Reduce Motion, repeated taps, all
transition checkpoints, and the actual timed recordings. The canister and film
stay above the card, the status bar is clear, and the recorded reveal resolves
into the dark camera without the welcome reappearing after peak exposure.

The saved [gallery](../../screenshots/welcome/index.html) contains 22 original
simulator PNGs and two native transition recordings. The camera preview in these
simulator captures uses the existing explicit UI-testing sample photo fixture.
Local pipeline, asset-integrity and all 19 Python CI tests also passed.
