# Account Persistence — Phase 2: Cloud Schema and Rules

Production documentation for the **cloud persistence foundation** in Forma (Fitness Coach).

**Status:** Phase 2 foundation **implemented** (DTOs, paths, mappers, remote store client, security rules, tests, DI).

> **Phase 3 update:** The local-first sync engine is now implemented — see [Phase 3 — Local-First Sync Engine](./PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md). Tables and flag defaults below describe **Phase 2 scope at ship time** (schema/rules without live sync).

---

## Critical distinction: schema exists ≠ sync is live

| Statement | True in Phase 2? |
|-----------|------------------|
| Food, water, weight, daily logs, and daily reviews have cloud DTOs and Firestore paths | **Yes** |
| `FirestoreAccountDataRemoteStore` can save/fetch documents | **Yes** (when called) |
| Logging a meal uploads to Firestore | **No** |
| Reinstall restores meal history from cloud | **No** |
| Background sync runs on app launch | **No** |

Phase 2 delivers the **contract and infrastructure**. Phase 3 delivers the **local-first sync engine** that actually moves data.

Feature flags (`AccountPersistenceFeatureFlags`):

```swift
static let cloudSchemaEnabled = true      // DTOs + remote store constructible
static let syncEngineEnabled = false      // No AccountSyncEngine yet
static let restoreOnLoginEnabled = false  // No AccountRestoreCoordinator yet
```

---

## 1. Scope of Phase 2

**Goal:** Define the Firestore layout, Swift DTOs, mapping layer, security rules, remote store protocol, and test coverage — without changing end-user logging behavior.

Phase 2 answers: *“If we sync nutrition logs to Firestore, what shape do they take, who can access them, and how do we map local SwiftData rows?”*

Phase 2 does **not** answer: *“When does data upload?”* That is Phase 3.

---

## 2. What was added

### Infrastructure (iOS)

| Component | Path | Purpose |
|-----------|------|---------|
| Canonical paths | `Fitness Coach/Infrastructure/Cloud/AccountDataCloudPaths.swift` | Firestore path helpers under `users/{uid}/` |
| Schema constants | `Fitness Coach/Infrastructure/Cloud/AccountDataCloudSchema.swift` | `schemaVersion`, field keys, `clientSource` |
| Cloud DTOs | `Fitness Coach/Infrastructure/Cloud/AccountData/Cloud*.swift` | Codable Firestore document types |
| Mappers | `Fitness Coach/Infrastructure/Cloud/AccountData/CloudAccountDataMappers.swift` | Local domain/entity ↔ cloud DTO |
| Remote store protocol | `Fitness Coach/Infrastructure/Cloud/AccountData/AccountDataRemoteStore.swift` | Injectable save/fetch/delete API |
| Firestore implementation | `Fitness Coach/Infrastructure/Cloud/AccountData/FirestoreAccountDataRemoteStore.swift` | Production Firestore client |
| In-memory test double | `InMemoryAccountDataRemoteStore` (same file) | Protocol contract tests / previews |
| Feature flags | `Fitness Coach/Infrastructure/Cloud/AccountPersistenceFeatureFlags.swift` | Rollout gates for Phase 3+ |
| DI wiring | `Fitness Coach/App/AppContainer.swift` | `accountDataRemoteStore` property (dormant) |

### Security and backend

| Component | Path | Purpose |
|-----------|------|---------|
| Firestore rules | `firestore.rules` | Owner-only access, `userId` match, `schemaVersion` required |
| Emulator tests | `functions/test/accountPersistenceFirestoreRules.test.ts` | 14 explicit account-persistence cases |
| Contract tests | `functions/test/nutritionSyncContract.test.ts` | 13 additional layout/validation cases |
| Fixtures | `functions/test/helpers/accountPersistenceRulesFixtures.ts` | Shared payloads (`userA`, `2026-07-04`) |

### Entity preparation (for Phase 1 / Phase 3 alignment)

Log entities include optional `ownerUID` for future ownership validation during entity→cloud mapping:

- `DailyLogEntity`, `FoodEntryEntity`, `WaterEntryEntity`, `WeightEntryEntity`, `DailyReviewEntity`

---

## 3. What was intentionally not added

Phase 2 explicitly **does not** include:

| Missing piece | Deferred to |
|---------------|-------------|
| `AccountSyncEngine` | Phase 3 |
| `SyncOutboxStore` / mutation queue | Phase 3 |
| `AccountRestoreCoordinator` | Phase 4 |
| Auto upload on food/water/weight mutations | Phase 3 |
| Restore on login / reinstall | Phase 4 |
| Wiring remote store into `FoodLogService`, `WaterLogService`, `WeightLogService`, `DailyLogService` | Phase 3 |
| Wiring remote store into `FitnessActionCenter`, `TodayModel`, `JourneyModel`, `CoachModel` | Phase 3–5 |
| Coach chat / timeline cloud sync | Phase 5b (unless implemented intentionally) |
| Raw meal image upload | Never (by design) |
| Raw HealthKit sample upload | Never (Health uses separate summary contract) |
| `syncStatus`, `mutationId`, `cloudUpdatedAt` on all entities | Phase 3 |
| Settings “sync meal history” toggle | Phase 3–5 |
| Account deletion orchestration | Phase 6 |

**No app user action uploads nutrition log data yet.** Local SwiftData remains the sole source of truth for meals, water, weight, and daily rollups.

---

## 4. Firestore collection structure

All account-backed nutrition data lives under `users/{uid}/`:

```
users/{uid}/
├── profile/current                          # existing — user profile snapshot
├── syncMetadata/current                     # sync cursors and timestamps (Phase 3)
├── dailyLogs/{yyyy-MM-dd}                   # daily rollup (targets + totals)
│   ├── foodEntries/{entryId}                # per-meal documents
│   └── waterEntries/{entryId}               # per-drink documents
├── weightEntries/{entryId}                  # standalone weight history
└── dailyReviews/{yyyy-MM-dd}                # AI daily review text
```

### Document ID conventions

| Collection | Document ID |
|------------|-------------|
| `dailyLogs` | `yyyy-MM-dd` in user's local calendar |
| `foodEntries` | `FoodEntryEntity.id.uuidString` |
| `waterEntries` | `WaterEntryEntity.id.uuidString` |
| `weightEntries` | `WeightEntryEntity.id.uuidString` |
| `dailyReviews` | `yyyy-MM-dd` |
| `syncMetadata` | `current` (singleton) |
| `profile` | `current` (singleton) |

### Path helpers (`AccountDataCloudPaths`)

Example for `userA` on `2026-07-04`:

```
users/userA/dailyLogs/2026-07-04
users/userA/dailyLogs/2026-07-04/foodEntries/food1
users/userA/dailyLogs/2026-07-04/waterEntries/water1
users/userA/weightEntries/weight1
users/userA/dailyReviews/2026-07-04
users/userA/syncMetadata/current
```

### Health collections (separate contract)

`firestore.rules` also covers Health Intelligence summary collections (`healthDaily`, `healthWorkouts`, `healthRecovery`, `healthWeeklyReviews`, `healthSyncMetadata`). These follow `Docs/HealthIntelligence/HEALTH_SUMMARY_SYNC_CONTRACT.md` and are **not** part of the nutrition account-persistence DTO set.

---

## 5. DTO list and purpose

All DTOs use `schemaVersion: 1` (`AccountDataCloudSchema.currentSchemaVersion`) and implement `CloudAccountDataDocument` for owner validation.

| DTO | Firestore location | Purpose |
|-----|-------------------|---------|
| `CloudDailyLogDocument` | `dailyLogs/{date}` | Daily targets, macro totals, water consumed, steps, workout calories, optional weight |
| `CloudFoodEntryDocument` | `dailyLogs/{date}/foodEntries/{id}` | Single meal: name, macros, source, confidence, optional `imageUrl`, optional `componentsJSON` |
| `CloudWaterEntryDocument` | `dailyLogs/{date}/waterEntries/{id}` | Single water log: `amountMl` |
| `CloudWeightEntryDocument` | `weightEntries/{id}` | Standalone weight entry: `weightKg`, `localDate`, optional note |
| `CloudDailyReviewDocument` | `dailyReviews/{date}` | AI review summary fields (text only) |
| `CloudSyncMetadataDocument` | `syncMetadata/current` | Pull/push cursors for Phase 3 sync engine |
| `CloudAccountDataEnvelope` | (shared metadata) | Reusable envelope fields; not a standalone collection |

### Shared envelope fields

Writable documents include:

- `userId`, `schemaVersion`, `createdAt`, `updatedAt`
- Optional: `deletedAt` (tombstone, Phase 3+), `deviceId`, `source`, `mutationId`

---

## 6. Local-to-cloud mapping rules

Mapping lives in `CloudAccountDataMappers` with context type `CloudAccountDataMappingContext` (`userId`, calendar, timezone, `deviceId`, `now`, optional `mutationId`).

### Domain model mapping (no `ownerUID` required)

Used when mapping from in-memory domain types (`FoodEntry`, `WaterEntry`, etc.) during tests or future sync engine assembly:

- `userId` comes from `context.userId`
- `localDate` derived from log date via `CloudAccountDataDateCodec`
- `schemaVersion` set to `AccountDataCloudSchema.currentSchemaVersion`

### Entity mapping (ownership enforced)

Used when mapping SwiftData entities that carry `ownerUID`:

| Check | Error |
|-------|-------|
| `ownerUID` is nil or empty | `CloudAccountDataMappingError.missingOwnerUID` |
| `ownerUID != context.userId` | `CloudAccountDataMappingError.ownerMismatch` |
| Invalid `localDate` string | `CloudAccountDataMappingError.invalidDate` |

### Remote store write guard

`AccountDataRemoteStoreSupport.validateWrite` runs **before** any Firestore write:

1. `document.userId` must match session `uid`
2. `schemaVersion` must be `> 0`

Mismatch throws `AccountDataRemoteStoreError.userIdMismatch` without touching Firestore.

### Field mapping highlights

| Local | Cloud |
|-------|-------|
| `FoodEntry.imageUrl` | `CloudFoodEntryDocument.imageUrl` (URL string only) |
| `FoodEntry.components` | `componentsJSON` (JSON-encoded array) |
| `DailyLog.targets` + `totals` | Flattened onto `CloudDailyLogDocument` |
| `WaterEntry.createdAt` | `createdAt` and `updatedAt` (water has no separate `updatedAt` locally) |
| `WeightEntry.date` | `localDate` (`yyyy-MM-dd`) |

### What is never mapped

- Raw meal image bytes / base64
- `fullImageJPEG` or similar binary coach attachments
- HealthKit samples or workout raw payloads
- Coach chat transcript bodies (deferred)

---

## 7. Security rules summary

Rules in `firestore.rules` enforce:

| Rule | Behavior |
|------|----------|
| Authentication | `request.auth != null` required for all access |
| Ownership | `request.auth.uid == userId` path segment |
| `userId` field match | `request.resource.data.userId == userId` on writes |
| `schemaVersion` | Required int `> 0` on account writes |
| Timestamps | `updatedAt` required; `createdAt` / `deletedAt` optional timestamps |
| Date document IDs | `yyyy-MM-dd` regex; `localDate` must match parent `dateId` |
| Cross-user denial | User B cannot read/write User A's paths |
| Unauthenticated denial | No read/write on protected paths |

Subcollections (`foodEntries`, `waterEntries`) inherit the parent `dailyLogs/{dateId}` path and apply the same owner and date validation.

---

## 8. Emulator test coverage

Run:

```bash
cd functions && npm run test:firestore-rules
```

### `accountPersistenceFirestoreRules.test.ts` (14 cases)

1. Owner can create own daily log
2. Other user cannot read daily log
3. Owner cannot write mismatched `userId`
4. Unauthenticated user cannot read/write account persistence docs
5. Owner can create food entry under own daily log
6. Other user cannot create food entry under another user's path
7. Owner can create water entry under own daily log
8. Other user cannot create water entry under another user's path
9. Owner can create weight entry
10. Other user cannot read weight entry
11. Owner can create daily review
12. Owner can update sync metadata `current`
13. Write without `schemaVersion` is denied
14. Profile rules: owner R/W, cross-user denied

Fixtures use `userA` / `userB` and date `2026-07-04`.

### `nutritionSyncContract.test.ts` (13 additional cases)

Covers invalid date IDs, `localDate` mismatch, water/weight/review collections, health daily summaries, and profile preservation.

**Total:** 27 Firestore rules tests for account persistence + nutrition contract.

---

## 9. iOS test coverage

Run on macOS:

```bash
xcodebuild test -scheme "Fitness Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Fitness CoachTests/AccountDataCloudPathsTests" \
  -only-testing:"Fitness CoachTests/CloudAccountDataMapperTests" \
  -only-testing:"Fitness CoachTests/CloudAccountDataDocumentTests" \
  -only-testing:"Fitness CoachTests/FirestoreAccountDataRemoteStoreTests" \
  -only-testing:"Fitness CoachTests/AppContainerAccountDataRemoteStoreWiringTests"
```

| Test file | Cases | What it verifies |
|-----------|-------|------------------|
| `AccountDataCloudPathsTests` | 6 | Canonical Firestore path strings |
| `CloudAccountDataMapperTests` | 7 | Owner UID guards; nutrition/hydration/weight/review field preservation |
| `CloudAccountDataDocumentTests` | 3 | No raw image base64; `schemaVersion`; JSON encode/decode round-trip |
| `FirestoreAccountDataRemoteStoreTests` | 15 | `userId` mismatch before write; save/fetch scoping; hard deletes |
| `AppContainerAccountDataRemoteStoreWiringTests` | 3 | DI wiring; Phase 2 flags remain dormant |

**Note:** Remote store contract tests use `InMemoryAccountDataRemoteStore`. Firestore mismatch tests instantiate `FirestoreAccountDataRemoteStore` but only exercise pre-write validation (no emulator required).

---

## 10. Privacy decisions

| Data | Phase 2 decision |
|------|------------------|
| Food / water / weight / daily logs | Structured fields only; no binary blobs |
| Meal images | **Never synced.** `CloudFoodEntryDocument` allows optional `imageUrl` (HTTPS reference) only. No `base64`, `imageBytes`, or `imageData` properties. |
| HealthKit | **Not synced via account persistence.** Health summaries use the separate Health Intelligence sync contract with user consent. |
| Coach chat / timeline | **Deferred** to Phase 5b unless explicitly scoped. No DTOs or paths added in Phase 2. |
| Daily reviews | Text summary fields only |
| Profile | Existing `CloudUserProfileDocument` flow unchanged |

Default posture: **local-first, upload only when Phase 3 sync engine is enabled and explicitly wired.**

---

## 11. Remaining work for Phase 3

Phase 3 implements the **local-first sync engine**. Minimum deliverables:

### New components

| Component | Responsibility |
|-----------|----------------|
| `AccountSyncEngine` | Orchestrate push/pull, foreground sync |
| `SyncOutboxStore` | Queue pending mutations from local writes |
| `SyncMutation` / `SyncStatus` | Track per-entity sync state on SwiftData rows |
| `NetworkSyncTrigger` | Retry on connectivity / foreground |

### Wiring (when `syncEngineEnabled == true`)

1. After `FoodLogService` / `WaterLogService` / `WeightLogService` / `DailyLogService` mutations:
   - Stamp `ownerUID`, `mutationId`, `syncStatus = .pending`
   - Enqueue outbox entry
   - `Task { await accountSyncEngine.pushPending() }`
2. Inject `AppContainer.accountDataRemoteStore` into `AccountSyncEngine`
3. Hook `FitnessActionCenter` post-mutation (not in Phase 2)
4. Foreground pull on app resume

### Push algorithm (summary)

1. Drain outbox ordered by `localUpdatedAt`
2. Map entity → cloud DTO via `CloudAccountDataMappers`
3. `save*` on `AccountDataRemoteStore` with session `uid`
4. On success: mark `syncStatus = .synced`, dequeue
5. On failure: backoff retry

### Pull algorithm (summary)

1. Read `syncMetadata/current`
2. Query changed `dailyLogs`, child food/water, `weightEntries` since cursor
3. Merge into SwiftData with LWW on `updatedAt`
4. Apply tombstones (`deletedAt != null`)

### Prerequisites before enabling sync

- [ ] Phase 1 UID hardening merged ([#106](https://github.com/isaacchua0309/FitnessCoach/pull/106)) — all writes stamp `ownerUID`
- [ ] `AccountPersistenceFeatureFlags.syncEngineEnabled = true` only after engine + tests land
- [ ] Emulator + iOS tests green for push/pull/conflict paths

### Phase 4+ (out of Phase 3 scope)

- `AccountRestoreCoordinator` — blocking restore on fresh install
- Progressive restore UI
- Cross-device foreground sync (Phase 5)
- Coach chat sync (Phase 5b, opt-in)
- Account deletion / GDPR (Phase 6)

---

## Quick reference: file map

```
Fitness Coach/Infrastructure/Cloud/
├── AccountDataCloudPaths.swift
├── AccountDataCloudSchema.swift
├── AccountPersistenceFeatureFlags.swift
└── AccountData/
    ├── CloudAccountDataEnvelope.swift
    ├── CloudDailyLogDocument.swift
    ├── CloudFoodEntryDocument.swift
    ├── CloudWaterEntryDocument.swift
    ├── CloudWeightEntryDocument.swift
    ├── CloudDailyReviewDocument.swift
    ├── CloudSyncMetadataDocument.swift
    ├── CloudAccountDataMappers.swift
    ├── AccountDataRemoteStore.swift          # protocol + InMemoryAccountDataRemoteStore
    └── FirestoreAccountDataRemoteStore.swift

Fitness Coach/App/AppContainer.swift            # accountDataRemoteStore (dormant)

firestore.rules
functions/test/accountPersistenceFirestoreRules.test.ts
functions/test/nutritionSyncContract.test.ts
```

---

*End of Phase 2 documentation. Sync engine: see [Phase 3 — Local-First Sync Engine](./PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md).*
