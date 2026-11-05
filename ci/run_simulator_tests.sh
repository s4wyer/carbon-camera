#!/bin/bash
# Run from the repository root on macOS after setup-ios has generated the project.
set -euo pipefail

TEST_TARGET="${1:?Expected a test target}"
RESULT_NAME="${2:?Expected a result bundle name}"
cd "$(dirname "$0")/../Carbon"
mkdir -p build

CACHE_DIR="${COMPILATION_CACHE_DIR:-$PWD/build/CompilationCache.noindex}"
SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"
BOOT_LOG="build/$RESULT_NAME-simulator.log"
BOOT_PID=""
DEVICE=""

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
  if [ -n "$BOOT_PID" ]; then
    kill "$BOOT_PID" 2>/dev/null || true
    wait "$BOOT_PID" 2>/dev/null || true
  fi
  if [ -n "$DEVICE" ]; then
    xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

printf '### %s timings\n\n| Phase | Duration |\n| --- | ---: |\n' "$TEST_TARGET" >> "$SUMMARY_FILE"
STARTED=$SECONDS
xcodebuild -showdestinations -project Carbon.xcodeproj -scheme Carbon \
  2>&1 | tee "build/$RESULT_NAME-destinations.log"
DEVICE=$(python3 ../ci/select_simulator.py < "build/$RESULT_NAME-destinations.log")
record_timing "Select eligible iPhone simulator" "$((SECONDS - STARTED))"
echo "Selected simulator: $DEVICE"

# bootstatus -b boots a shut-down device and blocks until it is ready. Let it
# run while the compiler works, then surface boot failures before starting tests.
xcrun simctl bootstatus "$DEVICE" -b > "$BOOT_LOG" 2>&1 &
BOOT_PID=$!

COMMON_ARGS=(
  -project Carbon.xcodeproj
  -scheme Carbon
  -destination "platform=iOS Simulator,id=$DEVICE"
  -only-testing:"$TEST_TARGET"
  -derivedDataPath ./build/DerivedData
  -parallel-testing-enabled NO
  -enableCodeCoverage YES
  CODE_SIGNING_ALLOWED=NO
  COMPILATION_CACHE_ENABLE_CACHING=YES
  COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=YES
  "COMPILATION_CACHE_CAS_PATH=$CACHE_DIR"
)

run_timed "Compile test bundles (overlaps simulator boot)" \
  xcodebuild build-for-testing "${COMMON_ARGS[@]}" -showBuildTimingSummary \
  2>&1 | tee "build/$RESULT_NAME-build.log"

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

# Use the same destination, DerivedData, coverage setting, and single simulator
# for both phases; this avoids a second build or a pool of simulator clones.
run_timed "Execute tests without rebuilding" \
  xcodebuild test-without-building "${COMMON_ARGS[@]}" \
    -resultBundlePath "./build/$RESULT_NAME.xcresult" \
  2>&1 | tee "build/$RESULT_NAME-test.log"
