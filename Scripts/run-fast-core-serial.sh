#!/usr/bin/env bash
# Run the Fast-Core test plan serially (recommended for XCTest stability).
#
# CI / documented destination: iPhone 17 (iOS 26.5).
# Local fallback: nearest available iOS Simulator when iPhone 17 is not installed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CI_DESTINATION='platform=iOS Simulator,name=iPhone 17'

resolve_destination() {
  if [ -n "${DESTINATION:-}" ]; then
    printf '%s' "$DESTINATION"
    return
  fi

  if ! command -v xcrun >/dev/null 2>&1; then
    echo "error: xcrun not found; set DESTINATION manually." >&2
    exit 1
  fi

  if xcrun simctl list devices available | grep -F 'iPhone 17 (' >/dev/null 2>&1; then
    printf '%s' "$CI_DESTINATION"
    return
  fi

  local fallback
  fallback="$(xcrun simctl list devices available | awk -F'[()]' '/iPhone/ {print $1; exit}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if [ -z "$fallback" ]; then
    echo "error: no available iOS Simulator found; install a simulator or set DESTINATION." >&2
    exit 1
  fi

  echo "note: iPhone 17 simulator not installed; using nearest available: ${fallback}" >&2
  printf 'platform=iOS Simulator,name=%s' "$fallback"
}

DESTINATION="$(resolve_destination)"

echo "Running Fast-Core with DESTINATION=${DESTINATION}" >&2

xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "$DESTINATION" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO
