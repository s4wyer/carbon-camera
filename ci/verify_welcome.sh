#!/bin/bash
# Run on macOS with Xcode + XcodeGen. Produces native XCTest screenshots.
set -euo pipefail
cd "$(dirname "$0")/../Carbon"
DEVICE_TYPE="${1:-com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max}"
LABEL="${2:-pro-max}"
xcodegen generate
RUNTIME=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x["isAvailable"] and "iOS" in x["name"]]; print(sorted(r,key=lambda x:tuple(map(int,x["version"].split("."))))[-1]["identifier"])')
DEVICE=$(xcrun simctl create "Welcome $LABEL" "$DEVICE_TYPE" "$RUNTIME")
trap 'xcrun simctl shutdown "$DEVICE" || true' EXIT
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl status_bar "$DEVICE" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
mkdir -p build
TESTS=(-only-testing:CarbonUITests/WelcomeUITests -only-testing:CarbonKitTests/WelcomeHandoffTests)
if [ "${3:-}" = "video" ]; then
  TESTS=(-only-testing:CarbonUITests/WelcomeUITests/testRapidTapsThenCameraIsInteractive
         -only-testing:CarbonUITests/WelcomeUITests/testRestingAndTransitionCheckpoints)
fi
xcodebuild test -project Carbon.xcodeproj -scheme Carbon \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  "${TESTS[@]}" \
  -parallel-testing-enabled NO \
  -derivedDataPath build/WelcomeDerivedData \
  -resultBundlePath "build/Welcome-$LABEL.xcresult" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "build/welcome-$LABEL.log"
xcrun xcresulttool export attachments --path "build/Welcome-$LABEL.xcresult" \
  --output-path "build/Welcome-$LABEL-screenshots"

# Record the actual timed animation too: frozen checkpoints alone cannot show
# a late cream frame or a discontinuity between animation ticks.
xcrun simctl io "$DEVICE" recordVideo --codec=h264 "build/Welcome-$LABEL.mov" &
RECORDER=$!
sleep 1
xcrun simctl launch --terminate-running-process "$DEVICE" app.carbon.Carbon \
  --ui-testing --insert-sample-shot --welcome-testing --welcome-autoplay
sleep 6
kill -INT "$RECORDER"
wait "$RECORDER" || true
