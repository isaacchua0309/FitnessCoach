#!/usr/bin/env bash
# Run the Fast-Core XCTest plan (serial execution; requires macOS + Xcode).
#
# Usage:
#   ./Scripts/run_fast_core_tests.sh
#   ./Scripts/run_fast_core_tests.sh 'platform=iOS Simulator,name=iPhone 17'

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DESTINATION="${1:-platform=iOS Simulator,name=iPhone 17}"
SCHEME="Fitness Coach"
BUILD_LOG="${TMPDIR:-/tmp}/fitness-coach-fast-core-build.log"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. Fast-Core requires macOS with Xcode." >&2
  exit 127
fi

print_build_errors() {
  if [[ -f "$BUILD_LOG" ]]; then
    echo "--- Swift compile errors (last 80) ---"
    grep -E '\.swift:[0-9]+:[0-9]+: error:' "$BUILD_LOG" | tail -80 || true
    echo "--- Build summary ---"
    grep -E 'TEST BUILD FAILED|TEST BUILD SUCCEEDED|TEST SUCCEEDED|BUILD FAILED|BUILD SUCCEEDED|Failed frontend command|Testing failed' "$BUILD_LOG" | tail -20 || true
    echo "--- Last 60 lines of build log ---"
    tail -60 "$BUILD_LOG" || true
  fi
}

run_xcodebuild() {
  local label="$1"
  shift
  echo "$label"
  set +e
  xcodebuild "$@" >"$BUILD_LOG" 2>&1
  local status=$?
  set -e
  if [[ $status -ne 0 ]]; then
    print_build_errors
    exit $status
  fi
  grep -E 'TEST BUILD SUCCEEDED|BUILD SUCCEEDED' "$BUILD_LOG" | tail -3 || true
}

echo "Resolving Swift package dependencies…"
xcodebuild -resolvePackageDependencies \
  -project "Fitness Coach.xcodeproj" \
  -scheme "$SCHEME" \
  >"$BUILD_LOG" 2>&1

run_xcodebuild "Building for testing…" \
  build-for-testing \
  -project "Fitness Coach.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION"

run_xcodebuild "Running Fast-Core (serial)…" \
  test-without-building \
  -project "Fitness Coach.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO

echo "Fast-Core tests passed."
