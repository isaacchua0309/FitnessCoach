# User Data Storage Context Packet

**Repository:** FitnessCoach (iOS app `Fitness Coach/` + Firebase `functions/`)  
**Generated:** 2026-07-04  
**Method:** Full-repo code audit. Claims marked **Confirmed**, **Likely**, or **Unknown**.

---

## 1. Executive Summary

### What data exists in the app

| Category | Examples | Status |
|----------|----------|--------|
| Profile & plan | Demographics, targets, unit system, diet preference | **Confirmed** — `UserProfileEntity`, `CloudUserProfileDocument` |
| Nutrition logs | Food entries, daily macro totals, water | **Confirmed** — SwiftData only |
| Weight | Per-day weight entries + daily log mirror | **Confirmed** — SwiftData only |
| Daily AI reviews | Narrative summaries per day | **Confirmed** — `DailyReviewEntity` |
| Coach | Chat transcript, timeline events, in-flight images | **Confirmed** — SwiftData + in-memory |
| Health / training | HealthKit-derived workouts, steps, recovery, intelligence | **Confirmed** — file cache + optional Firestore summaries |
| Onboarding | Draft wizard state, coaching context | **Confirmed** — UserDefaults |
| Settings | Theme, health sync consent, tab selection | **Confirmed** — UserDefaults |
| AI context | `CoachContextPacketV2` (ephemeral per request) | **Confirmed** — built on demand, sent to `aiGateway` |

### What is stored locally (**Confirmed**)

- **SwiftData** (`FormaSchemaV6`): profile, daily logs, food/water/weight/review, coach timeline, coach chat transcript (`Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelMigration.swift`)
- **UserDefaults**: onboarding draft, coaching context, theme, public-entry session, profile cloud-sync hints, health sync consent/state (per-UID keys), SwiftData migration gate, main-tab read migration, auth install marker
- **Application Support files**: `Forma/HealthCache/{userID}/` JSON bundles (`LocalHealthCacheStore.swift`)
- **In-memory only**: pending coach images, image analysis sessions, pipeline tracer, health sync phase, training insights `lastSyncedAt`

### What is stored remotely (**Confirmed**)

- **Firebase Auth**: Google Sign-In session (SDK keychain-backed)
- **Firestore**: `users/{uid}/profile/current` (profile/plan snapshot)
- **Firestore** (opt-in upload-only): `healthDaily`, `healthWorkouts`, `healthRecovery`, `healthWeeklyReviews`, `healthSyncMetadata` under `users/{uid}/`
- **Firebase Functions `aiGateway`**: stateless AI inference; no server-side user DB persistence in `functions/src/index.ts`
- **Firebase Storage**: **not used** (no client SDK, no `storage.rules`)

### What appears duplicated

| Data | Copies | Evidence |
|------|--------|----------|
| Profile targets | `UserProfileEntity` + `DailyLogEntity` target fields + `CloudUserProfileDocument.targets` | **Confirmed** — `DailyLogService.syncTodayTargetsFromProfile()` |
| Weight | `WeightEntryEntity` + `DailyLogEntity.weightKg` | **Confirmed** — `WeightLogService.logWeight` |
| Common/recent foods | Derived from `FoodEntryEntity` at runtime; also embedded in `CoachContextPacketV2` | **Confirmed** — `CoachContextFoodMemoryBuilder` |
| Health summaries | HealthKit → local cache → optional Firestore upload (upload not read back) | **Confirmed** — `HealthSummarySyncService` |
| Coach chat | In-memory `CoachModel.messages` + SwiftData transcript | **Confirmed** — `SwiftDataCoachChatTranscriptStore` |

### What appears missing

- Remote backup for food, water, weight, coach chat, timeline (**Confirmed** — no Firestore paths in client)
- Account / local data deletion implementation (**Confirmed** — `SettingsDeleteDataActionHandler.perform()` → `.notImplemented`)
- Weight entry delete API (**Confirmed** — no `deleteWeight` in `WeightLogService.swift`)
- Firestore security rules for health collections in committed `firestore.rules` (**Confirmed** — profile only)
- Sign-out local profile wipe despite `FormaAbTest.Auth.deletesLocalProfileOnSignOut = true` (**Confirmed** — flag unwired; `SignOutHygieneTests` asserts profile survives)
- User scoping on nutrition/weight SwiftData rows (**Confirmed** — no `ownerUID` on `FoodEntryEntity`, etc.)

### Unclear ownership

- **Device-local nutrition data vs Firebase UID**: Profile has `ownerUID`; food/water/weight logs are device-global (**Confirmed**)
- **Coach entities with `userId == nil`**: `CoachChatTranscriptPersistenceRepository.fetchEntities` includes entities where `userId` is nil for any signed-in user (**Confirmed** — lines 78–81)
- **Source of truth for plan**: Local SwiftData profile with async Firestore mirror; conflict UI exists (`accountProfileMismatch`) but nutrition logs never sync (**Confirmed**)

### Highest-risk gaps

1. **Multi-user local leakage**: Food/water/weight/coach data not partitioned by UID; logout does not clear SwiftData (**Confirmed**)
2. **Health Firestore rules gap**: Client writes health collections; `firestore.rules` only allows profile (**Confirmed**)
3. **Sensitive data in AI requests**: Meal photos as base64, full `CoachContextPacketV2` to `aiGateway` (**Confirmed**)
4. **DEBUG logs may include food names, calories, pipeline user messages** (**Confirmed** — `CoachFoodEstimateDebugLogger`, `FormaPipelineTracer`)
5. **No delete path** for account or bulk local wipe (**Confirmed**)

---

## 2. Storage Architecture Overview

```
User action
    → View (SwiftUI) / Model (TodayModel, CoachModel, OnboardingModel, …)
        → Coordinator or FitnessActionCenter (canonical mutations)
            → Repository Service (FoodLogService, UserProfileService, …)
                → SwiftDataStore (insert/fetch/delete/save)
                → UserDefaults stores (draft, theme, consent)
                → LocalHealthCacheStore (JSON files per UID)
                → FirestoreCloudUserProfileStore / FirestoreHealthSummaryRemoteSyncClient
                → AIService → FormaAIBackendClient → HTTPS aiGateway (Bearer Firebase ID token)
```

### Major layers

| Layer | Technology | Location |
|-------|------------|----------|
| Primary app DB | SwiftData SQLite (default Application Support) | `FormaModelContainer.swift` |
| Preferences & drafts | UserDefaults (`.standard` + onboarding suite in `AppContainer`) | Various `*Store.swift` |
| Health normalized cache | FileManager JSON | `{ApplicationSupport}/Forma/HealthCache/{userID}/` |
| Cloud profile | Firestore | `users/{uid}/profile/current` |
| Cloud health summaries | Firestore (upload-only, consent-gated) | `users/{uid}/health*` |
| AI inference | Firebase Functions HTTPS | `aiGateway` |
| Auth session | Firebase Auth + Google Sign-In (SDK keychain) | `AuthManager.swift` |
| Raw HealthKit | Not persisted; queried on demand | `HealthKitManager.swift` |

**No Core Data, no `@AppStorage`, no custom Keychain wrapper, no Firebase Storage** (**Confirmed** via repo search).

---

## 3. Complete Data Model Inventory

| Model / Type | File Path | Purpose | Key Fields | Local Storage | Remote Storage | Owner Service | Notes |
|-------------|-----------|---------|------------|---------------|----------------|---------------|-------|
| `UserProfile` | `Fitness Coach/Domain/Models/UserProfile.swift` | Domain profile | id, demographics, targets, unitSystem | SwiftData `UserProfileEntity` | `CloudUserProfileDocument` | `UserProfileService` | `ownerUID` links to Firebase |
| `UserProfileEntity` | `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/UserProfileEntity.swift` | Persistence | id, ownerUID, flattened targets, metadata | SwiftData | — | `UserProfileService` | Single on-device row |
| `CloudUserProfileDocument` | `Fitness Coach/Infrastructure/Cloud/CloudUserProfileDocument.swift` | Firestore DTO | name, birthDate, age, sex, metrics, targets, onboardingCompletedAt, updatedAt | — | Firestore `profile/current` | `FirestoreCloudUserProfileStore` | doc id `current` |
| `DailyLog` | `Fitness Coach/Domain/Models/DailyLog.swift` | Daily rollup | date, totals, targets, weightKg | SwiftData `DailyLogEntity` | — | `DailyLogService` | Not UID-scoped |
| `DailyLogEntity` | `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/DailyLogEntity.swift` | Persistence | macro totals, targets, relationships | SwiftData | — | `DailyLogService` | Cascade to food/water/review |
| `FoodEntry` | `Fitness Coach/Domain/Models/FoodEntry.swift` | Food log domain | nutrition, source, confidence, imageUrl | SwiftData `FoodEntryEntity` | — | `FoodLogService` | |
| `FoodEntryEntity` | `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/FoodEntryEntity.swift` | Persistence | componentsJSON (Codable blob) | SwiftData | — | `FoodLogService` | |
| `FoodLogDraft` / `FoodDraft` | `Fitness Coach/Data/DTOs/FoodLogDraft.swift` | AI/mutation DTO | meal components, totals | Transient | Sent in AI requests | `FitnessActionCenter` | |
| `WaterEntry` / `WaterEntryEntity` | `Domain/Models/WaterEntry.swift`, `Entities/WaterEntryEntity.swift` | Water log | amountMl, dailyLogId | SwiftData | — | `WaterLogService` | |
| `WeightEntry` / `WeightEntryEntity` | `Domain/Models/WeightEntry.swift`, `Entities/WeightEntryEntity.swift` | Weight log | date, weightKg, note | SwiftData | — | `WeightLogService` | Standalone entity |
| `DailyReview` / `DailyReviewEntity` | `Domain/Models/DailyReview.swift`, `Entities/DailyReviewEntity.swift` | AI daily narrative | summary fields | SwiftData | — | `ReviewService` | AI text only; numbers deterministic |
| `ChatMessage` | `Fitness Coach/Domain/Models/ChatMessage.swift` | Coach UI message | text, attachments, structured content | SwiftData `CoachChatTranscriptMessageEntity` | — | `SwiftDataCoachChatTranscriptStore` | |
| `CoachChatTranscriptMessageEntity` | `Entities/CoachChatTranscriptMessageEntity.swift` | Chat persistence | thumbnailJPEG, fullImageJPEG, structuredContentJSON | SwiftData | — | `CoachChatTranscriptPersistenceRepository` | Optional userId |
| `CoachTimelineEvent` | `Fitness Coach/Domain/CoachTimeline/` | Timeline domain | type, payload, links | SwiftData `CoachTimelineEventEntity` | — | `SwiftDataCoachTimelineStore` | No image bytes |
| `CoachTimelineEventEntity` | `Entities/CoachTimelineEventEntity.swift` | Timeline persistence | payloadJSON, userId?, schemaVersion | SwiftData | — | `CoachTimelinePersistenceRepository` | |
| `CoachContextPacketV2` | `Fitness Coach/Infrastructure/AI/CoachContextPacketV2.swift` | AI context transport | meta, profile, today, training, HI, timeline, chat, meals, foods | Ephemeral (built per request) | Sent to aiGateway | `CoachContextPacketV2Builder` | schemaVersion 2 |
| `OnboardingDraft` | `Fitness Coach/Data/DTOs/Onboarding/OnboardingDraft.swift` | Wizard snapshot | form fields, generatedPlan, step | UserDefaults `forma.onboarding.draft` | — | `OnboardingDraftStore` | draftVersion 2 |
| `OnboardingCoachingContext` | `Fitness Coach/Domain/Onboarding/OnboardingCoachingContext.swift` | Coaching handoff | onboardingVersion 4 | UserDefaults `forma.onboarding.coachingContext` | — | `OnboardingCoachingContextStore` | |
| `AppThemePreferences` | `Fitness Coach/DesignSystem/Theme/AppThemePreferences.swift` | Theme prefs | appearance, palette | UserDefaults | — | `ThemeStore` | Not cloud-synced |
| `HealthCachedDayFile` etc. | `Fitness Coach/Health/Cache/` | Health cache files | normalized day bundles | JSON files per UID | — | `LocalHealthCacheStore` | 90-day retention |
| `HealthDailySummarySyncPayload` etc. | `Fitness Coach/Health/Sync/` | Remote health DTOs | envelope + domain fields | — | Firestore health* | `FirestoreHealthSummaryRemoteSyncClient` | Upload-only |
| `HealthSummarySyncConsentState` | `Health/Sync/HealthSummarySyncConsentStore.swift` | Consent | optedIn, timestamps | UserDefaults per UID | — | `UserDefaultsHealthSummarySyncConsentStore` | |
| `AIParseCommandRequest` … | `Fitness Coach/Infrastructure/AI/AIContracts.swift` | AI gateway DTOs | text, context, images | Transient HTTP | aiGateway (stateless) | `FormaAIBackendClient` | See §8 |
| `WorkoutEntryEntity` / `ExerciseSetEntity` | `Entities/WorkoutEntryEntity.swift`, `ExerciseSetEntity.swift` | Legacy manual workouts | — | Migration-only (removed v3) | — | — | **Deprecated** |
| `ChatMessageEntity` | `Entities/ChatMessageEntity.swift` | Legacy chat | — | Migration-only (removed v2) | — | — | **Deprecated** |
| `WeeklyReviewEntity` | `Entities/WeeklyReviewEntity.swift` | Legacy weekly review | — | Migration-only (removed v2) | — | — | **Deprecated** |
| `DebugRecordEntity` | `Entities/DebugRecordEntity.swift` | Legacy debug | contextJson | Migration-only (removed v2) | — | — | **Deprecated** |

---

## 4. Local Persistence Inventory

### 4.1 SwiftData (FormaSchemaV6)

**Files:** `FormaModelContainer.swift`, `SwiftDataStore.swift`, `FormaModelMigration.swift`, `FormaSwiftDataMigrationGate.swift`, all `Entities/*.swift`, repository services under `Data/Repositories/`.

| Aspect | Detail |
|--------|--------|
| **Stored data** | Profile, daily logs, food, water, weight, daily reviews, coach timeline, coach chat |
| **Schema** | `FormaSchemaV6` — 8 active `@Model` types |
| **Read paths** | `SwiftDataStore.fetch` / `fetchOne`; domain services (`FoodLogService.getFoodEntries`, etc.) |
| **Write paths** | `SwiftDataStore.insert` + `save`; `FitnessActionCenter` for feature mutations |
| **Update paths** | Entity mutation in services; `replaceAll` for chat transcript |
| **Delete paths** | `SwiftDataStore.delete`; food/water delete APIs; timeline compaction; chat retention prune; profile `replaceLocalProfile` deletes prior profile row |
| **Migration** | `FormaMigrationPlan` — lightweight V1→V6; gate flags in UserDefaults |
| **User-scoped** | **Partial** — only `UserProfileEntity.ownerUID` and optional `userId` on coach entities |
| **Logout clears** | **No** (**Confirmed** — `SignOutHygieneTests`) |
| **Risks** | Device-global nutrition data; coach rows with nil `userId` visible to all sessions |

### 4.2 UserDefaults

| Key / Store | File | Data | User-scoped | Logout clears |
|-------------|------|------|-------------|---------------|
| `forma.onboarding.draft` | `OnboardingDraftStore.swift` | `OnboardingDraft` JSON | No | Cleared on onboarding complete / explicit clear |
| `forma.onboarding.coachingContext` | `OnboardingCoachingContextStore.swift` | `OnboardingCoachingContext` | No | `clear()` on demand |
| `forma.publicEntry.suppressAutomaticResume` | `PublicEntrySessionStore.swift` | Bool | No | Set on sign-out |
| `forma.publicEntry.pendingEntrySource` | `PublicEntrySessionStore.swift` | logout/sessionExpired | No | Consumed on read |
| `forma.profileCloudSync.lastSyncedUID` | `ProfileCloudSyncStore.swift` | UID + timestamp | Partial | **Yes** — `AuthLogoutPolicy.clearTransientSessionMetadata` |
| `forma.theme.appearance` / `forma.theme.palette` | `AppThemePreferences.swift` | Theme enums | No | **No** |
| `forma.healthSummaryRemoteSyncConsent.{userID}` | `HealthSummarySyncConsentStore.swift` | Consent JSON | **Yes** | **No** (per-UID keys persist) |
| `forma.healthSummaryRemoteSync.{userID}` | `HealthSummaryRemoteSyncStateStore.swift` | Sync state JSON | **Yes** | **No** |
| `forma.swiftdata.schemaVersion` | `FormaSwiftDataMigrationGate.swift` | Int | No | **No** |
| `forma.swiftdata.coachV2MigrationComplete` | `FormaSwiftDataMigrationGate.swift` | Bool | No | **No** |
| `forma.mainTab.selectedTab` | `MainTabView.swift` | Tab id (read + legacy migration) | No | **No** |
| `FitPilot.auth.installRegistered` | `AuthSignInSupport.swift` (`AuthInstallPolicy`) | Bool | No | **No** |
| `forma.trainingIntegration.stubConnected/Denied` | `HealthTrainingService.swift` | DEBUG stubs | No | `resetStubFlags` |

### 4.3 AppStorage

**None** (**Confirmed** — zero `@AppStorage` in `Fitness Coach/`).

### 4.4 Keychain

**No app-owned Keychain code** (**Confirmed**). Firebase Auth and Google Sign-In persist sessions via SDK (**Likely** — documented in `AuthSignInSupport.swift` install-marker behavior).

### 4.5 Local JSON / files (Health cache)

**File:** `Fitness Coach/Health/Cache/LocalHealthCacheStore.swift`

| Aspect | Detail |
|--------|--------|
| **Root** | `{ApplicationSupport}/Forma/HealthCache/{userID}/` |
| **Files** | `days/{yyyy-MM-dd}.json`, `workouts.json`, `sleep.json`, `heart.json`, `body-mass.json`, `recovery/`, `snapshots/`, `weekly-reviews/`, `metadata.json` |
| **User-scoped** | **Yes** — subdirectory per Firebase UID; `anonymous` when unsigned (`HealthCachePolicy.anonymousUserID`) |
| **Read** | `entry(for:)`, aggregate loaders |
| **Write** | `store(_:)`, batch upserts |
| **Delete** | `clearAll()`, `pruneOldEntries` (90-day `HealthCachePolicy.retentionDays`) |
| **L1 cache** | `MemoryHealthCacheStore` — restored from disk on read |
| **Logout clears** | **No** automatic; UID switch rebootstrap in `AppContainer.syncHealthCacheUserID()` |
| **Risks** | Prior user's cache files remain on disk after logout |

### 4.6 Image caches

| Store | File | Persisted | Notes |
|-------|------|-----------|-------|
| `CoachPendingImageLocalSourceStore` | `Features/Coach/Model/CoachPendingImageLocalSourceStore.swift` | **No** | `[UUID: UIImage]` for composer retry |
| `ImageAnalysisSessionStore` | `Features/Coach/Model/ImageAnalysisSession.swift` | **No** | Photo analysis FSM |
| Chat `thumbnailJPEG` / `fullImageJPEG` | `CoachChatTranscriptMessageEntity` | **Yes** | Full JPEG only if ≤ 64KB (`CoachChatTranscriptRetentionPolicy.maxPersistedFullImageBytes`) |
| `FoodEntryEntity.imageUrl` | `FoodEntryEntity.swift` | String URL only | Not image bytes |

### 4.7 In-memory caches with persistence backing

| Component | Backing | File |
|-----------|---------|------|
| `LocalHealthCacheStore` | JSON files | `LocalHealthCacheStore.swift` |
| `SwiftDataCoachChatTranscriptStore` | SwiftData | `SwiftDataCoachChatTranscriptStore.swift` |
| `SwiftDataCoachTimelineStore` | SwiftData | `CoachTimelineStore.swift` |
| `AuthUIDCache` | Not persisted | `Health/Cache/AuthUIDCache.swift` |
| `FormaPipelineTracer` | Not persisted (DEBUG) | `FormaPipelineTracer.swift` |
| `TrainingInsightsStore.lastSyncedAt` | Not persisted | `TrainingInsightsStore.swift` |

---

## 5. Remote Persistence Inventory

### 5.1 Firebase Auth

| Aspect | Detail |
|--------|--------|
| **Files** | `AuthManager.swift`, `AuthSignInSupport.swift`, `Fitness_CoachApp.swift` (`FirebaseApp.configure()`) |
| **Provider** | Google Sign-In only (**Confirmed** — non-Google sessions rejected in `AuthManager.applyUser`) |
| **Methods** | `signInWithGoogle()`, `signOut()`, `getIDToken(forcingRefresh:)`, auth state listener |
| **UID scoping** | `user.uid` → Firestore paths, health cache, AI quota |
| **Server** | `functions/src/index.ts` — `verifyIdToken()` on `Authorization: Bearer` |
| **Risks** | Emulator bypass `FORMA_AI_REQUIRE_AUTH=0` → null uid |

### 5.2 Firestore — Profile

| Aspect | Detail |
|--------|--------|
| **Path** | `users/{uid}/profile/current` |
| **Store** | `FirestoreCloudUserProfileStore.swift` |
| **Read** | `fetch(uid:)` — `getDocument()` |
| **Write** | `save(profile:uid:)` — `setData(merge: true)`; preserves `onboardingCompletedAt` |
| **Delete** | **No client delete API found** |
| **Schema** | `CloudUserProfileDocument` + nested `CloudUserTargets` |
| **Rules** | `firestore.rules` — read/write if `request.auth.uid == userId` (**Confirmed**) |
| **Idempotent writes** | Merge write on profile updates |
| **Sync conflicts** | `ProfileBootstrapService.resolve` checks `ownerUID`; mismatch → `accountProfileMismatch` route |

### 5.3 Firestore — Health summaries (opt-in)

| Collection | Path pattern | Client file |
|------------|--------------|-------------|
| Daily | `users/{uid}/healthDaily/{yyyy-MM-dd}` | `HealthDailySummarySyncPayload.swift` |
| Workouts | `users/{uid}/healthWorkouts/{workoutId}` | `HealthWorkoutSummarySyncPayload.swift` |
| Recovery | `users/{uid}/healthRecovery/{yyyy-MM-dd}` | `RecoverySummarySyncPayload.swift` |
| Weekly reviews | `users/{uid}/healthWeeklyReviews/{weekId}` | `WeeklyHealthReviewSyncPayload.swift` |
| Metadata | `users/{uid}/healthSyncMetadata/current` | `HealthSyncMetadataPayload.swift` |

**Store:** `FirestoreHealthSummaryRemoteSyncClient.swift`  
**Coordinator:** `HealthSummarySyncService.swift`  
**Read from remote:** **None** for app features — upload and delete only (**Confirmed** — contract in `HEALTH_SUMMARY_SYNC_CONTRACT.md`)  
**Write:** `batch.setData(merge: false)` — validates `payload.userId == authUid`  
**Delete:** `deleteRemoteHealthSummaries()` — batch delete + paginated collection cleanup  
**Consent:** `HealthSummarySyncConsentStore` (UserDefaults, not Firestore)  
**Rules in repo:** **Missing** — only profile in `firestore.rules` (**Confirmed** gap)

### 5.4 Firebase Functions — aiGateway

| Aspect | Detail |
|--------|--------|
| **Export** | `aiGateway` — `functions/src/index.ts` |
| **Persistence** | **Stateless** — no Firestore/Storage writes in handler |
| **Auth** | Firebase ID token; per-uid rate limits in `gatewayGuardrails.ts` |
| **User data in requests** | `context: CoachContextPacketV2`, optional images base64, daily review `input`, user text |
| **Logging** | `coachContextLogFields(body.context)` — sanitized metadata, not raw content (**Likely** — see `coachContextPacketV2.ts`) |

### 5.5 Firebase Storage

**Not used** (**Confirmed**).

### 5.6 Firestore rules summary

**Committed file:** `firestore.rules`

```
match /users/{userId}/profile/{docId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

Contract doc `Docs/HealthIntelligence/HEALTH_SUMMARY_SYNC_CONTRACT.md` §7 specifies required health rules — **not present in committed rules**.

---

## 6. User Data Domain Mapping

### 6.1 Auth / User Identity

| | |
|--|--|
| **Primary model** | Firebase `User`; cached in `AuthManager` |
| **Local SOT** | Firebase Auth SDK session (keychain via SDK) |
| **Remote SOT** | Firebase Auth |
| **Sync path** | `AuthManager.startListening()` → app routing |
| **Derived** | `AuthUIDCache.currentUserID()` for health/Firestore scoping |
| **Deletion** | `signOut()` only; no account deletion |
| **Gaps** | `deletesLocalProfileOnSignOut` flag unwired; install marker `FitPilot.auth.installRegistered` |

### 6.2 Profile and Onboarding

| | |
|--|--|
| **Primary model** | `UserProfile` / `UserProfileEntity` |
| **Local SOT** | SwiftData single profile row |
| **Remote SOT** | Firestore `users/{uid}/profile/current` |
| **Sync path** | `ProfileBootstrapService.resolve`, `saveProfileToCloud`, `syncOnboardingProfileToCloud` |
| **Draft path** | `OnboardingDraftStore` (UserDefaults) — pre-commit wizard |
| **Deletion** | `replaceLocalProfile` replaces row; `clearDraft()`; no account delete |
| **Gaps** | Local profile survives logout; pre-auth draft is device-global |

### 6.3 Goals, Calories, Macros

| | |
|--|--|
| **Primary model** | `UserTargets` on `UserProfile` |
| **Local SOT** | `UserProfileEntity` target fields; today's `DailyLogEntity` snapshot |
| **Remote SOT** | `CloudUserTargets` in profile document |
| **Sync path** | Plan save → `FitnessActionCenter.updatePlan` → async cloud upload; `DailyLogService.syncTodayTargetsFromProfile` |
| **Deletion** | With profile replacement only |
| **Gaps** | Historical daily logs freeze old targets; past days not updated on plan change |

### 6.4 Meals and Food Logs

| | |
|--|--|
| **Primary model** | `FoodEntry` / `FoodEntryEntity` |
| **Local SOT** | SwiftData |
| **Remote SOT** | **None** |
| **Sync path** | `FitnessActionCenter.logFood` → `FoodLogService` → `DailyLogService.recalculateDailyTotals` |
| **Derived** | `CoachContextFoodMemoryBuilder` → common/recent foods in AI context |
| **Deletion** | `deleteFoodEntry`, `undoLastFoodEntry`, daily log cascade |
| **Gaps** | No cloud backup; no UID partition; `imageUrl` string only |

### 6.5 Meal Images

| | |
|--|--|
| **Primary model** | `ChatMessageImageAttachment`, `AIMealImagePayload` |
| **Local SOT** | Transcript JPEG bytes (limited); pending images in-memory only |
| **Remote SOT** | **None** (sent transiently to aiGateway) |
| **Sync path** | `CoachImagePipeline` → `CoachMealImageAIRequestBuilder` → `AIService.analyzeMealImage` |
| **Deletion** | Chat retention policy; pending store `removeAll` |
| **Gaps** | Ambiguity: full photos not stored except small JPEG; AI receives base64 |

### 6.6 Water Logs

| | |
|--|--|
| **Primary model** | `WaterEntry` / `WaterEntryEntity` |
| **Local SOT** | SwiftData |
| **Remote SOT** | **None** |
| **Sync path** | `WaterLogService.addWater` |
| **Deletion** | `deleteWaterEntry`, `undoLastWaterEntry` |
| **Gaps** | No remote backup; not UID-scoped |

### 6.7 Weight Logs

| | |
|--|--|
| **Primary model** | `WeightEntry` / `WeightEntryEntity` |
| **Local SOT** | SwiftData |
| **Remote SOT** | Profile `currentWeightKg` only (not log history) |
| **Sync path** | `WeightLogService.logWeight` — upsert by day |
| **Deletion** | **No delete API** |
| **Gaps** | Cannot remove erroneous weight entries |

### 6.8 Workouts and Activity

| | |
|--|--|
| **Primary model** | `HealthWorkoutRecord`, `NormalizedWorkout`, `DailyTrainingActivity` |
| **Local SOT** | `LocalHealthCacheStore` (not SwiftData — legacy `WorkoutEntryEntity` removed v3) |
| **Remote SOT** | Optional `healthWorkouts` Firestore summaries |
| **Sync path** | HealthKit → `HealthDataRepository` → cache → UI; optional `HealthSummarySyncService` |
| **Deletion** | 90-day local prune; remote delete via settings opt-out |
| **Gaps** | `DailyLogEntity.workoutCaloriesBurned` legacy field; manual workout logging removed |

### 6.9 HealthKit and Derived Health Intelligence

| | |
|--|--|
| **Primary model** | `HealthIntelligenceSnapshot`, recovery/workout models under `Health/` |
| **Local SOT** | Health cache files + in-memory engines |
| **Remote SOT** | Optional normalized summaries (not raw HK) |
| **Sync path** | `HealthSyncService`, `HealthIntelligenceSnapshotService` |
| **Deletion** | Cache prune; `clearAll` on UID switch bootstrap |
| **Gaps** | Raw HK never persisted (by design); remote rules missing |

### 6.10 Coach Chat Messages

| | |
|--|--|
| **Primary model** | `ChatMessage` |
| **Local SOT** | SwiftData `CoachChatTranscriptMessageEntity` |
| **Remote SOT** | **None** |
| **Sync path** | `CoachModel` ↔ `SwiftDataCoachChatTranscriptStore.saveMessages` |
| **Deletion** | 30-day / 300-message retention (`CoachChatTranscriptRetentionPolicy`) |
| **Gaps** | Nil `userId` entities leak across users; images partially persisted |

### 6.11 AI Context Packets

| | |
|--|--|
| **Primary model** | `CoachContextPacketV2` (schemaVersion 2) |
| **Local SOT** | **Not persisted** — built per request |
| **Remote SOT** | Transient in aiGateway request body |
| **Sync path** | `CoachContextPacketV2Builder.makeContext` → `AIService` / `FormaAIBackendClient` |
| **Server sanitization** | `coachContextPacketV2.ts` — size limits, strips suspicious base64 |
| **Gaps** | Large surface area of user data per request; compaction policies must stay aligned client/server |

### 6.12 Plan Data

| | |
|--|--|
| **Primary model** | `UserProfile` + `UserTargets` (no separate plan entity) |
| **Presentation** | `PlanModel`, `PlanFormState` |
| **Local SOT** | SwiftData profile |
| **Remote SOT** | Cloud profile document |
| **Sync path** | `FitnessActionCenter.updatePlan` / `applyPlanTargets` |
| **Gaps** | Plan is not versioned; no plan history |

### 6.13 Journey / Progress Data

| | |
|--|--|
| **Primary model** | Computed `JourneyViewState`, streaks, projections |
| **Local SOT** | **None** — aggregated from logs + health cache |
| **Remote SOT** | Optional weekly health review summaries |
| **Sync path** | `JourneyModel.loadProgress()` via state builders |
| **Gaps** | No persisted journey state; recompute on every load |

### 6.14 Timeline Events

| | |
|--|--|
| **Primary model** | `CoachTimelineEvent` |
| **Local SOT** | SwiftData `CoachTimelineEventEntity` |
| **Remote SOT** | **None** |
| **Sync path** | `CoachTimelineRecorder` → `SwiftDataCoachTimelineStore`; backfill from logs |
| **Deletion** | `deleteEventsOlderThan` — 30-day default, 200 events/day cap |
| **Gaps** | Nil userId inclusion; never stores images (by design) |

### 6.15 Common Foods and Recent Foods

| | |
|--|--|
| **Primary model** | `CoachCommonFoodContext`, `CoachRecentMealContext` |
| **Local SOT** | **Derived** from `FoodEntryEntity` history |
| **Remote SOT** | **None** |
| **Sync path** | `CoachContextFoodMemoryBuilder` at context build time |
| **Gaps** | No explicit user food catalog DB |

### 6.16 Settings and Themes

| | |
|--|--|
| **Primary model** | `AppThemePreferences` |
| **Local SOT** | UserDefaults via `ThemeStore` |
| **Remote SOT** | **None** (intentional per `ThemeStore`) |
| **Sync path** | `setAppearance` / `setPalette` → `persist()` |
| **Gaps** | Theme survives logout (may be desired); not reactive across devices |

### 6.17 Debug Logs and Observability

| | |
|--|--|
| **Primary** | OSLog category loggers; `FormaPipelineTracer` (DEBUG in-memory) |
| **Local SOT** | In-memory only (`FormaPipelineTracer` max 300 events) |
| **Remote SOT** | **None** |
| **Production** | `NoOp*AnalyticsLogger` in release builds |
| **Gaps** | DEBUG loggers may emit food names, calories, user messages |

### 6.18 Analytics

| | |
|--|--|
| **Pattern** | `*AnalyticsLogging` protocols per feature |
| **DEBUG** | `OSLog*AnalyticsLogger` |
| **Release** | `NoOp*AnalyticsLogger` |
| **Third-party SDK** | **None found** in app code |
| **Gaps** | No persisted analytics warehouse on device |

---

## 7. Data Flow Traces

### 7.1 New User Sign-In Flow

| Step | Component |
|------|-----------|
| Entry | `AuthGateView` → `ExistingUserSignInView` |
| Action | `AuthGateCoordinator.signInAsExistingUser()` |
| Auth | `AuthManager.signInWithGoogle()` |
| Bootstrap | `ProfileBootstrapService.resolve(uid:)` |
| Reads | Firebase Auth; optional `FirestoreCloudUserProfileStore.fetch` |
| Writes | Optional `UserProfileService.restoreProfile` → SwiftData |
| Backend | Firestore read only (no Functions) |
| Offline | Sign-in requires network for Google/Firebase |
| Gaps | Local SwiftData from prior user may block bootstrap if `ownerUID` mismatch |

### 7.2 Onboarding Save Flow

| Step | Component |
|------|-----------|
| Entry | `OnboardingView` → `OnboardingModel.commitLocalProfileForSavePlan()` |
| Commit | `OnboardingProfileCommitter.commitIfNeeded` → `FitnessActionCenter.createProfile` |
| Local write | `UserProfileService.createProfile` → SwiftData; `OnboardingDraftStore.clearDraft` |
| Sign-in + cloud | `AuthGateCoordinator.handleOnboardingCompletionRequest` → `syncOnboardingProfileToCloud` |
| Remote write | `FirestoreCloudUserProfileStore.save` |
| Gaps | Draft in UserDefaults is device-global pre-sign-in |

### 7.3 Meal Text Log Flow

| Step | Component |
|------|-----------|
| Entry | `TodayView` → `TodayLogMealSheet` |
| Action | `TodayActionCoordinator.saveMeal` → `FitnessActionCenter.logFood` |
| Service | `FoodLogService.addFoodEntry` |
| Storage | Insert `FoodEntryEntity`; `DailyLogService.recalculateDailyTotals` |
| Timeline | `CoachTimelineRecorder.recordFoodLogged` |
| Backend | **None** |
| Offline | **Works** — local only |
| Gaps | No sync |

### 7.4 Meal Photo Analysis Flow

| Step | Component |
|------|-----------|
| Entry | `CoachView` → `CoachImagePickFlowController` |
| Model | `CoachModel.runImageAnalysisSession` |
| Pipeline | `CoachMealPhotoPipeline` → `CoachMealPhotoAnalyzer` |
| AI | `CoachAIRouteHandler.analyzeMealPhoto` → `AIService.analyzeMealImage` |
| HTTP | `FormaAIBackendClient` → `POST /v1/ai/analyze-meal-image` |
| Confirm | `CoachMutationExecutor` → `FitnessActionCenter.logFood` |
| Storage | Food SwiftData; chat transcript JPEG; timeline events |
| Gaps | Image bytes sent to cloud AI; not stored in Firebase Storage |

### 7.5 Meal Commit / Edit / Delete Flow

| Operation | Path |
|-----------|------|
| Edit | `FitnessActionCenter.editFoodEntry` → `FoodLogService.editFoodEntry` |
| Delete | `FitnessActionCenter.deleteFoodEntry` → `FoodLogService.deleteFoodEntry` |
| Undo | `FitnessActionCenter.undoLastFoodEntry` |
| Timeline | `recordFoodEdited`, `recordFoodDeleted` |
| Gaps | No remote propagation |

### 7.6 Water Log Flow

`TodayView` / Coach → `FitnessActionCenter.logWater` → `WaterLogService.addWater` → SwiftData → `recalculateDailyTotals`. **Offline-capable. No remote.**

### 7.7 Weight Log Flow

Coach / Today → `FitnessActionCenter.logDailyWeight` → `WeightLogService.logWeight` → upsert `WeightEntryEntity` + optional `DailyLogEntity.weightKg`. **No delete. No remote log history.**

### 7.8 Coach Chat Message Flow

`CoachView` → `CoachModel.send` → `CoachRouteDecider` → `CoachAIRouteHandler` → one or more `AIService` calls with `CoachContextPacketV2` → `CoachMutationExecutor` (if mutation) → `transcriptStore.saveMessages`. **Requires network for AI. Transcript persisted locally.**

### 7.9 Daily Summary / Today Page Load Flow

`TodayModel` hydration → reads `DailyLogService`, `FoodLogService`, `WaterLogService`, `WeightLogService`, `HealthActivityQueryService`, `UserProfileService`. Optional `ReviewService.generateDailyReview` (AI narrative). **All local reads except AI review generation.**

### 7.10 Plan Generation / Update Flow

Onboarding: `TargetService` / `FormaCalculationEngine` → plan targets → profile create.  
Plan tab: `PlanModel` → `FitnessActionCenter.updatePlan` → SwiftData + async `ProfileBootstrapService.saveProfileToCloud`.

### 7.11 Journey Dashboard Load Flow

`JourneyModel.loadProgress` → state builders (`JourneyPresentationBuilder`, `JourneyStreakBuilder`, etc.) aggregate SwiftData + health cache. **No persistence write.**

### 7.12 Theme Change Flow

`ThemeSettingsView` → `ThemeStore.setAppearance` / `setPalette` → `AppThemePreferences.write(to: UserDefaults.standard)`. **No cloud. Survives logout.**

### 7.13 Logout Flow

`AccountSettingsView` → `AccountSettingsLogoutHandler` → `AuthGateCoordinator.performUserInitiatedSignOut` → `AuthLogoutPolicy.prepareForSignOut` → `AuthManager.signOut()` → `ProfileCloudSyncStore.clear()` → `RootModel.resetForSignedOutSession()`.

**Does NOT clear:** SwiftData, health cache, theme, onboarding draft (unless separately cleared), per-UID health consent keys.

### 7.14 Account Reset / Delete Flow

`SettingsRootView` delete dialog → `SettingsDeleteDataActionHandler.perform()` → **`.notImplemented`** (`SettingsDataDeletionCapability.isImplemented` false).  
Partial: `AppleHealthSettingsViewModel` can `deleteRemoteHealthSummaries()` only.

---

## 8. Backend API and DTO Inventory

**Base URL:** `AIBackendConfiguration.swift` → `https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway`

| Endpoint / Function | Request DTO | Response DTO | User Data Sent | User Data Returned | Persisted? | File Paths |
|--------------------|-------------|--------------|----------------|--------------------|------------|-----------|
| `POST /v1/ai/classify-coach-intent` | `AICoachIntentClassificationRequest` | `AICoachIntentClassificationResponse` | text, full `CoachContextPacketV2` | `CoachIntentResult` | No | `AIContracts.swift`, `index.ts` |
| `POST /v1/ai/parse-command` | `AIParseCommandRequest` | `AIParseCommandResponse` | text, context | `AIParsedCommand` | No | same |
| `POST /v1/ai/estimate-food` | `AIFoodEstimateRequest` | `AIFoodEstimateResponse` | text, optional `imageJPEGBase64`, context | `FoodLogDraft`s, confidence | No | same + `foodEstimateExtraction.ts` |
| `POST /v1/ai/analyze-meal-image` | `AIMealImageAnalysisRequest` | `AIMealImageAnalysisResponse` | `image.base64`, context, optional clarification | items, totals, summary | No | same + `mealImageAnalysis.ts` |
| `POST /v1/ai/generate-meal-advice` | `AIMealAdviceRequest` | `AIMealAdviceResponse` | question, context | coach message | No | same |
| `POST /v1/ai/generate-nutrition-estimate` | `AINutritionEstimateRequest` | `AINutritionEstimateResponse` | question, context | nutrition estimate | No | same + `nutritionResponseSanitizer.ts` |
| `POST /v1/ai/generate-nutrition-comparison` | `AINutritionComparisonRequest` | `AINutritionComparisonResponse` | question, context | comparison | No | same |
| `POST /v1/ai/generate-daily-review` | `AIDailyReviewRequest` | `AIDailyReviewResponse` | `DailyReviewAIInput`, context | narrative text | No | same |
| `POST /v1/ai/parse-workout` | `AIWorkoutParseRequest` | `AIWorkoutParseResponse` | text, context | `workoutDraft` | No | same |
| `POST /v1/ai/parse-edit-delete` | `AIEditDeleteParseRequest` | `AIEditDeleteParseResponse` | text, context | `parsedCommand` | No | same |
| `POST /v1/ai/parse-multi-action` | `AIMultiActionParseRequest` | `AIMultiActionParseResponse` | text, context | `parsedCommand` | No | same |
| Firestore profile R/W | — | `CloudUserProfileDocument` | Full profile snapshot | Full profile snapshot | **Yes** | `FirestoreCloudUserProfileStore.swift` |
| Firestore health sync | `Health*SyncPayload` | — | Normalized health summaries | — | **Yes** (server) | `FirestoreHealthSummaryRemoteSyncClient.swift` |

**Swift endpoint enum:** `LLMEndpoint.swift`  
**Server routing:** `functions/src/index.ts` `handleAiGatewayRequest` switch on `path`

---

## 9. Source of Truth Analysis

| Domain | Current SOT | Mirrors/Caches | Conflict Risk | Recommendation |
|--------|-------------|----------------|---------------|----------------|
| Profile / plan | Local SwiftData | Firestore `profile/current` | Medium — cloud restore on new device; mismatch route exists | Define explicit merge policy; wire delete |
| Daily nutrition totals | SwiftData `DailyLogEntity` | Computed from food/water entries | Low locally | Single write path via `FitnessActionCenter` ✓ |
| Food entries | SwiftData | AI drafts transient; common foods derived | Low | Add UID scoping + optional cloud sync |
| Weight history | SwiftData | `DailyLogEntity.weightKg` mirror | Low | Add delete API |
| Health activity | HealthKit (authoritative raw) | Local cache; optional Firestore upload | Low — upload not read back | Deploy health Firestore rules |
| Coach chat | SwiftData transcript | In-memory `CoachModel.messages` | Low if save on change | Fix nil `userId` filter behavior |
| Coach timeline | SwiftData | Embedded in AI context (compacted) | Low | Same UID fix |
| Theme | UserDefaults | — | None | OK as device-local |
| AI context | Ephemeral builder | — | N/A | Keep server/client compaction aligned |

**High conflict scenarios:**
- User A logs out, User B signs in on same device → food/water/weight from User A still in SwiftData (**Confirmed**)
- `deletesLocalProfileOnSignOut=true` but profile and logs remain (**Confirmed**)

---

## 10. User Scoping and Multi-User Safety

| Store | Scoped by UID? | Evidence |
|-------|----------------|----------|
| `UserProfileEntity.ownerUID` | Partial | Set on link/restore |
| Food/water/weight/review SwiftData | **No** | No UID fields on entities |
| Coach chat/timeline | Partial | Optional `userId`; **nil matches all users** |
| Health cache files | **Yes** | `Forma/HealthCache/{userID}/` |
| Health sync UserDefaults | **Yes** | `forma.healthSummaryRemoteSyncConsent.{userID}` |
| Onboarding draft | **No** | Device-global |
| Theme | **No** | Device-global |
| Firestore paths | **Yes** | `users/{uid}/...` |
| Profile bootstrap | **Yes** | `ownerUID == uid` check in `ProfileBootstrapService.resolve` |

**Logout behavior:** Does not switch or wipe device-local nutrition database.  
**Stale data risk:** **Confirmed** — prior user's meals visible unless profile mismatch blocks sign-in (nutrition still present).  
**Pre-auth migration:** Local profile without `ownerUID` can await sign-in (`localProfileAwaitingSignIn`).

---

## 11. Privacy and Sensitive Data Review

| Data type | Stored locally | Logged | Sent to backend/AI | Raw images persisted | Redaction |
|-----------|----------------|--------|-------------------|---------------------|-----------|
| Body metrics (height, weight, BF%) | SwiftData profile + weight entries | DEBUG bootstrap logs UID only | In `CoachContextPacketV2.profile` | N/A | Server context limits |
| Diet / food names | SwiftData food entries | DEBUG `CoachFoodEstimateDebugLogger` (names, calories) | AI context + estimate endpoints | No (URL string only on food) | Server sanitizes context |
| Health / workouts | Health cache JSON | `HealthSyncLogger` | Optional Firestore summaries; AI training context | No raw HK | Envelope contract |
| Meal photos | Chat JPEG (limited); pending in-memory | Pipeline trace metadata | base64 in aiGateway | Partial (≤64KB full JPEG) | Server strips suspicious base64 |
| Chat messages | SwiftData transcript | DEBUG pipeline `userMessage` | Recent messages in context (max 12 server-side) | Text persisted | Chat preview length limits |
| AI context packets | Not persisted | `coachContextLogFields` (metadata) | Every AI call | N/A | `coachContextPacketV2.ts` |
| Debug logs | In-memory DEBUG tracer | OSLog | No | N/A | Release uses NoOp loggers |
| Analytics | No | OSLog DEBUG only | No third-party SDK found | N/A | NoOp in release |

**Production log safety:** Release builds use `NoOp*AnalyticsLogger` (**Confirmed**). DEBUG builds may log sensitive nutrition detail (**Confirmed**).

---

## 12. Deletion, Reset, and Logout Review

| Action | What it clears | What it does NOT clear |
|--------|----------------|------------------------|
| **Logout** | Firebase session; `ProfileCloudSyncStore`; routing session flags | SwiftData (profile, food, water, weight, chat, timeline, reviews); health cache files; theme; per-UID consent keys; onboarding draft |
| **Account delete (UI)** | **Nothing** — stub | Everything |
| **Remote health delete** | Firestore health* collections for current uid | Local cache; nutrition logs |
| **Health cache prune** | Files older than 90 days | Recent data |
| **Coach chat retention** | Messages >30 days or >300 count | N/A |
| **Timeline compaction** | Old/low-value events per policy | Confirmed mutations preserved |
| **Onboarding draft clear** | `forma.onboarding.draft` | Committed profile |
| **Daily reset** | **No global daily reset mechanism found** | N/A |

**Orphaned data risks:**
- Firestore profile remains after local-only usage (**Confirmed** — no client profile delete)
- Health summaries in Firestore if user disables sync without delete (**Mitigated** — opt-out offers delete)
- SwiftData orphan rows after profile `replaceLocalProfile` — food logs remain linked to daily logs, not profile id

---

## 13. Migration and Schema Versioning

### SwiftData

| Version | Change | File |
|---------|--------|------|
| V1 | All 11 original entities incl. chat, weekly review, debug, workouts | `FormaSchemaV1` |
| V2 | Remove chat, weekly review, debug | `FormaSchemaV2` |
| V3 | Remove manual workout/set entities | `FormaSchemaV3` |
| V4 | Placeholder | `FormaSchemaV4` |
| V5 | Add `CoachTimelineEventEntity` | `FormaSchemaV5` |
| V6 | Add `CoachChatTranscriptMessageEntity` (**active**) | `FormaSchemaV6` |

**Plan:** `FormaMigrationPlan` — five `MigrationStage.lightweight` steps.  
**Gate:** `FormaSwiftDataMigrationGate` — UserDefaults `forma.swiftdata.*`.

### Onboarding draft

- `OnboardingDraft.currentDraftVersion = 2`; v1 upgraded via `OnboardingDraftMigration.upgrade` on load.

### Onboarding coaching context

- `OnboardingCoachingContext.currentOnboardingVersion = 4`

### Theme

- Legacy `forma.theme.colorPalette` → `forma.theme.palette` (`ThemePalettePersistence.swift`)

### Health cache

- `HealthCachePolicy.schemaVersion = 1`; stale snapshots deleted on mismatch

### Coach timeline payload

- `CoachTimelineEventEntity.currentSchemaVersion = 1`; envelope in `payloadJSON`

### Main tab

- Legacy tab IDs migrated to `journey` / `plan` (`MainTabView.swift`)

---

## 14. Observability and Debug Logging

| Logger | File | User data in logs |
|--------|------|-------------------|
| `FormaPipelineTracer` | `FormaPipelineTracer.swift` | User message text, trace fields (DEBUG only, in-memory) |
| `CoachFoodEstimateDebugLogger` | `CoachFoodEstimateDebugLogger.swift` | Food names, calories, macros, sanity issues (DEBUG) |
| `CoachImageAnalysisDebugLogger` | `CoachImageAnalysisDebugLogger.swift` | Image analysis metadata (DEBUG) |
| `ProfileBootstrapDebugLogger` | `ProfileBootstrapDebugLogger.swift` | UID, profile timestamps (DEBUG) |
| `AuthSignInDebugLogger` | `AuthSignInDebugLogger.swift` | Auth events (DEBUG) |
| `OSLog*AnalyticsLogger` | `Infrastructure/Diagnostics/OSLog*.swift` | Feature analytics enums (DEBUG) |
| Server `logger.info` | `functions/src/index.ts` | uid, path, `coachContextLogFields` — not raw user content |

**Persisted debug:** `DebugRecordEntity` legacy only (removed from active schema).  
**Production:** NoOp analytics; pipeline tracer gated by `FormaAbTest.Coach.pipelineTraceEnabled`.

---

## 15. Gap Analysis

| Priority | Gap | Evidence | Risk | Recommended Fix |
|---------|-----|----------|------|-----------------|
| P0 | Nutrition logs not UID-scoped | `FoodEntryEntity` has no owner field; `FoodLogService` no UID filter | Cross-user data leakage on shared device | Partition SwiftData by UID or wipe on user switch |
| P0 | Logout does not clear local user data despite AB flag | `FormaAbTest.Auth.deletesLocalProfileOnSignOut=true`; `SignOutHygieneTests` profile survives | Privacy / wrong-user data | Wire flag to selective wipe contract |
| P0 | Health Firestore rules missing in repo | `firestore.rules` profile-only; client writes `healthDaily` etc. | Writes fail or rules deployed elsewhere unknown | Add rules from `HEALTH_SUMMARY_SYNC_CONTRACT.md` |
| P0 | Account delete not implemented | `SettingsDeleteDataActionHandler` → `.notImplemented` | GDPR / App Store compliance | Implement local wipe + Auth delete + Firestore cleanup |
| P1 | No remote backup for meals/water/weight/chat | No Firestore paths in client | Data loss on device loss | Cloud sync or export |
| P1 | Coach nil `userId` rows included for any user | `CoachChatTranscriptPersistenceRepository` lines 78–81 | Cross-user chat leakage | Migrate nil rows; strict filter |
| P1 | Meal images sent as base64 to AI | `AIFoodEstimateRequest.imageJPEGBase64`, `AIMealImagePayload` | Privacy / retention with OpenAI | Document retention; consider Storage + signed URLs |
| P1 | Weight entries cannot be deleted | No method in `WeightLogService` | Incorrect data permanent | Add `deleteWeightEntry` |
| P2 | Profile targets duplicated in daily logs | `DailyLogEntity` target fields | Historical inconsistency on plan change | Document frozen-target behavior or backfill |
| P2 | Theme not synced | `ThemeStore` uses local UserDefaults only | UX on new device | Optional cloud pref or keep explicit local-only |
| P2 | `deletesLocalProfileOnSignOut` misleading | Flag exists, unwired | Engineering confusion | Implement or remove flag |
| P2 | Firestore profile no delete API | `FirestoreCloudUserProfileStore` read/write only | Orphan cloud profile | Add delete on account removal |
| P3 | Main tab UserDefaults read-only on change | `MainTabView` — no write on tab change | Tab not restored | Intentional? document |
| P3 | Legacy SwiftData entities in codebase | Migration-only models remain | Confusion | Keep for migration only ✓ |

---

## 16. Recommended Target Architecture

1. **Single repository per domain** — e.g. `NutritionLogRepository` owning food/water/daily totals with explicit `userId` partition.
2. **Local-first with optional cloud** — Nutrition: local SOT + background Firestore sync queue; Profile: already hybrid — formalize conflict resolution.
3. **User-scoped local stores** — SwiftData store filename or `ownerUID` predicate on all user tables; wipe namespace on logout when `deletesLocalProfileOnSignOut`.
4. **Sync queue** — Outbox for profile + nutrition mutations with idempotent Firestore writes.
5. **DTO separation** — Keep `CoachContextPacketV2` as transport-only (already mostly true).
6. **Deletion contract** — Logout levels: (a) session only, (b) session + transient metadata, (c) full local wipe, (d) account delete = local + Firestore + Auth.
7. **Logging redaction contract** — No food names/weight in production logs; pipeline tracer DEBUG-only.
8. **AI context contract** — Versioned schema with shared client/server compaction tests (partially exists in `functions/test/coachContextV2Contract.test.ts`).
9. **Source-of-truth rules** — Document: HK = raw activity SOT; SwiftData = nutrition SOT; Firestore profile = cross-device profile SOT; health summaries = backup/analytics only.

---

## 17. Files Reviewed

### Persistence core
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelContainer.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelMigration.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/SwiftDataStore.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaSwiftDataMigrationGate.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/*.swift` (all 13 entity files)

### Repositories & use cases
- `Fitness Coach/Data/Repositories/UserProfileService.swift`
- `Fitness Coach/Data/Repositories/DailyLogService.swift`
- `Fitness Coach/Data/Repositories/FoodLogService.swift`
- `Fitness Coach/Data/Repositories/WaterLogService.swift`
- `Fitness Coach/Data/Repositories/WeightLogService.swift`
- `Fitness Coach/Data/Repositories/ReviewService.swift`
- `Fitness Coach/Data/Repositories/ProfileCloudSyncStore.swift`
- `Fitness Coach/Data/Repositories/CoachTimelinePersistenceRepository.swift`
- `Fitness Coach/Data/Repositories/CoachChatTranscriptPersistenceRepository.swift`
- `Fitness Coach/Application/UseCases/FitnessActionCenter.swift`
- `Fitness Coach/Application/UseCases/ProfileBootstrapService.swift`

### UserDefaults & session stores
- `Fitness Coach/Data/DTOs/Onboarding/OnboardingDraftStore.swift`
- `Fitness Coach/Data/DTOs/Onboarding/OnboardingDraft.swift`
- `Fitness Coach/Application/UseCases/Onboarding/OnboardingCoachingContextStore.swift`
- `Fitness Coach/Domain/PublicEntry/PublicEntrySessionStore.swift`
- `Fitness Coach/DesignSystem/Theme/AppThemePreferences.swift`
- `Fitness Coach/DesignSystem/Theme/ThemeStore.swift`

### Health
- `Fitness Coach/Health/Cache/LocalHealthCacheStore.swift`
- `Fitness Coach/Health/Cache/HealthCachePolicy.swift`
- `Fitness Coach/Health/Sync/HealthSummarySyncService.swift`
- `Fitness Coach/Health/Sync/HealthSummarySyncConsentStore.swift`
- `Fitness Coach/Health/Sync/Remote/HealthSummarySyncEnvelope.swift`

### Cloud & AI
- `Fitness Coach/Infrastructure/Cloud/FirestoreCloudUserProfileStore.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreHealthSummaryRemoteSyncClient.swift`
- `Fitness Coach/Infrastructure/Cloud/CloudUserProfileDocument.swift`
- `Fitness Coach/Infrastructure/AI/CoachContextPacketV2.swift`
- `Fitness Coach/Infrastructure/AI/AIContracts.swift`
- `Fitness Coach/Infrastructure/AI/LLMEndpoint.swift`
- `Fitness Coach/Infrastructure/AI/FormaAIBackendClient.swift`
- `Fitness Coach/Application/Services/AIService.swift`

### Auth, routing, settings
- `Fitness Coach/Application/Services/Auth/AuthManager.swift`
- `Fitness Coach/Application/Services/Auth/AuthSignInSupport.swift`
- `Fitness Coach/App/Routing/AppRouteResolver.swift`
- `Fitness Coach/Features/Auth/Coordinator/AuthGateCoordinator.swift`
- `Fitness Coach/Features/Settings/Model/SettingsDeleteDataActionHandler.swift`
- `Fitness Coach/Features/Settings/Model/SettingsDataDeletionCapability.swift`
- `Fitness Coach/Configuration/FormaAbTest.swift`

### Coach
- `Fitness Coach/Features/Coach/Model/CoachModel.swift`
- `Fitness Coach/Application/Services/SwiftDataCoachChatTranscriptStore.swift`
- `Fitness Coach/Application/Services/CoachTimelineStore.swift`
- `Fitness Coach/Domain/Coach/CoachChatTranscriptRetentionPolicy.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift`

### Diagnostics
- `Fitness Coach/Infrastructure/Diagnostics/FormaPipelineTracer.swift`
- `Fitness Coach/Infrastructure/Diagnostics/CoachFoodEstimateDebugLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/*.swift` (24 files)

### Backend
- `functions/src/index.ts`
- `functions/src/gatewayGuardrails.ts`
- `functions/src/coachContextPacketV2.ts`
- `functions/src/mealImageAnalysis.ts`
- `functions/src/foodEstimateExtraction.ts`
- `firestore.rules`
- `firebase.json`
- `Docs/HealthIntelligence/HEALTH_SUMMARY_SYNC_CONTRACT.md`

### Tests (validation references)
- `Fitness CoachTests/SignOutHygieneTests.swift`
- `Fitness CoachTests/LogoutRoutingTests.swift`
- `functions/test/aiGateway.contract.test.ts`

---

## 18. Unknowns / Needs Manual Verification

| Item | Why unknown |
|------|-------------|
| Production Firestore rules for health collections | Committed `firestore.rules` lacks health paths; may be deployed separately |
| OpenAI / third-party data retention for aiGateway | Not defined in repo — only API calls visible |
| Whether health sync is enabled for production users | Consent-gated; default opt-in state requires runtime/remote config check |
| Firebase Auth account deletion behavior | No client implementation to verify |
| Exact SwiftData SQLite file path on disk | Default `ModelConfiguration` — implicit Application Support location |
| Google/Firebase SDK keychain key names | SDK-internal |
| Whether `FormaAbTest` production resolved flags differ from defaults | `FormaAbTest.swift` defaults shown; production override mechanism not fully traced |

---

*End of context packet. All sections derived from repository source as of audit date. No application code was modified.*
