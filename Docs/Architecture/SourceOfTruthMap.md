# Source of Truth Map

**Last updated:** 2026-07-04  
**Related:** [../Architecture.md](../Architecture.md), [../../USER_DATA_STORAGE_CONTEXT_PACKET.md](../../USER_DATA_STORAGE_CONTEXT_PACKET.md) (partially stale — see §11), [TechnicalDebt/TechnicalDebtRegister.md](../TechnicalDebt/TechnicalDebtRegister.md)

---

## 1. Principles

1. **Local-first:** SwiftData is the on-device source of truth for nutrition, weight, reviews, and coach history when offline or signed in.
2. **Cloud mirror:** Firestore holds account-scoped backups when sync is enabled and the user is signed in.
3. **Single user-mutation facade:** Feature models mutate account nutrition/plan/review data through `FitnessActionCenter`, not repositories directly.
4. **Documented bypass paths:** Sync restore, bootstrap, migration, and account deletion write SwiftData through dedicated coordinators — not through `FitnessActionCenter`.
5. **Ephemeral transport:** AI context packets and HTTP bodies are built on demand — not persisted as SSOT.
6. **UID scoping:** Nutrition entities carry `ownerUID` on `FormaSchemaV7+`; reads filter by current Firebase UID.

---

## 2. Domain Table (where data lives)

| Domain | Source of truth (local) | Cloud mirror | Derived / cache | Sync path | Delete path | Risk |
|--------|-------------------------|--------------|-----------------|-----------|-------------|------|
| **Profile / plan** | `UserProfileEntity` | `users/{uid}/profile/current` | `DailyLogEntity` frozen targets | Profile bootstrap upload | Profile replace; cloud delete on account deletion | Target duplication across profile + daily log |
| **Daily logs** | `DailyLogEntity` | `users/{uid}/dailyLogs/{date}` | Rolled-up totals from child entries | Outbox → `AccountSyncUploader` | Entity delete + tombstone | Low |
| **Food entries** | `FoodEntryEntity` | Subcollection under daily log | Daily log macro totals | Outbox push | `FoodLogService` delete + tombstone | Low |
| **Water entries** | `WaterEntryEntity` | Subcollection under daily log | Daily log water total | Outbox push | `WaterLogService` delete | Low |
| **Weight entries** | `WeightEntryEntity` | `users/{uid}/weightEntries/{id}` | `DailyLogEntity.weightKg` mirror | Outbox push | Remote tombstone; **local delete API missing** (TD-DATA-001) | Medium |
| **Daily reviews** | `DailyReviewEntity` | `users/{uid}/dailyReviews/{date}` | None | Outbox push | Entity delete | Low |
| **Coach chat** | `CoachChatTranscriptMessageEntity` + in-memory `CoachModel.messages` | Outbox (text; images excluded by default) | Thumbnail JPEG in entity | Outbox push | Transcript prune/replace | Medium — dual memory+disk |
| **Coach timeline** | `CoachTimelineEventEntity` | Outbox | None | Outbox push | Compaction APIs | Low |
| **Journey dashboard** | **Derived** — no durable model | — | Built from logs + profile + HK | N/A | N/A | Recompute on refresh |
| **Journey weekly habits** | **Derived** in-memory | — | `JourneyWeeklyReviewBuilder` | N/A | N/A | Separate from HI weekly review |
| **HI weekly review** | **Derived** + health cache JSON | `healthWeeklyReviews` (upload-only, consent) | `WeeklyReviewService` cache | Optional upload | Cache prune | Not SSOT for Journey habits |
| **HealthKit raw** | **Not persisted** | — | Normalized in `LocalHealthCacheStore` | N/A | N/A | Low |
| **Health summaries** | `LocalHealthCacheStore` JSON per UID | `healthDaily`, `healthWorkouts`, etc. | In-memory L1 | Upload-only; not read back as SSOT | `clearAll()` per UID | One-way sync |
| **Onboarding draft** | `OnboardingDraftStore` (UserDefaults) | — | — | None | Clear on complete | Device-global |
| **Theme / settings** | `AppThemePreferences` (UserDefaults) | — | — | None | Partial on logout | Not cloud-synced |
| **Auth session** | Firebase Auth SDK (keychain) | Firebase Auth | — | SDK | Sign-out / account delete | — |
| **Sync metadata** | `AccountSyncMutationEntity` + UserDefaults cursors | `syncMetadata` docs | — | Internal | Wipe on account deletion | — |
| **Restore state** | `AccountRestoreStateStore` (UserDefaults) | — | `AccountRestoreSessionState` (memory) | Pull via `AccountRestoreCoordinator` | Reset after restore | — |

---

## 3. Write Path Ownership

**Rule:** Feature models (`TodayModel`, `CoachModel`, `PlanModel`, `OnboardingModel`, `JourneyModel`) must not call `*LogService` / `UserProfileService` / `ReviewService` write APIs directly. They route through coordinators that call `FitnessActionCenter`.

| Data | Canonical user write path | Repository that persists | Who may call repository writes |
|------|---------------------------|--------------------------|--------------------------------|
| Food | `FitnessActionCenter.logFood` / `editFoodEntry` / `deleteFoodEntry` | `FoodLogService` | `FitnessActionCenter`; `AccountSyncPuller` (merge); tests |
| Water | `FitnessActionCenter.logWater` / `deleteWaterEntry` | `WaterLogService` | `FitnessActionCenter`; `AccountSyncPuller`; tests |
| Weight | `FitnessActionCenter.logDailyWeight` | `WeightLogService` | `FitnessActionCenter`; `AccountSyncPuller`; tests |
| Daily log totals | Internal via log services + `DailyLogService.recalculateDailyTotals` | `DailyLogService` | Log services; `FitnessActionCenter.syncTodayTargetsFromProfile`; `AccountSyncPuller` |
| Plan / profile | `FitnessActionCenter.createProfile` / `updatePlan` / `applyPlanTargets` | `UserProfileService`, `TargetService` | `FitnessActionCenter`; `ProfileBootstrapService` (restore/conflict); `AccountSyncPuller` (profile via bootstrap) |
| Daily review | `FitnessActionCenter.generateDailyReview` | `ReviewService` | `FitnessActionCenter`; `AccountSyncPuller`; tests |
| Coach timeline | `CoachTimelineRecorder` → `CoachTimelineStoring.append` | `SwiftDataCoachTimelineStore` | Coach pipeline / backfill; not `FitnessActionCenter` |
| Coach chat transcript | `CoachChatTranscriptStore` save APIs | `SwiftDataCoachChatTranscriptStore` | `CoachModel` via store protocol; not `FitnessActionCenter` |
| Health Intelligence | **Read-only** from feature UI | `HealthDataRepository` → cache | `HealthSyncService`; no feature-model SwiftData writes |
| Cloud merge | N/A (server → device) | `AccountSyncPuller` direct `SwiftDataStore` | Restore, incremental pull, bounded foreground pull |
| Account wipe | N/A | `LocalAccountDataWipeService` | `AccountDeletionCoordinator` |

### Feature entry points (confirmed)

| Surface | Write coordinator | `FitnessActionCenter` methods used |
|---------|-------------------|-----------------------------------|
| Today | `TodayActionCoordinator` | `logFood`, `logWater`, `logDailyWeight`, `deleteFoodEntry`, `editFoodEntry` |
| Coach | `CoachMutationExecutor` | `logFood`, `logWater`, `logDailyWeight`, `generateDailyReview`, … |
| Plan | `PlanModel` | `createProfile`, `updatePlan`, `notifyDataChanged` |
| Onboarding | `OnboardingProfileCommitter` | `createProfile` |
| Auth bootstrap | `AuthGateCoordinator` | `syncTodayTargetsFromProfile` (target sync only) |
| Journey | — | **Read-only** — no nutrition mutations |

After every successful `FitnessActionCenter` nutrition/plan/review mutation: `AppRefreshCenter.notifyDataChanged()` and optional `AccountSyncLifecycle.scheduleAfterLocalMutation`.

---

## 4. Read Path Ownership

Feature models depend on **reader protocols** in `Domain/Protocols/`:

| Protocol | Implementation | Used by |
|----------|----------------|---------|
| `DailyLogReading` | `DailyLogService` | Today, Coach, Journey, Plan |
| `FoodLogReading` | `FoodLogService` | Today, Coach |
| `WeightLogReading` | `WeightLogService` | Today, Journey, Plan |
| `DailyReviewReading` | `ReviewService` | Today |
| `UserProfileReading` | `UserProfileService` | All tabs, onboarding |
| `PlanTargetCalculating` | `TargetService` | Plan, onboarding |

Health: `HealthDataRepository` (read/normalize), `HealthIntelligenceSnapshotServing` (derived snapshot). Optional read routing: `FormaAbTest.HealthIntelligence.repositoryReadRoutingEnabled`.

---

## 5. Sync / Restore (documented lower-level writes)

These paths **intentionally bypass** `FitnessActionCenter` because they merge remote snapshots or perform hygiene — not user-initiated logging.

### Upload (local → cloud)

```
FitnessActionCenter mutation
  → *LogService / UserProfileService / ReviewService
  → AccountLocalMutationTracker
  → AccountSyncOutboxStore
  → AccountSyncCoordinator
  → AccountSyncUploader
  → FirestoreAccountDataRemoteStore
```

### Pull / restore (cloud → local)

```
AccountRestoreCoordinator / AccountIncrementalPuller
  → AccountSyncPuller.merge*
  → SwiftDataStore.insert/update (stamps ownerUID, sync fields)
  → AppRefreshCenter → tab models reload
```

`AccountSyncPuller` writes entities directly to reconcile server `updatedAt` with local rows. It does not enqueue outbox mutations for merged rows.

### Profile bootstrap (hybrid)

`ProfileBootstrapService` may call `UserProfileService.replaceLocalProfile` during restore or conflict resolution, then `saveProfileToCloud` for owned updates triggered from `FitnessActionCenter.updatePlan`.

---

## 6. SwiftData Entities (`FormaSchemaV9`)

| Entity | Active | `ownerUID` | User writes via |
|--------|--------|------------|-----------------|
| `UserProfileEntity` | Yes | Yes | `FitnessActionCenter` / bootstrap |
| `DailyLogEntity` | Yes | Yes | Log services (via ActionCenter) |
| `FoodEntryEntity` | Yes | Yes | `FoodLogService` |
| `WaterEntryEntity` | Yes | Yes | `WaterLogService` |
| `WeightEntryEntity` | Yes | Yes | `WeightLogService` |
| `DailyReviewEntity` | Yes | Yes | `ReviewService` |
| `CoachTimelineEventEntity` | Yes | Optional `userId` | `SwiftDataCoachTimelineStore` |
| `CoachChatTranscriptMessageEntity` | Yes | Optional `userId` | `SwiftDataCoachChatTranscriptStore` |
| `AccountSyncMutationEntity` | Yes | N/A (outbox) | `AccountLocalMutationTracker` |

**Migration-only (keep on disk, not in active schema):** `ChatMessageEntity`, `WeeklyReviewEntity`, `WorkoutEntryEntity`, `ExerciseSetEntity`, `DebugRecordEntity`. See entity file headers and `Docs/PersistenceCleanupNotes.md`.

---

## 7. Duplicated or Derived Data (intentional)

| Data | Copies | Why |
|------|--------|-----|
| Plan targets | Profile + daily log frozen targets + cloud profile | Historical day accuracy when plan changes |
| Weight | `WeightEntryEntity` + `DailyLogEntity.weightKg` | Fast daily dashboard read |
| Coach chat | In-memory messages + SwiftData transcript | UI responsiveness + persistence |
| Maintenance calories | Formula TDEE in Plan vs learned (absent) | Not unified — see Technical Debt register |

---

## 8. Delete Path Completeness

| Domain | Local delete | Cloud delete | Account wipe |
|--------|--------------|--------------|--------------|
| Food / water | Yes | Tombstone via sync | Yes |
| Weight | **No dedicated API** | Yes (remote store) | Yes |
| Profile | Replace row | Yes | Yes |
| Daily review | Via entity delete | Tombstone | Yes |
| Coach transcript | Prune/replace | Outbox | Yes |
| Health cache | `clearAll()` | Upload collections deleted remotely | Yes |

---

## 9. AI and Ephemeral Data

| Artifact | Persisted? | Notes |
|----------|------------|-------|
| `CoachContextPacketV2` | No | Built per request → `aiGateway` |
| Meal photos (base64) | In-memory + optional transcript JPEG | Not SSOT |
| `FoodLogDraft` | Transient during confirmation | Commits via `FitnessActionCenter` |

---

## 10. Flags Affecting Source of Truth

| Flag | Effect |
|------|--------|
| `AccountPersistenceFeatureFlags.syncEngineEnabled` | Master sync switch |
| `restoreOnLoginEnabled` | Blocking restore on sign-in |
| `pullRecentDataEnabled` | Foreground bounded pull (default **false**) |
| `HealthIntelligenceFeatureFlags.isSyncEnabled` | Local HK cache sync |
| `healthSummaryRemoteSyncEnabled` + consent | Health Firestore upload |

---

## 11. Stale Documentation Note

`USER_DATA_STORAGE_CONTEXT_PACKET.md` predates full account persistence ship. Prefer **this document** and `Docs/AccountPersistence/` for current persistence truth. A staleness banner is on the packet file.

---

## 12. Revision History

| Date | Change |
|------|--------|
| 2026-07-04 | Initial SSOT map: write/read ownership, sync bypass paths, feature boundaries |
