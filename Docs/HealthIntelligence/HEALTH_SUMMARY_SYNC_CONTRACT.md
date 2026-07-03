# Health Summary Sync — Backend Contract

Design specification for **normalized Apple Health Intelligence summary sync** from Forma iOS clients to Firestore.

**Status:** Contract only — **no implementation** in this document.  
**Related:** [PHASE_16_20_AUDIT.md](./PHASE_16_20_AUDIT.md) · [PHASE_11_15_UI_INTEGRATION.md](./PHASE_11_15_UI_INTEGRATION.md) · [PHASE_6_10_IMPLEMENTATION.md](./PHASE_6_10_IMPLEMENTATION.md)

---

## 1. Purpose & scope

### Goals

- Enable **multi-device continuity** and **server-side features** (analytics aggregates, Coach enrichment, support tooling) using **summary payloads only**.
- Preserve Forma’s privacy posture: **no raw HealthKit samples**, no time-series heart/sleep segments, no identifiable free-text workout titles unless explicitly allowlisted.

### In scope

| Synced artifact | Source (client) |
|-----------------|-----------------|
| Daily activity rollup | `DailyHealthMetrics` + day workout aggregates |
| Individual workouts | `NormalizedWorkout` + engine `WorkoutSummary` fields |
| Daily recovery | `RecoverySummary` (sanitized) |
| Weekly review | `WeeklyHealthReview` (sanitized) |
| Sync metadata | Client sync state + permission summary |

### Explicitly out of scope

| Data | Reason |
|------|--------|
| Raw `HKSample` / statistics query results | PHI surface; never persisted locally today |
| Sleep stage segments / heart rate samples | Time-series PHI |
| HRV or resting heart rate **numeric values** | Shown only as missing-signal flags or qualitative status |
| Food logs, weight entries, chat transcripts | Separate product domains |
| Full `HealthIntelligenceSnapshot` blob | Too wide; compose summaries from constituent parts |

---

## 2. Privacy principles

1. **Summaries only** — Upload rolled-up daily metrics and engine outputs, not underlying samples.
2. **Minimum necessary** — Each payload contains only fields listed in this contract; no optional “debug” expansions in production.
3. **No raw biometrics in free text** — `contributingFactors`, `wins`, `risks`, `nextFocus` must pass the same sanitizer rules as UI/Coach copy (no `bpm`, `ms`, `hrv` numerics, baseline comparisons).
4. **User ownership** — All documents live under `/users/{uid}/…`; `{uid}` **must** match the authenticated Firebase user. Client never writes another user’s path.
5. **User deletion** — Account deletion removes all `/users/{uid}/health*` documents (see §10).
6. **Opt-in sync** — Upload requires an explicit client feature flag / user consent gate (not enabled by default at contract time).
7. **Coach parity** — Remote summaries must not exceed what `CoachHealthIntelligenceContext` may already send to the AI gateway.
8. **Auditability** — Every document carries `schemaVersion`, `generatedAt`, and `source` for traceability without storing raw HK payloads.

---

## 3. Shared conventions

### 3.1 Identifiers

| Field | Format | Notes |
|-------|--------|-------|
| **Document ID (daily/recovery)** | `yyyy-MM-dd` | Calendar **local** date in `timezone` (see §3.3) |
| **Document ID (workout)** | `{workoutId}` | Stable UUID string from `HealthStableIdentifier.workoutID(…)` |
| **Document ID (weekly)** | `{weekId}` | `yyyy-MM-dd` of **week start** (same calendar rules as `WeeklyHealthReview.weekStartDate`) |
| **Document ID (metadata)** | `current` | Singleton per user |
| **Stable record id** | Same as Firestore document ID unless noted | Enables idempotent upserts |

### 3.2 User ownership

- **`userId` assumption:** Firebase Auth UID (`AuthUIDCache.currentUserID()`).
- **Path binding:** `{uid}` in Firestore path **must equal** `request.auth.uid`.
- **Client field `userId`:** Optional redundant field inside payload for validation; if present, must match path `{uid}`. Server rejects mismatches.
- **Anonymous users:** Do **not** sync (`userId` nil / `"anonymous"`). Local cache only until authenticated.

### 3.3 Dates & timezones

| Field | Type | Semantics |
|-------|------|-----------|
| `localDate` | string `yyyy-MM-dd` | User’s **current** `Calendar` start-of-day for the record |
| `timezone` | string | IANA identifier, e.g. `America/Los_Angeles` |
| `weekStart` / `weekEnd` | string `yyyy-MM-dd` | Inclusive local week boundaries |
| `startTime` / `endTime` | string ISO-8601 UTC | Workout instants (`Z` suffix) |
| `generatedAt` | string ISO-8601 UTC | Client composition/sync timestamp |
| `lastSuccessfulSyncAt` | string ISO-8601 UTC | Metadata only |

**Rule:** Daily and recovery documents are keyed by **local** date, not UTC midnight, to match on-device `HealthIntelligenceEngine` behavior.

### 3.4 Source

```json
"source": "apple_health"
```

| Value | Meaning |
|-------|---------|
| `apple_health` | Derived from HealthKit normalized data |
| `forma_engine` | Derived from Forma engine output without fresh HK read (e.g. weekly review recompose) |
| `mixed` | Combined HK + app logs (weekly review only) |

### 3.5 Confidence

Shared enum `HealthSyncConfidence`:

```
low | moderate | high | unknown
```

Maps from domain enums (`RecoveryConfidence`, `WorkoutSummaryConfidence`, `WeeklyReviewConfidence`) via:

| Domain | Sync |
|--------|------|
| `.high` | `high` |
| `.moderate` | `moderate` |
| `.low` | `low` |
| `.unknown` | `unknown` |

### 3.6 Missing signals

Array of string enum tokens — **names only**, never values.

**Recovery:** `sleep`, `restingHeartRate`, `hrv`, `activity`, `workouts`, `trainingLoad`  
**Weekly review:** `sleep`, `hrv`, `weight`, `nutrition`, `workouts`, `activity`, `recovery`  
**Daily / workout:** `steps`, `activeEnergy`, `exerciseMinutes`, `workout`, `workoutCalories` (when applicable)

### 3.7 Schema version

| Field | Type | Initial |
|-------|------|---------|
| `schemaVersion` | integer | `1` |

- Increment on **breaking** field removal or semantic change.
- Additive fields may use same version with tolerant readers (see §12).

### 3.8 Common envelope (all payloads)

Every payload **includes**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✅ | Stable id (= document id) |
| `userId` | string | ✅ | Firebase UID (must match path) |
| `localDate` | string | ✅* | `yyyy-MM-dd` (*weekly uses `weekStart` as primary date key) |
| `timezone` | string | ✅ | IANA timezone |
| `generatedAt` | string | ✅ | ISO-8601 UTC |
| `source` | string | ✅ | §3.4 |
| `confidence` | string | ✅ | §3.5 |
| `missingSignals` | [string] | ✅ | §3.6 (empty array if none) |
| `schemaVersion` | integer | ✅ | §3.7 |

---

## 4. Payload definitions

### 4.1 `HealthDailySummarySyncPayload`

**Firestore path:** `/users/{uid}/healthDaily/{yyyy-MM-dd}`  
**Document ID:** `{yyyy-MM-dd}` local date  
**Stable id:** same as document id

#### Domain mapping

- `DailyHealthMetrics` + aggregated workouts for that local day from `HealthDataRepository` day bundle.

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| *(envelope)* | | ✅ | §3.8 |
| `date` | string | ✅ | `yyyy-MM-dd` (duplicate of `localDate` for clarity) |
| `steps` | integer \| null | ✅ | Total steps; `null` if unavailable |
| `activeEnergyKcal` | number \| null | ✅ | Kilocalories; `null` if unavailable |
| `exerciseMinutes` | number \| null | ✅ | Apple exercise minutes; `null` if unavailable |
| `workoutCount` | integer | ✅ | Count of normalized workouts that **start** on this local date |
| `totalWorkoutMinutes` | integer | ✅ | Sum of `durationMinutes` for those workouts |
| `totalWorkoutActiveEnergyKcal` | number \| null | ⬜ | Sum of workout active energy if **any** workout has energy; else `null` |

#### Example

```json
{
  "id": "2026-07-03",
  "userId": "firebase_uid_abc",
  "localDate": "2026-07-03",
  "timezone": "America/Los_Angeles",
  "generatedAt": "2026-07-03T15:30:00Z",
  "source": "apple_health",
  "confidence": "moderate",
  "missingSignals": [],
  "schemaVersion": 1,
  "date": "2026-07-03",
  "steps": 8450,
  "activeEnergyKcal": 420,
  "exerciseMinutes": 38,
  "workoutCount": 1,
  "totalWorkoutMinutes": 50,
  "totalWorkoutActiveEnergyKcal": 320
}
```

#### Must NOT include

Steps/minute samples, heart rate, sleep duration, body mass, raw HK metadata, workout titles.

---

### 4.2 `HealthWorkoutSummarySyncPayload`

**Firestore path:** `/users/{uid}/healthWorkouts/{workoutId}`  
**Document ID:** `{workoutId}` — UUID string from `HealthStableIdentifier.workoutID(…)`  
**Stable id:** same as document id

#### Domain mapping

- `NormalizedWorkout` + optional engine fields (`WorkoutSummaryIntensity`, `WorkoutDemand`).

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| *(envelope)* | | ✅ | §3.8 — `localDate` = start-of-day of `startTime` in `timezone` |
| `workoutId` | string | ✅ | UUID string (duplicate of `id`) |
| `type` | string | ✅ | `FormaWorkoutCategory` raw value: `strength`, `running`, `walking`, `cycling`, `swimming`, `yoga`, `hiit`, `other` |
| `category` | string | ✅ | Same as `type` (alias for backward compatibility) |
| `startTime` | string | ✅ | ISO-8601 UTC |
| `endTime` | string | ✅ | ISO-8601 UTC |
| `durationMinutes` | integer | ✅ | ≥ 0 |
| `activeEnergyKcal` | number \| null | ⬜ | Nullable if HK energy unavailable |
| `intensity` | string | ✅ | `low` \| `moderate` \| `high` \| `unknown` |
| `demand` | string | ✅ | `low` \| `moderate` \| `high` \| `unknown` |
| `sourceAppName` | string \| null | ⬜ | Only if already normalized (e.g. `"Apple Watch"`, `"iPhone"`, `"Strava"`). **Never** free-form HK bundle IDs or device serials |

#### `sourceAppName` allowlist policy

- Trimmed display name from `NormalizedWorkout.sourceName` after sanitization.
- Max 64 characters; alphanumeric + spaces + common punctuation.
- Reject strings containing email, UDID, or HealthKit bundle identifiers.
- If unsafe → omit field (`null`).

#### Must NOT include

Workout title, route/GPS, heart rate series, elevation, METs, raw HK UUID, lap splits.

---

### 4.3 `RecoverySummarySyncPayload`

**Firestore path:** `/users/{uid}/healthRecovery/{yyyy-MM-dd}`  
**Document ID:** `{yyyy-MM-dd}` local date  
**Stable id:** same as document id

#### Domain mapping

- `RecoverySummary` after UI/Coach sanitization rules.

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| *(envelope)* | | ✅ | §3.8 |
| `date` | string | ✅ | `yyyy-MM-dd` |
| `score` | integer \| null | ⬜ | 0–100 **only** when domain confidence is `moderate` or `high` **and** score is shown in UI; else `null` |
| `scoreBucket` | string \| null | ⬜ | Qualitative bucket when `score` omitted: `ready` \| `moderate` \| `low` \| `unknown` |
| `status` | string | ✅ | `ready` \| `moderate` \| `low` \| `unknown` (maps `RecoveryStatus`) |
| `confidence` | string | ✅ | Envelope confidence (recovery-specific) |
| `contributingFactors` | [ContributingFactor] | ✅ | See below; may be empty |
| `missingSignals` | [string] | ✅ | Recovery missing signal tokens |

#### `ContributingFactor` (sanitized)

| Field | Type | Required |
|-------|------|----------|
| `signal` | string | ✅ — `sleep`, `restingHeartRate`, `hrv`, `trainingLoad`, `consecutiveWorkouts`, `yesterdayActivity`, `limitedActivity` |
| `impact` | string | ✅ — `positive`, `negative`, `neutral`, `limited` |

**No `detail` field** in v1 — engine detail strings may contain raw metrics and are excluded from sync.

#### Score vs bucket rule

| Condition | Send |
|-----------|------|
| `confidence` ∈ {`moderate`, `high`} and UI would show numeric score | `score` + `status` |
| Otherwise | `score: null`, `scoreBucket` derived from `status` |

#### Must NOT include

`title`, `explanation`, `recommendedTraining`, `recommendedNutrition`, raw HRV/RHR values, contributing factor detail strings.

---

### 4.4 `WeeklyHealthReviewSyncPayload`

**Firestore path:** `/users/{uid}/healthWeeklyReviews/{weekId}`  
**Document ID:** `{weekId}` = `yyyy-MM-dd` of week start  
**Stable id:** same as document id

#### Domain mapping

- `WeeklyHealthReview` — **text fields sanitized**; no raw metric language in strings.

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| *(envelope)* | | ✅ | §3.8 — `localDate` = `weekStart` |
| `weekStart` | string | ✅ | `yyyy-MM-dd` |
| `weekEnd` | string | ✅ | `yyyy-MM-dd` inclusive |
| `aggregateStats` | WeeklyAggregateStats | ✅ | See below |
| `wins` | [string] | ✅ | Max 5 items; sanitized; max 200 chars each |
| `risks` | [string] | ✅ | Max 5 items; sanitized; max 200 chars each |
| `nextFocus` | [string] | ✅ | Max 3 items; sanitized; max 200 chars each |
| `confidence` | string | ✅ | Weekly review confidence |

#### `WeeklyAggregateStats`

| Field | Type | Required |
|-------|------|----------|
| `totalWorkouts` | integer | ✅ |
| `totalWorkoutMinutes` | integer | ✅ |
| `totalActiveCalories` | integer \| null | ⬜ |
| `averageSteps` | integer \| null | ⬜ |
| `totalSteps` | integer \| null | ⬜ |
| `proteinHitDays` | integer | ✅ |
| `calorieTargetHitDays` | integer | ✅ |
| `waterHitDays` | integer | ✅ |
| `averageRecoveryScore` | number \| null | ⬜ | Weekly average if scores exist; else `null` |
| `lowRecoveryDays` | integer | ✅ |
| `weightChangeKg` | number \| null | ⬜ |
| `loggingConsistencyDays` | integer | ✅ |

#### Must NOT include

`title`, `summary` prose (optional future v2 if sanitized), per-day time series, raw sleep/HRV data.

---

### 4.5 `HealthSyncMetadataPayload`

**Firestore path:** `/users/{uid}/healthSyncMetadata/current`  
**Document ID:** `current` (singleton)  
**Stable id:** `current`

#### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| *(envelope)* | | ✅ | §3.8 — `localDate` = today in client timezone at sync time |
| `lastSuccessfulSyncAt` | string | ✅ | ISO-8601 UTC of last **fully successful** batch sync |
| `clientSchemaVersion` | integer | ✅ | Client sync mapper version (initial `1`; may differ from per-doc `schemaVersion`) |
| `appVersion` | string \| null | ⬜ | CFBundleShortVersionString + build, e.g. `1.4.0 (42)` |
| `healthPermissionSummary` | HealthPermissionSummary | ✅ | See below |
| `syncWindowDays` | integer | ✅ | Lookback window uploaded, e.g. `90` |
| `lastSyncPhase` | string \| null | ⬜ | `idle` \| `syncing` \| `succeeded` \| `partialSuccess` \| `failed` |
| `lastSyncErrorCode` | string \| null | ⬜ | Opaque client error code, not user health details |

#### `HealthPermissionSummary`

Bucketed permission state — **no raw HealthKit authorization payloads**.

| Field | Type | Description |
|-------|------|-------------|
| `isHealthDataAvailable` | boolean | Device supports HealthKit |
| `connectionLevel` | string | `disconnected` \| `partial` \| `connected` \| `unavailableOnDevice` |
| `availableSignals` | [string] | Signal kinds with read access: `stepCount`, `activeEnergyBurned`, `appleExerciseTime`, `workout`, `restingHeartRate`, `heartRateVariabilitySDNN`, `sleepAnalysis`, `bodyMass` |
| `deniedSignals` | [string] | Signals explicitly denied |
| `cachedDayCount` | integer | Local cache days available |
| `resolvedAt` | string | ISO-8601 UTC when permission snapshot was taken |

---

## 5. Firestore layout

```
users/{uid}/
├── profile/…                    (existing — not part of this contract)
├── healthDaily/{yyyy-MM-dd}     HealthDailySummarySyncPayload
├── healthWorkouts/{workoutId}   HealthWorkoutSummarySyncPayload
├── healthRecovery/{yyyy-MM-dd}  RecoverySummarySyncPayload
├── healthWeeklyReviews/{weekId} WeeklyHealthReviewSyncPayload
└── healthSyncMetadata/current   HealthSyncMetadataPayload
```

### Collection notes

| Collection | Cardinality | Retention |
|------------|-------------|-----------|
| `healthDaily` | ~1 doc/day/user | Recommend 90-day TTL or client prune aligned with `HealthCachePolicy.retentionDays` |
| `healthWorkouts` | ~0–N per day | Prune workouts older than sync window |
| `healthRecovery` | ~1 doc/day/user | Same as daily |
| `healthWeeklyReviews` | ~1 doc/week/user | Keep 52 weeks or match client |
| `healthSyncMetadata` | 1 doc | Always overwrite `current` |

---

## 6. Sync behavior

### 6.1 Upload trigger (client — future)

Recommended triggers (not implemented):

- After successful `HealthSyncService` batch with opt-in flag
- On sign-in / foreground (throttled)
- After weekly review generation
- **Not** on every snapshot compose (debounced batch)

### 6.2 Batch ordering

1. `healthSyncMetadata` → mark syncing (optional intermediate write)
2. `healthDaily` + `healthRecovery` for each day in window
3. `healthWorkouts` for workouts in window
4. `healthWeeklyReviews` for completed weeks
5. `healthSyncMetadata` → `lastSuccessfulSyncAt` + `lastSyncPhase: succeeded`

### 6.3 Idempotency rules

| Rule | Detail |
|------|--------|
| **Document ID is idempotency key** | Re-uploading the same `{yyyy-MM-dd}` or `{workoutId}` overwrites the same document |
| **Upsert semantics** | Use `set` with merge on envelope fields; full document replace acceptable for v1 |
| **Stable workout IDs** | Must use `HealthStableIdentifier.workoutID` — same workout always maps to same `{workoutId}` |
| **Retry safety** | Clients may retry failed batches; server treats identical `id` + newer `generatedAt` as update |
| **De-duplication** | Client must not create alternate IDs for the same workout |

### 6.4 Conflict behavior

**Default: last-write-wins by `generatedAt` (client-authoritative).**

| Scenario | Resolution |
|----------|------------|
| Same device re-syncs same day | Newer `generatedAt` wins |
| Two devices sync same day | Newer `generatedAt` wins; **no merge** of numeric fields in v1 |
| Older `generatedAt` arrives after newer | **Reject** or ignore (server compares timestamps) |
| Same `generatedAt`, different payload hash | Log anomaly; accept last received (should not happen) |
| Schema version mismatch | Reader uses tolerant parsing (§12); writer must not downgrade `schemaVersion` on existing doc |

**Future (v2+):** optional `deviceId` + vector clock if true multi-device merge is required.

### 6.5 Partial sync

- `lastSyncPhase: partialSuccess` in metadata when some days failed.
- Successfully uploaded documents are **not** rolled back.
- Failed days retried on next sync pass.

---

## 7. Security rule assumptions

Firestore rules **must** enforce:

```javascript
// Pseudocode — not production rules
match /users/{uid}/healthDaily/{dayId} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
// Repeat for healthWorkouts, healthRecovery, healthWeeklyReviews, healthSyncMetadata
```

| Assumption | Detail |
|------------|--------|
| **Auth required** | No anonymous read/write |
| **UID match** | `request.auth.uid == uid` |
| **Payload validation** | Cloud Function or rules helper rejects documents with forbidden fields (optional hardening) |
| **No cross-user queries** | Clients query only their `{uid}` subtree |
| **Admin access** | Separate service account for support; not client SDK |
| **Size limits** | Enforce max string lengths (wins/risks/focus) server-side if using Functions |

### Fields forbidden in validation (reject write)

- Keys containing: `hrv`, `heartRate`, `restingHeartRate`, `bpm`, `sample`, `raw`, `healthKit`
- Arrays of numeric time-series
- Binary blobs

---

## 8. Deletion behavior

| Event | Action |
|-------|--------|
| **User deletes account** | Delete entire `/users/{uid}/healthDaily`, `healthWorkouts`, `healthRecovery`, `healthWeeklyReviews`, `healthSyncMetadata` |
| **User disconnects Apple Health** | Client stops uploading; **does not** auto-delete remote summaries (user may still want history) |
| **User opts out of sync** | Stop uploads; optional client prompt to delete remote health data |
| **Local cache wipe (sign-out)** | Independent of remote; remote data retained until account deletion |
| **GDPR/CCPA request** | Account deletion path covers remote health collections |

**Implementation note:** Batch delete via Cloud Function on auth user delete trigger recommended.

---

## 9. Migration strategy

### Schema versioning

| Version | Changes |
|---------|---------|
| `1` | Initial contract (this document) |

### Additive changes (non-breaking)

- New **optional** fields may be added without bumping `schemaVersion` if readers ignore unknown keys.
- Clients send `schemaVersion: 1`; servers accept `schemaVersion: 1` with extra fields.

### Breaking changes

1. Increment `schemaVersion` to `2`.
2. Deploy tolerant server readers for both v1 and v2.
3. Ship client that writes v2.
4. Backfill/migrate v1 → v2 via batch job (optional).
5. Deprecate v1 writes after adoption threshold.

### Client mapper versioning

- `HealthSyncMetadataPayload.clientSchemaVersion` tracks the **sync mapper** independent of per-document `schemaVersion`.
- Enables debugging client-side mapping bugs without mutating payload schema.

### Mapping from existing local models

| Local type | Sync payload |
|------------|--------------|
| `DailyHealthMetrics` + day workouts | `HealthDailySummarySyncPayload` |
| `NormalizedWorkout` | `HealthWorkoutSummarySyncPayload` |
| `RecoverySummary` (sanitized) | `RecoverySummarySyncPayload` |
| `WeeklyHealthReview` (sanitized) | `WeeklyHealthReviewSyncPayload` |
| `HealthDataAvailability` + sync state | `HealthSyncMetadataPayload` |

**Not synced:** `HealthIntelligenceSnapshot` whole blob, `NormalizedSleepRecord`, `NormalizedHeartMetric`, raw cache files.

---

## 10. Rollback strategy

| Level | Action |
|-------|--------|
| **Feature flag off** | Client stops all uploads immediately; reads from local cache only (current behavior) |
| **Server read off** | Backend ignores health collections; no user impact on client |
| **Bad client release** | Disable sync flag remotely; fix mapper; re-enable |
| **Data corruption incident** | Delete affected `{uid}` health subcollections or date range; client re-uploads on next sync |
| **Contract rollback** | Freeze writes; deploy previous client; server continues reading old `schemaVersion` |

Remote health data is **additive** — rollback does not require app update for local-first usage.

---

## 11. Relationship to existing systems

| System | Interaction |
|--------|-------------|
| **Local `LocalHealthCacheStore`** | Source of truth for upload batch; sync reads local normalized data |
| **Coach AI gateway** | Independent path today; remote summaries may **reduce** duplicate AI context in future — still sanitized |
| **Firestore profile sync** | Separate collection tree; no health fields in profile document |
| **Analytics** | Product analytics remain bucketed; this contract is **not** analytics transport |

---

## 12. Validation checklist (pre-upload)

Client sync mapper **must** verify before write:

- [ ] User authenticated (`userId` non-nil, not `anonymous`)
- [ ] Opt-in sync flag enabled
- [ ] All string dates match `yyyy-MM-dd` regex
- [ ] `timezone` is valid IANA identifier
- [ ] No forbidden keys or raw metric strings in free text
- [ ] `workoutId` is stable UUID v4 format
- [ ] `score` omitted when confidence is `low` or `unknown`
- [ ] `sourceAppName` passes allowlist or is null
- [ ] Array size limits (wins/risks/focus) enforced
- [ ] Document path `{uid}` matches authenticated user

---

## 13. Open questions (Phase 16–20 implementation)

| # | Question | Default recommendation |
|---|----------|------------------------|
| 1 | User-visible opt-in for cloud health sync? | **Yes** — separate from Apple Health connect |
| 2 | TTL / automatic expiry on Firestore collections? | 90-day aligned with local retention |
| 3 | Server-side Coach reads remote summaries vs device-only? | Device-first; remote as fallback for new device |
| 4 | Encrypt at rest beyond Firestore default? | Firestore default sufficient for v1 summaries |
| 5 | Include `deviceId` in metadata for conflict debugging? | Add in v2 if multi-device issues appear |

---

## 14. Document history

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-07-03 | Initial contract — summaries only, five payloads, Firestore paths |

---

*Contract only. No Swift, Cloud Functions, or Firestore rules are implemented in this change.*
