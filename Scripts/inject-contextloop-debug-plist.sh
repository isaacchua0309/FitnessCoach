#!/bin/sh
# Debug-only: merge ContextLoop ATS/env additions and stamp git SHA into the built Info.plist.
# Intentionally does not declare INFOPLIST_PATH as an Xcode output (avoids "Multiple commands produce").

if [ "${CONFIGURATION}" != "Debug" ]; then
  exit 0
fi

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
ADDITIONS="${SRCROOT}/Supporting/ContextLoop-Debug.plist"

if [ ! -f "$PLIST" ]; then
  echo "warning: ContextLoop inject skipped; Info.plist not found at $PLIST"
  exit 0
fi

if [ -f "$ADDITIONS" ]; then
  /usr/libexec/PlistBuddy -c "Merge \"$ADDITIONS\"" "$PLIST" || true
fi

SHA=$(git -C "${SRCROOT}" rev-parse --short HEAD 2>/dev/null || true)
if [ -n "$SHA" ]; then
  if /usr/libexec/PlistBuddy -c "Print :CONTEXTLOOP_GIT_SHA" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :CONTEXTLOOP_GIT_SHA $SHA" "$PLIST" || true
  else
    /usr/libexec/PlistBuddy -c "Add :CONTEXTLOOP_GIT_SHA string $SHA" "$PLIST" || true
  fi
  echo "ContextLoop: stamped CONTEXTLOOP_GIT_SHA=$SHA"
else
  echo "warning: ContextLoop could not resolve git SHA"
fi

# Ensure env + ATS survived merge.
if ! /usr/libexec/PlistBuddy -c "Print :CONTEXTLOOP_ENV" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :CONTEXTLOOP_ENV string debug" "$PLIST" || true
fi
if ! /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsLocalNetworking" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :NSAppTransportSecurity:NSAllowsLocalNetworking true" "$PLIST" || true
fi

exit 0
