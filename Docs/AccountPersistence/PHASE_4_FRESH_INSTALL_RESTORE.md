# Account Persistence — Phase 4: Fresh Install Restore & Account Bootstrap UX

Production documentation for **blocking account restore after sign-in** and **restore-aware main-shell entry** in Forma (Fitness Coach).

**Status:** Phase 4 **implemented (code + tests)** — rollout gated by `restoreOnLoginEnabled = false` until CI/manual QA passes.  
**Depends on:** [Phase 2 — Cloud Schema and Rules](./PHASE_2_CLOUD_SCHEMA_AND_RULES.md), [Phase 3 — Local-First Sync Engine](./PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md)  
**Related PRs:** [#113](https://github.com/isaacchua0309/FitnessCoach/pull/113) (background backfill), [#115](https://github.com/isaacchua0309/FitnessCoach/pull/115) (observability), [#116](https://github.com/isaacchua0309/FitnessCoach/pull/116) (restore tests), [#117](https://github.com/isaacchua0309/FitnessCoach/pull/117) (UI/routing/E2E tests)

---

## Critical distinction: Phase 4 restore ≠ Phase 5 realtime sync

| Statement | True in Phase 4? |
|-----------|------------------|
| Phase 4 restores account-backed logs from **Firestore** after sign-in | **Yes** |
| Phase 4 prevents false-empty **Today** / **Journey** screens during restore | **Yes** |
| Blocking restore pulls profile + bounded nutrition history into SwiftData | **Yes** |
| Background backfill extends history after user enters main shell | **Yes** |
| Pending local edits are **not** overwritten by older remote rows | **Yes** |
| Phase 4 implements **realtime cross-device listeners** | **No** (Phase 5) |
| Phase 4 restores **raw meal image bytes** | **No** — optional `imageUrl` strings only |
| Phase 4 restores **raw HealthKit samples** | **No** |
| Phase 4 implements **account deletion** | **No** (Phase 6) |
| Phase 5 will implement **cross-device refresh / realtime sync** | **Yes** — planned |

Default feature flags (`AccountPersistenceFeatureFlags`):

```swift
static let restoreOnLoginEnabled = false          // Phase 4 — off until QA
static let realtimeCrossDeviceSyncEnabled = false // Phase 5
static let pullRecentDataEnabled = false          // Phase 5 (foreground pull)
```

Both `AccountPersistenceFeatureFlags.restoreOnLoginEnabled` **and** `FormaAbTest.AccountPersistence.restoreOnLoginEnabled` must be true for production restore UX.

---

## 1. Scope of Phase 4

**Goal:** When a returning member signs in on a **fresh install** or **new device**, restore their **account-backed nutrition history** from Firestore into SwiftData before (or while) they use Today, Journey, and Plan — without showing misleading empty states.

Phase 4 answers: *“I deleted the app / got a new phone — why is my food log gone?”*

Phase 4 does **not** answer: *“Why didn’t my other phone update instantly when I logged lunch?”* That is Phase 5.

### In scope

| Area | Delivered |
|------|-----------|
| `AccountRestoreCoordinator` — single entry after sign-in | Yes |
| `AccountInitialRestoreService` — blocking + background backfill | Yes |
| Local / remote inspectors — restore decision inputs | Yes |
| `AccountRestoreStateStore` — per-UID restore metadata | Yes |
| Blocking restore UI (`AccountRestoreView`) | Yes |
| Auth gate routing — restore before main shell | Yes |
| `AccountRestoreSessionState` — tab restore awareness | Yes |
| `AppRefreshCenter.notifyAccountRestoreDidComplete()` | Yes |
| Privacy-safe restore diagnostics (DEBUG) | Yes |
| Unit, integration, UI/model, and E2E tests | Yes |

### Out of scope (deferred)

| Area | Phase |
|------|-------|
| Realtime Firestore listeners | 5 |
| Foreground pull enabled by default | 5 |
| Cross-device “device B sees device A instantly” | 5 |
| Coach chat / timeline cloud restore | 5b (opt-in) |
| Raw meal image download | Never (by policy) |
| Raw HealthKit re-import via restore | Never (by policy) |
| Account deletion orchestration | 6 |
| End-user Settings “Sync status” (non-DEBUG) | 5 |

---

## 2. What problem Phase 4 solves

| User pain | Phase 4 fix |
|-----------|-------------|
| Reinstall → empty Today / Journey despite years of cloud logs | Blocking restore pulls recent window; background backfill extends history |
| New device → “no progress” Journey before data arrives | Tabs stay in **loading** during blocking restore; refresh after completion |
| Offline sign-in on fresh install → scary failure or blank app | **Offline** terminal state with safe copy; user can continue when appropriate |
| Partial cloud failure → user stuck on spinner forever | **Partial** outcome + timeout policy; user can enter main shell |
| Account switch → previous user’s restore bleeds in | UID guards on coordinator, namespace quarantine, session reset |
| Local pending edit lost when cloud catches up | Phase 3 merge policy preserved during restore pulls |

---

## 3. Restore decision tree

High-level orchestration lives in `AccountRestoreCoordinator.prepareAccount(...)`.

```
Sign-in resolved (existing user with cloud/local profile path)
        │
        ▼
restoreOnLoginEnabled? ──no──► skip blocking restore → main shell
        │
       yes
        │
        ▼
AccountDataNamespaceService.prepareForSignedInUID(uid)
        │ (quarantine foreign ownerUID rows)
        ▼
AccountMigrationService.runSafeBackfill(uid)
        │
        ▼
AccountLocalDataInspector.inspectLocalData(uid)
AccountRemoteDataInspector.inspectRemoteData(uid, today)
        │
        ├─ permissionDenied / unauthenticated (fail-fast) ──► failed terminal UI
        │
        ▼
shouldRunBlockingRestore?
  • stateStore.shouldRunBlockingRestore (not recently completed)
  • local needsInitialRestore AND (remote has data OR empty cloud)
  • OR forceBlocking (manual retry)
        │
        ├─ no ──► mark skipped → upload pending if enabled → main
        │
       yes
        │
        ▼
AccountInitialRestoreService.runBlockingInitialRestore
  (timeout: AccountRestorePolicy.maximumBlockingRestoreTimeoutSeconds)
        │
        ├─ completed / skipped ──► schedule background backfill → main
        ├─ partial ──► schedule background backfill → partial UI → main on continue
        ├─ offline ──► schedule background backfill → offline UI → main on continue
        └─ failed ──► failed UI (retry / sign out)
```

**Skip blocking** when local store is already populated for this UID and restore metadata says blocking already succeeded (see `AccountRestoreStateStore.shouldRunBlockingRestore`).

---

## 4. Fresh install restore flow

Typical path: **app deleted → reinstall → Google sign-in → same account**.

```
AuthManager.signInWithGoogle
        │
        ▼
ProfileBootstrapCoordinatorService.resolveExistingUserSignIn
        │
        ▼
AuthGateCoordinator.routeToMainWithAccountRestore(uid, .afterSignIn)
        │
        ├─ RootModel.state = .restoringAccount
        ├─ AppShellRoute = .signedInProfileLoading
        ├─ AccountRestoreSessionState.beginBlockingRestore()
        └─ AccountRestoreViewModel.start(uid, .afterSignIn)
                │
                ▼
        AppContainer.runAccountRestoreAfterSignIn
                │
                ▼
        AccountRestoreCoordinator.prepareAccountAfterSignIn
                │
                ▼
        AccountInitialRestoreService.runBlockingInitialRestore
                │
                ├─ ProfileBootstrapService.resolve → restore UserProfile from Firestore
                ├─ AccountSyncPuller.pullRecentAccountData (30d logs + children)
                └─ weight pull (180d) when in blocking mode
                │
                ▼
Terminal outcome → AccountRestoreView (progress / partial / offline / failed)
                │
                ▼
User continues (or auto-continue on completed) → AuthGateCoordinator.completeRouteToMain
                │
                ├─ accountRestoreSessionState.recordRestoreCompletion(summary)
                ├─ AppRefreshCenter.notifyAccountRestoreDidComplete()
                └─ RootModel.didCompleteOnboarding() → .main
```

**Local store starts empty.** Cloud data is read via `AccountDataRemoteStore` (Firestore in production, `InMemoryAccountDataRemoteStore` in tests).

---

## 5. New device login restore flow

Same pipeline as fresh install; reason may be `.newDevice` or `.afterSignIn` depending on entry point. Differences are **product/analytics** only — restore logic is identical:

1. Namespace prepare for signed-in UID  
2. Blocking pull of profile + recent nutrition window  
3. Main shell entry with restore-aware tabs  
4. Background backfill for extended history (365d logs, 730d weight)

E2E coverage: `AccountRestoreEndToEndTests.testNewDeviceLoginRestoresToday`.

---

## 6. Existing local data restore flow

When the user **already has local nutrition rows** for the signed-in UID (same device, no reinstall):

| Local state | Blocking restore |
|-------------|------------------|
| Populated logs + `stateStore` shows recent **completed** blocking restore | **Skipped** — `AccountInitialRestoreServiceSupport.skippedLocalDataMessage` |
| Empty / `needsInitialRestore` but cloud has data | **Runs** |
| Pending local mutations, effectively empty | **Runs** if policy says empty enough |
| Pending local mutations, non-empty | **Skipped** unless manual retry |

Same-device logout → login **does not** wipe SwiftData (Phase 1 policy). Restore is usually skipped; Phase 3 upload/pull handles incremental sync when enabled.

**Manual retry:** `AccountRestoreCoordinator.retryRestore` → `forceBlocking: true` → re-runs blocking pull (respects newer-local merge rules).

---

## 7. Offline behavior

| Scenario | Outcome |
|----------|---------|
| Remote inspection fails **offline** / **unavailable**, no restorable data, empty local | `AccountRestoreStatus.offline`, safe user message |
| Network unavailable before pull, profile not yet local | `offline` — user may continue if `allowsContinuedEntry` |
| Network unavailable, local profile already exists | `offline` — user continues with local profile |
| Permission denied | `failed` — fail-fast, no foreign UID writes |

User-facing offline copy: `FormaProductCopy.AccountRestore.Offline.*` and `AccountInitialRestoreServiceSupport.offlineRestoreMessage`.

Tabs: if restore completes **offline** and local data is still **effectively empty**, Today/Journey show **pending restore** messaging (`AccountRestoreSessionState.shouldShowPendingRestoreUI`) instead of a false empty state.

---

## 8. Partial restore behavior

Partial restore occurs when:

- Some collection pulls fail (e.g. weight fetch) but others succeed  
- Blocking restore **times out** but local data was partially written (`AccountRestoreOutcomeSupport.timedOutSummary`)

| Property | Behavior |
|----------|----------|
| `summary.status` | `.partial` |
| `summary.isPartial` | `true` |
| `allowsContinuedEntry` | `true` — user can enter main shell |
| Background backfill | Scheduled for partial/offline when policy allows |
| Tab UI | Pending-restore message if still empty locally; otherwise loaded with restored slice |

User-facing copy: `FormaProductCopy.AccountRestore.Partial.*`.

---

## 9. Retry behavior

| Entry | Mechanism |
|-------|-----------|
| Restore UI secondary action (offline / failed-with-continue) | `AccountRestoreViewModel.retry()` → `AccountRestoreCoordinator.retryRestore` |
| Settings DEBUG diagnostics | `AccountRestoreDiagnostics` manual retry (DEBUG only) |
| Coordinator | `stateStore.prepareForManualRetry` then `prepareAccount(..., forceBlocking: true)` |

Retry re-runs blocking restore with **manual retry** mode. Concurrent restore attempts return **skipped** with `concurrentRestoreMessage`.

UID switch during retry cancels meaningful application of results (`accountSwitchedMessage`).

---

## 10. Background backfill behavior

After blocking restore allows continued entry (`allowsContinuedEntry`), coordinator schedules:

```
AccountRestoreCoordinator.scheduleBackgroundBackfill
        │
        ▼
AccountInitialRestoreService.runBackgroundBackfill
        │
        ├─ Wider daily log window: AccountRestorePolicy.backgroundDailyLogLookbackDays (365)
        ├─ Wider weight window: AccountRestorePolicy.backgroundWeightLookfillDays (730)
        └─ No blocking UI
        │
        ▼
onBackgroundBackfillFinished → AppRefreshCenter.notifyBackgroundBackfillDidComplete()
        │
        └─ TodayModel / JourneyModel listen via refreshToken
```

Backfill is **UID-safe**: tasks cancel on account switch; completion ignored if UID no longer current.

`AccountRestoreStateStore` records `lastSuccessfulBackgroundBackfillAt` only on **completed** backfill (not partial).

---

## 11. Today / Journey / Plan restore awareness

### Session state

`AccountRestoreSessionState`:

- `isBlockingRestoreActive` — set during auth gate blocking restore  
- `lastCompletedSummary` — terminal outcome for pending UI  
- `completionToken` / `accountRestoreDidComplete` notification

### Today & Journey

`TodayModel` / `JourneyModel`:

- While `isBlockingRestoreActive` → `viewState = .loading` (no false empty)  
- After restore, models reload via `AppRefreshCenter.refreshToken`  
- If terminal status is `.offline` or `.partial` **and** local inspector says effectively empty → `.pendingAccountRestore(message)`

Tests: `TodayRestoreAwarenessTests`, `JourneyRestoreAwarenessTests`, `RestoreAwareTabModelTests`.

### Plan

Plan does not use restore session loading gates the same way; it loads from `UserProfileService` after bootstrap.  
`ProfileBootstrapService.resolve` runs inside restore for profile adoption.  
Tests: `PlanRestoreAwarenessTests` (bootstrap + onboarding route guard).

---

## 12. What is intentionally not restored

Enforced by `AccountRestorePolicy` and pull payload contracts:

| Data | Phase 4 behavior |
|------|------------------|
| Raw meal image bytes | **Never downloaded** — `includesRawMealImages = false` |
| Raw HealthKit workouts / steps / sleep | **Never** — `includesRawHealthKitData = false` |
| Coach chat transcripts | **Not restored** — `includesCoachCloudData = false` |
| Coach timeline events | **Not restored** |
| Data belonging to another Firebase UID | **Quarantined / not pulled** |
| Entire account history in blocking phase | **No** — bounded windows only; rest via background backfill |
| Firestore documents outside nutrition schema | **No** |

Optional `imageUrl` **strings** on food entries may restore if present in Phase 2 DTOs (not binary image payloads).

---

## 13. Privacy / logging guarantees

### `AccountRestoreLogger` (OSLog)

- Logs **hashed UID** (`AccountSyncLogger.hashedUID`), never full Firebase UID in production paths  
- Logs aggregate counts: logs restored, food/water/weight/review counts, skipped/conflict/failed counts  
- Logs lifecycle: `runStarted`, `runCompleted`, timeout/offline/partial warnings  
- **Never logs:** food names, macros, weights, review text, profile names, raw Firestore payloads  

### `AccountRestoreDiagnosticsSnapshot` (DEBUG)

- In-memory last run snapshot for Settings debug UI  
- `safeFieldDictionary` allowlist only  
- Manual retry / reset helpers behind DEBUG  

### State store

`AccountRestoreStateStore` persists status and timestamps per UID — **not** sensitive document payloads or user-facing error strings beyond sanitized failure metadata.

---

## 14. Test coverage

Phase 4 tests use **`InMemoryAccountDataRemoteStore`**, in-memory SwiftData, and injected UID providers — **no production Firebase network required**.

Verify before enabling `restoreOnLoginEnabled`:

```bash
xcodebuild test -scheme "Fitness Coach CI" \
  -only-testing:"Fitness CoachTests/AccountRestoreCoordinatorTests" \
  -only-testing:"Fitness CoachTests/AccountInitialRestoreServiceTests" \
  -only-testing:"Fitness CoachTests/AccountRestoreStateStoreTests" \
  -only-testing:"Fitness CoachTests/AccountLocalDataInspectorTests" \
  -only-testing:"Fitness CoachTests/AccountRemoteDataInspectorTests" \
  -only-testing:"Fitness CoachTests/AccountRestoreOutcomeSupportTests" \
  -only-testing:"Fitness CoachTests/AccountRestorePolicyTests" \
  -only-testing:"Fitness CoachTests/AccountRestoreSessionStateTests" \
  -only-testing:"Fitness CoachTests/AccountRestoreLoggerTests" \
  -only-testing:"Fitness CoachTests/AccountBackgroundBackfillCoordinatorTests" \
  -only-testing:"Fitness CoachTests/AccountRestoreViewModelTests" \
  -only-testing:"Fitness CoachTests/AuthRestoreRoutingTests" \
  -only-testing:"Fitness CoachTests/TodayRestoreAwarenessTests" \
  -only-testing:"Fitness CoachTests/JourneyRestoreAwarenessTests" \
  -only-testing:"Fitness CoachTests/PlanRestoreAwarenessTests" \
  -only-testing:"Fitness CoachTests/AccountRestoreEndToEndTests"
```

### Layer summary

| Layer | Test files |
|-------|------------|
| Policy & models | `AccountRestorePolicyTests`, `AccountRestoreOutcomeSupportTests` |
| State store | `AccountRestoreStateStoreTests`, `AccountRestoreSessionStateTests` |
| Inspectors | `AccountLocalDataInspectorTests`, `AccountRemoteDataInspectorTests` |
| Initial restore service | `AccountInitialRestoreServiceTests` |
| Coordinator | `AccountRestoreCoordinatorTests`, `AccountBackgroundBackfillCoordinatorTests` |
| Observability | `AccountRestoreLoggerTests` |
| UI / view model | `AccountRestoreViewModelTests` |
| Auth routing | `AuthRestoreRoutingTests` |
| Tab awareness | `TodayRestoreAwarenessTests`, `JourneyRestoreAwarenessTests`, `PlanRestoreAwarenessTests`, `RestoreAwareTabModelTests` |
| End-to-end simulations | `AccountRestoreEndToEndTests` (reinstall, new device, UID isolation, pending edit, offline, partial → main) |

Phase 3 pull/merge tests (`AccountSyncPullerTests`, `AccountSyncMergePolicyTests`) underpin restore merge behavior.

---

## 15. Remaining work for Phase 5

Phase 5 builds on Phase 4 — **does not replace** the restore coordinator.

| Item | Notes |
|------|-------|
| Enable `pullRecentDataEnabled` by default | Foreground / lifecycle incremental pull |
| `realtimeCrossDeviceSyncEnabled` | Firestore snapshot listeners for nutrition collections |
| Cross-device freshness SLA | Device A logs → Device B sees update without reinstall restore |
| Conflict UI (rare) | Toast when remote supersedes local |
| Optional coach chat / timeline sync | Separate namespace; opt-in |
| Settings production “Sync status” | User-visible sync health |
| `syncMetadata` cursor orchestration | Drive incremental pull after restore baseline |
| Firestore emulator in iOS CI | Optional hardening beyond in-memory store |

### Phase 6 preview

- Account deletion (`SettingsDeleteDataActionHandler`)  
- Export, privacy copy, GDPR orchestration  

---

## Architecture map

```
Fitness Coach/Application/Restore/
├── AccountRestoreCoordinator.swift       # sign-in entry, timeout, backfill schedule
├── AccountInitialRestoreService.swift    # blocking + background pull orchestration
├── AccountRestoreStateStore.swift        # per-UID restore metadata
├── AccountRestoreSessionState.swift      # main-shell tab awareness
├── AccountRestorePolicy.swift            # lookback windows, exclusions
├── AccountRestoreOutcomeSupport.swift    # partial/offline/timeout summaries
├── AccountRestoreModels.swift            # AccountRestoreSummary, statuses
├── AccountLocalDataInspector.swift
├── AccountRemoteDataInspector.swift
└── AccountRestoreDiagnostics.swift       # DEBUG run history

Fitness Coach/Features/Auth/
├── Model/AccountRestoreViewModel.swift
├── Views/AccountRestoreView.swift
└── Coordinator/AuthGateCoordinator.swift # routeToMainWithAccountRestore

Fitness Coach/Infrastructure/Diagnostics/
└── AccountRestoreLogger.swift

Fitness Coach/Application/Sync/
├── AccountSyncPuller.swift               # merge during restore
└── AccountDataNamespaceService.swift     # UID switch quarantine
```

---

## Rollout checklist

1. Run Phase 4 test suite on macOS CI (`xcodebuild test`).  
2. Manual QA: delete app → reinstall → sign in → Today/Journey show restored data on Wi‑Fi.  
3. Manual QA: airplane mode fresh install → offline restore copy → retry when online.  
4. Set `AccountPersistenceFeatureFlags.restoreOnLoginEnabled = true` (and AB test flag).  
5. Monitor `AccountRestoreLogger` aggregates in Console — confirm no payload leakage.  
6. **Do not** enable `realtimeCrossDeviceSyncEnabled` until Phase 5 ships.

---

*End of Phase 4 documentation.*
