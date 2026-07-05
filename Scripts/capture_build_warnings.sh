#!/usr/bin/env bash
# Captures Xcode build warnings/errors for BuildWarningsRegister triage.
# Usage: ./Scripts/capture_build_warnings.sh [simulator name]

set -euo pipefail

DESTINATION="${1:-platform=iOS Simulator,name=iPhone 17}"
LOG_DIR="${LOG_DIR:-/tmp/forma-build-logs}"
mkdir -p "$LOG_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/xcodebuild-${STAMP}.log"

echo "Building Fitness Coach → $LOG_FILE"
xcodebuild build \
  -scheme "Fitness Coach" \
  -destination "$DESTINATION" \
  2>&1 | tee "$LOG_FILE"

echo ""
echo "=== Summary ==="
rg -n "error:|warning:" "$LOG_FILE" || true
echo ""
echo "warning count: $(rg -c "warning:" "$LOG_FILE" || echo 0)"
echo "error count: $(rg -c "error:" "$LOG_FILE" || echo 0)"
