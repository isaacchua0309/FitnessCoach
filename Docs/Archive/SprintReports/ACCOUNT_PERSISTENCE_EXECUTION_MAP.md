# Account Persistence — Execution Map

**Branch:** `feature/account-persistence-restore`  
**Generated:** 2026-07-04  
**Status:** Planning only — no application code changes in this deliverable  
**Sources:** `../ContextPackets/USER_DATA_STORAGE_CONTEXT_PACKET.md`, `../ContextPackets/ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`, `ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`

---

## Purpose

This map is the ordered execution guide for account persistence and restore. It covers the full feature (UID hardening → cloud schema → sync → restore → cross-device → deletion), but **this branch deliverable is the map only**. Implementation proceeds phase-by-phase on this branch (or phase-scoped sub-branches) without skipping Phase 1.

**Out of scope for the first coding slice:** real-time cross-device sync polish, account delete, and export — those are later phases.

---

## 1. Current Highest-Risk Gaps

Ranked by user impact and privacy exposure. All items are **Confirmed** in the storage audit unless noted.

| Rank | Gap | Why it is highest risk | Blocks restore? |
|------|-----|------------------------|-----------------|
| **R1** | Nutrition logs have no cloud backup | Food, water, weight, daily rollups, daily reviews, coach chat/timeline are SwiftData-only. Reinstall and new device = permanent loss. | **Yes** — core product failure |
| **R2** | Nutrition data not UID-scoped | `FoodEntryEntity`, `WaterEntryEntity`, `WeightEntryEntity`, `DailyLogEntity` have no `ownerUID`. User B on a shared device can see User A's logs. | **Yes** — must fix before any upload |
| **R3** | Logout does not wipe or quarantine local user data | `AuthLogoutPolicy` clears session metadata only; `SignOutHygieneTests` expect profile survives. Cross-user leakage persists after sign-out. | Indirect — unsafe account switch |
| **R4** | Coach rows with `userId == nil` match all users | `CoachChatTranscriptPersistenceRepository.fetchEntities` returns nil-userId rows for any signed-in user. | Indirect — chat leakage |
| **R5** | Journey/progress is derived-only | `JourneyModel` reads local logs + health cache; no durable model. Empty after reinstall even if profile restores. | **Yes** — user expectation gap |
| **R6** | Health Firestore rules missing in repo | `firestore.rules` allows profile only; client writes `healthDaily` etc. Rules may fail in prod or drift from deployed state. | No for nutrition — yes for health sync |
| **R7** | Account delete not implemented | `SettingsDeleteDataActionHandler` → `.notImplemented`. GDPR / App Store compliance risk. | No for restore MVP |
| **R8** | `deletesLocalProfileOnSignOut = true` unwired | `FormaAbTest.Auth.deletesLocalProfileOnSignOut` exists but sign-out path ignores it. Engineering and privacy confusion. | Indirect |
| **R9** | Weight entries cannot be deleted | No `deleteWeightEntry` in `WeightLogService`. Bad data persists locally and would propagate once synced. | Indirect — sync quality |
| **R10** | Uploading unowned legacy rows to wrong account | Pre-auth or multi-user residue without `ownerUID` could attach to wrong Firebase UID without confirmation. | **Yes** — data integrity |

### Immediate pre-sync invariant

**Do not upload nutrition data to Firestore until Phase 1 (UID hardening + namespace quarantine) is complete and tested.** Uploading before R2/R3/R4 are fixed would amplify leakage into the cloud.

---

## 2. Exact Implementation Order

Execute strictly in order. Each phase has a gate before the next starts.

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6
 UID         Cloud       Sync        Restore     Cross-       Delete/
 hardening   schema +    engine +    pipeline    device       export
             rules       outbox                    sync
```

### Phase 1 — UID hardening and account-switch safety (P0, no cloud writes)

**Goal:** Stop cross-user local leakage; prepare entities for sync metadata.

| Step | Action | Gate |
|------|--------|------|
| 1.1 | Add `FormaSchemaV7` optional fields to all 8 active entities (`ownerUID`, sync metadata) | Lightweight migration compiles |
| 1.2 | Set `ownerUID` from `AuthManager.currentUID` on every write in log services + `FitnessActionCenter` | New rows always scoped |
| 1.3 | Filter all fetches by current UID in `FoodLogService`, `WaterLogService`, `WeightLogService`, `DailyLogService`, `ReviewService` | Queries return empty for wrong user |
| 1.4 | Fix coach nil-userId filter; require `userId` on insert in `SwiftDataCoachChatTranscriptStore` | Coach isolation tests pass |
| 1.5 | Implement `AccountDataNamespaceService` (quarantine/delete rows where `ownerUID != newUID`) | Account switch safe |
| 1.6 | Wire namespace prep into `AuthGateCoordinator.reconcileSignedInProfile` on UID change | Integration test pass |
| 1.7 | Implement `AccountMigrationService.runV7Backfill()` — attach legacy rows to profile `ownerUID` | Backfill idempotent |
| 1.8 | Resolve or wire `FormaAbTest.Auth.deletesLocalProfileOnSignOut` (implement selective wipe or remove flag) | Sign-out contract documented |
| 1.9 | Add `deleteWeightEntry` API (needed before sync tombstones) | Weight delete test pass |

**Phase 1 exit criteria:** User B cannot read User A food/water/weight/coach after account switch; all new writes carry `ownerUID`.

---

### Phase 2 — Firestore schema, DTOs, rules (no iOS sync yet)

**Goal:** Cloud contract exists and is rule-tested before any client upload.

| Step | Action | Gate |
|------|--------|------|
| 2.1 | Define `CloudNutritionDocuments.swift` DTOs mirroring SwiftData entities | Round-trip encode/decode tests |
| 2.2 | Implement Firestore clients: `FirestoreDailyLogSyncClient`, `FirestoreFoodEntrySyncClient`, `FirestoreWaterEntrySyncClient`, `FirestoreWeightEntrySyncClient`, `FirestoreSyncMetadataClient` | Unit tests with mock Firestore |
| 2.3 | Expand `firestore.rules` for nutrition + `syncMetadata` + health collections per `HEALTH_SUMMARY_SYNC_CONTRACT.md` | Emulator tests pass |
| 2.4 | Add `functions/test/nutritionSyncContract.test.ts` (or dedicated rules test file) | CI green |
| 2.5 | Add feature flag stub `FormaAbTest.Sync.nutritionSyncEnabled = false` | No accidental upload |

**Phase 2 exit criteria:** Emulator proves owner R/W and cross-user denial; DTOs stable; rules deployable in one PR.

---

### Phase 3 — Local-first sync engine and outbox

**Goal:** Signed-in mutations upload; incremental pull merges; offline queue.

| Step | Action | Gate |
|------|--------|------|
| 3.1 | Add `SyncOutboxStore` (+ optional `SyncOutboxEntity`) | Enqueue/dequeue tests |
| 3.2 | Implement `AccountSyncEngine` — push pending, pull incremental, conflict LWW | Engine unit tests |
| 3.3 | Hook `FitnessActionCenter` post-mutation → outbox enqueue → background push | Meal upload test |
| 3.4 | Tombstones on delete (`deletedAt` on entity + Firestore doc) | Delete propagation test |
| 3.5 | `NetworkSyncTrigger` via `NWPathMonitor` + foreground lifecycle in `AppContainer`/`RootModel` | Offline → reconnect upload |
| 3.6 | Enable `FormaAbTest.Sync.nutritionSyncEnabled` for internal testing | Flag-gated rollout |

**Phase 3 exit criteria:** Offline log uploads on reconnect; `mutationId` prevents duplicates; edit/delete reach Firestore.

---

### Phase 4 — Fresh install / new device restore pipeline

**Goal:** Reinstall + same account restores profile **and** logging history (Journey inputs).

| Step | Action | Gate |
|------|--------|------|
| 4.1 | Implement `AccountRestoreCoordinator.beginRestore(uid:)` | Coordinator unit tests |
| 4.2 | Integrate after `ProfileBootstrapService.resolve` in `ProfileBootstrapCoordinatorService` | Bootstrap + restore sequence |
| 4.3 | Blocking pull: `syncMetadata/current`, weight entries (90d), daily logs + food/water (30d) | Today populated after restore |
| 4.4 | Write pulled rows to SwiftData with `ownerUID`, `syncStatus = synced` | Journey weight chart works |
| 4.5 | Add `RestoreProgressView` + routing states in `AuthGateCoordinator`/`RootModel` | UX for restoring / partial / offline |
| 4.6 | Background pull for older days + optional coach (non-blocking) | No UI block > 60s on Wi‑Fi |
| 4.7 | One-time modal for unowned legacy data: "Attach history to account?" | Prevents wrong-account upload |

**Phase 4 exit criteria:** Delete app → reinstall → sign in → Today shows restored meals from cloud; Journey streaks/weight trend populated from restored logs.

---

### Phase 5 — Cross-device sync and optional collections

**Goal:** Device B reflects Device A changes on foreground; optional coach/reviews.

| Step | Action | Gate |
|------|--------|------|
| 5.1 | Foreground pull in `AccountSyncEngine` on `UIApplication.willEnterForeground` | Cross-device meal test |
| 5.2 | Settings sync status UI + optional "Sync meal history across devices" toggle (default ON) | Opt-out works |
| 5.3 | (5b) Coach chat/timeline text sync — flag-gated, no raw images | Coach text optional |
| 5.4 | (5b) `dailyReviews` collection sync | Review narrative on second device |

**Phase 5 exit criteria:** Device A logs → Device B foreground → B sees entry; delete/edit propagate.

---

### Phase 6 — Account deletion, export, privacy copy

**Goal:** GDPR-complete delete; implement stub handlers.

| Step | Action | Gate |
|------|--------|------|
| 6.1 | `AccountDeletionService` — delete Firestore `users/{uid}/**` nutrition + profile | Remote wipe test |
| 6.2 | `AuthManager` Firebase Auth `user.delete()` | Auth removal |
| 6.3 | `AccountDataNamespaceService.wipeAll()` local SwiftData + health cache | Local wipe test |
| 6.4 | Wire `SettingsDeleteDataActionHandler`; set `SettingsDataDeletionCapability.isImplemented = true` | Settings UI works |
| 6.5 | Export handler + privacy copy in onboarding/settings | Product compliance |

**Phase 6 exit criteria:** Account delete clears local + remote + Auth user.

---

## 3. Files Likely Affected

### New files (by phase)

| File | Phase |
|------|-------|
| `Fitness Coach/Application/Sync/AccountDataNamespaceService.swift` | 1 |
| `Fitness Coach/Application/Sync/AccountMigrationService.swift` | 1 |
| `Fitness Coach/Infrastructure/Cloud/CloudNutritionDocuments.swift` | 2 |
| `Fitness Coach/Infrastructure/Cloud/FirestoreDailyLogSyncClient.swift` | 2 |
| `Fitness Coach/Infrastructure/Cloud/FirestoreFoodEntrySyncClient.swift` | 2 |
| `Fitness Coach/Infrastructure/Cloud/FirestoreWaterEntrySyncClient.swift` | 2 |
| `Fitness Coach/Infrastructure/Cloud/FirestoreWeightEntrySyncClient.swift` | 2 |
| `Fitness Coach/Infrastructure/Cloud/FirestoreSyncMetadataClient.swift` | 2 |
| `Fitness Coach/Application/Sync/SyncOutboxStore.swift` | 3 |
| `Fitness Coach/Application/Sync/AccountSyncEngine.swift` | 3 |
| `Fitness Coach/Application/Sync/NetworkSyncTrigger.swift` | 3 |
| `Fitness Coach/Domain/Sync/SyncMutation.swift` | 3 |
| `Fitness Coach/Domain/Sync/SyncStatus.swift` | 3 |
| `Fitness Coach/Application/Sync/AccountRestoreCoordinator.swift` | 4 |
| `Fitness Coach/Features/Restore/RestoreProgressView.swift` | 4 |
| `Fitness Coach/Application/Sync/AccountDeletionService.swift` | 6 |
| `functions/test/nutritionSyncContract.test.ts` | 2 |

### Modified files (by phase)

| File | Phases | Change summary |
|------|--------|----------------|
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelMigration.swift` | 1, 3 | `FormaSchemaV7`, migration stages |
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelContainer.swift` | 1 | Point to V7 schema |
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaSwiftDataMigrationGate.swift` | 1 | V7 gate flag |
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/*.swift` (8 active) | 1 | `ownerUID`, sync fields |
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/*+Mapping.swift` | 1, 3 | Map new fields |
| `Fitness Coach/Data/Repositories/FoodLogService.swift` | 1, 3 | UID filter, sync hooks, tombstones |
| `Fitness Coach/Data/Repositories/WaterLogService.swift` | 1, 3 | Same |
| `Fitness Coach/Data/Repositories/WeightLogService.swift` | 1, 3 | Same + delete API |
| `Fitness Coach/Data/Repositories/DailyLogService.swift` | 1, 3 | UID filter, rollup sync |
| `Fitness Coach/Data/Repositories/ReviewService.swift` | 1, 5 | UID filter; optional cloud |
| `Fitness Coach/Data/Repositories/CoachChatTranscriptPersistenceRepository.swift` | 1 | Remove nil-userId passthrough |
| `Fitness Coach/Application/Services/SwiftDataCoachChatTranscriptStore.swift` | 1 | Require userId on insert |
| `Fitness Coach/Application/UseCases/FitnessActionCenter.swift` | 1, 3 | Set ownerUID; enqueue sync |
| `Fitness Coach/Application/UseCases/ProfileBootstrapService.swift` | 4 | Hand off to restore coordinator |
| `Fitness Coach/Features/Auth/Coordinator/AuthGateCoordinator.swift` | 1, 4 | Namespace prep; restore routing |
| `Fitness Coach/App/Routing/ProfileBootstrapCoordinator.swift` | 4 | Restore integration |
| `Fitness Coach/App/Routing/AppRouteResolver.swift` (`AuthLogoutPolicy`) | 1 | Sign-out wipe contract |
| `Fitness Coach/App/AppContainer.swift` | 3, 4 | Sync engine DI, lifecycle |
| `Fitness Coach/Configuration/FormaAbTest.swift` | 1, 3 | Sync flags |
| `Fitness Coach/Features/Settings/Model/SettingsDeleteDataActionHandler.swift` | 6 | Implement delete |
| `Fitness Coach/Features/Journey/Model/JourneyModel.swift` | 4 | Verify reload after restore (likely no schema change) |
| `firestore.rules` | 2 | Nutrition + health rules |
| `firebase.json` | 2 | Emulator config if needed |

### Test files (new or extended)

| File | Phase |
|------|-------|
| `Fitness CoachTests/MultiUserNutritionIsolationTests.swift` | 1 |
| `Fitness CoachTests/CoachTranscriptUserIsolationTests.swift` | 1 |
| `Fitness CoachTests/SignOutHygieneTests.swift` | 1 (extend) |
| `Fitness CoachTests/NutritionSyncEngineTests.swift` | 3 |
| `Fitness CoachTests/OfflineFoodLogSyncTests.swift` | 3 |
| `Fitness CoachTests/ReinstallRestoreIntegrationTests.swift` | 4 |
| Cross-device tests (new suite) | 5 |

### Explicitly unchanged in early phases

| Area | Reason |
|------|--------|
| `ThemeStore` / UserDefaults theme keys | Remain local-only by design |
| `LocalHealthCacheStore` / HealthKit reads | Re-fetch per device; not nutrition SOT |
| `aiGateway` / `functions/src/index.ts` | Stateless; no server-side user DB |
| Raw meal photo upload | Never sync full JPEG by default |

---

## 4. SwiftData Schema Migration Plan

### Current state

- **Active schema:** `FormaSchemaV6` (8 `@Model` types)
- **Migration mechanism:** `FormaMigrationPlan` with lightweight stages V1→V6
- **Gate:** `FormaSwiftDataMigrationGate` (`forma.swiftdata.*` UserDefaults keys)

### Target: `FormaSchemaV7`

#### 4.1 New fields (all user-data entities)

Add optional fields with safe defaults for lightweight migration:

| Field | Type | Default / notes |
|-------|------|---------------|
| `ownerUID` | `String?` | `nil` until backfill |
| `localUpdatedAt` | `Date?` | Set on mutation |
| `cloudUpdatedAt` | `Date?` | Set after successful pull/push |
| `syncStatusRawValue` | `String?` | Default `"synced"` for legacy rows post-backfill |
| `lastSyncError` | `String?` | Optional |
| `deletedAt` | `Date?` | Tombstone for sync |
| `mutationId` | `UUID?` | New UUID per mutation |
| `entitySchemaVersion` | `Int` | Default `1` |

#### 4.2 Entity-specific changes

| Entity | Additional notes |
|--------|------------------|
| `UserProfileEntity` | `ownerUID` already exists; add sync fields only |
| `DailyLogEntity` | Add `ownerUID`; evaluate compound uniqueness `(ownerUID, date)` — may need custom migration spike in Phase 1 |
| `FoodEntryEntity`, `WaterEntryEntity`, `WeightEntryEntity`, `DailyReviewEntity` | Full field set above |
| `CoachChatTranscriptMessageEntity` | Require non-null `userId` on new inserts; backfill nil → session UID |
| `CoachTimelineEventEntity` | Same as coach chat |

#### 4.3 Migration stages

```
FormaSchemaV6  ──lightweight──►  FormaSchemaV7
     │                                │
     │                                ├── AccountMigrationService.runV7Backfill()
     │                                │     • ownerUID ← UserProfileEntity.ownerUID
     │                                │     • coach nil userId → sessionUID
     │                                │     • legacy syncStatus → pending (if signed in + sync enabled)
     │                                │
     └── FormaSwiftDataMigrationGate sets V7 complete flag
```

#### 4.4 Backfill rules (cohorts)

| Cohort | Behavior |
|--------|----------|
| Signed-in user, profile has `ownerUID` | Backfill all nil-owner rows to that UID |
| Local logs, no profile / no `ownerUID` | **Do not upload** until user confirms attach dialog |
| Coach nil `userId` rows | Assign current UID or delete orphaned rows |
| Multi-user device residue | `AccountDataNamespaceService` quarantines rows where `ownerUID != currentUID` on login |

#### 4.5 Optional new entities (Phase 3)

| Entity | Purpose |
|--------|---------|
| `SyncOutboxEntity` | Persistent mutation queue |
| `SyncCursorEntity` | Per-collection `lastPulledAt` (alternative: store in UserDefaults or `syncMetadata` only) |

#### 4.6 Rollback (SwiftData)

- Feature flag `FormaAbTest.Sync.nutritionSyncEnabled` disables upload/pull; local V7 fields are inert
- V7 lightweight migration is **not reversible** without app reinstall — mitigate with thorough migration tests on V6 fixture stores before release
- Keep `FormaSchemaV6` types in migration file for forward-only path (existing pattern)

---

## 5. Firestore Schema Plan

### Existing (keep unchanged)

```
users/{uid}/
  profile/current                    # CloudUserProfileDocument — EXISTS
  healthDaily/{yyyy-MM-dd}           # Consent-gated — EXISTS (upload-only today)
  healthWorkouts/{workoutId}         # EXISTS
  healthRecovery/{yyyy-MM-dd}        # EXISTS
  healthWeeklyReviews/{weekId}     # EXISTS
  healthSyncMetadata/current       # EXISTS
```

### New (nutrition + restore)

```
users/{uid}/
  syncMetadata/current               # NEW — cursors, schemaVersion, deviceId
  dailyLogs/{yyyy-MM-dd}             # NEW — rollup doc (DailyLogEntity mirror)
    foodEntries/{foodEntryId}        # NEW — subcollection (avoid 1MB doc limit)
    waterEntries/{waterEntryId}      # NEW — subcollection
  weightEntries/{entryId}            # NEW — standalone history (UUID doc id)
  dailyReviews/{yyyy-MM-dd}          # NEW — Phase 5b, optional
  coachMessages/{messageId}          # NEW — Phase 5b, text only, no fullImageJPEG
  coachTimelineEvents/{eventId}      # NEW — Phase 5b, optional
```

### Document contracts

#### `syncMetadata/current`

| Field | Type | Purpose |
|-------|------|---------|
| `userId` | string | Must equal `{uid}` |
| `schemaVersion` | int | Start at `1` |
| `clientSchemaVersion` | int | iOS codec version |
| `lastPushedAt` | timestamp \| null | Push cursor |
| `lastPulledAt` | timestamp \| null | Pull cursor |
| `lastFullRestoreAt` | timestamp \| null | Reinstall marker |
| `deviceId` | string | Installed device id |
| `appVersion` | string | Build/version |
| `updatedAt` | timestamp | LWW |

#### `dailyLogs/{yyyy-MM-dd}`

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Same as date key |
| `userId` | string | Must equal `{uid}` |
| `localDate` | string | `yyyy-MM-dd` in user TZ |
| `timezone` | string | IANA TZ id |
| `calorieTarget`, macro targets | int/double | Frozen snapshot from plan |
| `caloriesConsumed`, `proteinConsumed`, etc. | int/double | Rollups |
| `waterConsumedMl` | int | |
| `weightKg` | double? | Day snapshot |
| `schemaVersion` | int | `1` |
| `updatedAt` | timestamp | LWW |
| `deletedAt` | timestamp? | Tombstone |
| `lastMutationId` | string | Idempotency |
| `deviceId` | string | |
| `source` | string | `ios_forma` |

#### `foodEntries/{uuid}` / `waterEntries/{uuid}`

Mirror respective SwiftData entities plus:

- `userId`, `schemaVersion`, `updatedAt`, `deletedAt`, `mutationId`, `deviceId`, `source`

Food entry includes `componentsJSON` equivalent, nutrition fields, `imageUrl` (string URL only — **no image bytes**).

#### `weightEntries/{uuid}`

Mirror `WeightEntryEntity`: `date`, `weightKg`, `note`, plus sync metadata fields.

### Design decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Food/water storage | **Subcollections** under daily log | Avoid 1MB Firestore doc limit on heavy days |
| Document IDs | UUID strings for entries; `yyyy-MM-dd` for daily logs | Match SwiftData ids; stable keys |
| Deletes | Soft delete via `deletedAt` | Pull merge + cross-device delete propagation |
| Conflicts | LWW on `updatedAt` + `mutationId` dedup | Matches existing profile merge pattern |
| Images | **Never** upload raw meal photos | Privacy + cost; chat sync text-only in Phase 5b |
| Retention | Consider 2-year cap (future compaction job) | Cost control for large histories |

### Security rules (deploy with Phase 2)

Expand `firestore.rules`:

- `isOwner(uid)` — `request.auth.uid == uid`
- `validUserId(uid)` — `request.resource.data.userId == uid`
- Apply to `syncMetadata`, `dailyLogs` (+ nested `foodEntries`, `waterEntries`), `weightEntries`
- Add health collection rules from `Docs/HealthIntelligence/HEALTH_SUMMARY_SYNC_CONTRACT.md`
- Deny writes where `userId != uid`; validate `schemaVersion` is int

### Restore read order (Phase 4)

1. `profile/current` (existing bootstrap)
2. `syncMetadata/current`
3. `weightEntries` — last 90 days
4. `dailyLogs` — last 30 days + child `foodEntries` / `waterEntries`
5. Background: older daily logs, optional coach/reviews

---

## 6. Test Plan

### 6.1 Regression — app kill (must pass today and after every phase)

| Test | Expected | Target |
|------|----------|--------|
| Log meal → kill → reopen | Meal visible | `FoodLogService`, `TodayModel` |
| Add water → kill → reopen | Water total correct | `WaterLogService` |
| Log weight → kill → reopen | Weight in history | `WeightLogService` |
| Image analysis before result → kill | No food row; session gone | `CoachModel`, `ImageAnalysisSessionStore` |
| Committed image analysis → kill | Food + chat persist | `FoodLogService`, `CoachModel.persistTranscript` |

### 6.2 Phase 1 — multi-user isolation (new)

| Test | Expected |
|------|----------|
| User A logs food → logout → User B login | B queries return **zero** A food rows |
| User A logs back in | A data visible (local if same UID, or from cloud after Phase 4) |
| Coach transcript User A vs B | Strict `userId` filter; nil rows excluded post-migration |
| V7 backfill | Legacy rows get `ownerUID` from profile; no duplicate entities |
| Sign-out hygiene | Behavior matches documented contract (preserve or wipe per flag) |

### 6.3 Phase 2 — Firestore contract (emulator)

| Test | Expected |
|------|----------|
| Owner R/W own `dailyLogs`, `foodEntries`, `weightEntries` | Allow |
| User A reads User B nutrition docs | Deny |
| Write with `userId != auth.uid` | Deny |
| DTO round-trip Swift ↔ Firestore JSON | Field parity |

### 6.4 Phase 3 — sync engine

| Test | Expected |
|------|----------|
| Offline log → reconnect | Outbox uploads; Firestore doc created |
| Retry with same `mutationId` | Idempotent — no duplicate docs |
| Edit food offline → push | Remote doc updated |
| Delete food → tombstone | `deletedAt` set locally and remotely |
| Local pending + remote older | Local pushed |
| Local pending + remote newer | Remote applied; conflict logged |

### 6.5 Phase 4 — reinstall restore

| Test | Expected |
|------|----------|
| Cloud profile + cloud logs, fresh SwiftData | Profile + Today meals restored |
| Cloud profile only | Plan restored; empty Today; copy explains rebuild |
| No cloud profile | Routes to onboarding |
| Offline reinstall | Retry UI; no crash; partial state OK |
| Journey after restore | Weight trend + streak inputs from restored logs |
| Unowned legacy attach prompt | Upload blocked until user confirms |

### 6.6 Phase 5 — cross-device

| Test | Expected |
|------|----------|
| A logs meal → B foreground | B sees meal |
| A edits → B refresh | B sees edit |
| A deletes → B refresh | Entry removed on B |
| A changes plan → B Plan tab | Targets updated (existing profile sync) |

### 6.7 Phase 6 — deletion

| Test | Expected |
|------|----------|
| Account delete | Local SwiftData wiped; Firestore `users/{uid}/**` removed; Auth user deleted |
| Health remote delete | Reuses existing health delete path |

### 6.8 Test execution commands

```bash
# iOS — phase-scoped
xcodebuild test -scheme "Fitness Coach" -only-testing:Fitness\ CoachTests/MultiUserNutritionIsolationTests
xcodebuild test -scheme "Fitness Coach" -only-testing:Fitness\ CoachTests/ReinstallRestoreIntegrationTests
xcodebuild test -scheme "Fitness Coach" -only-testing:Fitness\ CoachTests/NutritionSyncEngineTests

# Firestore rules
cd functions && npm test
```

### 6.9 Manual QA checklist (Phase 4+)

- [ ] Delete app → reinstall → Google sign-in → Today shows last 30 days of meals
- [ ] Second device login → same meal history after foreground sync
- [ ] Airplane mode log → online → appears in Firebase console under correct UID
- [ ] Switch Google account on device → prior user's meals not visible

---

## 7. Risks and Rollback Strategy

### 7.1 Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Upload User A data to User B account | Medium (pre-Phase 1) | Critical | Phase 1 gate; attach-history confirmation dialog |
| Duplicate Firestore docs on retry | Medium | Medium | `mutationId` idempotency; merge guard |
| 1MB daily log document | Low if subcollections used | High | **Subcollections** for food/water — never embed unbounded arrays |
| Firestore cost on full history backfill | Medium | Medium | Paginated pull; 30d blocking + background for rest; optional retention cap |
| Long restore blocks UI | Medium | Medium | Progressive restore; 60s Wi‑Fi target for 30-day window |
| SwiftData V7 migration failure | Low | High | Lightweight migration only; fixture tests; feature flag disables sync |
| Conflict on simultaneous edits | Low | Low | LWW on `updatedAt`; log superseded local pending |
| Health rules deployment drift | Medium | Medium | Single `firestore.rules` PR for nutrition + health |
| Coach image storage cost | Low (if text-only default) | Medium | Text-only sync; exclude `fullImageJPEG` |
| Breaking offline-only usage | Low | Low | Local-first unchanged; sync only when signed in + flag on |
| Legacy nil-owner rows uploaded incorrectly | Medium | High | Backfill + confirm dialog; `syncStatus = pending` until confirmed |

### 7.2 Rollback strategy

#### Feature flags

| Flag | Purpose | Rollback action |
|------|---------|-----------------|
| `FormaAbTest.Sync.nutritionSyncEnabled` | Master switch for upload/pull | Set `false` — app reverts to local-only behavior; V7 fields ignored |
| `FormaAbTest.Sync.restoreBlockingEnabled` | Blocking restore UI | Set `false` — skip to main app with profile only (pre-Phase 4 behavior) |
| Account switch quarantine flag | Namespace wipe on UID change | Disable to preserve legacy sign-out behavior during investigation |

#### Phase-level rollback

| Phase rolled back | User-visible behavior | Data impact |
|-------------------|----------------------|-------------|
| Phase 6 disabled | Delete UI shows not implemented | None |
| Phase 5 disabled | No cross-device updates until foreground manually added later | Local + upload still works |
| Phase 4 disabled | Reinstall restores profile only (current production) | Cloud data safe; device empty for logs |
| Phase 3 disabled | No upload/pull; local-only | Firestore empty for nutrition |
| Phase 2 disabled | No cloud writes possible | Rules/clients unused |
| Phase 1 **must not roll back** after Phase 3 ships | — | UID scoping is safety invariant |

#### Firestore rollback

- New collections are additive — disabling sync leaves orphan cloud docs (acceptable)
- Do **not** delete production nutrition collections without Phase 6 account delete flow
- Rules rollback: revert `firestore.rules` commit; nutrition paths deny all — client sync flag off prevents client errors from retries

#### SwiftData rollback

- V6→V7 is forward-only — rollback = ship fixed build or user reinstall
- Mitigation: beta cohort on TestFlight with V6→V7 migration tests before broad release

#### Incident response playbook

1. Disable `FormaAbTest.Sync.nutritionSyncEnabled` via remote config / hotfix build
2. Stop rules deploy if cross-user write detected
3. Identify affected UIDs via Firestore audit (`userId` mismatch logs)
4. Ship Phase 1 fix if leakage is local; ship namespace wipe if cloud contamination
5. Communicate to users if attach-history dialog misfired

---

## 8. Acceptance Criteria Summary

Final feature (Phase 6 complete) must satisfy:

1. Reinstall + same Google account → profile, plan, food, water, weight, Journey restored (30-day window blocking, ≤60s on Wi‑Fi)
2. Second device → same core logging history after foreground sync
3. Force kill → committed logs remain (regression green)
4. User A → logout → User B login → zero A food rows in queries
5. User A login again → A data from cloud, not B's local residue
6. Delete/edit on device A propagates to device B
7. Offline log uploads within 30s of reconnect (foreground)
8. Firestore rules deny cross-user access (emulator CI)
9. V6 → V7 migration without duplication; unowned data requires user confirm before upload
10. Account delete removes local + remote nutrition + profile + Auth user

---

## 9. Next Step (When Coding Starts)

**Start Phase 1 only.** First PR slice:

1. `FormaSchemaV7` + entity field additions
2. UID on write + filtered reads in log services
3. Coach nil-userId fix
4. `MultiUserNutritionIsolationTests`

Do **not** merge Firestore clients or sync engine until Phase 1 tests pass.

---

*End of execution map. No application code was modified.*
