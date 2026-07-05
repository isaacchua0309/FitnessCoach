# Account Persistence — Phase Readiness

**Generated:** 2026-07-04  
**Branch:** `feature/account-persistence-restore`  
**Status:** Readiness summary only — no application code changes in this deliverable  
**Sources:** `../ContextPackets/USER_DATA_STORAGE_CONTEXT_PACKET.md`, `../ContextPackets/ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`, `ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`

---

## 1. Current Data-Loss Problem Summary

The app persists most user activity locally in SwiftData (`FormaSchemaV6` in `FormaModelMigration.swift`) and only partially in Firestore. After delete/reinstall or login on a new device, users lose almost all logging history even when signing into the same Firebase account.

### What survives account restore today

| Data | Storage | Restore path |
|------|---------|--------------|
| Profile + plan targets | `UserProfileEntity` + Firestore `users/{uid}/profile/current` | `ProfileBootstrapService.resolve(uid:)` → `FirestoreCloudUserProfileStore.fetch(uid:)` → `UserProfileService.restoreProfile(from:ownerUID:)` |
| Firebase Auth session | SDK keychain | Google sign-in; fresh install clears stale session via `AuthManager.clearPersistedSessionIfFreshInstall()` / `AuthInstallPolicy` |
| Health summaries (opt-in) | Firestore `healthDaily`, `healthWorkouts`, etc. | **Upload-only** — `HealthSummarySyncService` never reads remote health as source of truth |

### What is lost on reinstall / new device

All of the following live in SwiftData, UserDefaults, or Application Support — wiped by iOS on app deletion:

| Domain | Entity / component | Service |
|--------|-------------------|---------|
| Food logs | `FoodEntryEntity` | `FoodLogService` |
| Water logs | `WaterEntryEntity` | `WaterLogService` |
| Weight logs | `WeightEntryEntity` | `WeightLogService` |
| Daily rollups | `DailyLogEntity` | `DailyLogService` |
| Daily AI reviews | `DailyReviewEntity` | `ReviewService` |
| Coach chat | `CoachChatTranscriptMessageEntity` | `SwiftDataCoachChatTranscriptStore` / `CoachChatTranscriptPersistenceRepository` |
| Coach timeline | `CoachTimelineEventEntity` | `SwiftDataCoachTimelineStore` |
| Journey inputs | Derived — no durable model | `JourneyModel.loadProgress()` reads `dailyLogReader`, `weightLogReader` |
| Health cache | JSON under `Forma/HealthCache/{userID}/` | `LocalHealthCacheStore` |
| Theme, consent flags | UserDefaults | `ThemeStore`, `HealthSummarySyncConsentStore` |

**User-visible outcome after reinstall + sign-in:** Plan tab may show restored targets, but Today, Journey, Coach common foods, and weight trend are empty until the user logs again.

### Compounding local-only risks (same device, no reinstall)

| Issue | Evidence |
|-------|----------|
| Nutrition rows not UID-scoped | `FoodEntryEntity` has no `ownerUID` field (only `id`, `dailyLogId`, nutrition fields) |
| Logout preserves all SwiftData | `AuthLogoutPolicy.prepareForSignOut` clears `ProfileCloudSyncStore` only; `SignOutHygieneTests.testSignOutPolicyPreservesLocalProfile` asserts profile survives |
| Coach nil-userId leakage | `CoachChatTranscriptPersistenceRepository.fetchEntities` lines 79–81: `entity.userId == nil` → `return true` for any signed-in user |
| Account delete stub | `SettingsDeleteDataActionHandler.perform()` returns `.notImplemented`; `SettingsDataDeletionCapability.isImplemented` is false |
| AB flag unwired | `FormaAbTest.Auth.deletesLocalProfileOnSignOut = true` exposed via `AuthLogoutPolicy.deletesLocalProfileOnSignOut`, but sign-out path does not wipe SwiftData |

---

## 2. Why Phase 1 Must Be UID Hardening Before Firestore Sync

### The core failure mode

If Firestore upload or sync is implemented **before** local UID isolation is correct, the app can **upload User A's device-local meals, water, weight, and coach history to User B's Firebase account** (`users/{userB}/dailyLogs/...`).

This happens because:

1. **Writes are device-global today.** `FoodLogService.addFoodEntry`, `WaterLogService.addWater`, and `WeightLogService.logWeight` insert into SwiftData with no `ownerUID` and no UID predicate on reads.
2. **Logout does not clear nutrition data.** User A logs out; User B signs in on the same device; A's rows remain in the SQLite store and are still returned by unscoped fetches.
3. **Coach rows with `userId == nil` are shared.** Any signed-in user sees orphan transcript entities.
4. **Only profile has ownership metadata.** `UserProfileEntity.ownerUID` exists and `ProfileBootstrapService.resolve(uid:)` checks it for routing — but food/water/weight services ignore UID entirely.
5. **Legacy unowned rows exist.** Pre-auth or pre-upgrade rows may have no owner; blind upload would attach them to whoever signs in next.

### Required invariant before any Firestore write

> **No nutrition, weight, coach, or review data may be written to Firestore until every local read/write is scoped to `AuthManager` / `AuthUIDCache` current UID, account-switch quarantine is implemented, and multi-user isolation tests pass.**

Phase 1 establishes this invariant. Phases 2–6 depend on it.

### What Phase 1 delivers (minimum)

- `FormaSchemaV7` with `ownerUID` (+ sync metadata fields) on all 8 active `@Model` types
- Set `ownerUID` on every mutation via `FitnessActionCenter` and log services
- Filter all fetches by current UID in `FoodLogService`, `WaterLogService`, `WeightLogService`, `DailyLogService`, `ReviewService`
- Fix `CoachChatTranscriptPersistenceRepository` — exclude `userId == nil` when filtering; require `userId` on insert in `SwiftDataCoachChatTranscriptStore`
- `AccountDataNamespaceService` — delete/quarantine rows where `ownerUID != newUID` on account switch
- `AccountMigrationService.runV7Backfill()` — attach legacy rows to profile `ownerUID` with user confirmation for unowned data
- Wire namespace prep into `AuthGateCoordinator.reconcileSignedInProfile`

**Phase 1 does not add Firestore clients, outbox, or upload calls.**

---

## 3. Implementation Phase Order

Execute in strict sequence. Do not skip Phase 1.

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6
 UID         Firestore    Local-first   Fresh install  Cross-device  Account
 hardening   schema +     sync engine   restore        sync          delete /
             rules        + outbox                     + optional    privacy
                                         pipeline       collections
```

| Phase | Name | Goal | Cloud writes? |
|-------|------|------|---------------|
| **1** | UID hardening | Stop cross-user local leakage; add `ownerUID` + V7 schema | **No** |
| **2** | Firestore schema/rules | DTOs, clients, `firestore.rules`, emulator tests | Clients only — no iOS sync hook yet |
| **3** | Local-first sync engine | Outbox, push/pull, offline retry, tombstones | **Yes** — behind `FormaAbTest.Sync.nutritionSyncEnabled` |
| **4** | Fresh install restore | `AccountRestoreCoordinator` after `ProfileBootstrapService.resolve` | Read from Firestore; write to scoped SwiftData |
| **5** | Cross-device sync | Foreground pull; optional coach/reviews sync | Yes |
| **6** | Account delete/privacy | `SettingsDeleteDataActionHandler`, remote wipe, Auth delete | Delete operations |

### Phase exit gates

| Phase | Must pass before next phase |
|-------|------------------------------|
| 1 → 2 | `MultiUserNutritionIsolationTests`: User B sees zero User A food rows after account switch |
| 2 → 3 | Emulator: owner R/W own docs; User A denied User B docs |
| 3 → 4 | Offline log uploads on reconnect; `mutationId` idempotency |
| 4 → 5 | Reinstall integration test: Today populated from mock cloud |
| 5 → 6 | Cross-device edit/delete propagation |
| 6 → ship | Account delete clears local + `users/{uid}/**` + Auth user |

---

## 4. Risk List

| Risk | Phase | Mitigation |
|------|-------|------------|
| **Upload User A data to User B account** | 2–3 | **Phase 1 required first**; attach-history confirmation for unowned rows; validate `userId == auth.uid` in rules |
| Duplicate Firestore documents on retry | 3 | `mutationId` idempotency; merge guard on push |
| 1MB Firestore document limit | 2 | Subcollections `dailyLogs/{date}/foodEntries/{id}` — never embed unbounded arrays |
| Firestore cost on full history backfill | 4 | Paginated pull; 30-day blocking window; background for older days |
| Long restore blocking UI | 4 | Progressive restore; target ≤60s on Wi‑Fi for recent window |
| SwiftData V7 migration failure | 1 | Lightweight migration with defaults; fixture tests on V6 stores |
| Coach image storage cost | 5 | Text-only sync default; exclude `fullImageJPEG` |
| Health rules deployment drift | 2 | Single `firestore.rules` PR for nutrition + health per `HEALTH_SUMMARY_SYNC_CONTRACT.md` |
| Conflict on simultaneous edits | 3, 5 | LWW on `updatedAt`; `mutationId` dedup |
| Breaking offline-only users | 3 | Local-first unchanged; sync only when signed in + flag enabled |
| Weight bad data persists | 1 | Add `deleteWeightEntry` before sync tombstones |
| `deletesLocalProfileOnSignOut` misleading | 1 | Wire selective wipe or document/remove flag |

---

## 5. Files Likely Modified in Each Phase

### Phase 1 — UID hardening

**New:**
- `Fitness Coach/Application/Sync/AccountDataNamespaceService.swift`
- `Fitness Coach/Application/Sync/AccountMigrationService.swift`
- `Fitness CoachTests/MultiUserNutritionIsolationTests.swift`
- `Fitness CoachTests/CoachTranscriptUserIsolationTests.swift`

**Modified:**
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelMigration.swift` — add `FormaSchemaV7`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelContainer.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaSwiftDataMigrationGate.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/FoodEntryEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/WaterEntryEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/WeightEntryEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/DailyLogEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/DailyReviewEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/UserProfileEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/CoachChatTranscriptMessageEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/CoachTimelineEventEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/*+Mapping.swift`
- `Fitness Coach/Data/Repositories/FoodLogService.swift`
- `Fitness Coach/Data/Repositories/WaterLogService.swift`
- `Fitness Coach/Data/Repositories/WeightLogService.swift`
- `Fitness Coach/Data/Repositories/DailyLogService.swift`
- `Fitness Coach/Data/Repositories/ReviewService.swift`
- `Fitness Coach/Data/Repositories/CoachChatTranscriptPersistenceRepository.swift`
- `Fitness Coach/Application/Services/SwiftDataCoachChatTranscriptStore.swift`
- `Fitness Coach/Application/UseCases/FitnessActionCenter.swift`
- `Fitness Coach/Features/Auth/Coordinator/AuthGateCoordinator.swift`
- `Fitness Coach/App/Routing/AppRouteResolver.swift` (`AuthLogoutPolicy`)
- `Fitness Coach/Configuration/FormaAbTest.swift`
- `Fitness CoachTests/SignOutHygieneTests.swift`

### Phase 2 — Firestore schema/rules

**New:**
- `Fitness Coach/Infrastructure/Cloud/CloudNutritionDocuments.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreDailyLogSyncClient.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreFoodEntrySyncClient.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreWaterEntrySyncClient.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreWeightEntrySyncClient.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreSyncMetadataClient.swift`
- `functions/test/nutritionSyncContract.test.ts`

**Modified:**
- `firestore.rules`
- `firebase.json` (emulator config if needed)

**Pattern to follow:** `FirestoreCloudUserProfileStore.swift` (`fetch`, `save` → `users/{uid}/profile/current`)

### Phase 3 — Local-first sync engine

**New:**
- `Fitness Coach/Application/Sync/SyncOutboxStore.swift`
- `Fitness Coach/Application/Sync/AccountSyncEngine.swift`
- `Fitness Coach/Application/Sync/NetworkSyncTrigger.swift`
- `Fitness Coach/Domain/Sync/SyncMutation.swift`
- `Fitness Coach/Domain/Sync/SyncStatus.swift`
- `Fitness CoachTests/NutritionSyncEngineTests.swift`
- `Fitness CoachTests/OfflineFoodLogSyncTests.swift`

**Modified:**
- `Fitness Coach/Application/UseCases/FitnessActionCenter.swift` — post-mutation outbox enqueue
- `Fitness Coach/Data/Repositories/FoodLogService.swift` — `deletedAt` tombstones, sync fields
- `Fitness Coach/Data/Repositories/WaterLogService.swift`
- `Fitness Coach/Data/Repositories/WeightLogService.swift`
- `Fitness Coach/Data/Repositories/DailyLogService.swift`
- `Fitness Coach/App/AppContainer.swift` — engine DI, lifecycle
- `Fitness Coach/Configuration/FormaAbTest.swift` — `Sync.nutritionSyncEnabled`

### Phase 4 — Fresh install restore

**New:**
- `Fitness Coach/Application/Sync/AccountRestoreCoordinator.swift`
- `Fitness Coach/Features/Restore/RestoreProgressView.swift`
- `Fitness CoachTests/ReinstallRestoreIntegrationTests.swift`

**Modified:**
- `Fitness Coach/Application/UseCases/ProfileBootstrapService.swift`
- `Fitness Coach/App/Routing/ProfileBootstrapCoordinator.swift`
- `Fitness Coach/Features/Auth/Coordinator/AuthGateCoordinator.swift`
- `Fitness Coach/App/AppContainer.swift`
- `Fitness Coach/Features/Journey/Model/JourneyModel.swift` — verify reload after restore (likely observer-only)

### Phase 5 — Cross-device sync

**Modified:**
- `Fitness Coach/Application/Sync/AccountSyncEngine.swift` — foreground pull
- `Fitness Coach/Features/Settings/` — sync status UI, opt-out toggle
- Optional: coach/review Firestore clients and `ReviewService` cloud path

### Phase 6 — Account delete/privacy

**New:**
- `Fitness Coach/Application/Sync/AccountDeletionService.swift`

**Modified:**
- `Fitness Coach/Features/Settings/Model/SettingsDeleteDataActionHandler.swift`
- `Fitness Coach/Features/Settings/Model/SettingsDataDeletionCapability.swift`
- `Fitness Coach/Application/Services/Auth/AuthManager.swift` — `user.delete()`
- `Fitness Coach/Application/Sync/AccountDataNamespaceService.swift` — `wipeAll()`
- Reuse: `HealthSummarySyncService.deleteRemoteHealthSummaries()`

---

## 6. Test Strategy

### Principles

1. **Phase 1 tests block all cloud work** — no Phase 2+ merge without isolation green.
2. **Regression tests run every phase** — app-kill persistence must never break.
3. **Emulator tests gate Firestore** — rules before iOS upload.
4. **Integration tests use in-memory SwiftData + mock Firestore** — no production project writes.

### By phase

| Phase | Test suite | Key assertions |
|-------|------------|----------------|
| **1** | `MultiUserNutritionIsolationTests`, `CoachTranscriptUserIsolationTests`, extended `SignOutHygieneTests` | User B queries return zero User A food/water/weight; coach nil-userId excluded; V7 backfill idempotent |
| **2** | `functions/test/nutritionSyncContract.test.ts`, DTO round-trip unit tests | Owner R/W; cross-user deny; `userId != uid` write rejected |
| **3** | `NutritionSyncEngineTests`, `OfflineFoodLogSyncTests` | Offline log → upload; `mutationId` no duplicate; delete tombstone |
| **4** | `ReinstallRestoreIntegrationTests` | Fresh SwiftData + mock cloud → Today meals restored; Journey weight trend populated |
| **5** | Cross-device integration tests | Device A log → Device B foreground → B sees entry; edit/delete propagate |
| **6** | Account deletion tests | Local wipe + Firestore `users/{uid}/**` removed + Auth user deleted |

### Regression (all phases — must stay green)

| Test | Classes |
|------|---------|
| Meal survives force quit | `FoodLogService`, `TodayModel` |
| Water survives force quit | `WaterLogService` |
| Weight survives force quit | `WeightLogService` |
| Uncommitted image analysis lost on kill | `CoachModel`, `ImageAnalysisSessionStore` |
| Fresh install clears stale auth | `AuthManager`, `AuthInstallPolicy` |

### Commands

```bash
# Phase 1 isolation (required gate)
xcodebuild test -scheme "Fitness Coach" \
  -only-testing:Fitness\ CoachTests/MultiUserNutritionIsolationTests

# Phase 4 restore
xcodebuild test -scheme "Fitness Coach" \
  -only-testing:Fitness\ CoachTests/ReinstallRestoreIntegrationTests

# Phase 2 rules
cd functions && npm test
```

---

## 7. Explicit Pre-Sync Policy

> **DO NOT implement cloud sync, Firestore writes, sync outbox, or restore pull until Phase 1 local UID isolation is complete and tested.**

Specifically, before any `FirestoreDailyLogSyncClient` (or similar) is wired into mutation paths:

1. Every active SwiftData entity that holds user data must have `ownerUID` (or required `userId` for coach entities).
2. Every read in `FoodLogService`, `WaterLogService`, `WeightLogService`, `DailyLogService`, and `ReviewService` must filter by current Firebase UID.
3. `CoachChatTranscriptPersistenceRepository.fetchEntities` must **not** return `userId == nil` rows when a user is signed in.
4. `AccountDataNamespaceService` must quarantine or delete rows belonging to a prior UID on account switch.
5. `MultiUserNutritionIsolationTests` must demonstrate that **User A's local meals cannot appear in User B's queries** — and by extension, must not be eligible for upload to `users/{userB}/...`.

**Phase 1 is required to avoid uploading User A's data to User B's Firebase account.** This is the single most critical safety gate in the entire feature.

---

## 8. Readiness Checklist (Before Phase 1 Coding)

- [x] Storage audit complete (`../ContextPackets/USER_DATA_STORAGE_CONTEXT_PACKET.md`)
- [x] Restore behavior documented (`../ContextPackets/ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`)
- [x] Phased plan defined (`ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`)
- [x] Execution map available (`ACCOUNT_PERSISTENCE_EXECUTION_MAP.md`)
- [ ] Phase 1 branch created
- [ ] `FormaSchemaV7` migration spike on V6 fixture store
- [ ] `MultiUserNutritionIsolationTests` scaffold written (fail against current code)

**First coding PR scope:** Phase 1 only — UID hardening, no Firestore writes, no sync engine.

---

*End of phase readiness summary. No application code was modified.*
