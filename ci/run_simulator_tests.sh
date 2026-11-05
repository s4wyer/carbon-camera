#!/bin/bash
# Run from the repository root on macOS after setup-ios has generated the project.
set -euo pipefail

TEST_TARGET="${1:?Expected a test target}"
RESULT_NAME="${2:?Expected a result bundle name}"
SESSION_MODE="${3:-run}"
case "$SESSION_MODE" in
  run|--keep-simulator|--reuse-simulator) ;;
  *) echo "::error::Unknown simulator session mode: $SESSION_MODE"; exit 1 ;;
esac
cd "$(dirname "$0")/../Carbon"
mkdir -p build

CACHE_DIR="${COMPILATION_CACHE_DIR:-$PWD/build/CompilationCache.noindex}"
SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"
BOOT_LOG="build/$RESULT_NAME-simulator.log"
BOOT_PID=""
DEVICE=""
SESSION_FILE=./build/UISimulatorSession.txt
HOST_ARCH=$(uname -m)
case "$HOST_ARCH" in
  arm64|x86_64) ;;
  *) echo "::error::Unsupported simulator architecture: $HOST_ARCH"; exit 1 ;;
esac

record_timing() {
  printf '| %s | %ss |\n' "$1" "$2" >> "$SUMMARY_FILE"
  echo "Timing: $1: ${2}s"
}

run_timed() {
  local label="$1" started=$SECONDS status
  shift
  if "$@"; then
    status=0
  else
    status=$?
  fi
  record_timing "$label" "$((SECONDS - started))"
  return "$status"
}

cleanup() {
  local status=$?
  if [ -n "$BOOT_PID" ]; then
    kill "$BOOT_PID" 2>/dev/null || true
    wait "$BOOT_PID" 2>/dev/null || true
  fi
  if [ -n "$DEVICE" ] && { [ "$SESSION_MODE" != --keep-simulator ] || [ "$status" -ne 0 ]; }; then
    xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

printf '### %s timings\n\n| Phase | Duration |\n| --- | ---: |\n' "$TEST_TARGET" >> "$SUMMARY_FILE"
if [ "$SESSION_MODE" = --reuse-simulator ]; then
  if [ ! -f "$SESSION_FILE" ]; then
    echo "::error::No prepared simulator session exists"
    exit 1
  fi
  {
    IFS= read -r DEVICE
    IFS= read -r SESSION_ARCH
    IFS= read -r TEST_RUN
  } < "$SESSION_FILE"
  if [ "$SESSION_ARCH" != "$HOST_ARCH" ] || [ ! -f "$TEST_RUN" ]; then
    echo "::error::Prepared simulator session has incompatible architecture or missing test bundles"
    exit 1
  fi
  echo "Reusing simulator $DEVICE and test manifest $TEST_RUN"
  record_timing "Reuse prepared simulator and test bundles" 0
else
STARTED=$SECONDS
# Query CoreSimulator directly: Xcode can initially report only generic
# placeholders before the simulator service has enumerated its devices.
xcrun simctl list devices available -j \
  | tee "build/$RESULT_NAME-destinations.log"
DEVICE=$(python3 ../ci/select_simulator.py --simctl-json < "build/$RESULT_NAME-destinations.log")
record_timing "Select available iPhone simulator" "$((SECONDS - STARTED))"
echo "Selected simulator: $DEVICE"

# bootstatus -b boots a shut-down device and blocks until it is ready. Let it
# run while the compiler works, then surface boot failures before starting tests.
xcrun simctl bootstatus "$DEVICE" -b > "$BOOT_LOG" 2>&1 &
BOOT_PID=$!

BUILD_ARGS=(
  -project Carbon.xcodeproj
  -scheme Carbon
  -destination 'generic/platform=iOS Simulator'
  # Build the whole target so later test groups can reuse the same manifest.
  -only-testing:"${TEST_TARGET%%/*}"
  -derivedDataPath ./build/DerivedData
  -parallel-testing-enabled NO
  -enableCodeCoverage YES
  "ARCHS=$HOST_ARCH"
  ONLY_ACTIVE_ARCH=YES
  CODE_SIGNING_ALLOWED=NO
  COMPILATION_CACHE_ENABLE_CACHING=YES
  COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES
  "COMPILATION_CACHE_CAS_PATH=$CACHE_DIR"
)

run_timed "Compile test bundles (overlaps simulator boot)" \
  xcodebuild build-for-testing "${BUILD_ARGS[@]}" -showBuildTimingSummary \
  2>&1 | tee "build/$RESULT_NAME-build.log"

# Products are fresh on every runner; only compiler outputs are cached. Require
# one manifest so an ambiguous or missing build cannot select stale test bundles.
TEST_RUNS=(./build/DerivedData/Build/Products/*.xctestrun)
if [ "${#TEST_RUNS[@]}" -ne 1 ] || [ ! -f "${TEST_RUNS[0]}" ]; then
  echo "::error::Expected exactly one generated .xctestrun in build/DerivedData/Build/Products"
  exit 1
fi
echo "Test manifest: ${TEST_RUNS[0]}"
TEST_RUN="${TEST_RUNS[0]}"

STARTED=$SECONDS
if wait "$BOOT_PID"; then
  BOOT_PID=""
else
  BOOT_STATUS=$?
  BOOT_PID=""
  cat "$BOOT_LOG"
  record_timing "Simulator readiness failed" "$((SECONDS - STARTED))"
  exit "$BOOT_STATUS"
fi
cat "$BOOT_LOG"
record_timing "Wait for simulator after compilation" "$((SECONDS - STARTED))"
fi

# The manifest contains the built bundle paths and configuration. Execute it
# directly, without loading the project or re-evaluating the scheme's build.
run_timed "Execute tests without rebuilding" \
  xcodebuild test-without-building \
    -xctestrun "$TEST_RUN" \
    -destination "platform=iOS Simulator,id=$DEVICE,arch=$HOST_ARCH" \
    -only-testing:"$TEST_TARGET" \
    -parallel-testing-enabled NO \
    -enableCodeCoverage YES \
    -resultBundlePath "./build/$RESULT_NAME.xcresult" \
  2>&1 | tee "build/$RESULT_NAME-test.log"

# Incompatible bundles can be skipped by Xcode. A successful process alone must
# not turn an empty or skipped suite green after changing destination handling.
xcrun xcresulttool get test-results summary --path "./build/$RESULT_NAME.xcresult" \
  > "build/$RESULT_NAME-summary.json"
python3 ../ci/check_test_results.py "build/$RESULT_NAME-summary.json"

if [ "$SESSION_MODE" = --keep-simulator ]; then
  printf '%s\n%s\n%s\n' "$DEVICE" "$HOST_ARCH" "$TEST_RUN" > "$SESSION_FILE"
fi
