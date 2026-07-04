# Account Persistence — Phase 5: Cross-Device Refresh & Near-Realtime Sync

Production documentation for **incremental cross-device sync** — foreground refresh, manual refresh, and Firestore realtime **change hints** — in Forma (Fitness Coach).

**Status:** Phase 5 **implemented (code + tests)** — verify with `xcodebuild test` on macOS before production rollout.  
**Depends on:** [Phase 2 — Cloud Schema and Rules](./PHASE_2_CLOUD_SCHEMA_AND_RULES.md), [Phase 3 — Local-First Sync Engine](./PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md), [Phase 4 — Fresh Install Restore](./PHASE_4_FRESH_INSTALL_RESTORE.md)  
**Related PRs:** [#122](https://github.com/isaacchua0309/FitnessCoach/pull/122) (incremental pull + cursor tests), [#123](https://github.com/isaacchua0309/FitnessCoach/pull/123) (coordinator + lifecycle tests), [#124](https://github.com/isaacchua0309/FitnessCoach/pull/124) (Today/Journey/Plan refresh tests), [#125](https://github.com/isaacchua0309/FitnessCoach/pull/125) (end-to-end cross-device simulations)

---

## Critical distinction: Phase 4 restore ≠ Phase 5 refresh

| Statement | Phase 4 restore | Phase 5 refresh |
|-----------|-----------------|-----------------|
| Runs after **fresh install / new device sign-in** | **Yes** | No (restore handles bootstrap) |
| Makes **same-account changes visible across devices** after refresh or realtime hint | No | **Yes** |
| Uses **bounded blocking pull** + background backfill | **Yes** | No |
| Uses **per-domain incremental cursors** (`updatedAt` since last pull) | No | **Yes** |
| **Upload-before-pull** on every refresh run | Partial (Phase 3 upload) | **Yes** — enforced by `CrossDeviceSyncCoordinator` |
| **Firestore snapshot listeners** (change hints) | No | **Yes** — optional, flag-gated |
| **Push notifications** required | No | **No** |
| Syncs **raw meal image bytes** | No | **No** |
| Syncs **raw HealthKit samples** | No | **No** |
| **Full account deletion** | No | **No** (Phase 6) |

**Phase 5 makes same-account changes visible across devices after refresh or realtime hint.**  
Device A logs lunch → Device B sees the entry after foreground refresh, manual pull-to-refresh, or a debounced realtime hint — without reinstalling or re-running blocking restore.

Default feature flags (`AccountPersistenceFeatureFlags`):

```swift
static let syncEngineEnabled = true
static let foregroundCrossDeviceRefreshEnabled = true   // Phase 5
static let realtimeCrossDeviceSyncEnabled = true      // Phase 5
static let manualRefreshEnabled = true                  // Phase 5
static let pullRecentDataEnabled = false              // Phase 3 bounded pull — superseded by incremental puller
static let restoreOnLoginEnabled = true               // Phase 4
```

Both `AccountPersistenceFeatureFlags.*` **and** `FormaAbTest.AccountPersistence.*` must be true for production cross-device behavior.

---

## 1. Scope of Phase 5

**Goal:** Keep signed-in devices **eventually consistent** for the **same Firebase UID** — nutrition logs, weight, daily reviews, and profile/plan targets — without requiring reinstall restore or push notifications.

Phase 5 answers: *“I logged food on my phone — why doesn’t my iPad show it?”*

Phase 5 does **not** answer: *“Delete my account and all my data everywhere.”* That is Phase 6.

### In scope

| Area | Delivered |
|------|-----------|
| `CrossDeviceSyncCoordinator` — upload-then-pull orchestration | Yes |
| `AccountIncrementalPuller` — cursor-driven incremental fetch + merge | Yes |
| `AccountSyncCursorStore` — per-UID, per-domain pull cursors | Yes |
| `CrossDeviceSyncPolicy` — lookback windows, throttles, exclusions | Yes |
| `AccountRealtimeChangeListener` + `FirestoreAccountRealtimeChangeListener` | Yes |
| `CrossDeviceSyncLifecycle` — foreground, manual, listener start/stop | Yes |
| `AccountDataRefreshEventBus` — domain-scoped UI refresh events | Yes |
| Today / Journey / Plan cross-device refresh policies | Yes |
| `CrossDeviceSyncLogger` — privacy-safe diagnostics | Yes |
| Unit, integration, feature, lifecycle, and E2E tests | Yes |

### Out of scope (deferred)

| Area | Phase |
|------|-------|
| Full **account deletion** orchestration | 6 |
| Privacy controls, **local wipe**, user-facing data management UI | 6 |
| **Raw meal image** upload/download | Never (by policy) |
| **Raw HealthKit** sample sync | Never (by policy) |
| **Push notifications** for sync | Not required |
| Coach chat / timeline cloud sync | 5b (opt-in) |
| Production Settings “Sync status” screen | 5b / polish |
| Conflict toast UI (rare) | Optional polish |

---

## 2. What problem Phase 5 solves

| User pain | Phase 5 fix |
|-----------|-------------|
| Logged meal on phone; iPad still empty | Foreground refresh or realtime hint pulls incremental changes |
| Edited food on one device; other shows stale row | Incremental pull merges newer remote `updatedAt` |
| Deleted food on one device; other still shows it | Remote tombstone (`deletedAt`) propagates when safe |
| Updated calorie target on phone; Today on iPad wrong | Profile incremental pull + domain refresh events |
| Pending local edit overwritten by older cloud row | Phase 3 merge policy preserved — skip/conflict, never blind overwrite |
| Account switch leaks previous user’s refresh | UID guards, listener stop, cursor isolation, cancelled in-flight runs |
| Offline device loses data on failed refresh | Offline summary — local SwiftData unchanged |

---

## 3. Difference between Phase 4 restore and Phase 5 refresh

| Dimension | Phase 4 restore | Phase 5 refresh |
|-----------|-----------------|-----------------|
| **Trigger** | Sign-in, fresh install, manual restore retry | App foreground, pull-to-refresh, realtime hint |
| **User UX** | Blocking `AccountRestoreView` when enabled | Silent / background; tabs reload via event bus |
| **Pull strategy** | Bounded full window (`AccountSyncPuller.pullRecentAccountData`) | Incremental `fetch*UpdatedSince(cursor)` per domain |
| **Cursors** | Restore metadata in `AccountRestoreStateStore` | `AccountSyncCursorStore` per domain |
| **Lookback** | 30d blocking, 365d/730d background backfill | 14d foreground, 90d manual, 7d realtime |
| **Listeners** | None | Firestore snapshot hints (optional) |
| **When local store empty** | Restore is primary path | Restore still required first; refresh maintains consistency after |
| **Purpose** | Bootstrap empty local store from cloud | Keep populated store fresh across devices |

Phase 5 **builds on** Phase 4 — it does not replace `AccountRestoreCoordinator`. A new device still needs Phase 4 (or equivalent history) before incremental refresh has a meaningful baseline.

---

## 4. Foreground refresh flow

Triggered from `MainTabView` → `AppContainer.handleAccountDataSyncOnAppForeground()` → `CrossDeviceSyncLifecycle.handleAppForeground`.

```
App willEnterForeground / scene active
        │
        ▼
CrossDeviceSyncLifecycle.isForegroundRefreshEnabled?
        │ (syncEngine + foregroundCrossDeviceRefresh flags)
        ├─ no ──► skip
        │
       yes
        │
        ▼
CrossDeviceSyncCoordinator.foregroundRefreshIfNeeded(uid)
        │
        ├─ UID missing / account switched ──► skip
        ├─ lastForegroundRefreshAt < 30s ago ──► throttle skip
        │
       yes (needs refresh)
        │
        ▼
Task { refreshNow(mode: .foregroundRefresh, reason: .appForeground) }
        │  (non-blocking — does not await on foreground path)
        ▼
CrossDeviceSyncCoordinator.refreshNow
        │
        ├─ network offline ──► .offline summary, local data preserved
        ├─ concurrent run for same UID ──► .cancelled
        │
        ▼
uploadPendingOnly (upload-before-pull)
        │
        ▼
AccountIncrementalPuller.pullChanges (14d lookback for food/water)
        │
        ├─ merge via AccountSyncMergePolicy
        ├─ advance per-domain cursors on success only
        └─ update lastForegroundRefreshAt
        │
        ▼
didRefreshUI? → AppRefreshCenter.notifyCrossDeviceSyncDidComplete()
              → AccountDataRefreshEventBus.publish(domains)
        │
        ▼
TodayModel / JourneyModel / PlanModel reload from SwiftData
```

**Throttle:** `CrossDeviceSyncPolicy.foregroundRefreshThrottleSeconds` = 30s per UID (`cursor.lastForegroundRefreshAt`).

**Timeout budget:** `maximumForegroundRefreshSeconds` = 12s.

---

## 5. Manual refresh flow

Entry: `AppContainer.performManualCrossDeviceRefresh()` → `CrossDeviceSyncLifecycle.handleManualRefresh`.

```
User pull-to-refresh (Today / Journey when wired)
        │
        ▼
CrossDeviceSyncLifecycle.isManualRefreshEnabled?
        ├─ no ──► nil
        │
       yes
        │
        ▼
CrossDeviceSyncCoordinator.manualRefresh(uid)
        │  (awaits completion — user-initiated)
        ▼
refreshNow(mode: .manualRefresh, reason: .manualPullToRefresh)
        │
        ├─ bypasses foreground throttle
        ├─ upload-before-pull
        ├─ incremental pull with 90d lookback (food/water date window)
        └─ updates lastManualRefreshAt
        │
        ▼
Returns CrossDeviceSyncSummary to caller
        │
        ▼
Tab models reload via refresh event bus (same as foreground)
```

Manual refresh pulls a **wider date window** than foreground (90 vs 14 days) but still uses incremental cursors — not a full account re-download.

---

## 6. Realtime listener hint flow

Listeners **do not merge documents**. They emit a lightweight UID hint; merge happens only in `CrossDeviceSyncCoordinator`.

```
Sign-in session ready (AuthGateCoordinator)
        │
        ▼
CrossDeviceSyncLifecycle.startRealtimeListenerIfEnabled
        │
        ▼
FirestoreAccountRealtimeChangeListener.startListening(uid)
        │
        ├─ dailyLogs collection snapshot
        ├─ weightEntries collection snapshot
        ├─ dailyReviews collection snapshot
        └─ profile/current document snapshot
        │
        ▼
Snapshot callback (any change)
        │
        ▼
AccountRealtimeChangeHintDebouncer (500ms)
        │
        ▼
onRemoteChangeHint(uid)
        │
        ▼
CrossDeviceSyncCoordinator.handleRealtimeHint(uid)
        │
        ├─ debounce again (500ms) at coordinator layer
        ├─ cancel prior pending realtime task on rapid events
        │
        ▼
refreshNow(mode: .realtimeListener, reason: .realtimeSnapshot)
        │
        ├─ upload-before-pull
        ├─ incremental pull (7d lookback for food/water)
        └─ tab refresh via event bus
```

**Option A design:** No per-food or per-water subcollection listeners. A `dailyLogs` collection change hints that recent food/water child documents may have changed; incremental pull fetches them by `updatedAt` cursor + date window.

**Phase 5 does not require push notifications.** Near-realtime behavior is achieved via Firestore listeners while the app is active (and catch-up on next foreground).

**Logout / account switch:** `stopCrossDeviceSyncSession` → `listener.stopAll()` + `cancelPendingWork()`.

---

## 7. Upload-before-pull policy

`CrossDeviceSyncPolicy.uploadsLocalChangesBeforePull = true` for all refresh modes.

Every `CrossDeviceSyncCoordinator.refreshNow` run:

1. **Upload** — `AccountSyncCoordinator.uploadPendingOnly(for:reason:)` drains the Phase 3 outbox for the active UID.
2. **Pull** — `AccountIncrementalPuller.pullChanges` fetches remote changes since cursors.

**Why:** Prevents a pull from overwriting a local pending mutation that has not reached Firestore yet. Device B is more likely to see Device A’s upload before applying its own pull.

Upload failures contribute to `.partial` status; pull still proceeds when upload completes (with failed mutation count recorded).

---

## 8. Incremental cursor strategy

`AccountSyncCursorStore` persists per-UID timestamps in `UserDefaults` — **no food names, weights, or review text**.

| Cursor field | Domain |
|--------------|--------|
| `profileLastPulledAt` | `users/{uid}/profile/current` |
| `dailyLogsLastPulledAt` | Daily log parent documents |
| `foodEntriesLastPulledAt` | Food subcollection entries |
| `waterEntriesLastPulledAt` | Water subcollection entries |
| `weightEntriesLastPulledAt` | Weight entries collection |
| `dailyReviewsLastPulledAt` | Daily review documents |
| `lastForegroundRefreshAt` | Foreground throttle only |
| `lastManualRefreshAt` | Manual refresh audit |

**Advance rule:** Cursors advance to `max(updatedAt)` of successfully merged documents **per domain**. Failed domain pulls do not advance that domain’s cursor (`testPartialFailureDoesNotAdvanceFailedDomainCursor`).

**UID isolation:** Keys are namespaced `forma.crossDeviceSync.{uid}.{domain}`. Clearing one UID does not affect another (`testClearRemovesOnlyOneUserCursor`).

**Fetch API:** `AccountDataRemoteStore.fetch*UpdatedSince(uid:since:limit:)` with optional date range for food/water (bounded by mode lookback).

---

## 9. Merge/conflict policy

Phase 5 reuses `AccountSyncMergePolicy` from Phase 3 — no separate cross-device merge fork.

| Local state | Remote | Decision |
|-------------|--------|----------|
| No local row | Active remote | `.insert` |
| No local row | Tombstone | `.skipRemoteDeletedNoLocal` |
| `.synced` | Newer remote | `.update` |
| `.synced` | Older remote | `.skipStaleRemote` |
| `.pendingUpload` / `.pendingDelete` | Newer remote | `.skipLocalNewer` or `.conflict(...)` |
| `.pendingUpload` | Remote tombstone | `.conflict(pendingUploadVsRemoteDelete)` |
| `.pendingDelete` | Active remote | `.conflict(pendingDeleteVsRemoteRevive)` |
| Wrong `ownerUID` | Any | `.failedOwnerMismatch` |

`CrossDeviceSyncPolicy.preservesLocalNewerUnsyncedEdits = true` — newer local pending edits are **never** silently overwritten.

Conflicts increment `CrossDeviceSyncSummary.conflicts` and log via `CrossDeviceSyncLogger.mergeConflictDetected` (entity type + cloud ID suffix + reason code only).

---

## 10. Remote delete propagation

Deletes upload as tombstones (`deletedAt` on cloud documents). On pull:

- `AccountSyncMergePolicy.decideRemoteTombstone` applies `.applyRemoteTombstone` when local is `.synced` and remote delete is newer.
- Pending local edits block unsafe delete application (`testPullDoesNotApplyRemoteDeleteOverPendingLocalEdit`).
- `testDeviceADeletesFoodDeviceBRemovesIt` — E2E verification across two simulated devices.

Local `pendingDelete` rows are not resurrected from non-deleted remotes (`resurrectPendingDeleteFromRemote = false`).

---

## 11. Today / Journey / Plan refresh behavior

Tabs **never apply remote JSON directly**. They reload from merged SwiftData after domain-scoped events.

### Event bus

`AccountDataRefreshEventBus` publishes `AccountDataRefreshEvent(uid, domains, reason)` — no payloads.

Domain mapping (`AccountDataRefreshEventSupport.domains`):

| Pull activity | Domains notified |
|---------------|------------------|
| Profile merged | `.profile`, `.plan`, `.today`, `.journey` |
| Food entries | `.food`, `.today`, `.coachContext` |
| Water entries | `.water`, `.today`, `.coachContext` |
| Weight entries | `.weight`, `.journey` |
| Daily reviews | `.dailyReview`, `.journey` |
| Upload succeeded | `.today`, `.journey`, `.coachContext` |

### Tab policies

| Tab | Policy file | Reload when domains intersect |
|-----|-------------|-------------------------------|
| Today | `TodayCrossDeviceRefreshPolicy` | `.today`, `.food`, `.water`, `.weight`, `.dailyReview`, `.plan`, `.profile` |
| Journey | `JourneyCrossDeviceRefreshPolicy` | `.journey`, `.today`, `.food`, `.water`, `.weight`, `.dailyReview`, `.plan`, `.profile` |
| Plan | `PlanCrossDeviceRefreshPolicy` | `.plan`, `.profile`, `.today`, `.weight`, `.dailyReview`, `.food`, `.water` |

Each tab:

- Filters events with `matchesCurrentUID` — ignores other accounts.
- Debounces reloads (200ms) to coalesce rapid hints.
- Does **not** show false-empty during refresh (`testJourneyDoesNotShowFalseEmptyDuringRefresh`).
- Preserves visible pending local edits (`testTodayKeepsLocalPendingEditVisible`).

`AppRefreshCenter.notifyCrossDeviceSyncDidComplete()` also bumps global `refreshToken` for legacy listeners.

---

## 12. Account switch safety

| Mechanism | Behavior |
|-----------|----------|
| `isUIDStillCurrent` guard | Every coordinator stage checks `uidProvider.currentUID()` |
| `CrossDeviceSyncRunGuard` | One in-flight refresh per UID; cancelled if account changes mid-run |
| `cancelPendingWork()` | Cancels debounced realtime refresh task |
| `CrossDeviceSyncLifecycle.cancelOnAccountSwitch` | Coordinator cancel + listener stop |
| `AccountSyncCursorStore.clear(uid)` | Per-UID cursor wipe on namespace prepare |
| `AccountDataNamespaceService` | Quarantine foreign `ownerUID` rows (Phase 1) |
| Refresh events | `matchesCurrentUID` drops stale UID events |

`testOldUIDResultIgnoredAfterAccountSwitch`, `testAccountSwitchDoesNotLeakOldUserChanges`, `testDifferentUIDDoesNotReceiveOtherAccountData` — automated coverage.

---

## 13. Offline behavior

| Scenario | Outcome |
|----------|---------|
| Foreground refresh while offline | `.offline` summary; **local SwiftData unchanged** |
| Manual refresh while offline | Same — user-facing offline message |
| Realtime hint while offline | Hint may fire; refresh returns offline without merge |
| Pending local mutations | Remain in outbox; upload on next online refresh |
| Device B offline, Device A logs | B sees changes after next online foreground/manual/realtime refresh |

User-facing copy: `CrossDeviceSyncCoordinatorSupport.offlineMessage` — *"You're offline. Your data is saved on this device."*

---

## 14. Privacy / logging guarantees

### `CrossDeviceSyncLogger` (OSLog)

- Logs **hashed UID** (`AccountSyncLogger.hashedUID`), never full Firebase UID in production paths  
- Logs aggregate counts: inserted/updated/deleted, conflicts, pull counts per collection  
- Logs lifecycle: `cross_device_sync_started`, `cross_device_sync_completed`, `incremental_pull_completed`  
- Logs listener: `realtime_listener_started/stopped`, `realtime_change_hint_emitted`  
- Logs conflicts: entity type, cloud ID **suffix**, conflict reason code  
- **Never logs:** food names, macros, weights, review text, profile fields, raw Firestore payloads  
- **DEBUG only:** gated by `FormaAbTest.Diagnostics.accountSyncTrace`

### `AccountSyncCursorStore`

Persists timestamps per UID/domain only — no document content.

### `AccountDataRefreshEventBus`

Events carry UID + domain set — no nutrition payloads.

### `CrossDeviceSyncPolicy` exclusions

- `includesRawMealImages = false`  
- `includesRawHealthKitData = false`  

Optional `imageUrl` **strings** may sync via Phase 2 DTOs; binary meal images do not.

---

## 15. What is intentionally not implemented

| Item | Notes |
|------|-------|
| **Full account deletion** | `SettingsDeleteDataActionHandler` returns `.notImplemented` — Phase 6 |
| **Privacy controls / local wipe / data management UI** | Phase 6 |
| **Raw meal image sync** | Policy exclusion — optional URL strings only |
| **Raw HealthKit sync** | Policy exclusion — health summaries use separate consent flow |
| **Push notifications** | Not required; Firestore listeners + foreground catch-up suffice |
| **Coach chat / timeline sync** | Phase 5b opt-in |
| **Production sync status Settings screen** | DEBUG diagnostics only today |
| **Conflict toast UI** | Logged; user-facing toast optional |
| **Food/water subcollection Firestore listeners** | Option A — dailyLogs hint only |
| **Phase 3 `pullRecentDataEnabled` path** | Superseded by incremental puller for Phase 5 |

---

## 16. Remaining work for Phase 6

Phase 6 owns **account lifecycle exit** and **user-facing privacy** — not cross-device freshness.

| Item | Phase 6 deliverable |
|------|---------------------|
| `SettingsDeleteDataActionHandler` implementation | Wire to `AccountDeletionService` |
| Delete Firestore `users/{uid}/**` | Remote nutrition + profile wipe |
| Firebase Auth `user.delete()` | `AuthManager` |
| Local SwiftData wipe | `AccountDataNamespaceService.wipeAll()` |
| Health remote delete | Reuse `HealthSummarySyncService.deleteRemoteHealthSummaries` |
| Export | `SettingsExportDataActionHandler` |
| Privacy copy in onboarding / Settings | `FormaProductCopy` |
| `SettingsDataDeletionCapability.isImplemented == true` | Acceptance gate |

Phase 5 and Phase 6 are **orthogonal**: Phase 5 keeps devices in sync while the account exists; Phase 6 removes the account and all copies.

### Optional Phase 5b / polish (post–Phase 6)

- Coach chat / timeline opt-in sync  
- Production “Sync status” in Settings  
- Conflict toast when remote supersedes local  
- Firestore emulator in iOS CI (beyond in-memory store)

---

## Test coverage

Phase 5 tests use **`InMemoryAccountDataRemoteStore`**, in-memory SwiftData, fake clocks, and injected UID providers — **no production Firebase network required**.

Verify before production rollout:

```bash
xcodebuild test -scheme "Fitness Coach CI" \
  -only-testing:"Fitness CoachTests/AccountSyncCursorStoreTests" \
  -only-testing:"Fitness CoachTests/AccountIncrementalPullerTests" \
  -only-testing:"Fitness CoachTests/CrossDeviceSyncCoordinatorTests" \
  -only-testing:"Fitness CoachTests/AccountRealtimeChangeListenerTests" \
  -only-testing:"Fitness CoachTests/AppLifecycleCrossDeviceSyncTests" \
  -only-testing:"Fitness CoachTests/TodayCrossDeviceRefreshTests" \
  -only-testing:"Fitness CoachTests/JourneyCrossDeviceRefreshTests" \
  -only-testing:"Fitness CoachTests/PlanCrossDeviceRefreshTests" \
  -only-testing:"Fitness CoachTests/CrossDeviceEndToEndSyncTests" \
  -only-testing:"Fitness CoachTests/CrossDeviceSyncLoggerTests" \
  -only-testing:"Fitness CoachTests/AccountDataRefreshEventBusTests"
```

### Layer summary

| Layer | Test files |
|-------|------------|
| Cursors | `AccountSyncCursorStoreTests` (5) |
| Incremental pull + merge | `AccountIncrementalPullerTests` (13), `AccountSyncPullerTests` (Phase 3 underpin) |
| Coordinator | `CrossDeviceSyncCoordinatorTests` (10) |
| Realtime listener | `AccountRealtimeChangeListenerTests` (6) |
| App lifecycle | `AppLifecycleCrossDeviceSyncTests` (6) |
| Tab refresh | `TodayCrossDeviceRefreshTests` (7), `JourneyCrossDeviceRefreshTests` (6), `PlanCrossDeviceRefreshTests` (4) |
| End-to-end two-device | `CrossDeviceEndToEndSyncTests` (10) |
| Observability | `CrossDeviceSyncLoggerTests`, `AccountDataRefreshEventBusTests` |

---

## Architecture map

```
Fitness Coach/Application/Sync/
├── CrossDeviceSyncCoordinator.swift      # upload-then-pull orchestration
├── CrossDeviceSyncPolicy.swift           # lookback, throttle, exclusions
├── CrossDeviceSyncLifecycle.swift        # foreground / manual / listener hooks
├── AccountIncrementalPuller.swift        # cursor-driven incremental fetch + merge
├── AccountSyncCursorStore.swift          # per-UID per-domain cursors
├── AccountRealtimeChangeListener.swift   # hint abstraction + debouncer
├── AccountSyncMergePolicy.swift          # Phase 3 merge (reused)
├── AccountDataRefreshEventBus.swift      # domain-scoped UI events
└── AccountSyncCoordinator.swift          # Phase 3 upload engine

Fitness Coach/Infrastructure/Cloud/AccountData/
└── FirestoreAccountRealtimeChangeListener.swift

Fitness Coach/Features/
├── Today/Model/TodayCrossDeviceRefreshPolicy.swift
├── Journey/Model/JourneyCrossDeviceRefreshPolicy.swift
└── Plan/Model/PlanCrossDeviceRefreshPolicy.swift

Fitness Coach/Infrastructure/Diagnostics/
└── CrossDeviceSyncLogger.swift

Fitness Coach/App/
└── AppContainer.swift                    # foreground, session ready, manual refresh
```

---

## Rollout checklist

1. Run Phase 5 test suite on macOS CI (`xcodebuild test`).  
2. Manual QA: Device A logs food → Device B foreground → meal appears.  
3. Manual QA: Device A deletes → Device B refresh → meal gone.  
4. Manual QA: Edit on A while B has pending local edit → B keeps newer local.  
5. Manual QA: Account switch → no cross-user rows or refresh events.  
6. Confirm flags: `foregroundCrossDeviceRefreshEnabled`, `realtimeCrossDeviceSyncEnabled`, `manualRefreshEnabled`.  
7. Monitor `CrossDeviceSyncLogger` in Console — confirm no payload leakage.  
8. **Do not** conflate with Phase 6 — account delete remains unimplemented.

---

*End of Phase 5 documentation.*
