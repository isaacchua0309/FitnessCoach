# Account Persistence and Restore Context Packet

**Repository:** FitnessCoach  
**Generated:** 2026-07-04  
**Scope:** App lifecycle, account restore, reinstall, cross-device, multi-user safety  
**Related audit:** `USER_DATA_STORAGE_CONTEXT_PACKET.md`  
**Method:** Code audit only — no behavior changes. Claims marked **Confirmed**, **Likely**, or **Unknown**.

---

## 1. Executive Summary

### What currently persists with the account (**Confirmed**)

Only data written to **Firestore under `users/{uid}/`** survives device loss:

| Data | Firestore path | Restore on sign-in |
|------|----------------|-------------------|
| Profile + plan targets | `users/{uid}/profile/current` | **Yes** — `ProfileBootstrapService.resolve` → `UserProfileService.restoreProfile` |
| Health summaries (opt-in) | `users/{uid}/healthDaily`, `healthWorkouts`, `healthRecovery`, `healthWeeklyReviews`, `healthSyncMetadata` | **No** — upload-only; app never reads remote health as SOT (`HealthSummarySyncService`, contract doc) |

**Firebase Auth** can restore a Google session via SDK keychain persistence, but on **fresh install** the app explicitly clears stale auth (`AuthManager.clearPersistedSessionIfFreshInstall`, `AuthInstallPolicy.shouldClearPersistedSessionOnLaunch`) (**Confirmed**).

### What only persists on the device (**Confirmed**)

| Layer | Contents |
|-------|----------|
| SwiftData (`FormaSchemaV6`) | Food, water, weight, daily logs, daily reviews, coach chat, coach timeline |
| UserDefaults | Onboarding draft, theme, health sync consent (per-UID keys), profile sync hints, migration flags |
| Application Support | `Forma/HealthCache/{userID}/` normalized health JSON |

### What is lost on app reinstall (**Confirmed**)

All SwiftData, UserDefaults, and Application Support data is removed by iOS on app deletion. Because **food, water, weight, coach, journey inputs, and daily reviews were never uploaded**, they are **permanently lost** even when the user signs into the same Firebase account.

**Profile/plan** can be restored from Firestore if previously uploaded via `FirestoreCloudUserProfileStore.save`.

### What is lost on another device (**Confirmed**)

Same as reinstall for nutrition/coach data. Second device receives **profile only** (if cloud profile exists). Today, Journey, and Coach context appear empty or minimal until new local logging occurs.

### What is unsafe across multiple users on the same device (**Confirmed**)

| Issue | Evidence |
|-------|----------|
| Food/water/weight not UID-scoped | No `ownerUID` on `FoodEntryEntity`, `WaterEntryEntity`, `WeightEntryEntity`, `DailyLogEntity` |
| Logout does not wipe local logs | `SignOutHygieneTests.testSignOutPolicyPreservesLocalProfile`; `AuthLogoutPolicy` has no SwiftData wipe |
| Coach rows with `userId == nil` visible to all users | `CoachChatTranscriptPersistenceRepository.fetchEntities` lines 78–81: `nil` userId → `return true` |
| Profile mismatch blocks routing but not nutrition reads | `ProfileBootstrapCoordinator.showAccountMismatch` — food services have no UID filter |
| `deletesLocalProfileOnSignOut = true` unwired | `FormaAbTest.Auth.deletesLocalProfileOnSignOut` returns `true`; `AuthLogoutPolicy` only clears sync metadata — `SignOutHygieneTests.testSignOutPolicyPreservesLocalProfile` confirms profile survives sign-out |

### What should become cloud-backed (recommendation)

**Must cloud sync (signed-in default):** profile (exists), food entries, water entries, weight entries, daily log rollups, daily reviews (optional narrative).  
**Should cloud sync:** coach timeline (metadata), coach chat (text only, limited retention).  
**Optional / consent-gated:** health summaries (already exists), meal image thumbnails.  
**Local-only:** theme, debug logs, HealthKit raw reads, in-flight coach images, onboarding draft (pre-commit).

### What should remain local-only (recommendation)

- Theme (`ThemeStore` — intentional device preference)
- HealthKit sample queries (re-fetch from Apple Health on device)
- Pending image analysis sessions (`ImageAnalysisSessionStore`)
- DEBUG pipeline tracer (`FormaPipelineTracer`)
- Raw meal photos (do not sync full JPEG by default)

---

## 2. User Expectations

A signed-in user **should** expect:

1. **Profile and plan** restore after reinstall — **partially met today** (Firestore profile only).
2. **Food, water, weight logs** restore after reinstall — **not met** (local-only).
3. **Journey/progress** continuous after reinstall — **not met** (computed from local logs + health cache).
4. **Same account on another device** shows same core logging history — **not met**.
5. **App force kill** does not lose committed logs — **met** (SwiftData `save()` on each mutation via `SwiftDataStore.insert/delete`).
6. **In-flight uncommitted actions** may be lost — **expected** (pending coach images, in-progress AI, unsaved onboarding draft until `saveDraft`).
7. **Different users on same device** never see each other's data — **not met** (nutrition leakage).

---

## 3. Current Persistence Survival Matrix

Legend: **Survives** | **Lost** | **Partial** | **Unsafe** | **Unknown**

| Data Domain | App Kill | Device Restart | Logout | Same-Device Re-login | Different User Login | Delete/Reinstall | New Device Login | Current Storage | Current Risk |
|------------|----------|----------------|--------|----------------------|----------------------|------------------|------------------|-----------------|--------------|
| Auth session | Survives | Survives | Lost (signed out) | Survives (re-auth) | N/A | Partial — keychain may hold session but app clears on fresh install | Survives after Google sign-in | Firebase Auth SDK + `AuthManager` | Fresh install forces sign-out (`AuthInstallPolicy`) |
| User profile | Survives | Survives | Survives | Survives | Unsafe if mismatch unresolved | Lost locally; Partial if cloud | Partial — cloud restore | `UserProfileEntity`; Firestore `profile/current` | Multi-user profile conflict UI; local profile not wiped |
| Onboarding completion | Survives | Survives | Survives | Survives | Unsafe — same local profile | Lost; cloud `onboardingCompletedAt` in profile doc | Partial via cloud profile | `CloudUserProfileDocument.onboardingCompletedAt` | Draft may resume wrongly |
| Plan targets | Survives | Survives | Survives | Survives | Unsafe | Lost; Partial cloud | Partial cloud | `UserProfileEntity` + `CloudUserTargets` | Historical `DailyLogEntity` targets frozen |
| Calories/macros (daily) | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | `DailyLogEntity` totals | No remote backup |
| Food logs | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | `FoodEntryEntity` | Cross-user leakage |
| Meal photos | Partial | Partial | Survives | Survives | **Unsafe** | **Lost** | **Lost** | `CoachChatTranscriptMessageEntity` JPEG; `FoodEntryEntity.imageUrl` string | In-memory pending lost on kill |
| Water logs | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | `WaterEntryEntity` | No remote backup |
| Weight logs | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | `WeightEntryEntity` | No delete API; no remote |
| Daily logs | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | `DailyLogEntity` | Aggregates local-only |
| Daily reviews | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | `DailyReviewEntity` | AI narrative not backed up |
| Journey/progress | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | Derived — `JourneyModel` reads logs + `healthCacheStore` | Empty after reinstall |
| Coach chat | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | `CoachChatTranscriptMessageEntity` | nil userId leak |
| Coach timeline | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | `CoachTimelineEventEntity` | nil userId leak |
| Common/recent foods | Survives | Survives | Survives | Survives | **Unsafe** | **Lost** | **Lost** | Derived — `CoachContextFoodMemoryBuilder` from `FoodEntry` | Rebuilds from logs only |
| HealthKit cache | Survives | Survives | Survives | Survives | Partial — per-UID dir | **Lost** | **Lost** | `LocalHealthCacheStore` `Forma/HealthCache/{uid}/` | Re-query HK on device |
| Health intelligence summaries | Survives | Survives | Survives | Survives | Partial | Lost local; Partial remote if consented | Partial remote only | Local cache + optional Firestore health* | Remote not read back |
| Settings/theme | Survives | Survives | Survives | Survives | **Unsafe** — shared | **Lost** | **Lost** | UserDefaults `forma.theme.*` | Device-global |
| Health sync consent | Survives | Survives | Survives | Survives | Partial — per-UID key | **Lost** | **Lost** | `forma.healthSummaryRemoteSyncConsent.{uid}` | Consent re-prompt |
| Debug/observability | Lost (in-memory) | Lost | Lost | Lost | N/A | Lost | Lost | `FormaPipelineTracer` (DEBUG) | OK |

### Extended lifecycle scenarios (§3 supplement)

The main matrix above maps to the full audit checklist as follows:

| Audit scenario | Matrix column / section |
|----------------|-------------------------|
| App backgrounding | Same as App Kill — committed SwiftData/UserDefaults survive (**Confirmed**) |
| App force kill | App Kill column |
| Device restart | Device Restart column |
| Logout | Logout column |
| Same-account re-login (same device) | Same-Device Re-login column |
| Different-account login (same device) | Different User Login column |
| Delete and reinstall | Delete/Reinstall column |
| New device, same account | New Device Login column |
| Auth token expiry / session restoration | §3.1 below |
| Offline app launch | §3.1 below |
| Offline logging + later reconnect | §3.1 below |

### 3.1 Auth, Offline, and Session Restoration

| Data Domain | App Backgrounding | Auth Token Expiry / Session Restore | Offline App Launch | Offline Log → Reconnect | Evidence |
|------------|-------------------|-----------------------------------|--------------------|-------------------------|----------|
| Auth session | Survives | **Survives** — Firebase SDK refreshes via `AuthManager.refreshIDToken(forceRefresh:)` | Partial — local session may exist; cloud profile fetch fails without network | N/A — no upload queue for nutrition | `AuthManager.swift` lines 260–310; `AuthTokenPolicy.eligibility` |
| User profile | Survives | Survives locally; cloud refresh on next online bootstrap | **Survives** locally; cloud restore blocked if no local + offline | No cloud write until online | `ProfileBootstrapService.resolveCloudProfile` returns `.failed` on network error |
| Onboarding completion | Survives | Survives | Survives locally | N/A | `CloudUserProfileDocument.onboardingCompletedAt` |
| Plan targets | Survives | Survives | Survives locally | N/A | `UserProfileEntity` targets |
| Food/water/weight logs | Survives | Survives | **Survives** — local-first, no network required | **Stranded on device** — no sync engine; logs persist locally only | `FoodLogService.addFoodEntry` — no network; no `SyncOutbox` |
| Journey/progress | Survives | Survives | Survives from local data | N/A until sync exists | `JourneyModel.loadProgress()` |
| Coach chat | Survives | Survives | Survives locally | Unsent AI replies fail; committed transcript survives | `CoachModel` offline retry path in `CoachManualImageQAExecutionTests` |
| Health summaries | Survives | Survives | Local cache survives; remote sync skipped when offline | Upload queued implicitly in `HealthSummarySyncService` on reconnect | `HealthSummarySyncService.syncOnAppForeground` |
| Settings/theme | Survives | Survives | Survives | N/A | `ThemeStore` → UserDefaults |

**Auth token expiry (**Confirmed**):** `AuthManager.idToken(forceRefresh:)` calls `currentUser.getIDToken(forcingRefresh:)` (`AuthManager.swift` lines 296–310). Firebase Auth SDK restores session from keychain on relaunch unless fresh-install policy clears it (`AuthInstallPolicy.shouldClearPersistedSessionOnLaunch`).

**Offline app launch (**Confirmed**):** Nutrition logging works offline (`FoodLogService` has no network dependency). Profile cloud bootstrap requires network — `ProfileBootstrapService.resolveCloudProfile` returns `.failed(CloudProfileResolutionFailure)` on fetch error, blocking cloud restore path. Local profile with matching `ownerUID` routes to `.main` without network (`ProfileBootstrapServiceTests` — `offline-local-user` case).

**Offline log → reconnect (**Confirmed** gap):** Committed food/water/weight entries remain on device but are **never uploaded** today. Health summaries may upload on foreground via `HealthSummarySyncService.syncOnAppForeground` when consent + capability enabled. **No nutrition outbox exists.**

### Code evidence (representative)

- **SwiftData survives kill:** `SwiftDataStore.save()` called on `insert`/`delete` (`SwiftDataStore.swift` lines 37–48)
- **Profile cloud restore:** `ProfileBootstrapService.resolve(uid:)` lines 77–84
- **No nutrition cloud:** no Firestore client for food/water/weight in `Fitness Coach/Infrastructure/Cloud/`
- **Logout preserves data:** `SignOutHygieneTests.swift`
- **Coach nil userId:** `CoachChatTranscriptPersistenceRepository.swift` lines 76–82
- **Fresh install auth clear:** `AuthManager.clearPersistedSessionIfFreshInstall()` lines 404–418
- **Journey from local:** `JourneyModel` dependencies `dailyLogReader`, `weightLogReader` (`JourneyModel.swift` lines 17–19)

---

## 4. Current Cloud Restore Behavior

### Bootstrap participants

| Component | File | Role |
|-----------|------|------|
| `AuthManager` | `Application/Services/Auth/AuthManager.swift` | Session listener, Google sign-in, `idToken(forceRefresh:)` |
| `AuthGateCoordinator` | `Features/Auth/Coordinator/AuthGateCoordinator.swift` | `reconcileSignedInProfile`, sign-out |
| `ProfileBootstrapCoordinatorService` | `App/Routing/ProfileBootstrapCoordinator.swift` | Reconcile decisions, existing-user resolution |
| `ProfileBootstrapService` | `Application/UseCases/ProfileBootstrapService.swift` | `resolve(uid:)`, cloud fetch, local restore |
| `FirestoreCloudUserProfileStore` | `Infrastructure/Cloud/FirestoreCloudUserProfileStore.swift` | `fetch`, `save` → `users/{uid}/profile/current` |
| `UserProfileService` | `Data/Repositories/UserProfileService.swift` | `restoreProfile`, `replaceLocalProfile`, `assignOwnerUID` |

### Sequence: Fresh install → sign in → main app

```
Fresh install
  → AuthManager.startListening()
  → clearPersistedSessionIfFreshInstall()  [clears keychain-restored session]
  → User taps Google sign-in
  → AuthManager.signInWithGoogle()
  → AuthGateCoordinator.reconcileSignedInProfile(uid:isFreshSignIn:)
  → ProfileBootstrapCoordinatorService.resolveExistingUserSignIn (or reconcile decision)
  → ProfileBootstrapService.resolve(uid:)
       ├─ local profile with ownerUID == uid → .main (skip cloud)
       ├─ local profile with different/missing owner → ownership error or mismatch UI
       └─ no local profile → FirestoreCloudUserProfileStore.fetch(uid:)
            ├─ found → UserProfileService.restoreProfile(from:ownerUID:)
            └─ missing → .missingCloudProfile → onboarding
  → RootModel routes to .main
  → TodayModel / JourneyModel / CoachModel load
       └─ read SwiftData food/water/weight → EMPTY on fresh install
```

### Explicit gaps after successful profile restore

| Missing after reinstall + sign-in | Why |
|----------------------------------|-----|
| Food entries | Never uploaded — `FoodLogService` local only |
| Water entries | Same |
| Weight history | Same |
| Daily macro totals | `DailyLogEntity` empty |
| Daily reviews | `DailyReviewEntity` empty |
| Coach chat / timeline | SwiftData wiped |
| Journey streaks, projections | `JourneyPresentationBuilder` needs local logs |
| Common/recent foods | `CoachContextFoodMemoryBuilder` needs `FoodEntry` history |
| Health cache | Application Support deleted |
| Health intelligence on Journey | `healthCacheStore` empty until HK sync |
| Theme | UserDefaults wiped → defaults |
| Health sync consent state | Per-UID UserDefaults wiped |

### Scenario matrix

| Scenario | Behavior | Evidence |
|----------|----------|----------|
| Cloud profile exists, no local SwiftData | Profile restored; logs empty | `ProfileBootstrapService.resolve` lines 75–92 |
| Local profile exists for another UID | `showAccountMismatch` or ownership error | `SignOutHygieneTests.testDifferentUserSignInShowsMismatchAfterSignOutHygiene`; `ProfileBootstrapService.resolve` lines 65–72 |
| No local, no cloud | `missingCloudProfile` → onboarding | `ProfileBootstrapService.resolve` lines 93–98 |
| Local unowned profile (`ownerUID == nil`) | `requireOwnershipCloudLookup` | `SignOutHygieneTests.testUnownedLocalWithoutSyncHintRequiresCloudLookupAfterSignOutHygiene` |

---

## 5. App Kill vs Reinstall vs New Device

### 5.1 App Kill

| Category | Survives? | Evidence |
|----------|-----------|----------|
| Committed SwiftData | **Yes** | `SwiftDataStore.insert` → `save()` immediately |
| UserDefaults | **Yes** | OS-persisted |
| Application Support (health cache) | **Yes** | `LocalHealthCacheStore` file-backed |
| In-memory coach messages (unsaved) | **Lost** if `persistTranscript()` not yet called | `CoachModel.persistTranscript()` → `transcriptStore.saveMessages` |
| Pending image analysis | **Lost** | `ImageAnalysisSessionStore`, `CoachPendingImageLocalSourceStore` — not persisted |
| Pending composer attachment | **Lost** | `CoachInputState.pendingImage` in-memory |
| In-flight AI request | **Lost** (no queue) | `AIService` / `FormaAIBackendClient` — no offline outbox |
| Unsaved onboarding draft | **Partial** — last `saveDraft` survives | `OnboardingDraftStore.saveDraft` |
| Auth session | **Yes** | Firebase Auth persists |

**Committed log example:** `FoodLogService.addFoodEntry` → `store.insert` → disk (**Confirmed**).

**Image analysis kill before result:** session state lost; no food committed unless user had confirmed earlier (**Likely** from `CoachModel` flow).

### 5.2 Delete and Reinstall

| Deleted by iOS | Survives in cloud |
|----------------|-----------------|
| SwiftData SQLite store | Firestore `users/{uid}/profile/current` if uploaded |
| All UserDefaults (including `FitPilot.auth.installRegistered` reset → fresh install path) | Firestore health summaries if uploaded + consented |
| `Forma/HealthCache/` | Firebase Auth account (user re-authenticates with Google) |

**Permanently lost (never uploaded):** all nutrition logs, coach history, local reviews, journey-computed state, theme, consent flags.

**Auth on reinstall:** `AuthInstallPolicy` — keychain may restore Firebase user, but `clearPersistedSessionIfFreshInstall` calls `purgeStaleSession()` on first launch (**Confirmed**).

### 5.3 New Device Same Account

| Downloads from cloud | Does not exist in cloud |
|---------------------|-------------------------|
| Profile + plan targets (`CloudUserProfileDocument`) | Food, water, weight entries |
| Health summaries (if consented — **not read by app today**) | Coach chat, timeline |
| | Daily reviews, journey state |

| UI state | Expected |
|----------|----------|
| Plan tab | Shows restored targets (**Confirmed** if cloud profile exists) |
| Today | Empty food/water for today |
| Journey | Empty or minimal streaks; HK section needs new device HealthKit permission |
| Coach common foods | Empty until new logs |
| Weight trend | Empty |
| Calories/macros history | Empty |

**Journey rebuild:** `JourneyModel.loadProgress()` requires `dailyLogReader`, `weightLogReader` — cannot rebuild without restored logs (**Confirmed**).

**Weight trend rebuild:** `WeightLogService.getWeightTrend` — local only.

---

## 6. Domain-by-Domain Source of Truth Review

### 6.1 Profile

| | |
|--|--|
| **Local** | `UserProfileEntity` — `UserProfileService` |
| **Remote** | `CloudUserProfileDocument` @ `users/{uid}/profile/current` |
| **Read** | `UserProfileService.getCurrentProfile()` |
| **Write** | `createProfile`, `updateProfile`, `replaceLocalProfile` |
| **Delete** | `replaceLocalProfile` deletes prior row; no account delete |
| **Restore** | `restoreProfile(from:ownerUID:)` on bootstrap |
| **Cross-device** | Cloud SOT for profile; local mirror |
| **Current SOT** | Local for reads; cloud for cross-device |
| **Future SOT** | Cloud with local cache |
| **Migration** | Add sync metadata to `UserProfileEntity` |
| **Firestore** | Exists |
| **Rules** | Exists in `firestore.rules` |
| **Offline** | Local reads work; cloud upload fails until network |

### 6.2 Plan targets

Embedded in profile + `DailyLogEntity` target snapshot for today.  
**Restore:** targets in cloud profile restore to `UserProfileEntity`; today's daily log synced via `DailyLogService.syncTodayTargetsFromProfile`.  
**Gap:** historical daily target snapshots not in cloud.

### 6.3 Food logs

| | |
|--|--|
| **Local** | `FoodEntryEntity` — `FoodLogService` |
| **Remote** | **None** |
| **Restore** | **None** |
| **Future SOT** | Cloud + local cache |
| **Firestore** | `users/{uid}/dailyLogs/{date}/foodEntries/{id}` (proposed) |
| **Offline** | Local write works (**Confirmed** — no network in `FoodLogService`) |

### 6.4 Water logs

Same pattern as food — `WaterLogService`, `WaterEntryEntity`. No remote.

### 6.5 Weight logs

`WeightLogService`, `WeightEntryEntity`. No delete API. No remote.

### 6.6 Daily logs

`DailyLogEntity` — `DailyLogService`. Rollups computed from children. Proposed as parent document in Firestore.

### 6.7 Journey/progress

No durable model — `JourneyModel` + state builders.  
**Restore:** recompute from restored logs + health cache + profile.  
**Cannot restore** without nutrition/weight cloud data.

### 6.8 Coach chat

`CoachChatTranscriptMessageEntity` — `SwiftDataCoachChatTranscriptStore`.  
Optional `userId`. Retention 30d/300 msgs.  
**Future:** sync text only; not images by default.

### 6.9 Coach timeline

`CoachTimelineEventEntity` — `SwiftDataCoachTimelineStore`.  
Compaction 30d. No image bytes.  
**Future:** optional sync for cross-device coach context.

### 6.10 Health cache

`LocalHealthCacheStore` — device-local, UID-scoped directory.  
**Restore:** re-sync from HealthKit on each device (not account-backed).

### 6.11 Health summaries

Upload-only Firestore — `FirestoreHealthSummaryRemoteSyncClient`.  
Consent: `HealthSummarySyncConsentStore`.  
Keep consent-gated; do not use as nutrition SOT.

### 6.12 Settings/theme

`ThemeStore` → UserDefaults. Remain local-only.

### 6.13 Meal images

In-memory pending; optional small JPEG in chat entity.  
**Never sync raw images by default.**

---

## 7. Recommended Cloud Data Model

### Sync categories

| Category | Data |
|----------|------|
| **Must cloud sync** | Profile, food entries, water entries, weight entries, daily log rollups |
| **Should cloud sync** | Daily reviews (text), coach timeline (compact) |
| **Optional cloud sync** | Coach chat (text, capped), meal thumbnails |
| **Local-only** | Theme, HealthKit raw, debug, onboarding draft, pending images |
| **Never sync** | Raw HealthKit samples, full meal photos, API tokens |

### Proposed Firestore schema

```
users/{uid}/
  profile/current                          # EXISTS
  syncMetadata/current                     # NEW — cursors, schemaVersion, lastPullAt
  dailyLogs/{yyyy-MM-dd}                   # NEW — rollup doc
    foodEntries/{foodEntryId}              # NEW — subcollection OR embedded map (see plan)
    waterEntries/{waterEntryId}            # NEW
  weightEntries/{entryId}                  # NEW — id = UUID string
  dailyReviews/{yyyy-MM-dd}                # NEW — optional
  coachMessages/{messageId}                # NEW — optional
  coachTimelineEvents/{eventId}            # NEW — optional
  settings/current                         # NEW — optional (units could stay in profile)
  healthDaily/{dayId}                      # EXISTS (consent-gated)
  healthWorkouts/{workoutId}               # EXISTS
  healthRecovery/{dayId}                   # EXISTS
  healthWeeklyReviews/{weekId}             # EXISTS
  healthSyncMetadata/current               # EXISTS
```

### Document field contract (nutrition example)

**`users/{uid}/dailyLogs/{yyyy-MM-dd}`**

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Same as date key |
| `userId` | string | Must equal `{uid}` |
| `localDate` | string | `yyyy-MM-dd` |
| `timezone` | string | User calendar TZ |
| `calorieTarget` | int | Frozen snapshot |
| `caloriesConsumed` | int | Rollup |
| `proteinConsumed` | double | … |
| `waterConsumedMl` | int | … |
| `weightKg` | double? | Day snapshot |
| `schemaVersion` | int | Start at 1 |
| `updatedAt` | timestamp | Server or client |
| `deletedAt` | timestamp? | Tombstone for day-level delete (rare) |
| `lastMutationId` | string | UUID for idempotency |
| `deviceId` | string | Installed device identifier |
| `source` | string | `ios_forma` |

**`foodEntries/{foodEntryId}`** — mirror `FoodEntryEntity` fields + `deletedAt`, `mutationId`, `schemaVersion`.

**Conflict policy:** Last-write-wins on `updatedAt` with `mutationId` dedup; server rejects `userId != uid`.

**Subcollection vs embedded:** Use **subcollections** for food/water entries to avoid 1MB doc limits on heavy logging days.

---

## 8. Local Schema Changes Needed

### Proposed `FormaSchemaV7` additions (all user-data entities)

| Field | Purpose |
|-------|---------|
| `ownerUID` | Partition reads/writes by Firebase UID |
| `cloudUpdatedAt` | Remote timestamp for conflict |
| `localUpdatedAt` | Local mutation time |
| `syncStatus` | `pending` \| `synced` \| `failed` |
| `lastSyncError` | Optional string code |
| `deletedAt` | Soft delete tombstone |
| `mutationId` | UUID per mutation for idempotent upload |
| `schemaVersion` | Per-entity codec version |

### Entity-specific notes

| Entity | Required changes |
|--------|------------------|
| `UserProfileEntity` | Add sync fields; `ownerUID` already exists |
| `DailyLogEntity` | Add `ownerUID`, sync fields; unique key may become `(ownerUID, date)` |
| `FoodEntryEntity` | Add `ownerUID`, sync fields |
| `WaterEntryEntity` | Add `ownerUID`, sync fields |
| `WeightEntryEntity` | Add `ownerUID`, sync fields |
| `DailyReviewEntity` | Add `ownerUID`, sync fields |
| `CoachChatTranscriptMessageEntity` | Require `userId` non-null; add sync fields |
| `CoachTimelineEventEntity` | Require `userId` non-null; add sync fields |

### SwiftData migration

- Add `FormaSchemaV7` in `FormaModelMigration.swift`
- Lightweight migration for new optional fields with defaults
- Backfill job: set `ownerUID` from `UserProfileEntity.ownerUID` for existing rows
- **Risk:** rows created pre-auth with no owner — prompt user on first sync after upgrade

### New local tables (optional)

- `SyncOutboxEntity` — pending mutations queue
- `SyncCursorEntity` — last pulled timestamps per collection

---

## 9. Sync Architecture Recommendation

### Requirements

- Local-first writes (keep `FitnessActionCenter` as mutation hub)
- Background upload queue
- Initial cloud restore on login (pull before push on first login for reinstall)
- Incremental sync on foreground
- Retry with exponential backoff
- Offline logging with `syncStatus = pending`
- Idempotent writes via `mutationId`
- Tombstones for deletes
- Per-user namespace: all queries filter `ownerUID == AuthManager.currentUID`
- Account switch: wipe or quarantine local namespace before loading new UID

### Option comparison

| Approach | Pros | Cons |
|----------|------|------|
| **A. Firestore direct** | Low latency, offline SDK, matches existing profile pattern | Client conflict logic, large rule surface |
| **B. Functions-mediated** | Centralized validation, easier migrations | Extra latency, more ops |
| **C. Hybrid** | Profile + nutrition direct; heavy batch via Functions optional | Two code paths |

### **Recommendation: A — Firestore direct client sync (hybrid-ready)**

**Rationale:** App already uses `FirestoreCloudUserProfileStore` and `FirestoreHealthSummaryRemoteSyncClient` directly. Nutrition sync fits the same pattern. Add a `NutritionSyncEngine` parallel to health sync. Introduce Functions later only for bulk backfill or GDPR delete if needed.

### Sync engine components (new)

```
FitnessActionCenter (write)
  → Local repository (SwiftData + ownerUID)
  → SyncOutbox.enqueue(mutation)
  → NutritionSyncEngine (background)
       ├─ pushPendingMutations()
       └─ pullRemoteChanges(since: cursor)
  → AppRefreshCenter (UI refresh)
```

**Account switch:** `AccountDataNamespaceService.switchToUID(uid:)` — delete or archive rows where `ownerUID != uid` before pull.

---

## 10. Initial Restore Flow

### Blocking vs non-blocking

| Step | Blocking? |
|------|-----------|
| Auth + profile fetch | **Blocking** — existing pattern |
| Sync metadata + recent 30 days daily logs | **Blocking** — user expects Today populated |
| Weight entries (90 days) | **Blocking** for Journey weight chart |
| Older history | **Non-blocking** — background |
| Coach chat/timeline | **Non-blocking** — optional phase |

### Flow

1. User opens fresh install → welcome
2. Google sign-in → `AuthManager.signInWithGoogle`
3. `ProfileBootstrapService.resolve` → profile restored
4. **NEW:** `AccountRestoreCoordinator.beginRestore(uid:)`
5. Fetch `syncMetadata/current`
6. Pull weight entries + daily logs (last 30 days) + food/water children
7. Write to SwiftData with `ownerUID`, `syncStatus = synced`
8. `AppRefreshCenter` notify → Today/Journey reload
9. Background: pull older days, coach data if enabled

### UI states

| State | Copy (proposed) |
|-------|-----------------|
| Restoring | "Restoring your progress…" |
| Partial failure | "Some history couldn't be downloaded. You can keep using the app." + Retry |
| Offline first launch | "You're offline. Showing saved data on this device." / empty if reinstall |
| No cloud history | "Welcome back. Your plan is restored. Start logging to rebuild history." |

### Telemetry (proposed events)

- `account_restore_started`, `account_restore_completed`, `account_restore_partial`, `account_restore_failed`

---

## 11. App Lifecycle Test Matrix

### App Kill Tests

| Test | Expected | Classes |
|------|----------|---------|
| Log meal → kill → reopen | Meal visible | `FoodLogService`, `TodayModel` |
| Add water → kill → reopen | Water total correct | `WaterLogService` |
| Log weight → kill → reopen | Weight in history | `WeightLogService` |
| Image analysis before result → kill | No food entry; session gone | `CoachModel`, `ImageAnalysisSessionStore` |
| Image analysis committed → kill | Food + chat persist | `FoodLogService`, `CoachModel.persistTranscript` |

### Reinstall Tests

| Test | Expected (today) | Expected (after feature) |
|------|-------------------|--------------------------|
| Cloud profile only | Plan yes, logs no | Plan yes, logs no until first use |
| Cloud profile + cloud logs | Plan yes, logs no | Plan + logs yes |
| Empty cloud | Onboarding | Onboarding |
| Offline after reinstall | Profile fail or cached | Queue restore |

### Cross-Device Tests

| Test | Expected (after feature) |
|------|--------------------------|
| A logs meal → B opens | B sees meal after sync |
| A edits → B refresh | B sees edit |
| A deletes → B refresh | B removes entry |
| A logs weight → B Journey | B trend updates |
| A changes plan → B Plan | B targets update |

### Multi-User Tests

| Test | Expected (after feature) |
|------|--------------------------|
| A logs food → logout → B login | B sees **no** A food |
| A logs back in | A food restored from cloud |
| A logs food unscoped (migration) | Upgrade backfill attaches to A only after confirm |

---

## 12. Security Rules Plan

**Current:** `firestore.rules` — profile only.

**Required expansion** (pseudocode):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }
    function docUserId() {
      return request.resource.data.userId;
    }
    function validUserId(uid) {
      return docUserId() == uid;
    }

    match /users/{uid}/profile/{docId} {
      allow read, write: if isOwner(uid);
    }

    match /users/{uid}/syncMetadata/{docId} {
      allow read, write: if isOwner(uid) && validUserId(uid);
    }

    match /users/{uid}/dailyLogs/{dayId} {
      allow read, write: if isOwner(uid) && validUserId(uid);
      match /foodEntries/{entryId} {
        allow read, write: if isOwner(uid) && validUserId(uid);
      }
      match /waterEntries/{entryId} {
        allow read, write: if isOwner(uid) && validUserId(uid);
      }
    }

    match /users/{uid}/weightEntries/{entryId} {
      allow read, write: if isOwner(uid) && validUserId(uid);
    }

  // health collections per HEALTH_SUMMARY_SYNC_CONTRACT.md
  }
}
```

Validate `schemaVersion` is int, `deletedAt` is timestamp or null, deny writes where `userId != uid`.

---

## 13. Privacy and Product Decision Review

| Data | Sync by Default? | User Consent Needed? | Reason |
|------|------------------|----------------------|--------|
| Food logs | **Yes** (signed-in) | No — core product | Account restore expectation |
| Water logs | **Yes** | No | Core logging |
| Weight logs | **Yes** | No — sensitive but essential | Journey continuity |
| Daily rollups | **Yes** | No | Derived from above |
| Profile/plan | **Yes** (exists) | No | Already synced |
| Coach chat text | **Optional** | Soft opt-in or default limited | Privacy sensitivity |
| Meal images | **No** | Yes if ever | Large + sensitive |
| Health summaries | **No** | **Yes** (exists) | Already consent-gated |
| HealthKit raw | **Never** | N/A | Apple Health stays on device |
| Theme | **No** | No | Device preference |
| Daily review AI text | **Should** | No | Nice for cross-device |

---

## 14. Migration Plan

### Cohorts

| Cohort | Strategy |
|--------|----------|
| Signed-in user with local logs + cloud profile | Backfill `ownerUID` from profile; upload with user confirmation if unowned rows |
| Signed-in user, cloud profile only | Pull-only on first launch after upgrade |
| Local logs, no `ownerUID` | Block upload until user confirms "Attach history to this account" |
| nil-user coach rows | Migrate to current UID or delete |
| Multi-user device residue | On login, quarantine rows not matching UID; offer "Remove other user's data from this device" |
| Duplicate upload prevention | `mutationId` + Firestore `set` with merge on `mutationId` equality check |

### User prompt (recommended)

First launch after upgrade with local unowned data:

> "We found meal history on this device. Attach it to your account `[email]` for backup and sync?"

Options: Attach / Not now / Delete local history

---

## 15. Implementation Phases

See **`../SprintReports/ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`** for file-level tasks, tests, and Cursor workflow.

Summary:

1. **Phase 1** — UID hardening + account switch safety  
2. **Phase 2** — Firestore schema, rules, DTOs, emulator tests  
3. **Phase 3** — Local-first sync engine + outbox  
4. **Phase 4** — Fresh install restore pipeline + UI  
5. **Phase 5** — Cross-device real-time/foreground sync + conflicts  
6. **Phase 6** — Account delete, export, privacy copy  

---

## 16. Concrete Acceptance Criteria

- [ ] Reinstall + same account restores profile, plan, food, water, weight, Journey  
- [ ] Second device loads same core logging history  
- [ ] Force kill never loses committed logs (already true; regression tests)  
- [ ] In-flight uncommitted actions handled explicitly  
- [ ] User B never sees User A logs on same device  
- [ ] Deletes propagate cross-device  
- [ ] Edits propagate cross-device  
- [ ] Offline logs upload on reconnect  
- [ ] Firestore rules prevent cross-user access  
- [ ] Existing local data migrates without duplication  
- [ ] Tests: reinstall, kill, offline sync, multi-user  

---

## 17. Files Inspected

### Persistence
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelMigration.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelContainer.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/SwiftDataStore.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/*.swift` (13 files)

### Repositories & use cases
- `Fitness Coach/Data/Repositories/UserProfileService.swift`
- `Fitness Coach/Data/Repositories/DailyLogService.swift`
- `Fitness Coach/Data/Repositories/FoodLogService.swift`
- `Fitness Coach/Data/Repositories/WaterLogService.swift`
- `Fitness Coach/Data/Repositories/WeightLogService.swift`
- `Fitness Coach/Data/Repositories/ReviewService.swift`
- `Fitness Coach/Data/Repositories/CoachChatTranscriptPersistenceRepository.swift`
- `Fitness Coach/Data/Repositories/CoachTimelinePersistenceRepository.swift`
- `Fitness Coach/Application/UseCases/FitnessActionCenter.swift`
- `Fitness Coach/Application/UseCases/ProfileBootstrapService.swift`

### Cloud & rules
- `Fitness Coach/Infrastructure/Cloud/FirestoreCloudUserProfileStore.swift`
- `Fitness Coach/Infrastructure/Cloud/CloudUserProfileDocument.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreHealthSummaryRemoteSyncClient.swift`
- `firestore.rules`, `firebase.json`

### Auth & routing
- `Fitness Coach/Application/Services/Auth/AuthManager.swift`
- `Fitness Coach/Application/Services/Auth/AuthSignInSupport.swift`
- `Fitness Coach/Features/Auth/Coordinator/AuthGateCoordinator.swift`
- `Fitness Coach/App/Routing/ProfileBootstrapCoordinator.swift`
- `Fitness Coach/App/Routing/AppRouteResolver.swift` (`AuthLogoutPolicy`)

### Journey, Plan, Coach
- `Fitness Coach/Features/Journey/Model/JourneyModel.swift`
- `Fitness Coach/Features/Coach/Model/CoachModel.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextFoodMemoryBuilder.swift`
- `Fitness Coach/Application/Services/SwiftDataCoachChatTranscriptStore.swift`
- `Fitness Coach/Domain/Coach/CoachChatTranscriptRetentionPolicy.swift`

### Health
- `Fitness Coach/Health/Cache/LocalHealthCacheStore.swift`
- `Fitness Coach/Health/Sync/HealthSummarySyncService.swift`

### Tests
- `Fitness CoachTests/SignOutHygieneTests.swift`
- `Fitness CoachTests/LogoutRoutingTests.swift`

---

## 18. Deliverables Index

| # | Deliverable | Location |
|---|-------------|----------|
| 1 | Context packet | This file |
| 2 | Implementation plan | `../SprintReports/ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md` |
| 3 | Prioritized gap table | §15 + Implementation Plan §1 |
| 4 | Firestore schema | §7 |
| 5 | SwiftData migration plan | §8 |
| 6 | Restore flow diagram | §4, §10 |
| 7 | Sync engine design | §9 |
| 8 | Test matrix | §11 |
| 9 | Risk list | Implementation Plan §2 |
| 10 | Phase workflow | Implementation Plan §3–8 |

---

## Prioritized Gap Table

| Priority | Gap | Evidence | Risk |
|---------|-----|----------|------|
| P0 | No cloud backup for nutrition logs | No Firestore food/water paths | Total loss on reinstall |
| P0 | Journey not restorable | `JourneyModel` reads local logs only | Broken user expectation |
| P0 | Multi-user nutrition leakage | `FoodEntryEntity` no ownerUID; logout no wipe | Privacy |
| P0 | Reinstall loses all logging history | SwiftData deleted | Core product failure |
| P1 | Health rules missing for health sync | `firestore.rules` | Sync may fail silently |
| P1 | Coach nil userId includes all rows | `CoachChatTranscriptPersistenceRepository:78-81` | Chat leakage |
| P1 | No offline upload queue for logs | `FoodLogService` local only | Offline data stranded on device |
| P1 | No cross-device edit/delete propagation | No sync engine | Inconsistent devices |
| P2 | Weight cannot be deleted | No API in `WeightLogService` | Bad data persists |
| P2 | Daily reviews not backed up | `DailyReviewEntity` local | Narrative lost |
| P2 | Theme/consent reset on reinstall | UserDefaults wiped | UX friction |
| P3 | Health summaries upload but never restore | `HealthSummarySyncService` | Missed opportunity for HI only |

---

## Unknowns / Needs Manual Verification

| Item | Status |
|------|--------|
| Production Firestore rules for health (beyond committed file) | **Unknown** |
| Whether users already have cloud profiles without knowing logs aren't backed up | **Unknown** — product analytics |
| iOS SwiftData store exact file path on disk | **Likely** Application Support default |
| Firebase Auth persistence across reinstall in all iOS versions | **Likely** cleared by app policy |
| Opt-in rate for health remote sync | **Unknown** |

---

*End of context packet. No application code was modified.*
