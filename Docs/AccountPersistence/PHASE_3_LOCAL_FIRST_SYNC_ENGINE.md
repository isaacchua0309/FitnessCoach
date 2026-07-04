# Account Persistence — Phase 3: Local-First Sync Engine

Production documentation for the **local-first account sync engine** in Forma (Fitness Coach).

**Status:** Phase 3 **implemented** — outbox, upload, pull/merge, lifecycle wiring, diagnostics, and tests. Pull-on-foreground and full restore remain gated off by feature flags.

**Related PR:** [#110](https://github.com/isaacchua0309/FitnessCoach/pull/110)  
**Depends on:** [Phase 2 — Cloud Schema and Rules](./PHASE_2_CLOUD_SCHEMA_AND_RULES.md)

---

## Critical distinction: sync engine exists ≠ full restore or realtime cross-device

| Statement | True in Phase 3? |
|-----------|------------------|
| Food, water, weight, daily logs, and daily reviews enqueue cloud sync mutations | **Yes** |
| Local logging still works offline (no network required) | **Yes** |
| Sync failure does not delete local data | **Yes** |
| Pending mutations survive app kill (durable outbox in SwiftData) | **Yes** |
| Upload runs after local mutations (debounced) and on foreground/sign-in | **Yes** |
| Full fresh-install restore UI / blocking restore flow | **No** (Phase 4) |
| Cross-device realtime sync (listeners, instant B←A) | **No** (Phase 5) |
| Pull recent cloud data on every foreground | **No** — `pullRecentDataEnabled = false` by default |
| Raw meal images uploaded to Firestore | **No** — never |
| Raw HealthKit samples uploaded | **No** — never |
| Coach chat / timeline synced to account namespace | **No** — unless added intentionally in Phase 5b |

Phase 3 delivers the **sync engine and local-first mutation pipeline**. Phase 4 delivers **restore UX**. Phase 5 delivers **cross-device freshness**.

Default feature flags (`AccountPersistenceFeatureFlags`):

```swift
static let cloudSchemaEnabled = true
static let syncEngineEnabled = true
static let uploadPendingMutationsEnabled = true
static let pullRecentDataEnabled = false          // bounded pull exists but is off
static let restoreOnLoginEnabled = false         // Phase 4
static let realtimeCrossDeviceSyncEnabled = false // Phase 5
```

---

## 1. Scope of Phase 3

**Goal:** After a user logs food, water, weight, or related rollups locally, the app **durably records** a cloud sync intent, **uploads when online**, and can **merge bounded remote changes** back into SwiftData — without blocking the local write path.

Phase 3 answers: *“When the user logs a meal while signed in, how does that change eventually reach Firestore safely, offline-first, and per-UID?”*

Phase 3 does **not** answer: *“How does a fresh install show years of history before the user can log again?”* That is Phase 4.

### In scope

| Area | Delivered |
|------|-----------|
| Durable outbox (`AccountSyncMutationEntity`) | Yes |
| Local mutation tracking + sync metadata on entities | Yes |
| Payload reconstruction from SwiftData (Phase 2 DTOs) | Yes |
| Upload drain via `AccountDataRemoteStore` | Yes |
| Pull + merge policy (bounded date window) | Yes — code complete, flag off |
| Coordinator + lifecycle hooks | Yes |
| Privacy-safe diagnostics / DEBUG tooling | Yes |
| Unit + integration tests | Yes |

### Out of scope (deferred)

| Area | Phase |
|------|-------|
| `AccountRestoreCoordinator` + restore progress UI | 4 |
| Blocking restore on login / reinstall | 4 |
| Foreground pull enabled by default | 5 |
| Realtime Firestore listeners | 5 |
| Coach chat / timeline account sync | 5b (opt-in) |
| Account deletion orchestration | 6 |
| Firestore emulator harness in iOS test target | Future hardening |

---

## 2. What is now synced

When the user is **signed in** (`ownerUID` available), these local mutations enqueue outbox work and stamp entity sync metadata:

| Entity | Local service | Outbox `entityType` | Cloud destination (Phase 2) |
|--------|---------------|---------------------|----------------------------|
| Food entry | `FoodLogService` | `.foodEntry` | `users/{uid}/dailyLogs/{date}/foodEntries/{id}` |
| Water entry | `WaterLogService` | `.waterEntry` | `users/{uid}/dailyLogs/{date}/waterEntries/{id}` |
| Weight entry | `WeightLogService` | `.weightEntry` | `users/{uid}/weightEntries/{id}` |
| Daily log rollup | `DailyLogService` | `.dailyLog` | `users/{uid}/dailyLogs/{date}` |
| Daily review | `ReviewService` | `.dailyReview` | `users/{uid}/dailyReviews/{date}` |

**Explicit:** Food, water, weight, daily logs, and daily reviews **now enqueue cloud sync mutations** after local persistence succeeds.

Each food/water/weight mutation typically also enqueues a **daily log upsert** (recalculated totals).

### What is uploaded

- Text fields, numeric macros, targets, totals, review summaries
- Optional `imageUrl` string reference on food (if already stored as URL locally)
- Schema version, timestamps, `userId`, device metadata per Phase 2 DTO contract

### What is never uploaded

- Raw meal image bytes / JPEG payloads
- HealthKit workout samples, step samples, or other raw HealthKit data
- Coach chat messages or coach timeline events (separate persistence; not part of account nutrition sync unless intentionally added later)

---

## 3. What is not yet synced (or not enabled)

| Capability | Status |
|------------|--------|
| Automatic **pull** on foreground / sign-in | Implemented but **disabled** (`pullRecentDataEnabled = false`) |
| Full account **restore** after reinstall | Not implemented (Phase 4) |
| **Realtime** cross-device updates | Not implemented (Phase 5) |
| User profile snapshot | Existing `FirestoreCloudUserProfileStore` path — not part of nutrition outbox |
| `syncMetadata` cursor maintenance | Partial — remote store supports it; full cursor orchestration is Phase 4/5 |
| Settings “Sync status” production UI | DEBUG diagnostics only in Phase 3 |
| Daily log **delete** to cloud | Upload path **cancels** daily log delete mutations in Phase 3 |

---

## 4. Local-first write behavior

```
User action (log food, etc.)
        │
        ▼
┌───────────────────────┐
│ FoodLogService / etc. │  ← writes SwiftData immediately
└───────────────────────┘
        │
        ├──► UI / Today updates from local store (no await on cloud)
        │
        └──► AccountLocalMutationTracker (if ownerUID present)
                    │
                    ├── stamp entity: pendingUpload / pendingDelete
                    └── enqueue identity-only outbox mutation
                              │
                              └── AccountSyncLifecycle.scheduleAfterLocalMutation
                                        └── debounced upload (2s)
```

**Rules:**

1. **Local write always wins for responsiveness** — logging never waits on Firestore.
2. **No owner UID → local-only** — guest/offline-account paths skip outbox enqueue; data remains on device.
3. **Sync failure does not delete local data** — failed uploads set `syncStatus = .failed` and retry later; local rows stay visible unless the user deletes them.
4. **App kill safe** — outbox rows live in SwiftData (`AccountSyncMutationEntity`); pending mutations survive relaunch.

---

## 5. Outbox model

### Storage

- SwiftData entity: `AccountSyncMutationEntity` (schema V8+)
- Store API: `SwiftDataAccountSyncOutboxStore` conforming to `AccountSyncOutboxStore`

### Identity-only mutations

Outbox rows store **no meal names, weights, or image bytes**. At upload time, `SwiftDataAccountSyncPayloadBuilder` reconstructs Phase 2 cloud DTOs from local entities.

| Field | Purpose |
|-------|---------|
| `ownerUID` | Namespace — all fetch/mark operations require matching UID |
| `entityType` | `dailyLog`, `foodEntry`, `waterEntry`, `weightEntry`, `dailyReview` |
| `entityId` | Stable id (UUID string, or `yyyy-MM-dd` for daily log / review) |
| `localDate` | Calendar date key for subcollection paths |
| `operation` | `upsert` or `delete` |
| `status` | `pending`, `inFlight`, `succeeded`, `failed`, `cancelled` |
| `attemptCount` / `nextRetryAt` | Retry backoff |
| `mutationGroupId` | Correlates food + daily log upserts from one user action |

### Coalescing

`AccountSyncMutationCoalescing` collapses redundant work per `(ownerUID, entityType, entityId)`:

- Repeated **upserts** → single pending upsert
- **Delete** after never-uploaded upsert → both discarded (no remote row)
- **Delete** after synced entity → single pending delete
- **Upsert** after delete (with `mutationGroupId`) → can recreate pending upsert
- Coalescing is **never cross-user** — same `entityId` for two UIDs stays isolated

---

## 6. Sync statuses

### On nutrition entities (`AccountDataSyncStatus`)

| Status | Meaning |
|--------|---------|
| `localOnly` | Created before sync metadata applied, or never enqueued |
| `pendingUpload` | Local edit waiting for upload |
| `synced` | Last upload (or safe pull merge) succeeded |
| `pendingDelete` | Tombstoned locally; delete mutation queued |
| `failed` | Last upload attempt failed; will retry |
| `conflict` | Remote newer while local had pending edits — needs resolution (Phase 5 UI optional) |

Helper: `needsSyncWork` is true for `pendingUpload`, `pendingDelete`, `failed`, `conflict`.

### On outbox rows (`AccountSyncMutationStatus`)

`pending` → `inFlight` → `succeeded` | `failed` | `cancelled`

Succeeded rows can be pruned after TTL via `pruneSucceeded(ownerUID:olderThan:)`.

---

## 7. Upload flow

```
AccountSyncCoordinator.uploadPendingOnly / syncNow
        │
        ▼
AccountSyncUploader.uploadDueMutations(uid)
        │
        ├── fetchDueMutations (pending + failed past backoff, UID-scoped)
        │
        └── for each mutation:
                markInFlight
                buildPayload (SwiftDataAccountSyncPayloadBuilder)
                validate userId match
                AccountDataRemoteStore.save* / delete*
                stamp entity synced / hard-delete tombstone
                markSucceeded
            on error:
                stamp entity failed + outbox markFailed (backoff)
```

**Guards:**

- Mutations with `ownerUID != session uid` are skipped / rejected
- Payload `userId` must match session uid (`AccountDataRemoteStoreSupport.validateWrite`)
- Missing local entity on **upsert** → mutation **cancelled** (not retried forever)
- **Daily log delete** → mutation **cancelled** in Phase 3 (deferred)
- Successful **food/water/weight** delete → remote hard delete + local tombstone row removed

---

## 8. Pull/merge flow

```
AccountSyncPuller.pullRecentAccountData(uid, from, to)   // default window: 90 days
        │
        ├── fetch daily logs, food, water, weights, reviews from AccountDataRemoteStore
        │
        └── for each remote document:
                AccountSyncMergePolicy.decide(context)
                AccountSyncRemoteMergeApplicator apply insert | update | tombstone | conflict
```

**Default pull window:** `AccountSyncPuller.defaultRecentPullDayCount` = **90** local dates ending at reference day.

Pull is **implemented** but **not enabled** in production flags (`pullRecentDataEnabled = false`). Coordinator skips pull unless the flag is turned on (or manual/debug path calls `pullRecentOnly`).

---

## 9. Conflict policy

`AccountSyncMergePolicy.decide` uses `remoteUpdatedAt` vs `localEffectiveUpdatedAt` (`localUpdatedAt` when present).

| Local state | Remote newer? | Decision |
|-------------|---------------|----------|
| Missing locally | active remote | `insert` |
| Missing locally | remote deleted | `skipRemoteDeletedNoLocal` |
| `synced` / `localOnly` | yes | `update` |
| `synced` / `localOnly` | no | `skipStaleRemote` |
| `pendingUpload` / `failed` / `conflict` | yes | `conflict` (local kept, status stamped) |
| `pendingUpload` / … | no | `skipLocalNewer` |
| `pendingDelete` | any non-tombstone remote | `skipLocalNewer` (no resurrection in Phase 3) |
| Owner mismatch | — | `failedOwnerMismatch` |

Phase 3 **does not** resurrect `pendingDelete` rows from a non-deleted remote (`resurrectPendingDeleteFromRemote = false`).

---

## 10. Tombstone/delete policy

### Local delete (`AccountDataSyncDeletionPolicy`)

| Entity state | Local delete behavior |
|--------------|----------------------|
| Never synced (no `cloudId` / `lastSyncedAt`) | **Hard delete** locally; outbox upsert+delete coalesced away |
| Previously synced or has `cloudId` | Set `deletedAt`, `pendingDelete`, enqueue **delete** mutation |

### Remote delete upload

- Food / water / weight: `delete*` on `AccountDataRemoteStore`
- After success: local tombstone row **hard-deleted** (`AccountSyncDeleteRetentionPolicy`)

### Remote delete pull

When remote document has `deletedAt` and merge policy returns `applyRemoteTombstone`:

- Local entity gets `deletedAt` + `synced` metadata
- UI filters tombstones via `AccountDataSyncReadFilter.isVisible` (`deletedAt == nil`)

---

## 11. Retry/backoff policy

### Outbox mutation retry (`AccountSyncRetryPolicy`)

| Attempt after failure | Delay |
|----------------------|-------|
| 1 | 30 seconds |
| 2 | 2 minutes |
| 3 | 10 minutes |
| 4+ | 1 hour |

Failed mutations return to the due queue when `now >= nextRetryAt`.

### Entity-level retry metadata

Failed uploads also increment `syncAttemptCount` and set `nextRetryAt` on the entity via `AccountSyncPostUploadStamping.markFailed`.

---

## 12. App lifecycle sync triggers

Wiring: `AccountSyncLifecycle` + `AppContainer` + `FitnessActionCenter` + `AuthGateCoordinator` + `MainTabView`.

| Trigger | Entry point | Behavior |
|---------|-------------|----------|
| After local mutation | `FitnessActionCenter.notifyAccountDataChanged()` → `scheduleAfterLocalMutation` | Debounced upload (2s), upload only |
| App foreground | `MainTabView` → `handleAppForeground` | `syncNow(.appForeground)` — upload; pull only if `pullRecentDataEnabled` |
| After sign-in | `AuthGateCoordinator` → `handleAfterSignIn` | `syncNow(.afterSignIn)` — upload; pull only if pull flag on and restore flag off |
| Account switch / sign-out | `cancelOnAccountSwitch` | Cancels debounced upload task |
| Manual / retry | Coordinator API | Full `syncNow` per flags |

**Concurrency:** `AccountSyncCoordinator` allows only **one active run per UID**; overlapping calls receive `syncAlreadyInProgress`.

**UID guard:** If `currentUIDProvider()` does not match the requested uid, sync is skipped (`uidChanged`).

---

## 13. Offline behavior

| Scenario | Behavior |
|----------|----------|
| Log meal offline | Local save succeeds; outbox mutation `pending`; entity `pendingUpload` |
| App killed with pending outbox | Mutations persist in SwiftData; upload resumes on next trigger |
| Upload fails (network/server) | Outbox `failed` + backoff; entity `failed`; **local data retained** |
| Signed out | No outbox enqueue; existing local data unchanged |
| Online again | Foreground / debounced upload drains due mutations |

There is **no** separate `NWPathMonitor` upload trigger in Phase 3 — retry is driven by lifecycle events and backoff timers on subsequent runs.

---

## 14. Account switch safety

| Layer | Protection |
|-------|------------|
| Outbox fetch / mark | All APIs require `ownerUID` match |
| Uploader | Processes only mutations for requested uid; validates payload `userId` |
| Puller | Skips rows where local `ownerUID` ≠ session uid (`failedOwnerMismatch`) |
| Coordinator | `isUIDStillCurrent` before upload/pull; debounced task cancelled on switch |
| Remote store | `AccountDataRemoteStoreSupport.validateUserIdMatch` on every write |

User B **cannot** upload User A mutations. User B pull **does not** read User A remote collections when using uid-scoped fetch APIs.

---

## 15. Privacy and logging rules

### `AccountSyncLogger` (OSLog)

- Logs **hashed UID** (SHA-256 prefix), never full Firebase uid in production paths
- Logs entity **type** and **operation**, not food names or weights
- Logs aggregate upload/pull counts and error **categories**, not document payloads
- DEBUG-only settings surface: `AccountSyncDiagnosticsView` via `AccountSyncDebugEnvironment`

### Payload builder

- Reconstructs Phase 2 DTOs only
- No raw image bytes; optional `imageUrl` string only
- No HealthKit fields in nutrition DTOs

### Error sanitization

`AccountDataSyncMetadataSupport.sanitizedSyncError` stores truncated, non-sensitive messages on entities and outbox rows.

---

## 16. Remaining work for Phase 4

Phase 4 should build on this engine — **not** replace it.

| Item | Notes |
|------|-------|
| `AccountRestoreCoordinator` | Orchestrate bounded/full pull after `ProfileBootstrapService.resolve` |
| `restoreOnLoginEnabled` flag | Gate blocking restore |
| Restore progress UI | `RestoreProgressView` — show pull state, allow retry |
| Block main UI until minimum window restored | e.g. last 30 days before Today is usable |
| Migration backfill prompt | Offer upload of pre-sync local history |
| `syncMetadata` cursor updates | `lastFullPullAt`, `lastSuccessfulPushAt` drive incremental restore |
| Enable `pullRecentDataEnabled` selectively | After restore UX is ready |
| Firestore emulator iOS integration tests | Optional hardening — Phase 3 uses `InMemoryAccountDataRemoteStore` for round-trips |

### Phase 5 preview (out of Phase 4 scope)

- Turn on foreground pull by default
- Realtime listeners (`realtimeCrossDeviceSyncEnabled`)
- Conflict resolution UI
- Optional coach chat / timeline sync (separate namespace)
- Settings sync status for end users

---

## Architecture map

```
Fitness Coach/Application/Sync/
├── AccountLocalMutationTracker.swift      # stamp + enqueue on local writes
├── AccountSyncOutboxStore.swift           # durable queue + coalescing + retry
├── AccountSyncMutationModels.swift        # domain types + coalescing rules
├── AccountSyncPayloadBuilder.swift        # SwiftData → Phase 2 DTOs
├── AccountSyncUploader.swift              # outbox → AccountDataRemoteStore
├── AccountSyncPuller.swift                # remote → SwiftData merge
├── AccountSyncMergePolicy.swift           # conflict / tombstone decisions
├── AccountSyncCoordinator.swift           # orchestration, debounce, flags
├── AccountSyncLifecycle.swift             # app lifecycle entry points
├── AccountSyncDiagnostics.swift           # in-memory run history (DEBUG)
└── AccountDataSyncStamping.swift          # entity sync metadata helpers

Fitness Coach/Infrastructure/Diagnostics/
└── AccountSyncLogger.swift                # privacy-safe OSLog

Fitness Coach/Data/Repositories/
├── FoodLogService.swift                   # mutationTracker hooks
├── WaterLogService.swift
├── WeightLogService.swift
├── DailyLogService.swift
└── ReviewService.swift

Fitness Coach/App/AppContainer.swift         # wires coordinator + remote store
```

---

## Test coverage

Phase 3 acceptance is validated by the iOS test target (run on macOS):

```bash
xcodebuild test -scheme "Fitness Coach" \
  -only-testing:"Fitness CoachTests/AccountSyncOutboxStoreTests" \
  -only-testing:"Fitness CoachTests/AccountSyncPayloadBuilderTests" \
  -only-testing:"Fitness CoachTests/AccountSyncUploaderTests" \
  -only-testing:"Fitness CoachTests/AccountSyncPullerTests" \
  -only-testing:"Fitness CoachTests/AccountSyncCoordinatorTests" \
  -only-testing:"Fitness CoachTests/AccountSyncMutationIntegrationTests" \
  -only-testing:"Fitness CoachTests/AccountSyncRemoteIntegrationTests" \
  -only-testing:"Fitness CoachTests/AccountSyncMergePolicyTests" \
  -only-testing:"Fitness CoachTests/AccountSyncMutationCoalescingTests" \
  -only-testing:"Fitness CoachTests/AccountLocalMutationTrackingTests" \
  -only-testing:"Fitness CoachTests/AccountSyncLifecycleWiringTests" \
  -only-testing:"Fitness CoachTests/AccountSyncLoggerTests" \
  -only-testing:"Fitness CoachTests/AccountSyncDiagnosticsTests"
```

**Remote integration note:** `AccountSyncRemoteIntegrationTests` exercises uploader/puller through the `AccountDataRemoteStore` protocol via `InMemoryAccountDataRemoteStore`. A Firestore emulator harness is not wired in the iOS test target; production `FirestoreAccountDataRemoteStore` pre-write validation is covered in `FirestoreAccountDataRemoteStoreTests`.

---

## Why Phase 2 schema exists

Phase 2 defined **what** gets stored in Firestore and **who** can access it. Phase 3 defines **when** local changes become cloud writes:

1. User logs food → local SwiftData is immediate (Today works offline).
2. `AccountLocalMutationTracker` enqueues an identity mutation.
3. `AccountSyncCoordinator` schedules upload (debounced or foreground).
4. `AccountSyncUploader` builds Phase 2 DTOs and calls `AccountDataRemoteStore`.
5. On success, entity is `synced`; on failure, local data remains and retry is scheduled.

Without Phase 2 DTOs/paths/rules, Phase 3 would have no typed contract to upload. Without Phase 3, Phase 2 schema would remain unused at runtime.

---

*End of Phase 3 documentation. Restore UX begins in Phase 4.*
