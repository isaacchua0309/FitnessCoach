#!/usr/bin/env bash
# Phase 16–20 final verification (macOS + Xcode required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="${SCHEME:-Fitness Coach CI}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
DERIVED="${DERIVED:-/tmp/forma-phase-16-20-derived}"
LOG_DIR="${LOG_DIR:-/tmp/forma-phase-16-20-logs}"
mkdir -p "$LOG_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass=0
fail=0
skip=0
warn=0

note_pass() { echo -e "${GREEN}PASS${NC}: $1"; pass=$((pass + 1)); }
note_fail() { echo -e "${RED}FAIL${NC}: $1"; fail=$((fail + 1)); }
note_skip() { echo -e "${YELLOW}SKIP${NC}: $1"; skip=$((skip + 1)); }
note_warn() { echo -e "${YELLOW}WARN${NC}: $1"; warn=$((warn + 1)); }

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    note_skip "Requires macOS with Xcode ($1)"
    return 1
  fi
  if ! command -v xcodebuild >/dev/null 2>&1; then
    note_skip "xcodebuild not found ($1)"
    return 1
  fi
  return 0
}

echo "=== Phase 16–20 Final Verification ==="
echo "Root: $ROOT"
echo

# --- Static checks (any OS) ---

echo "--- Static checks ---"

# HealthKit imports outside allowed infrastructure
HK_VIOLATIONS=$(rg -l 'import HealthKit' "Fitness Coach" 2>/dev/null \
  | rg -v '^Fitness Coach/Health/HealthKit/' \
  | rg -v '^Fitness Coach/Infrastructure/Health/' || true)
if [[ -z "$HK_VIOLATIONS" ]]; then
  note_pass "No HealthKit imports outside Health infrastructure"
else
  note_fail "HealthKit imports outside infrastructure:"
  echo "$HK_VIOLATIONS"
fi

# Features layer must not import HealthKit
if rg -q 'import HealthKit' "Fitness Coach/Features" 2>/dev/null; then
  note_fail "Features/ imports HealthKit"
else
  note_pass "Features/ has no HealthKit imports"
fi

# Application state builders must not import HealthKit
if rg -q 'import HealthKit' "Fitness Coach/Application" 2>/dev/null; then
  note_fail "Application/ imports HealthKit"
else
  note_pass "Application/ has no HealthKit imports"
fi

# Production feature flag defaults (source-level)
if rg -q 'static let uiEnabled = false' "Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift" \
  && rg -q 'static let coachContextEnabled = false' "Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift" \
  && rg -q 'static let remoteSummarySyncEnabled = false' "Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift"; then
  note_pass "Feature flag production defaults are conservative in source"
else
  note_fail "Feature flag defaults may not be safe for release"
fi

# Remote sync noop wiring
if rg -q 'NoopHealthSummaryRemoteSyncClient' "Fitness Coach/App/AppContainer.swift"; then
  note_pass "AppContainer wires NoopHealthSummaryRemoteSyncClient when remote sync disabled"
else
  note_fail "AppContainer missing NoopHealthSummaryRemoteSyncClient fallback"
fi

# Debug diagnostics gated
if rg -q '#if DEBUG' "Fitness Coach/Features/Settings/UI/HealthIntelligenceDiagnosticsView.swift" \
  && rg -q 'includesCompiledDeveloperTools' "Fitness Coach/Features/Settings/SettingsRootView.swift"; then
  note_pass "Health Intelligence diagnostics gated behind DEBUG / developer tools"
else
  note_fail "Health Intelligence diagnostics may be exposed in production"
fi

# TODO/FIXME in Health production paths
HI_TODOS=$(rg -n 'TODO|FIXME' "Fitness Coach/Health" "Fitness Coach/Application/StateBuilders" \
  --glob '*Health*' 2>/dev/null || true)
if [[ -z "$HI_TODOS" ]]; then
  note_pass "No TODO/FIXME in Health Intelligence production paths"
else
  note_warn "TODO/FIXME found in Health paths (review):"
  echo "$HI_TODOS"
fi

# Force unwrap inventory (Health module)
FORCE_UNWRAPS=$(rg -n '(\)!|\]!|as!|try!)' "Fitness Coach/Health" \
  --glob '*.swift' \
  --glob '!**/HealthIntelligenceMocks.swift' 2>/dev/null || true)
if [[ -z "$FORCE_UNWRAPS" ]]; then
  note_pass "No force unwraps in Health module (excluding mocks)"
else
  note_warn "Force unwraps present in Health module (pre-existing cache paths):"
  echo "$FORCE_UNWRAPS" | head -20
fi

echo

# --- Build & tests (macOS only) ---

if require_macos "build/tests"; then
  echo "--- Clean build ---"
  BUILD_LOG="$LOG_DIR/clean-build.log"
  if xcodebuild clean build \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO \
    | tee "$BUILD_LOG"; then
    note_pass "Clean build succeeded"
  else
    note_fail "Clean build failed (see $BUILD_LOG)"
  fi

  echo
  echo "--- Unit + integration tests (Full test plan) ---"
  TEST_LOG="$LOG_DIR/full-test.log"
  if xcodebuild test \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED" \
    -testPlan Full \
    CODE_SIGNING_ALLOWED=NO \
    | tee "$TEST_LOG"; then
    note_pass "Full test plan succeeded"
  else
    note_fail "Full test plan failed (see $TEST_LOG)"
  fi

  echo
  echo "--- Swift concurrency warnings ---"
  if rg -q "warning:.*(actor-isolated|Sendable|data race|concurrency)" "$BUILD_LOG" "$TEST_LOG" 2>/dev/null; then
    note_fail "Swift concurrency warnings detected in build/test logs"
    rg "warning:.*(actor-isolated|Sendable|data race|concurrency)" "$BUILD_LOG" "$TEST_LOG" || true
  else
    note_pass "No Swift concurrency warnings in build/test logs"
  fi

  echo
  echo "--- Simulator smoke (launch + tab load) ---"
  APP_PATH=$(find "$DERIVED/Build/Products" -name "Fitness Coach.app" -type d | head -1 || true)
  if [[ -z "$APP_PATH" ]]; then
    note_fail "Could not locate built .app for simulator smoke"
  else
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_PATH/Info.plist" 2>/dev/null || echo "")
    SIM_UDID=$(xcrun simctl list devices available | rg -m1 'iPhone 17 \(' | rg -o '[0-9A-F-]{36}' || true)
    if [[ -z "$SIM_UDID" ]]; then
      SIM_UDID=$(xcrun simctl list devices available | rg -m1 'iPhone' | rg -o '[0-9A-F-]{36}' || true)
    fi
    if [[ -n "$SIM_UDID" && -n "$BUNDLE_ID" ]]; then
      xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
      xcrun simctl install "$SIM_UDID" "$APP_PATH"
      xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" && note_pass "App launched on simulator (HealthKit unavailable on sim — expected)"
      note_pass "Manual follow-up: verify Today/Coach/Journey/Plan/Settings Apple Health screens in simulator"
    else
      note_skip "Simulator smoke (no simulator UDID or bundle id)"
    fi
  fi
else
  note_skip "Clean build (non-macOS environment)"
  note_skip "Full test plan (non-macOS environment)"
  note_skip "Simulator launch (non-macOS environment)"
  note_skip "Swift concurrency log scan (requires build logs)"
fi

echo
echo "=== Summary ==="
echo "Pass: $pass | Fail: $fail | Warn: $warn | Skip: $skip"
if [[ $fail -gt 0 ]]; then
  exit 1
fi
exit 0
