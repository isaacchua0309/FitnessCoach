# Project Hygiene Register

Cross-cutting repo health: documentation layout, command defaults, test plans, target membership, and tracked TODO inventory. Complements [BuildWarningsRegister.md](./BuildWarningsRegister.md) and [TechnicalDebtRegister.md](./TechnicalDebtRegister.md).

**Last reviewed:** 2026-07-05

---

## Capture summary (2026-07-05)

| Check | Result |
|-------|--------|
| Xcode available | Yes (`/Applications/Xcode.app`) |
| iPhone 16 simulator | **Missing** — machine has iPhone 17 (iOS 26.5) |
| App builds | Pass |
| Unit tests (`Fast-Core`) | **Unblocked (BW-101 fix)** — verify on macOS via `./Scripts/run-fast-core-serial.sh` or `./Scripts/run_fast_core_tests.sh` |
| `functions` build / lint / test | Pass |
| Swift `TODO`/`FIXME` in `Fitness Coach/` | **0** |
| TypeScript `TODO` in `functions/src/` | **0** |
| Root clutter | **Clean** — only `PRD.md` at repo root; context packets archived |

---

## Command defaults

### iOS

| Item | Canonical value | Notes |
|------|-----------------|-------|
| Scheme | `Fitness Coach` | |
| Test plan (fast) | `Fast-Core` | Serial: `-parallel-testing-enabled NO` when debugging XCTest restarts |
| Simulator | `platform=iOS Simulator,name=iPhone 17` | Update CI/scripts if still pinned to iPhone 16 |
| Warning capture script | `Scripts/capture_build_warnings.sh` | Default destination updated to iPhone 17 (2026-07-05) |

### Backend (`functions/`)

| Script | Purpose |
|--------|---------|
| `npm run build` | `tsc` compile |
| `npm run lint` | ESLint (`.js`, `.ts`) |
| `npm test` | Jest unit suite (excludes Firestore rules integration) |
| `npm run test:coach` | Coach prompt/context tests only (`test/coach`) |
| `npm run test:firestore-rules` | Rules integration — **requires emulator :8080** |
| `npm run test:all` | Full suite including emulator-dependent tests |

---

## Documentation layout

| Location | Purpose | Hygiene status |
|----------|---------|----------------|
| `PRD.md` (root) | Product requirements | Canonical root doc |
| `Docs/Architecture/` | System design, DI map, logging contracts | Active |
| `Docs/TechnicalDebt/` | Debt + build/hygiene registers | Active — this file |
| `Docs/Testing/` | Test command cheatsheet | Active |
| `Docs/Archive/ContextPackets/` | Historical context packets | Archived 2026-07-05 |
| `Docs/Archive/SprintReports/` | Sprint plans, `arch.md`, implementation maps | Archived |
| `Docs/Coach/archive/` | Pre-V2 coach context snapshot | Intentional archive |

**Rule:** New long-form context packets go to `Docs/Archive/ContextPackets/` unless explicitly promoted to a canonical `Docs/<Domain>/` guide.

---

## Xcode target membership

| Target | Inclusion model | Notes |
|--------|-----------------|-------|
| `Fitness Coach` | `PBXFileSystemSynchronizedRootGroup` on `Fitness Coach/` | SPM: Firebase*, GoogleSignIn, SwiftHorizontalRuler |
| `Fitness CoachTests` | Folder-sync on `Fitness CoachTests/` | **No** direct SPM products (BW-002); depends on app target |
| Resources | Folder-sync only | `GoogleService-Info.plist` must not be duplicated in explicit Resources phase (BW-106) |

### Files with special membership

| File | Target | Reason |
|------|--------|--------|
| `Fitness Coach/TestingSupport/StubTrainingIntegrationProvider.swift` | App | Previews + shared test doubles |
| `Fitness Coach/Application/StateBuilders/Nutrition/TodayAISummary.swift` | App | Replaces deleted `AIContext` |

---

## Backend hygiene

| Item | Status |
|------|--------|
| TypeScript strict compile | Pass |
| ESLint | 0 issues |
| Unit tests | 679 pass, 2 skipped (live benchmark) |
| Snapshots | 14 pass (`coachPromptSnapshots`) |
| `functions/lib/` | Generated — do not hand-edit |
| npm `devdir` warning | Host env config (BW-301) — not repo issue |

---

## TODO inventory

### In-source markers (Swift)

Production Swift uses `TD-*` comment IDs instead of `TODO`. Active markers:

| ID | File | Summary |
|----|------|---------|
| TD-LEGAL-001 | `FormaLegalCopy.swift` | Hosted Terms/Privacy URLs nil |
| TD-LEGAL-002 | `FormaLegalCopy.swift` | Legal links use in-app sheet |
| TD-SETTINGS-001 | `SettingsSupportConfiguration.swift` | Support email confirmation |
| TD-THEME-001 | `ThemeAccessibilityAdaptationPolicy.swift` | Increased-contrast palettes |
| TD-THEME-002 | `ThemeAccessibilityAdaptationPolicy.swift` | Reduce-transparency compositing |

`SettingsDeleteDataActionHandler.swift` references TD-SETTINGS-002 (export) — tracked in [TechnicalDebtRegister.md](./TechnicalDebtRegister.md).

### Documented gaps (no `TODO` in code)

| Area | Reference |
|------|-----------|
| Data export UI | TD-SETTINGS-002 — `SettingsExportDataActionHandler` |
| Weight log delete API | TD-DATA-001 |
| Coach chat persistence | `CoachInMemoryChatTranscriptStore` — SwiftData store planned |
| Analytics production sink | `Docs/Architecture/AnalyticsReadinessChecklist.md` |
| Weekly progress analytics adapter | `Docs/WeeklyProgress/ANALYTICS.md` |

Full register: [TechnicalDebtRegister.md](./TechnicalDebtRegister.md).

---

## Test infrastructure hygiene

| Item | Status | Notes |
|------|--------|-------|
| Canonical fixtures | `Fitness CoachTests/TestingSupport/` | `TestFixtureFactory`, `ProfileFixtures`, `FoodLogFixtures`, `DailyLogFixtures`, etc. |
| Legacy aliases | `ProfileTestFixtures` only | `CoachFoodFixtures` → `FoodLogFixtures` and `DailyNutritionSummaryTestFixtures` → `DailyLogFixtures` fully migrated (2026-07-05); ~31 test files still import `ProfileTestFixtures` for onboarding/profile-heavy suites |
| Async polling | `AsyncTestSupport` | Account deletion/sync tests migrated off `Task.sleep` |
| AI test stubs | `CoachContextPacketV2` | `AIContext` removed (TD-AI-001 closed) |

---

## Scripts and automation

| Script | Purpose | Default |
|--------|---------|---------|
| `Scripts/run_fast_core_tests.sh` | Resolve SPM → build-for-testing → serial Fast-Core | iPhone 17 simulator |
| `Scripts/capture_build_warnings.sh` | Log `xcodebuild` warnings (+ test build) | iPhone 17 simulator |

---

## Open hygiene items

| ID | Priority | Item | Unblock |
|----|----------|------|---------|
| PH-002 | P1 | Update CI / docs still referencing iPhone 16 | Grep `iPhone 16`; align to available simulators |
| PH-003 | P2 | Concurrency warning burn-down (BW-102) | Subsystem-by-subsystem Swift 6 isolation pass |
| PH-004 | P2 | Complete test fixture migration to `TestingSupport/` | **In progress** — `FoodLogFixtures` / `DailyLogFixtures` canonical; ~70 files migrated off `ProfileTestFixtures`; remaining: onboarding, profile bootstrap, auth-route suites |
| PH-005 | P3 | Close TD-COPY-001 | **Done 2026-07-05** — equivalence tests added |

---

## Closed hygiene items

| ID | Item | Resolution |
|----|------|------------|
| PH-001 | `Fitness CoachTests` SPM module resolution (BW-101) | **Closed 2026-07-05** — SPM products linked for compile-time module resolution; **Strip Duplicate SPM Frameworks** build phase on `Fitness CoachTests`; verify via `./Scripts/run-fast-core-serial.sh` or `./Scripts/run_fast_core_tests.sh`. Mac verify pending. |

---

## Revision history

| Date | Change |
|------|--------|
| 2026-07-05 | **PH-004 fixture migration (batch 1)** — `CoachFoodFixtures` / `DailyNutritionSummaryTestFixtures` fully migrated; ~70 test/support files now use `ProfileFixtures` |
| 2026-07-05 | **PH-001 closed** — Fast-Core SPM/host wiring (BW-101); added `run_fast_core_tests.sh` |
| 2026-07-05 | Initial register; 2026-07-05 build capture; BW-106–108 fixes; iPhone 17 simulator default |
| 2026-07-04 | Build warnings register created (predecessor doc) |
