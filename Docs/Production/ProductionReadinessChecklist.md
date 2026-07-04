# Production readiness checklist

Master gate before TestFlight, App Store submission, or a major backend deploy. Work through sections in order; each item links to deeper runbooks where they exist.

**Companion docs (use for execution detail):**

| Doc | Use when |
|-----|----------|
| [ReleaseTestPlan.md](./ReleaseTestPlan.md) | Manual QA on a release candidate build |
| [PrivacyReviewChecklist.md](./PrivacyReviewChecklist.md) | Privacy questionnaire, legal, and logging review |
| [AppStoreReadinessChecklist.md](./AppStoreReadinessChecklist.md) | Submission copy, permissions, and reviewer notes |

**Related engineering docs:** [Architecture.md](../Architecture.md) · [ReleaseAI.md](../ReleaseAI.md) · [BackendAPI.md](../BackendAPI.md) · [TESTING.md](../../Fitness%20CoachTests/TESTING.md)

---

## How to use

1. Pick a **release candidate** (RC) build number and git tag.
2. Assign an **owner** per section (Eng / QA / Release).
3. Mark each row **Pass / Fail / N/A** with evidence (CI link, screenshot, log snippet).
4. Block release on any **Fail** in sections 1–7 unless explicitly waived with a written risk acceptance.

---

## 1. App builds

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 1.1 | **Debug** builds on simulator | Eng | Xcode → scheme **Fitness Coach** → Run (iPhone simulator) | App launches to auth gate without crash |
| 1.2 | **Release** archive succeeds | Eng | Product → Archive (Release) or CI archive job | Archive completes; no signing/provisioning errors |
| 1.3 | **TestFlight** binary installs | Release | Upload archive → install on physical device | Cold launch succeeds; Coach gateway URL resolves (not localhost) |
| 1.4 | Gateway URL baked correctly | Eng | Inspect `Info.plist` / build setting `FORMA_AI_BACKEND_URL` | Points at production `aiGateway` base URL — see [ReleaseAI.md](../ReleaseAI.md) |
| 1.5 | No localhost AI fallback in Release | Eng | Release build → Coach prompt without network | Shows user-safe unavailable copy; no requests to `127.0.0.1` |

---

## 2. Tests pass

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 2.1 | iOS **Fast-Core** | Eng | `xcodebuild test -scheme "Fitness Coach" -destination 'platform=iOS Simulator,name=iPhone 17' -testPlan Fast-Core` | `TEST SUCCEEDED` |
| 2.2 | iOS **Integration** | Eng | Same with `-testPlan Integration` | `TEST SUCCEEDED` |
| 2.3 | iOS **Full** (pre-merge / RC) | Eng / CI | `xcodebuild test -scheme "Fitness Coach CI" -destination '…'` | `TEST SUCCEEDED` |
| 2.4 | Backend unit suite | Eng | `npm --prefix functions run build && npm --prefix functions run lint && npm --prefix functions test` | 0 lint warnings; all unit tests green |
| 2.5 | Test plan manifest current | Eng | After adding tests: `python3 Scripts/generate_test_plans.py` | Plans committed; new integration tests in `INTEGRATION_FILES` when needed |

See [TESTING.md](../../Fitness%20CoachTests/TESTING.md) for plan scope and single-class runs.

---

## 3. Backend builds, lints, and tests

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 3.1 | TypeScript compile | Eng | `npm --prefix functions run build` | Exit 0 |
| 3.2 | ESLint clean | Eng | `npm --prefix functions run lint` | 0 errors, 0 warnings |
| 3.3 | Contract tests | Eng | `npm --prefix functions test -- aiGateway.contract.test.ts` | All routes return expected shapes |
| 3.4 | Account deletion handler | Eng | `npm --prefix functions test -- accountDeletion.test.ts` | Remote delete + auth paths covered |
| 3.5 | Model / reasoning guards | Eng | `npm --prefix functions test -- openAIReasoningEffort.test.ts` | Unsupported effort rejected locally |
| 3.6 | Deploy smoke (optional RC) | Release | `FORMA_ID_TOKEN=… npm --prefix functions run smoke:auth` | HTTP 200 on classify + estimate — [ReleaseAI.md](../ReleaseAI.md) |

Route and env reference: [BackendAPI.md](../BackendAPI.md) § Firebase Functions.

---

## 4. Firestore rules tested

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 4.1 | Rules unit suite | Eng | `npm --prefix functions run test:firestore-rules` | Emulator suite passes (owner-only writes, cross-user deny) |
| 4.2 | Account deletion client rules | Eng | Included in `accountPersistenceFirestoreRules` tests | Cross-user delete denied |
| 4.3 | Nutrition sync contract | Eng | `nutritionSyncContract` tests in `test:all` | Contract assertions pass |

Requires Firestore emulator — see `functions/package.json` `test:firestore-rules`.

---

## 5. Account restore tested

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 5.1 | Automated restore tests | Eng | Integration plan: `ProfileBootstrap*`, `ProfileRestoreRouting`, `AccountRestore*` | Green in Integration / Full |
| 5.2 | **Manual fresh install** | QA | Sign in on clean simulator → observe restore UX | No false-empty Today/Journey during blocking restore |
| 5.3 | Flags aligned | Eng | `AccountPersistenceFeatureFlags.restoreOnLoginEnabled` **and** `FormaAbTest.AccountPersistence.restoreOnLoginEnabled` | Both `true` for production restore |
| 5.4 | Background backfill | QA | Enter main shell after restore → wait / relaunch | Older days appear without overwriting pending local edits |

Deep dive: [PHASE_4_FRESH_INSTALL_RESTORE.md](../AccountPersistence/PHASE_4_FRESH_INSTALL_RESTORE.md). Manual steps: [ReleaseTestPlan.md](./ReleaseTestPlan.md) § Restore / Reinstall.

---

## 6. Cross-device sync tested

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 6.1 | Automated cross-device tests | Eng | `CrossDeviceSync*`, `AccountSync*` in Integration / Full | Green |
| 6.2 | **Manual two-device** | QA | Device A logs food → Device B foreground / pull-to-refresh | Same UID sees new entry without reinstall |
| 6.3 | Realtime hint (if enabled) | QA | Enable `realtimeCrossDeviceSyncEnabled` on RC | Debounced refresh updates UI |
| 6.4 | Upload-before-pull | Eng | Code review + `CrossDeviceSyncCoordinator` tests | Pending local mutations not clobbered |

Deep dive: [PHASE_5_CROSS_DEVICE_REFRESH.md](../AccountPersistence/PHASE_5_CROSS_DEVICE_REFRESH.md).

---

## 7. Account deletion tested

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 7.1 | iOS deletion flow | QA | Settings → Privacy & Data → Delete account → type `DELETE` | Progress UI; signed out; Auth account removed for disposable test user |
| 7.2 | Local-only wipe | QA | Delete local device data | Cloud + Auth remain; local SwiftData cleared for UID |
| 7.3 | Backend endpoint | Eng | `accountDeletion.test.ts` + manual POST with token | Firestore user subtree removed; logs use uid hash only |
| 7.4 | Reauth path | QA | Trigger `requires-recent-login` if possible | Reauth sheet; retry succeeds |
| 7.5 | Settings visibility | QA | `FormaAbTest.Settings.dataDeletionEnabled` on RC | Delete rows visible — [AppStoreReadinessChecklist.md](./AppStoreReadinessChecklist.md) |

Deep dive: [PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md](../AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md).

---

## 8. Offline states tested

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 8.1 | Airplane mode — logging | QA | Log food/water/weight offline → go online | Local entries persist; sync catches up when online |
| 8.2 | Airplane mode — Coach | QA | Coach prompt offline | User-safe error; no crash |
| 8.3 | Gateway timeout | QA | Slow network / throttling | "Took too long" or unavailable copy — not raw stack trace |
| 8.4 | Offline Today / Journey | QA | Open tabs offline | Dashboards reach loaded or explicit empty state — no infinite spinner |

Manual steps: [ReleaseTestPlan.md](./ReleaseTestPlan.md) § Offline.

---

## 9. Analytics behavior documented

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 9.1 | Event inventory reviewed | Eng | Trace `*AnalyticsLogger` / `OSLog*Analytics*` implementations | No raw food text, workout titles, or HealthKit values in payloads |
| 9.2 | Production traces off | Eng | `FormaAbTest.Diagnostics.*` defaults on RC | OSLog analytics traces disabled unless internal build |
| 9.3 | HI pipeline analytics | Eng | `HealthIntelligencePipelineAnalytics` + [PHASE_20_RELEASE_READINESS.md](../HealthIntelligence/PHASE_20_RELEASE_READINESS.md) §15 | Bucketed events only |
| 9.4 | No-op loggers in tests | Eng | `FakeAnalyticsLogger` / `NoOp*AnalyticsLogger` in unit tests | Tests do not require network analytics |

---

## 10. Logging privacy reviewed

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 10.1 | Coach / gateway logs | Eng | Sample Firebase `aiGateway` logs | `traceId` + uid present; no full request bodies with PII |
| 10.2 | Account deletion logs | Eng | Backend deletion logs | Counts + privacy-safe uid hash only |
| 10.3 | Account sync / restore logs | Eng | `AccountSyncLogger`, `AccountRestoreLogger` gated by diagnostics flags | Verbose traces off in Release |
| 10.4 | Health Intelligence logs | Eng | `HealthSyncLogger`, engine loggers | No raw HK samples in log fields |
| 10.5 | Client OSLog categories | Eng | Grep `Logger(subsystem:` in `Infrastructure/Diagnostics/` | Subsystem `Forma` / `FitPilot`; no secrets |

Cross-reference: [PrivacyReviewChecklist.md](./PrivacyReviewChecklist.md) § Logs.

---

## 11. Feature flags reviewed

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 11.1 | `FormaAbTest` shipping snapshot | Eng | Review `Fitness Coach/Configuration/FormaAbTest.swift` + RC binary behavior | Production defaults match intent (no debug-only surfaces) |
| 11.2 | Health Intelligence flags | Eng | `HealthIntelligenceFeatureFlags.swift` env table | UI / remote sync / weekly review match ship plan — [PHASE_20_RELEASE_READINESS.md](../HealthIntelligence/PHASE_20_RELEASE_READINESS.md) |
| 11.3 | Account persistence flags | Eng | `AccountPersistenceFeatureFlags.swift` | Sync + restore + cross-device match rollout stage |
| 11.4 | Settings gates | Eng | `dataDeletionEnabled`, `dataExportEnabled`, `developerSectionVisible` | Deletion on; export/developer off unless internal build |
| 11.5 | Build configuration | Eng | `FormaBuildConfiguration` / `FormaAbTest.Build` | `internalBuildEnabled` false for App Store archive |

---

## 12. Migrations reviewed

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 12.1 | SwiftData schema version | Eng | Review `FormaSchema*` migration plan + migration tests | Upgrade from previous App Store version succeeds |
| 12.2 | Fresh install | QA | Install RC on clean device | Onboarding + empty state correct |
| 12.3 | Upgrade install | QA | Install RC over previous TestFlight build | Data retained; no crash on first launch |
| 12.4 | Cloud schema compatibility | Eng | `AccountPersistence` DTO mappers | Older Firestore documents still decode |

---

## 13. App Store build config reviewed

| # | Check | Owner | Command / action | Pass criteria |
|---|-------|-------|------------------|---------------|
| 13.1 | Version / build numbers | Release | Xcode → General | Monotonic build; marketing version set |
| 13.2 | Signing & capabilities | Release | Target → Signing & Capabilities | HealthKit, Sign in with Apple, Google URL schemes valid |
| 13.3 | Entitlements match features | Eng | Compare entitlements to shipped flags | No unused sensitive entitlements |
| 13.4 | AI backend URL (Release) | Eng | Archive `Info.plist` | Production gateway only |
| 13.5 | App Store checklist complete | Release | [AppStoreReadinessChecklist.md](./AppStoreReadinessChecklist.md) | All items pass |

---

## Sign-off

| Role | Name | Date | RC build | Notes |
|------|------|------|----------|-------|
| Engineering | | | | |
| QA | | | | |
| Release | | | | |
