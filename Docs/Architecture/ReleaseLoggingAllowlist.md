# Release Logging Allowlist

**Last updated:** 2026-07-05  
**Related:** [LoggingAndPrivacyContract.md](./LoggingAndPrivacyContract.md)  
**Machine-readable:** `Fitness CoachTests/Fixtures/ReleaseLoggingAllowlist.json`  
**Guard test:** `ReleaseLoggingGuardTests`

---

## Purpose

Make Release logging policy explicit and test enforced. Any **Release-reachable** logging emission in `Fitness Coach/` must be either:

1. Gated behind `#if DEBUG` / `#else return`, or
2. Listed in the allowlist with owner, sensitivity, and redaction requirements.

`ReleaseLoggingGuardTests` scans Swift sources and fails when a new non-DEBUG log appears without an allowlist update.

---

## Scanned patterns

| Pattern | Notes |
|---------|--------|
| `Logger(` | Declarations ignored; emissions flagged |
| `logger.log` / `logger.info` / `logger.error` / … | OSLog emissions |
| `print(` / `debugPrint(` | Console output |
| `NSLog` / `os_log` / `OSLog` | Legacy/diagnostic APIs |

---

## Allowlist entry types

### File entries (`fileEntries`)

One entry per file that **intentionally** emits Release-safe logs.

| Field | Meaning |
|-------|---------|
| `path` | Repo-relative Swift file |
| `owner` | Team/domain owner |
| `reason` | Why Release logging is allowed |
| `sensitivity` | `none` / `low` / `medium` |
| `redactorRequired` | When `true`, file must reference `FormaLogRedactor` / `LogRedactor` |
| `redactorSymbols` | Symbols that must appear in the file when redaction is required |

### Line pattern entries (`linePatternEntries`)

Narrow patterns for call sites whose callees are already safe (NoOp analytics, DEBUG-only loggers).

### DEBUG-only files (`debugOnlyFiles`)

Files that may contain logging but **must** gate Release with `else-return` or `file-debug-implementation` (see JSON).

---

## Adding a new Release log

1. **Default:** do not log in Release — use `#if DEBUG` or `#else return`.
2. If Release logging is required: sanitize with `FormaLogRedactor` / `LogRedactor`, add a specific JSON entry, update this doc, run `ReleaseLoggingGuardTests`.

---

## Prohibited without explicit approval

- Raw UIDs, emails, tokens, meal names, macros, chat text, image bytes
- `error.localizedDescription` without redaction
- `print(` in Release paths
- Broad wildcard allowlist entries
