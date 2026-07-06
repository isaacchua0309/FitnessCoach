#!/usr/bin/env bash
# Captures Xcode build warnings/errors for BuildWarningsRegister triage.
# Usage: ./Scripts/capture_build_warnings.sh [destination]

set -euo pipefail

DESTINATION="${1:-platform=iOS Simulator,name=iPhone 17}"
LOG_DIR="${LOG_DIR:-/tmp/forma-build-logs}"
mkdir -p "$LOG_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/xcodebuild-${STAMP}.log"
BFT_LOG="$LOG_DIR/xcodebuild-bft-${STAMP}.log"

echo "Resolving Swift package dependencies…"
xcodebuild -resolvePackageDependencies \
  -project "Fitness Coach.xcodeproj" \
  -scheme "Fitness Coach"

echo "Building Fitness Coach app → $LOG_FILE"
xcodebuild build \
  -project "Fitness Coach.xcodeproj" \
  -scheme "Fitness Coach" \
  -destination "$DESTINATION" \
  2>&1 | tee "$LOG_FILE"

echo ""
echo "Building for testing → $BFT_LOG"
xcodebuild build-for-testing \
  -project "Fitness Coach.xcodeproj" \
  -scheme "Fitness Coach" \
  -destination "$DESTINATION" \
  2>&1 | tee "$BFT_LOG"

echo ""
echo "=== App build summary ==="
rg -n "error:|warning:" "$LOG_FILE" || true
echo "warning count: $(rg -c "warning:" "$LOG_FILE" || echo 0)"
echo "error count: $(rg -c "error:" "$LOG_FILE" || echo 0)"

echo ""
echo "=== Test build summary ==="
rg -n "error:|warning:" "$BFT_LOG" || true
echo "warning count: $(rg -c "warning:" "$BFT_LOG" || echo 0)"
echo "error count: $(rg -c "error:" "$BFT_LOG" || echo 0)"
