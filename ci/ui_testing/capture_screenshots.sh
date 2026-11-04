#!/bin/bash
set -euo pipefail

# Capture screenshots of Carbon app screens in iOS Simulator
# Usage: ./capture_screenshots.sh <simulator_id> <app_bundle_path> <output_dir>

SIMULATOR_ID="${1}"
APP_BUNDLE="${2}"
OUTPUT_DIR="${3:-./screenshots}"

echo "📱 Starting screenshot capture"
echo "   Simulator: $SIMULATOR_ID"
echo "   App: $APP_BUNDLE"
echo "   Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# Boot simulator if not already running
echo "🔄 Booting simulator..."
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
sleep 3

# Install the app
echo "📦 Installing app..."
xcrun simctl install "$SIMULATOR_ID" "$APP_BUNDLE"

# Get the bundle identifier
BUNDLE_ID=$(defaults read "${APP_BUNDLE}/Info.plist" CFBundleIdentifier)
echo "   Bundle ID: $BUNDLE_ID"

# Grant camera permission before launching
echo "🔐 Granting camera permissions..."
xcrun simctl privacy "$SIMULATOR_ID" grant camera "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl privacy "$SIMULATOR_ID" grant photos-add "$BUNDLE_ID" 2>/dev/null || true

# Launch the app
echo "🚀 Launching app..."
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
sleep 4

# Screenshot 1: Welcome screen
echo "📸 Capturing Welcome screen..."
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/01-welcome.png"
sleep 1

# Tap "Open camera" button (approximate center-bottom position)
# iPhone 16 resolution is typically 1179x2556 at 3x scale
# Button is roughly at x=50%, y=80%
echo "👆 Tapping 'Open camera' button..."
xcrun simctl ui "$SIMULATOR_ID" tap 590 2045
sleep 2

# Handle permission dialog if it appears (tap "OK" / "Allow")
echo "👆 Accepting camera permission..."
xcrun simctl ui "$SIMULATOR_ID" tap 590 1400 2>/dev/null || true
sleep 2

# Screenshot 2: Camera viewfinder
echo "📸 Capturing Camera screen..."
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/02-camera.png"
sleep 1

# Try to take a photo using the shutter button (center-bottom)
# The shutter button is at the bottom center of the camera view
echo "📸 Attempting to take a photo with shutter button..."
# Tap the shutter button (approx x=590, y=2350 for iPhone 16)
xcrun simctl ui "$SIMULATOR_ID" tap 590 2350 2>/dev/null || true
# Wait for the photo to process and save to roll
sleep 3

# Tap the preset name to open preset menu
echo "👆 Opening preset menu..."
xcrun simctl ui "$SIMULATOR_ID" tap 150 100
sleep 2

# Screenshot 3: Preset browser
echo "📸 Capturing Preset menu..."
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/03-preset-menu.png"
sleep 1

# Tap "Done" to close preset menu
echo "👆 Closing preset menu..."
xcrun simctl ui "$SIMULATOR_ID" tap 1050 100
sleep 1

# Tap the roll thumbnail (bottom left) to navigate to Rolls
echo "👆 Navigating to Rolls..."
xcrun simctl ui "$SIMULATOR_ID" tap 100 2350
sleep 2

# Screenshot 4: Rolls screen
echo "📸 Capturing Rolls screen..."
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/04-rolls.png"
sleep 1

# Tap settings gear icon on camera
echo "👆 Going back to camera..."
xcrun simctl ui "$SIMULATOR_ID" tap 80 100
sleep 1

# Tap settings gear
echo "👆 Opening settings..."
xcrun simctl ui "$SIMULATOR_ID" tap 1100 100
sleep 2

# Screenshot 5: Settings
echo "📸 Capturing Settings screen..."
xcrun simctl io "$SIMULATOR_ID" screenshot "$OUTPUT_DIR/05-settings.png"

# Terminate the app
echo "🛑 Terminating app..."
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID"

echo "✅ Screenshot capture complete!"
echo "   Screenshots saved to: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.png
