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

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. Fast-Core requires macOS with Xcode." >&2
  exit 127
fi

echo "Resolving Swift package dependencies…"
xcodebuild -resolvePackageDependencies \
  -project "Fitness Coach.xcodeproj" \
  -scheme "$SCHEME"

echo "Building for testing…"
xcodebuild build-for-testing \
  -project "Fitness Coach.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION"

echo "Running Fast-Core (serial)…"
xcodebuild test-without-building \
  -project "Fitness Coach.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO
