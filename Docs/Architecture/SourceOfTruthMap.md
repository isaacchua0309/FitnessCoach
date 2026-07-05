# Source of Truth Map

**Last updated:** 2026-07-04  
**Related:** [AppArchitectureOverview.md](./AppArchitectureOverview.md), [../../USER_DATA_STORAGE_CONTEXT_PACKET.md](../../USER_DATA_STORAGE_CONTEXT_PACKET.md) (partially stale — see §12), [../../ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md](../../ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md)

---

## 1. Principles

1. **Local-first:** SwiftData is the on-device source of truth for nutrition, weight, reviews, and coach history when offline or signed out.
2. **Cloud mirror:** Firestore holds account-scoped backups for profile and nutrition when sync is enabled and user is signed in.
3. **Ephemeral transport:** AI context packets and HTTP request bodies are built on demand — not persisted as SSOT.
4. **UID scoping:** Post–Phase 1, nutrition entities carry `ownerUID`; reads filter by current Firebase UID (**Confirmed** `FormaSchemaV7+`).

---

## 2. Domain Table

| Domain | Source of truth (local) | Cloud mirror | Mirrors / derived caches | Sync path | Delete path | Risk |
|--------|-------------------------|--------------|--------------------------|-----------|-------------|------|
| **Profile / plan** | `UserProfileEntity` | `users/{uid}/profile/current` | `DailyLogEntity` target fields; `CloudUserProfileDocument` | `ProfileBootstrapService` upload on save/bootstrap | Profile replace; cloud doc delete on account deletion | Target duplication across profile + daily log |
| **Daily logs** | `DailyLogEntity` | `users/{uid}/dailyLogs/{date}` | Rolled-up totals from child entries | Outbox → `AccountSyncUploader` | Entity delete + tombstone | Low |
| **Food entries** | `FoodEntryEntity` | Subcollection under daily log | Daily log macro totals; `CoachContextPacketV2` (ephemeral) | Outbox push | `FoodLogService` delete + sync tombstone | Low |
| **Water entries** | `WaterEntryEntity` | Subcollection under daily log | Daily log water total | Outbox push | `WaterLogService` delete | Low |
| **Weight entries** | `WeightEntryEntity` | `users/{uid}/weightEntries/{id}` | `DailyLogEntity.weightKg` (per-day mirror) | Outbox push | Remote `deleteWeightEntry` **Confirmed**; **local delete API missing** | Medium |
| **Daily reviews** | `DailyReviewEntity` | `users/{uid}/dailyReviews/{date}` | None | Outbox push | Entity delete | Low |
| **Coach chat** | `CoachChatTranscriptMessageEntity` + in-memory `CoachModel.messages` | Outbox (text; images excluded by default) | Thumbnail JPEG in entity | Outbox push | Transcript replace/prune | Medium — dual memory+disk |
| **Coach timeline** | `CoachTimelineEventEntity` | Outbox | None | Outbox push | Compaction APIs | Low |
| **Journey dashboard** | **Derived** — no durable model | — | Built from logs + profile + HK | N/A | N/A | Recompute on refresh |
| **Journey weekly habits** | **Derived** in-memory | — | `JourneyWeeklyReviewBuilder` from 7-day window | N/A | N/A | Separate from HI weekly review |
| **HI weekly review** | **Derived** + health cache JSON | `healthWeeklyReviews` (upload-only, consent) | `WeeklyReviewService` cache | Optional upload via `HealthSummarySyncService` | Cache prune | Flag-gated; not SSOT for Journey habits |
| **HealthKit raw** | **Not persisted** | — | Normalized in `LocalHealthCacheStore` | N/A | N/A | Low |
| **Health summaries** | `LocalHealthCacheStore` JSON per UID | `healthDaily`, `healthWorkouts`, etc. | In-memory L1 | Upload-only; **not read back as SSOT** | `clearAll()` per UID | One-way sync |
| **Onboarding draft** | `OnboardingDraftStore` (UserDefaults) | — | — | None | Clear on complete | Device-global |
| **Theme / settings** | `AppThemePreferences` (UserDefaults) | — | — | None | Partial on logout | Not cloud-synced |
| **Auth session** | Firebase Auth SDK (keychain) | Firebase Auth | — | SDK | Sign-out / account delete | — |
| **Sync metadata** | `AccountSyncMutationEntity` + cursors in UserDefaults | `syncMetadata` docs | — | Internal | Wipe on account deletion | — |
| **Restore state** | `AccountRestoreStateStore` (UserDefaults) | — | `AccountRestoreSessionState` (memory) | Pull via `AccountRestoreCoordinator` | Reset after restore | — |

---

## 3. Local vs Cloud Persistence

### SwiftData (`FormaSchemaV9`) — **Confirmed**

| Entity | Active | `ownerUID` | Sync fields |
|--------|--------|------------|-------------|
| `UserProfileEntity` | Yes | Yes | Yes |
| `DailyLogEntity` | Yes | Yes | Yes |
| `FoodEntryEntity` | Yes | Yes | Yes |
| `WaterEntryEntity` | Yes | Yes | Yes |
| `WeightEntryEntity` | Yes | Yes | Yes |
| `DailyReviewEntity` | Yes | Yes | Yes |
| `CoachTimelineEventEntity` | Yes | Optional `userId` | Yes |
| `CoachChatTranscriptMessageEntity` | Yes | Optional `userId` | Yes |
| `AccountSyncMutationEntity` | Yes | N/A (outbox) | N/A |

**Migration-only files on disk (not in active schema):** `ChatMessageEntity`, `WeeklyReviewEntity`, `WorkoutEntryEntity`, `ExerciseSetEntity`, `DebugRecordEntity`.

### UserDefaults (selected keys)

| Key / store | Data | User-scoped | Survives logout |
|-------------|------|-------------|-----------------|
| `forma.onboarding.draft` | Onboarding wizard | No | Cleared on complete |
| `forma.theme.*` | Appearance, palette | No | Yes |
| `forma.profileCloudSync.lastSyncedUID` | Profile sync hint | Partial | Cleared on sign-out hygiene |
| `forma.healthSummaryRemoteSyncConsent.{uid}` | HI remote consent | Yes | Per-UID keys persist |
| `forma.account.restore.*` | Restore progress | Partial | Per implementation |
| `forma.mainTab.selectedTab` | Tab selection | No | Yes |

### File cache

| Path | Contents |
|------|----------|
| `{ApplicationSupport}/Forma/HealthCache/{uid}/` | Normalized health day bundles, workouts, recovery, weekly-review cache |

---

## 4. Sync / Restore Ownership

### Sync (Phase 3–5) — owner: `Application/Sync/`

```
Local mutation (FitnessActionCenter / *LogService)
  → AccountLocalMutationTracker
  → AccountSyncOutboxStore (SwiftData)
  → AccountSyncCoordinator (on foreground / debounce / sign-in)
  → AccountSyncUploader → FirestoreAccountDataRemoteStore
```

**Gating:** `AccountPersistenceFeatureFlags.syncEngineEnabled`, `uploadPendingMutationsEnabled`, `pullRecentDataEnabled` (false = no bounded foreground pull).

### Cross-device refresh (Phase 5) — owner: `CrossDeviceSyncCoordinator`

- Foreground refresh, manual pull-to-refresh, realtime listener hints
- Does **not** replace restore; incremental merge via `AccountIncrementalPuller`

### Restore (Phase 4) — owner: `Application/Restore/`

```
Sign-in → ProfileBootstrapService.resolve
  → AccountRestoreCoordinator
  → AccountInitialRestoreService (blocking window)
  → AccountSyncPuller → SwiftData (ownerUID stamped)
  → AppRefreshCenter → tab models reload
```

**Gating:** `AccountPersistenceFeatureFlags.restoreOnLoginEnabled`

### Account deletion (Phase 6) — owner: `Application/Privacy/`

```
AccountDeletionCoordinator
  1. Stop sync / realtime listeners (deletion guard)
  2. Remote delete (functions accountDataDeletion)
  3. Firebase Auth user delete
  4. LocalAccountDataWipeService (SwiftData, cache, UserDefaults)
```

---

## 5. Duplicated or Derived Data (intentional)

| Data | Copies | Why |
|------|--------|-----|
| Plan targets | Profile + daily log frozen targets + cloud profile | Historical day accuracy when plan changes |
| Weight | `WeightEntryEntity` + `DailyLogEntity.weightKg` | Fast daily dashboard read |
| Coach chat | In-memory messages + SwiftData transcript | UI responsiveness + persistence |
| Maintenance calories | Formula TDEE in Plan vs learned (absent) | **Not unified** — Weekly Progress sprint scope |

---

## 6. Delete Path Completeness

| Domain | Local delete | Cloud delete | Account wipe |
|--------|--------------|--------------|--------------|
| Food / water | Yes | Tombstone via sync | Yes |
| Weight | **No dedicated API** | Yes (remote store) | Yes |
| Profile | Replace row | Yes | Yes |
| Coach transcript | Prune/replace | Outbox | Yes |
| Health cache | `clearAll()` | Upload collections deleted remotely | Yes |
| Theme | N/A | N/A | Optional / retained |

---

## 7. AI and Ephemeral Data

| Artifact | Persisted? | Sent where |
|----------|------------|------------|
| `CoachContextPacketV2` | No — built per request | `aiGateway` HTTPS |
| Meal photos (base64) | In-memory + optional JPEG in transcript | `aiGateway` meal analysis |
| `FoodLogDraft` | Transient during confirmation | Mutations + AI |

**Not server-side SSOT:** Firebase Functions `aiGateway` is stateless (**Confirmed**).

---

## 8. Firestore Paths (account data)

See `Docs/AccountPersistence/PHASE_2_CLOUD_SCHEMA_AND_RULES.md`. Summary:

| Collection | Purpose |
|------------|---------|
| `users/{uid}/profile/current` | Profile/plan snapshot |
| `users/{uid}/dailyLogs/{date}/…` | Daily rollup + child entries |
| `users/{uid}/weightEntries/{id}` | Weight rows |
| `users/{uid}/dailyReviews/{date}` | Daily AI reviews |
| `users/{uid}/syncMetadata/{doc}` | Sync cursors |
| `users/{uid}/health*` | Health summary upload (consent-gated) |

Security: `firestore.rules` — owner-only writes with `userId` + `schemaVersion` validation.

---

## 9. Read Routing

Feature models depend on **repository protocols** in `Domain/Protocols/`:

- `DailyLogReading`, `FoodLogReading`, `WeightLogReading`, `DailyReviewReading`
- `UserProfileReading`, `PlanTargetCalculating`

Implementations: `Data/Repositories/*Service.swift`.

Health Intelligence optional read routing: `FormaAbTest.HealthIntelligence.repositoryReadRoutingEnabled`.

---

## 10. Flags Affecting Source of Truth

| Flag | Effect |
|------|--------|
| `AccountPersistenceFeatureFlags.syncEngineEnabled` | Master sync switch |
| `restoreOnLoginEnabled` | Blocking restore on sign-in |
| `pullRecentDataEnabled` | Foreground bounded pull (default **false**) |
| `HealthIntelligenceFeatureFlags.isSyncEnabled` | Local HK cache sync |
| `healthSummaryRemoteSyncEnabled` + user consent | Health Firestore upload |

Full registry: [FeatureFlagRegistry.md](./FeatureFlagRegistry.md).

---

## 11. Stale Documentation Note

`USER_DATA_STORAGE_CONTEXT_PACKET.md` (2026-07-04) predates full account persistence ship and states:

- No `ownerUID` on food entities — **stale**; V7+ adds `ownerUID`
- Account delete stub — **stale**; `AccountDeletionCoordinator` implemented
- Settings delete not implemented — **stale**; gated by `FormaAbTest.Settings.dataDeletionEnabled`

Use **this document** and `ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md` for current persistence truth.

---

## 12. Revision History

| Date | Change |
|------|--------|
| 2026-07-04 | Initial SSOT map for PRDX v1 |
