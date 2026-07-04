# Account Persistence — Implementation Plan

**Companion to:** `ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`  
**Status:** Phases 2–4 foundation **implemented** — see `Docs/AccountPersistence/PHASE_2_CLOUD_SCHEMA_AND_RULES.md`, `Docs/AccountPersistence/PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md`, and `Docs/AccountPersistence/PHASE_4_FRESH_INSTALL_RESTORE.md`  
**Generated:** 2026-07-04 · **Updated:** 2026-07-04

---

## Phase status

| Phase | Goal | Status |
|-------|------|--------|
| **1** | UID hardening — stop cross-user local leakage | **In progress** ([#106](https://github.com/isaacchua0309/FitnessCoach/pull/106)) |
| **2** | Cloud schema, DTOs, rules, remote store, tests, DI (no sync) | **Implemented** ([#108](https://github.com/isaacchua0309/FitnessCoach/pull/108)) |
| **3** | Local-first sync engine — upload/pull/outbox | **Implemented** ([#110](https://github.com/isaacchua0309/FitnessCoach/pull/110)) |
| **4** | Fresh install restore + bootstrap UX | **Implemented** — verify with `xcodebuild test` before enabling `restoreOnLoginEnabled` ([#113](https://github.com/isaacchua0309/FitnessCoach/pull/113)–[#117](https://github.com/isaacchua0309/FitnessCoach/pull/117)) |
| **5** | Cross-device sync + optional coach/review sync | **Pending** |
| **6** | Account delete, export, privacy | **Pending** |

**Phase 2 reminder:** Cloud DTOs and Firestore paths exist. See Phase 2 doc for schema/rules.

**Phase 3 reminder:** Signed-in users enqueue nutrition sync mutations; upload runs on debounced local changes, foreground, and sign-in. **Pull on foreground is off by default** (`pullRecentDataEnabled = false`). See `Docs/AccountPersistence/PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md`.

**Phase 4 reminder:** Blocking restore after sign-in pulls profile + bounded nutrition history from Firestore; background backfill extends windows. **Restore UX is off by default** (`restoreOnLoginEnabled = false`) until CI/manual QA passes. **No realtime cross-device listeners.** See `Docs/AccountPersistence/PHASE_4_FRESH_INSTALL_RESTORE.md`.

---

## 1. Prioritized Gap Table (Action-Oriented)

| Priority | Gap | Fix | Phase |
|---------|-----|-----|-------|
| P0 | Nutrition logs lost on reinstall | Firestore sync + restore pipeline | 2–4 |
| P0 | Cross-user local leakage | `ownerUID` + filtered reads + switch wipe | 1 |
| P0 | Journey empty on new device | Restore daily/weight logs before Journey load | 4 |
| P1 | No offline upload | Sync outbox + retry | 3 ✅ |
| P1 | Deletes don't propagate | Tombstones + pull merge | 3 ✅ (upload); 5 (cross-device pull enabled) |
| P1 | Firestore rules incomplete | Expand `firestore.rules` + emulator tests | 2 |
| P2 | Account delete stub | GDPR delete orchestration | 6 |
| P2 | Coach nil userId rows | Backfill + strict filter | 1 |
| P3 | Daily reviews not synced | Optional collection | 3 ✅ (upload); 5 (pull enabled by default) |

---

## 2. Risk List

| Risk | Mitigation |
|------|------------|
| Duplicate uploads on migration | `mutationId` idempotency; server merge guard |
| Uploading User A data to User B account | Confirm dialog; `ownerUID` validation before push |
| Firestore cost on large histories | Paginated pull; subcollections; retention policy (e.g. 2 years) |
| 1MB document limit | Subcollections for food/water per day |
| Conflict on simultaneous edits | LWW on `updatedAt` + optional field-level merge for edits |
| Long restore blocking UI | Progressive restore: 30 days blocking, rest background |
| SwiftData migration failure | Lightweight migration + feature flag `FormaAbTest.Sync.enabled` |
| Breaking offline-only users | Sync only when signed in; local-first unchanged |
| Health rules deployment drift | Single `firestore.rules` PR with nutrition + health |
| Coach image storage cost | Text-only sync default |

---

## 3. Restore Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        FRESH INSTALL / NEW DEVICE                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │   AuthManager.signInWithGoogle │
                    └───────────────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │ ProfileBootstrapService.resolve│
                    │  → Firestore profile/current   │
                    │  → UserProfileService.restore  │
                    └───────────────────────────────┘
                                    │
                                    ▼
              ┌─────────────────────────────────────────────┐
              │         AccountRestoreCoordinator            │
              │  [NEW] Blocking restore phase                │
              └─────────────────────────────────────────────┘
                    │                    │
         ┌──────────┘                    └──────────┐
         ▼                                          ▼
┌─────────────────────┐                 ┌─────────────────────┐
│ Pull syncMetadata   │                 │ Show restore UI      │
│ Pull weightEntries  │                 │ (spinner / progress) │
│ Pull dailyLogs 30d  │                 └─────────────────────┘
│ + food/water child  │
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│ Write SwiftData      │
│ ownerUID = uid       │
│ syncStatus = synced  │
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│ AppRefreshCenter     │
│ → TodayModel         │
│ → JourneyModel       │
│ → CoachModel         │
└─────────────────────┘
         │
         ▼
┌─────────────────────┐
│ Background pull      │
│ older days, coach    │
└─────────────────────┘
```

### Same-device logout → login (no reinstall)

```
Logout → AuthManager.signOut()
       → ProfileCloudSyncStore.clear() only
       → SwiftData UNCHANGED (today)
       
[After Phase 1]
Logout → optional namespace quarantine (flag-gated)
       → OR keep data for same UID return (current tests expect preserve)

Login same UID → ProfileBootstrapService.resolve → owner matches → main
               → NutritionSyncEngine incremental pull/push
```

### Account switch (User A → User B)

```
[After Phase 1]
Login User B → AccountDataNamespaceService.prepareForUID(B)
            → Delete/quarantine rows where ownerUID != B AND ownerUID != nil
            → Pull B's cloud data
            → NEVER show A's food/water rows
```

---

## 4. Sync Engine Design

### Components (new files)

| File | Responsibility |
|------|----------------|
| `Fitness Coach/Application/Sync/AccountSyncEngine.swift` | Orchestrator: foreground sync, restore |
| `Fitness Coach/Application/Sync/AccountRestoreCoordinator.swift` | First-login / reinstall pull |
| `Fitness Coach/Application/Sync/SyncOutboxStore.swift` | Pending mutations queue |
| `Fitness Coach/Application/Sync/AccountDataNamespaceService.swift` | UID switch / quarantine |
| `Fitness Coach/Infrastructure/Cloud/FirestoreDailyLogSyncClient.swift` | dailyLogs CRUD |
| `Fitness Coach/Infrastructure/Cloud/FirestoreFoodEntrySyncClient.swift` | food subcollection |
| `Fitness Coach/Infrastructure/Cloud/FirestoreWaterEntrySyncClient.swift` | water subcollection |
| `Fitness Coach/Infrastructure/Cloud/FirestoreWeightEntrySyncClient.swift` | weightEntries |
| `Fitness Coach/Infrastructure/Cloud/FirestoreSyncMetadataClient.swift` | syncMetadata/current |
| `Fitness Coach/Infrastructure/Cloud/CloudNutritionDocuments.swift` | Codable DTOs |
| `Fitness Coach/Domain/Sync/SyncMutation.swift` | mutationId, entity type, operation |
| `Fitness Coach/Domain/Sync/SyncStatus.swift` | enum |

### Write path (local-first)

```
FitnessActionCenter.logFood(...)
  → FoodLogService.addFoodEntry (existing)
  → entity.ownerUID = AuthManager.currentUID
  → entity.syncStatus = .pending
  → entity.mutationId = UUID()
  → entity.localUpdatedAt = now
  → SwiftDataStore.save()
  → SyncOutboxStore.enqueue(.foodEntryUpsert(id))
  → Task { await AccountSyncEngine.pushPending() }
```

### Push algorithm

1. Load outbox ordered by `localUpdatedAt`
2. For each mutation, build Firestore DTO with `userId == uid`
3. `setData(merge: true)` with `mutationId` check
4. On success: `syncStatus = .synced`, `cloudUpdatedAt = serverTime`, dequeue
5. On failure: `syncStatus = .failed`, `lastSyncError`, retry with backoff

### Pull algorithm (incremental)

1. Read `syncMetadata/current` → `lastPulledAt`, cursors per collection
2. Query `dailyLogs` where `updatedAt > lastPulledAt` (paginated)
3. For each day, query food/water subcollections
4. Query `weightEntries` where `updatedAt > lastPulledAt`
5. Merge into SwiftData:
   - If local `mutationId` == remote → skip
   - If remote `updatedAt` > local → apply remote
   - If local `syncStatus == .pending` and local newer → keep local, push later
6. Apply tombstones: `deletedAt != null` → delete local row

### Conflict resolution

| Case | Resolution |
|------|------------|
| Same `mutationId` | Idempotent — no-op |
| Remote newer `updatedAt` | Take remote |
| Local pending + remote older | Push local |
| Local pending + remote newer | Take remote; mark local as superseded (log) |
| Delete vs edit | `deletedAt` wins if newer timestamp |

### Offline behavior

- All mutations work offline (already true for food/water)
- Outbox grows; `AccountSyncEngine` retries on `NWPathMonitor` / foreground
- UI badge: "Syncing…" / "Offline — changes saved on device"

### Account switch

`AccountDataNamespaceService.prepareForUID(newUID)`:
1. If `newUID == lastActiveUID` → return
2. Cancel in-flight sync tasks
3. Delete SwiftData rows where `ownerUID != nil && ownerUID != newUID`
4. Clear health cache for old UID (`LocalHealthCacheStore.clearAll()`)
5. Set `lastActiveUID = newUID`
6. Run `AccountRestoreCoordinator.beginRestore`

Wire into `AuthGateCoordinator.reconcileSignedInProfile` when `isFreshSignIn`.

---

## 5. Proposed Firestore Schema (Detailed)

### `users/{uid}/syncMetadata/current`

```typescript
{
  userId: string,
  schemaVersion: 1,
  clientSchemaVersion: 1,
  lastPushedAt: Timestamp | null,
  lastPulledAt: Timestamp | null,
  lastFullRestoreAt: Timestamp | null,
  deviceId: string,
  appVersion: string,
  updatedAt: Timestamp
}
```

### `users/{uid}/dailyLogs/{yyyy-MM-dd}`

Rollup fields mirror `DailyLogEntity` totals + targets + `weightKg`.  
Subcollections:

- `foodEntries/{uuid}` — mirrors `FoodEntryEntity` + sync metadata
- `waterEntries/{uuid}` — mirrors `WaterEntryEntity` + sync metadata

### `users/{uid}/weightEntries/{uuid}`

Standalone weight history (not only daily log mirror).

### `users/{uid}/dailyReviews/{yyyy-MM-dd}` (Phase 5)

Text fields from `DailyReviewEntity`; optional.

### `users/{uid}/coachMessages/{uuid}` (Phase 5, optional)

Text + metadata only; **exclude** `fullImageJPEG` by default.

### `users/{uid}/coachTimelineEvents/{uuid}` (Phase 5, optional)

Mirror `CoachTimelineEventEntity.payloadJSON` + index fields.

### Document ID strategies

| Collection | ID |
|------------|-----|
| dailyLogs | `yyyy-MM-dd` in user TZ |
| foodEntries | `FoodEntryEntity.id.uuidString` |
| waterEntries | `WaterEntryEntity.id.uuidString` |
| weightEntries | `WeightEntryEntity.id.uuidString` |
| coachMessages | `ChatMessage.id.uuidString` |

### Tombstones

Set `deletedAt: Timestamp` instead of hard delete. Pull applies local delete.  
Compaction job (future): purge tombstones older than 90 days.

---

## 6. SwiftData Migration Plan (V6 → V7)

### Step 1 — Add optional fields (lightweight)

All nutrition + coach entities gain:

```swift
var ownerUID: String?
var localUpdatedAt: Date?
var cloudUpdatedAt: Date?
var syncStatusRawValue: String?  // default "synced" for legacy
var lastSyncError: String?
var deletedAt: Date?
var mutationId: UUID?
var entitySchemaVersion: Int  // default 1
```

### Step 2 — Backfill on upgrade

`AccountMigrationService.runV7Backfill()`:
1. Read `UserProfileEntity.ownerUID` → `sessionUID`
2. If `sessionUID` set: update all rows missing `ownerUID`
3. Coach rows with `userId == nil` → set to `sessionUID`
4. Set `syncStatus = .pending` for backfilled rows (trigger upload)

### Step 3 — Strict queries

Update all `FetchDescriptor`s in:
- `FoodLogService`
- `WaterLogService`
- `WeightLogService`
- `DailyLogService`
- `CoachChatTranscriptPersistenceRepository` — **remove** nil-userId passthrough
- `CoachTimelinePersistenceRepository`

Predicate: `#Predicate { $0.ownerUID == uid }` (or `userId == uid` for coach).

### Step 4 — Unique constraints

Consider compound uniqueness `(ownerUID, date)` on `DailyLogEntity` — may require custom migration (evaluate in Phase 1 spike).

### Files to modify

- `FormaModelMigration.swift` — add `FormaSchemaV7`
- All `Entities/*.swift` (active 8 types)
- All `Data/Repositories/*LogService.swift`
- `Mapping/*+Mapping.swift`

---

## 7. Security Rules (Deploy-Ready Draft)

See context packet §12. Add to `firestore.rules`:

- `syncMetadata`
- `dailyLogs` + `foodEntries` + `waterEntries` subcollections
- `weightEntries`
- Health collections from `Docs/HealthIntelligence/HEALTH_SUMMARY_SYNC_CONTRACT.md`

**Emulator tests (new):**

- `functions/test/` or new `Firebase/firestore.rules.test.ts` using `@firebase/rules-unit-testing`
- iOS: `Fitness CoachTests/FirestoreRulesNutritionSyncTests.swift` (optional integration)

---

## 8. Implementation Phases (Detailed)

### Phase 1 — Audit and UID Hardening

**Goal:** Stop cross-user leakage before any cloud upload.

| Action | Files |
|--------|-------|
| Add `ownerUID` to entities (optional first) | `Entities/*.swift`, `FormaModelMigration.swift` |
| Set `ownerUID` on every write | `FoodLogService`, `WaterLogService`, `WeightLogService`, `DailyLogService`, `FitnessActionCenter` |
| Filter all reads by `AuthManager.currentUID` | Same + `ReviewService` |
| Fix coach nil filter | `CoachChatTranscriptPersistenceRepository.fetchEntities` — exclude nil when userId set |
| Require coach userId on insert | `SwiftDataCoachChatTranscriptStore` |
| Add `AccountDataNamespaceService` stub | New file |
| Wire `deletesLocalProfileOnSignOut` OR document removal | `AuthGateCoordinator`, `AuthLogoutPolicy` |
| Account switch quarantine (flag) | `AuthGateCoordinator.reconcileSignedInProfile` |

**Tests:**
- `Fitness CoachTests/MultiUserNutritionIsolationTests.swift` (new)
- `Fitness CoachTests/CoachTranscriptUserIsolationTests.swift` (new)
- Extend `SignOutHygieneTests`

**Acceptance:**
- User B cannot read User A food entries on same device
- All new writes have `ownerUID == currentUID`

**Risks:** Legacy rows without owner — gate cloud upload until backfill

---

### Phase 2 — Cloud Schema and Rules

**Goal:** Firestore structure + DTOs + rules + emulator tests (no iOS sync yet).

**Status:** **Implemented** — documented in `Docs/AccountPersistence/PHASE_2_CLOUD_SCHEMA_AND_RULES.md` ([#108](https://github.com/isaacchua0309/FitnessCoach/pull/108)).

| Action | Files |
|--------|-------|
| Define `CloudDailyLogDocument`, `CloudFoodEntryDocument`, etc. | `Infrastructure/Cloud/AccountData/Cloud*.swift` |
| Canonical paths + schema version | `AccountDataCloudPaths.swift`, `AccountDataCloudSchema.swift` |
| Local ↔ cloud mappers | `CloudAccountDataMappers.swift` |
| Remote store protocol + Firestore client | `AccountDataRemoteStore.swift`, `FirestoreAccountDataRemoteStore.swift` |
| DI (dormant) | `AppContainer.accountDataRemoteStore`, `AccountPersistenceFeatureFlags.swift` |
| Expand `firestore.rules` | `firestore.rules` |
| Emulator + iOS tests | `functions/test/accountPersistenceFirestoreRules.test.ts`, `Fitness CoachTests/*AccountData*` |

**Acceptance (met):**
- Emulator: owner can R/W own nutrition docs; user A cannot read user B docs (27 rules tests)
- DTO round-trip + mapper ownership tests (iOS)
- Remote store `userId` mismatch rejected before Firestore write
- **Not met (by design):** no production log mutations call the remote store

---

### Phase 3 — Local-First Sync Engine

**Goal:** Upload local mutations; incremental pull; offline outbox.

**Status:** **Implemented** — documented in `Docs/AccountPersistence/PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md` ([#110](https://github.com/isaacchua0309/FitnessCoach/pull/110)).

| Action | Files |
|--------|-------|
| Durable outbox + coalescing | `Application/Sync/AccountSyncOutboxStore.swift`, `AccountSyncMutationModels.swift`, `AccountSyncMutationEntity` |
| Local mutation tracking | `Application/Sync/AccountLocalMutationTracker.swift`, `AccountDataSyncStamping.swift` |
| Payload builder (Phase 2 DTOs) | `Application/Sync/AccountSyncPayloadBuilder.swift` |
| Upload / pull | `AccountSyncUploader.swift`, `AccountSyncPuller.swift`, `AccountSyncMergePolicy.swift` |
| Orchestration | `AccountSyncCoordinator.swift`, `AccountSyncLifecycle.swift` |
| Hook repositories | `FoodLogService`, `WaterLogService`, `WeightLogService`, `DailyLogService`, `ReviewService` |
| Hook action center + lifecycle | `FitnessActionCenter.swift`, `AppContainer.swift`, `MainTabView.swift`, `AuthGateCoordinator.swift` |
| Observability | `AccountSyncLogger.swift`, `AccountSyncDiagnostics.swift`, DEBUG `AccountSyncDiagnosticsView` |
| Feature flags | `AccountPersistenceFeatureFlags.swift`, `FormaAbTest.AccountPersistence` |

**Tests (iOS — run on macOS):**
- `AccountSyncOutboxStoreTests`, `AccountSyncMutationCoalescingTests`
- `AccountSyncPayloadBuilderTests`, `AccountSyncUploaderTests`, `AccountSyncPullerTests`
- `AccountSyncMergePolicyTests`, `AccountSyncCoordinatorTests`
- `AccountLocalMutationTrackingTests`, `AccountSyncMutationIntegrationTests`
- `AccountSyncRemoteIntegrationTests` (protocol round-trips via `InMemoryAccountDataRemoteStore`)
- `AccountSyncLifecycleWiringTests`, `AccountSyncLoggerTests`, `AccountSyncDiagnosticsTests`

**Acceptance (met by test suite; verify with `xcodebuild test`):**
- Meal logged while signed in → outbox mutation + `pendingUpload`; uploads when coordinator runs
- Edit/delete propagates to remote store (in-memory contract tests)
- Offline pending mutations survive store reopen; failed uploads retry with backoff
- UID isolation on outbox, uploader, puller, coordinator
- No duplicate outbox rows for rapid edits (coalescing)
- **Not met (by design):** `pullRecentDataEnabled` remains false; no restore UI; no realtime listeners; no raw images/HealthKit

---

### Phase 4 — Fresh Install Restore

**Goal:** Reinstall / new device gets logging history back.

**Status:** **Implemented** — documented in `Docs/AccountPersistence/PHASE_4_FRESH_INSTALL_RESTORE.md` ([#113](https://github.com/isaacchua0309/FitnessCoach/pull/113)–[#117](https://github.com/isaacchua0309/FitnessCoach/pull/117)).

| Action | Files |
|--------|-------|
| `AccountRestoreCoordinator` + `AccountInitialRestoreService` | `Application/Restore/*.swift` |
| Restore state + session awareness | `AccountRestoreStateStore`, `AccountRestoreSessionState` |
| Integrate after sign-in | `AuthGateCoordinator.routeToMainWithAccountRestore`, `AppContainer` |
| Restore UI | `AccountRestoreView`, `AccountRestoreViewModel` |
| Background backfill (365d/730d) | `AccountInitialRestoreService.runBackgroundBackfill` |
| Tab refresh | `AppRefreshCenter.notifyAccountRestoreDidComplete` |
| Privacy-safe diagnostics | `AccountRestoreLogger`, DEBUG `AccountRestoreDiagnosticsView` |
| Feature flags | `restoreOnLoginEnabled = false` until QA |

**Tests (iOS — run on macOS):**
- `AccountRestoreCoordinatorTests`, `AccountInitialRestoreServiceTests`
- `AccountRestoreStateStoreTests`, `AccountLocalDataInspectorTests`, `AccountRemoteDataInspectorTests`
- `AccountRestoreOutcomeSupportTests`, `AccountRestorePolicyTests`, `AccountRestoreSessionStateTests`
- `AccountRestoreLoggerTests`, `AccountBackgroundBackfillCoordinatorTests`
- `AccountRestoreViewModelTests`, `AuthRestoreRoutingTests`
- `TodayRestoreAwarenessTests`, `JourneyRestoreAwarenessTests`, `PlanRestoreAwarenessTests`
- `AccountRestoreEndToEndTests` (reinstall / new-device simulations via in-memory store)

**Acceptance (met by test suite; verify with `xcodebuild test` before flag enable):**
- Delete app → reinstall → sign in → Today shows restored meals (in-memory cloud fixtures)
- Journey weight / log history populated after restore
- UID isolation — user B never receives user A rows
- Pending local edits not overwritten by older remote
- Offline / partial terminal states allow safe main-shell entry
- **Not met (by design):** `restoreOnLoginEnabled` remains false; no realtime listeners; no raw images/HealthKit; no account deletion

---

### Phase 5 — Cross-Device Sync

**Goal:** Device B sees Device A changes within foreground refresh.

**Status:** **Pending**

| Action | Files |
|--------|-------|
| Foreground pull in `AccountSyncEngine` | Existing engine |
| Conflict UI (rare) | Optional toast |
| Coach chat/timeline sync (optional flag) | Phase 5b |
| Daily review sync | Phase 5b |
| Sync status in Settings | `SettingsRootView` |

**Tests:** Cross-device test matrix (§11 of context packet)

**Acceptance:**
- Device A logs → Device B foreground → B sees entry
- Delete on A removes on B

---

### Phase 6 — Deletion and Privacy

**Goal:** Account delete, export, privacy copy.

**Status:** **Pending**

| Action | Files |
|--------|-------|
| Implement `SettingsDeleteDataActionHandler` | Existing stub |
| Delete Firestore `users/{uid}/**` | New `AccountDeletionService` |
| Firebase Auth `user.delete()` | `AuthManager` |
| Local SwiftData wipe | `AccountDataNamespaceService.wipeAll()` |
| Health remote delete | Reuse `HealthSummarySyncService.deleteRemoteHealthSummaries` |
| Export | `SettingsExportDataActionHandler` |
| Privacy copy in onboarding | `FormaProductCopy` |

**Acceptance:**
- Account delete clears local + remote nutrition + profile
- `SettingsDataDeletionCapability.isImplemented == true`

---

## 9. Test Matrix (Implementation Checklist)

### App Kill (regression — should pass today + after)

- [ ] `testMealSurvivesForceQuit` — `FoodLogService` + in-memory container
- [ ] `testWaterSurvivesForceQuit`
- [ ] `testWeightSurvivesForceQuit`
- [ ] `testUncommittedImageAnalysisLostOnKill`

### Reinstall Restore (Phase 4)

- [x] `testReinstallSameAccountRestoresNutritionHistory` — `AccountRestoreEndToEndTests`
- [x] `testReinstallSameAccountJourneyCanRebuild` — `AccountRestoreEndToEndTests`
- [x] `testNewDeviceLoginRestoresToday` — `AccountRestoreEndToEndTests`
- [x] `testRestoreDoesNotPullOtherUserData` — `AccountRestoreEndToEndTests`
- [x] `testOfflineFreshInstallShowsOfflineRestoreState` — `AccountRestoreEndToEndTests`
- [x] `testPartialRestoreStillAllowsMainApp` — `AccountRestoreEndToEndTests`
- [x] `testFreshInstallRestoresProfileAndRecentLogs` — `AccountInitialRestoreServiceTests`
- [ ] Manual QA on device with production Firestore before `restoreOnLoginEnabled = true`

### Cross-Device (new — Phase 5)

- [ ] `testDeviceBReceivesDeviceAMeal`
- [ ] `testDeviceBReceivesEdit`
- [ ] `testDeviceBReceivesDelete`
- [ ] `testPlanUpdatePropagates`

### Multi-User (new — Phase 1)

- [ ] `testUserBDoesNotSeeUserAFoodAfterSwitch`
- [ ] `testUserADataRestoredAfterReLogin`
- [ ] `testCoachTranscriptIsolatedByUserId`
- [ ] `testNilUserIdCoachRowsExcludedAfterMigration`

### Offline Sync (Phase 3)

- [x] `testOfflineMutationRemainsPendingAfterStoreReopen` — `AccountSyncMutationIntegrationTests`
- [x] `testMarkFailedAppliesRetryBackoff` / `testUploaderLeavesFailedMutationRetryable` — outbox + uploader retry
- [x] `testFoodEditMarksPendingUploadAndEnqueuesMutation` — local-first + outbox
- [x] `testUploadFoodThenFetchFromRemoteStore` — remote contract round-trip (`AccountSyncRemoteIntegrationTests`)
- [ ] `testOfflineLogUploadsOnReconnect` — manual QA / future NWPathMonitor trigger (lifecycle retry covers partial case)

### Auth Lifecycle

- [ ] `testFreshInstallClearsStaleAuth` — existing behavior
- [ ] `testTokenRefreshForSync` — `AuthManager.idToken(forceRefresh: true)`

---

## 10. Cursor Implementation Workflow

Execute phases in order. **Do not skip Phase 1.**

### Workflow per phase

```
1. Read ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md + this file
2. Create feature branch: feature/account-sync-phase-N
3. Implement smallest vertical slice
4. Add tests first where behavior is new
5. Run: xcodebuild test -scheme "Fitness Coach" -only-testing:...
6. Run: cd functions && npm test (for rules)
7. Manual QA checklist from §9
8. PR with acceptance criteria copy-paste
```

### Suggested Cursor prompts per phase

**Phase 1:**
> Add `ownerUID` to FoodEntryEntity, WaterEntryEntity, WeightEntryEntity, DailyLogEntity with FormaSchemaV7 lightweight migration. Set ownerUID from AuthManager on all writes in FoodLogService/WaterLogService/WeightLogService. Filter all fetches by current UID. Fix CoachChatTranscriptPersistenceRepository to exclude nil userId when filtering. Add MultiUserNutritionIsolationTests.

**Phase 2:**
> Add CloudNutritionDocuments.swift DTOs and FirestoreDailyLogSyncClient following FirestoreCloudUserProfileStore patterns. Expand firestore.rules for dailyLogs, foodEntries, waterEntries, weightEntries, syncMetadata. Add emulator tests.

**Phase 3:**
> Implemented: `AccountSyncOutboxStore`, `AccountSyncUploader`, `AccountSyncPuller`, `AccountSyncCoordinator`. Hook `FitnessActionCenter` mutations via `AccountLocalMutationTracker`. See `Docs/AccountPersistence/PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md`.

**Phase 4:**
> Implemented: `AccountRestoreCoordinator`, blocking restore UI, tab awareness, background backfill. See `Docs/AccountPersistence/PHASE_4_FRESH_INSTALL_RESTORE.md`. Enable `restoreOnLoginEnabled` only after `xcodebuild test` + manual QA.

**Phase 5:**
> Foreground pull on UIApplication.willEnterForeground. Cross-device integration tests with shared mock Firestore.

**Phase 6:**
> Wire SettingsDeleteDataActionHandler to delete local SwiftData, Firestore collections, Firebase Auth user.

---

## 11. Privacy Defaults (Implementation)

When implementing sync, default behavior for signed-in users:

| Data | Default |
|------|---------|
| Food/water/weight/dailyLogs | Sync ON |
| Profile | Sync ON (existing) |
| Coach chat | Sync OFF until Phase 5b + setting |
| Meal images | Never upload raw |
| Health summaries | Existing consent flow unchanged |
| Theme | Local only |

Add Settings toggle: **"Sync meal history across devices"** (ON by default) — allows opt-out without disabling profile sync.

---

## 12. Acceptance Criteria (Final Feature)

Copy into Phase 6 PR description:

1. Reinstall + same Google account → profile, plan, food, water, weight, Journey restored within 60s on Wi‑Fi (30-day window blocking).
2. Second device → same history after foreground sync.
3. Force kill → committed logs remain (regression tests green).
4. Uncommitted coach image analysis → safely discarded with no orphan food row.
5. User A → logout → User B login → zero A food rows in queries.
6. User A login again → A data from cloud, not B's.
7. Delete food on device A → gone on device B after sync.
8. Edit food on A → updated on B.
9. Offline log → uploads within 30s of reconnect (foreground).
10. Firestore rules tests pass for cross-user denial.
11. Migration from V6 local-only → V7 uploads once with user confirm if unowned data exists.
12. Account delete removes local + `users/{uid}` nutrition collections + profile + Auth user.

---

## 13. Files to Create (Summary)

| New file | Phase |
|----------|-------|
| `Application/Sync/AccountSyncEngine.swift` | 3 |
| `Application/Restore/AccountRestoreCoordinator.swift` | 4 |
| `Application/Sync/AccountDataNamespaceService.swift` | 1 |
| `Application/Sync/SyncOutboxStore.swift` | 3 |
| `Application/Sync/AccountMigrationService.swift` | 1 |
| `Infrastructure/Cloud/CloudNutritionDocuments.swift` | 2 |
| `Infrastructure/Cloud/FirestoreDailyLogSyncClient.swift` | 2 |
| `Infrastructure/Cloud/FirestoreFoodEntrySyncClient.swift` | 2 |
| `Infrastructure/Cloud/FirestoreWaterEntrySyncClient.swift` | 2 |
| `Infrastructure/Cloud/FirestoreWeightEntrySyncClient.swift` | 2 |
| `Infrastructure/Cloud/FirestoreSyncMetadataClient.swift` | 2 |
| `Domain/Sync/SyncMutation.swift` | 3 |
| `Features/Auth/Views/AccountRestoreView.swift` | 4 |
| `Fitness CoachTests/MultiUserNutritionIsolationTests.swift` | 1 |
| `Fitness CoachTests/AccountRestoreEndToEndTests.swift` | 4 |
| `Fitness CoachTests/NutritionSyncEngineTests.swift` | 3 |

---

## 14. Files to Modify (Summary)

| File | Phases |
|------|--------|
| `FormaModelMigration.swift` | 1, 3 |
| `Entities/*.swift` (8 active) | 1 |
| `FoodLogService.swift`, `WaterLogService.swift`, `WeightLogService.swift`, `DailyLogService.swift` | 1, 3 |
| `FitnessActionCenter.swift` | 1, 3 |
| `CoachChatTranscriptPersistenceRepository.swift` | 1 |
| `AuthGateCoordinator.swift` | 1, 4 |
| `ProfileBootstrapCoordinatorService.swift` | 4 |
| `AppContainer.swift` | 3, 4 |
| `FormaAbTest.swift` | 1, 3 |
| `firestore.rules` | 2 |
| `SettingsDeleteDataActionHandler.swift` | 6 |

---

*End of implementation plan. Phases 2–4 implemented; Phases 5–6 pending. Phase 4 rollout gated by `restoreOnLoginEnabled`.*
