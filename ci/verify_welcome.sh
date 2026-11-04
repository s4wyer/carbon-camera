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
xcodebuild test -project Carbon.xcodeproj -scheme Carbon \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -only-testing:CarbonUITests/WelcomeUITests -only-testing:CarbonKitTests/WelcomeHandoffTests \
  -parallel-testing-enabled NO \
  -derivedDataPath build/WelcomeDerivedData \
  -resultBundlePath "build/Welcome-$LABEL.xcresult" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "build/welcome-$LABEL.log"
xcrun xcresulttool export attachments --path "build/Welcome-$LABEL.xcresult" \
  --output-path "build/Welcome-$LABEL-screenshots"
