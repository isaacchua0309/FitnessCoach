# Account Persistence — Phase 6: Account Deletion & Privacy

Production documentation for **account deletion**, **local device wipe**, and **privacy controls** in Forma (Fitness Coach).

**Status:** Phase 6 **implemented (code + tests)** — verify with `xcodebuild test` (iOS) and `npm --prefix functions test` (backend) before production rollout.  
**Depends on:** [Phase 2](./PHASE_2_CLOUD_SCHEMA_AND_RULES.md), [Phase 3](./PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md), [Phase 4](./PHASE_4_FRESH_INSTALL_RESTORE.md), [Phase 5](./PHASE_5_CROSS_DEVICE_REFRESH.md)  
**Companion:** [ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md](../Archive/SprintReports/ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md) § Phase 6  
**Release checklists:** [Production/PrivacyReviewChecklist.md](../Production/PrivacyReviewChecklist.md), [Production/AppStoreReadinessChecklist.md](../Production/AppStoreReadinessChecklist.md) § Account deletion

---

## Explicit product guarantees

| Statement | True / False |
|-----------|--------------|
| **Full account deletion** removes app-held account data (Firestore nutrition/profile/sync + local SwiftData) **and** the **Firebase Auth** account for the signed-in UID | **True** |
| Full account deletion deletes the user's **Google account** | **False** |
| Full account deletion deletes **raw Apple Health** source data on the device or in Apple Health | **False** |
| Full account deletion syncs or deletes **raw meal images** | **False** — images are not uploaded by default; no image blob deletion is implemented unless a future phase adds cloud image storage |
| **Local device-only wipe** removes local app data for the current UID | **True** |
| Local device-only wipe leaves **cloud Firestore data** and the **Firebase Auth** account active | **True** |
| Destructive actions require **typed confirmation** (`DELETE`) | **True** |
| **Reauthentication** may be required before Firebase Auth deletion | **True** (Firebase `requires-recent-login`) |

---

## 1. Scope of Phase 6

**Goal:** Give signed-in users safe, UID-scoped control over their Forma account data — full deletion, local-only wipe, privacy status, and (foundation-only) data export — without cross-user leakage, silent destructive actions, or false claims about Google / Apple Health deletion.

### In scope

| Area | Delivered |
|------|-----------|
| Full account deletion orchestration (remote → Auth → local) | Yes |
| Local device-only wipe (no remote / Auth) | Yes |
| Settings **Privacy & Data** section (account status, sync status, delete rows, health note) | Yes |
| Confirmation UI with typed `DELETE`, progress, reauth, retry | Yes |
| Backend `POST /v1/account/delete-data` (Firebase Admin SDK) | Yes |
| Firebase Auth `user.delete()` (Google sign-in only) | Yes |
| UID-scoped local wipe (`LocalAccountDataWipeService`) | Yes |
| Sync / realtime listener cancellation during deletion | Yes |
| Account-switch and session guards | Yes |
| Privacy-safe logging (counts + uid hash prefix, no payloads) | Yes |
| iOS + backend test suites | Yes |
| Optional JSON export **foundation** (`AccountDataExportService`) | Yes — **feature flag off**; Settings export row disabled |

### Out of scope (this phase)

| Area | Notes |
|------|-------|
| **Download my data** share sheet wired to Settings | Export service exists; `AccountDataExportPolicy.accountDataExportEnabled = false` |
| Remote-only deletion (cloud without Auth/local) | `AccountDeletionPolicy.allowRemoteOnlyDelete = false` |
| Raw meal image cloud storage / deletion | Policy: `deleteRawMealImages = false` |
| Raw HealthKit sample deletion | Policy: `deleteRawHealthKitFromAppleHealth = false` |
| Deleting the user's Google account | Copy + policy explicitly excluded |
| Push notifications for deletion status | N/A |

---

## 2. User-facing deletion options

Settings → **Privacy & Data** (when `FormaAbTest.Settings.dataDeletionEnabled` is true):

| Row | Scope | What happens |
|-----|-------|----------------|
| **Delete account** | `.fullAccount` | Remote Firestore wipe → Firebase Auth delete → local wipe → route signed-out |
| **Delete local device data** | `.localDeviceOnly` | Stop sync → local wipe for current UID → sign out session → route signed-out (cloud + Auth remain) |
| **Export account data** | N/A | Placeholder when export flag off; shows “Not available” |
| Account data status / Sync status | Informational | Counts and timestamps only — no document payloads |

Both destructive rows open `AccountDeletionView` with scope-specific copy from `AccountDeletionPresentationBuilder` / `FormaProductCopy.Settings.PrivacyData`.

**Confirmation gate:** User must type exactly `DELETE` (`AccountDeletionPolicy.confirmationPhrase`). Wrong or missing phrase blocks the action.

---

## 3. Full account deletion flow

**Entry:** Settings → Delete account → `AccountDeletionViewModel.confirmDeletion()` → `AccountDeletionCoordinator.deleteAccount(confirmation:)`

**Orchestration order** (always for `.fullAccount`):

```
1. Validate confirmation phrase
2. Resolve session UID; begin deletion run (guard token)
3. preparing / stoppingSync
   → AccountDeletionGuard.beginDeletion
   → realtime listener stop
   → cross-device + account sync cancel
   → restore coordinator cancel
4. deletingRemoteData
   → AccountDeletionRemoteClient → POST /v1/account/delete-data
   → Verified Firebase ID token uid only (client-supplied uid rejected)
5. deletingAuthAccount
   → AuthManager.deleteCurrentAuthAccount()  [Google only]
   → On requires-recent-login: pause → reauthenticationRequired state
6. wipingLocalData
   → LocalAccountDataWipeService (authorization: .deletionInProgress(uid:))
7. completed (or partial / failed terminal state)
   → DeferredAccountDeletionRouter.routeToSignedOutAfterFullAccountDeletion()
```

**Key files:**

| Layer | File |
|-------|------|
| Coordinator | `Fitness Coach/Application/Privacy/AccountDeletionCoordinator.swift` |
| Policy | `Fitness Coach/Application/Privacy/AccountDeletionPolicy.swift` |
| Models | `Fitness Coach/Application/Privacy/AccountDeletionModels.swift` |
| Remote HTTP | `Fitness Coach/Infrastructure/Cloud/AccountDeletionRemoteClient.swift` |
| Local wipe | `Fitness Coach/Application/Privacy/LocalAccountDataWipeService.swift` |
| Auth | `Fitness Coach/Application/Services/Auth/AuthManager.swift` |
| UI | `Fitness Coach/Features/Settings/View/AccountDeletionView.swift`, `.../Model/AccountDeletionViewModel.swift` |
| Router | `Fitness Coach/Application/Privacy/DeferredAccountDeletionRouter.swift` |

---

## 4. Local device-only wipe flow

**Entry:** Settings → Delete local device data → `AccountDeletionCoordinator.deleteLocalDeviceDataOnly(confirmation:)`

```
1. Validate confirmation + scope enabled
2. preparing / stoppingSync (same shutdown as full deletion)
3. wipingLocalData
   → LocalAccountDataWipeService (authorization: .activeSession)
4. signOutCurrentSession()
5. routeToSignedOutAfterLocalDeviceOnlyWipe()
```

**Does not call:** remote deletion client, Firebase Auth delete.

**User messaging:** Copy states cloud account stays active and data may be restored on sign-in again.

---

## 5. Remote Firestore deletion paths

**Endpoint:** `POST /v1/account/delete-data`  
**Handler:** `functions/src/accountDeletion/accountDeletionHandler.ts`  
**Service:** `functions/src/accountDeletion/accountDeletionService.ts`

Authenticated via Firebase ID token; deletes only the **verified token uid**. Client body may include `confirmation: "DELETE"` only — **`uid` / `userId` in body are rejected**.

### Collections and documents deleted (per uid)

| Path | Notes |
|------|-------|
| `users/{uid}/profile/current` | Singleton |
| `users/{uid}/syncMetadata/current` | Singleton |
| `users/{uid}/dailyLogs/{dateId}` | Parent docs |
| `users/{uid}/dailyLogs/{dateId}/foodEntries/*` | Subcollection — paginated batch delete |
| `users/{uid}/dailyLogs/{dateId}/waterEntries/*` | Subcollection |
| `users/{uid}/weightEntries/*` | Top-level collection |
| `users/{uid}/dailyReviews/*` | Top-level collection |
| `users/{uid}/healthDaily/*` | Health summary sync |
| `users/{uid}/healthWorkouts/*` | Health summary sync |
| `users/{uid}/healthRecovery/*` | Health summary sync |
| `users/{uid}/healthWeeklyReviews/*` | Health summary sync |
| `users/{uid}/healthSyncMetadata/current` | Singleton |

**Not deleted remotely in Phase 6:** coach messages/timeline (not in cloud by default), raw meal images (not stored in Firestore), Firebase Auth (separate iOS step), Google account.

**Security:** Client Firestore rules enforce owner-only access; backend uses **Firebase Admin SDK (IAM)**, not client rules. Cross-user client deletes are denied (rules tests 15–18 in `accountPersistenceFirestoreRules.test.ts`).

---

## 6. Firebase Auth deletion behavior

**Implementation:** `AuthManager.deleteCurrentAuthAccount()` conforming to `AccountAuthDeleting`.

| Rule | Behavior |
|------|----------|
| Provider | **Google sign-in only** (`AuthAccountDeletionPolicy`) |
| API | `Auth.auth().currentUser.delete()` |
| After success | Google Sign-In sign-out + `applySignedOut()` |
| Unsupported provider | `AccountAuthDeletionError.providerMismatch` — partial flow if remote already deleted |

Auth deletion runs **after** successful remote deletion in full account flow, **before** local wipe.

---

## 7. Reauthentication handling

Firebase may return `requires-recent-login` when deleting the Auth user.

| Step | Behavior |
|------|----------|
| First `deleteCurrentAuthAccount()` | Throws `.reauthenticationRequired` |
| Coordinator | Stores `PendingReauthenticationState` (token, uid, remote result); returns `.reauthenticationRequired` |
| UI | Shows reauth CTA; **no local wipe** until Auth succeeds |
| Retry | `retryAfterReauthentication(confirmation:)` → `reauthenticateForAccountDeletion()` (Google UI) → `deleteCurrentAuthAccount()` → local wipe |
| Cancel | `cancelDeletion()` clears pending state and reinstates sync |

**Classifier:** `AuthAccountDeletionErrorClassifier` maps Firebase code `17014` → `.reauthenticationRequired`.

---

## 8. Local SwiftData wipe behavior

**Service:** `LocalAccountDataWipeService.wipeLocalData(for:scope:authorization:)`

Deletes rows **only** where `ownerUID == uid` (coach entities use `userId == uid`):

| Entity | Owner field |
|--------|-------------|
| `FoodEntryEntity` | `ownerUID` |
| `WaterEntryEntity` | `ownerUID` |
| `WeightEntryEntity` | `ownerUID` |
| `DailyReviewEntity` | `ownerUID` |
| `DailyLogEntity` | `ownerUID` |
| `UserProfileEntity` | `ownerUID` |
| `CoachChatTranscriptMessageEntity` | `userId` |
| `CoachTimelineEventEntity` | `userId` |
| `AccountSyncMutationEntity` | `ownerUID` |

**Authorization:**

| Mode | When |
|------|------|
| `.activeSession` | Local device-only wipe — requires `mayDeleteData(target, sessionUID)` |
| `.deletionInProgress(uid:)` | Full account flow after Auth delete — allows wipe even if session UID already cleared |

**Skipped when** `scope.wipesLocalAppData == false` (e.g. `.remoteAccountDataOnly` — disabled).

---

## 9. UserDefaults metadata wipe behavior

Cleared per UID via `LocalAccountDataWipeService.clearUIDScopedPreferences(for:)`:

| Store / key | Action |
|-------------|--------|
| `AccountRestoreStateStore` | `clear(uid:)` |
| `AccountSyncCursorStore` | `clear(uid:)` |
| `UserDefaultsHealthSummarySyncConsentStore` | `clear(for: uid)` |
| `UserDefaultsHealthSummaryRemoteSyncStateStore` | `clear(for: uid)` |
| `ProfileCloudSyncStore` | `clear()` if `lastSyncedUID == uid` |
| `AccountDataNamespaceService.lastActiveUIDKey` | Removed if value matches uid |

---

## 10. Health cache wipe behavior

| Target | Path / API |
|--------|------------|
| On-disk cache | `Application Support/Forma/HealthCache/{uid}/` via `LocalAccountDataWipeSupport.clearOnDiskHealthCache` |
| In-memory cache | `LocalHealthCacheStore.clearAll()` when current session matches uid |

**Does not delete:** HealthKit samples, Apple Health app data, or health data on other UIDs' cache directories.

If on-disk health cache removal fails, wipe returns **`.partial`** with `failureCategory: .localWipeFailed` (SwiftData may already be cleared).

---

## 11. What the app does not delete

| Data | Reason |
|------|--------|
| User's **Google account** | Forma only deletes Firebase Auth user; copy + policy guardrails |
| **Apple Health / HealthKit** source samples | Policy `deleteRawHealthKitFromAppleHealth = false`; Settings health note explains |
| **Raw meal images** | Not uploaded to Firestore by default; no image blob store to delete |
| **Another user's** local or cloud data | UID guards on client, server, and wipe service |
| **Coach cloud messages/timeline** | Not in default Firestore deletion paths (local coach rows wiped locally only) |
| **Debug / internal trace payloads** in logs | Logging policy — see §16 |

---

## 12. Partial failure behavior

| Scenario | Terminal status | Typical outcome |
|----------|-----------------|-----------------|
| Remote fails (offline, 5xx, etc.) | `.offline` / `.failed` | No Auth delete; no local wipe; sync guard released |
| Remote succeeds, Auth fails (non-reauth) | `.partial` | Cloud gone; Auth + local may remain; retry allowed |
| Reauth required | `.reauthenticationRequired` | Cloud gone; pending state; retry after Google reauth |
| Auth succeeds, local wipe partial | `.partial` | Auth gone; router may still sign out; retry allowed |
| Backend deletion timeout (paginated) | `ok: false` + 503 | Partial counts returned; iOS maps to failure/partial |

`AccountDeletionSummary.isSuccessful` is `true` only when `status == .completed`.

---

## 13. Offline behavior

| Action | Offline behavior |
|--------|------------------|
| Full account deletion | Remote step fails → `.offline`; user sees safe offline message; no Auth/local destructive steps |
| Local device-only wipe | **Works offline** (no network required) |
| Reauth retry | Requires network + Google UI for reauthentication |

Copy: `FormaProductCopy.Settings.PrivacyData.deletionOfflineErrorMessage`

---

## 14. Account switch safety

During an in-flight deletion, if `uidProvider.currentUID` no longer matches the deletion target:

- Run is invalidated (`isRunStillValid`)
- `abortDeletion` reinstates sync scheduling
- Returns `failureCategory: .accountSwitched`
- **Does not** apply deletion results to the new session's UID

`AccountDeletionPolicy.mayDeleteData` and `mayContinueDeletion` enforce normalized UID equality.

---

## 15. Sync/listener cancellation

Before remote or local destructive work, `AccountDeletionCoordinator.prepareForDeletion(uid:)`:

1. `AccountDeletionGuard.beginDeletion(for:)`
2. `realtimeListener.stopListening(uid:)`
3. `crossDeviceCoordinator.cancelAllWork(for:)`
4. `accountSyncCoordinator.cancelAllWork(for:)`
5. `restoreCoordinator.cancelAllWork(for:)`

In-flight sync/upload tasks check the guard and return skip reason `deletionInProgress`.

On **abort** (cancel / account switch): guard ends, sync/cross-device work reinstated.  
On **complete** (success or partial after Auth): guard ends without reinstating during signed-out routing.

**Tests:** `AccountDeletionCancellationTests`, `AccountDeletionEndToEndTests.testDeletionStopsRealtimeListenerAndSync`

---

## 16. Privacy-safe logging

| Logger | Fields logged | Never logged |
|--------|---------------|--------------|
| `AccountDeletionCoordinatorLogger` | `scope`, `status`, `uid` prefix (`privacySafeUIDField`), `durationMs`, `category` | Full uid, Firestore paths, document bodies, tokens |
| Backend handler | `uidHash` (SHA-256 prefix), `deletedCounts`, `durationMs` | Raw uid, document payloads |
| `AuthSignInDebugLogger` (account deletion) | Error category only | Tokens, emails |

UI errors use `AccountDeletionErrorFormatting` — raw backend/Firebase strings are filtered.

---

## 17. Test coverage

### iOS (`xcodebuild test -scheme "Fitness Coach"`)

| File | Focus |
|------|-------|
| `LocalAccountDataWipeServiceTests` | Per-entity wipe, health cache, metadata, UID isolation, idempotency |
| `AccountDeletionCoordinatorTests` | Phase order, reauth, partial, cancel, local-only |
| `AccountDeletionCancellationTests` | Sync/listener races during deletion guard |
| `AccountDeletionEndToEndTests` | Full stack: real coordinator + real local wipe + fakes |
| `AccountDeletionViewModelTests` | Confirmation, progress, offline, reauth, routing |
| `AccountAuthDeletionTests` | Policy, error classifier, in-memory auth fake |
| `AccountDeletionRemoteClientTests` | HTTP contract |
| `PrivacyDataSettingsTests` / `SettingsPrivacyDataTests` | Settings rows, capabilities, copy |
| `AccountDataExportServiceTests` | UID-scoped export (flag injectable in tests) |
| `AccountDataExportPolicyTests` | Export disabled by default |

### Backend (`npm --prefix functions test`)

| File | Focus |
|------|-------|
| `functions/test/accountDeletion.test.ts` | Auth, confirmation, uid scoping, per-collection delete, partial timeout, log privacy |
| `functions/test/accountPersistenceFirestoreRules.test.ts` | Cross-user delete denied (rules 15–18) |

### Verification commands

```bash
# iOS Phase 6 suites
xcodebuild test -scheme "Fitness Coach" \
  -only-testing:"Fitness CoachTests/AccountDeletionEndToEndTests" \
  -only-testing:"Fitness CoachTests/AccountDeletionCoordinatorTests" \
  -only-testing:"Fitness CoachTests/LocalAccountDataWipeServiceTests"

# Backend
npm --prefix functions test -- --testPathPatterns=accountDeletion
npm --prefix functions run build
npm --prefix functions run lint

# Firestore rules (requires Java + emulator)
npm --prefix functions run test:firestore-rules
```

---

## 18. Remaining future work

| Item | Priority | Notes |
|------|----------|-------|
| Wire **Export account data** Settings row to `AccountDataExportService` + share sheet | P2 | Set `AccountDataExportPolicy.accountDataExportEnabled = true` after QA |
| Manual QA on device (full delete + reinstall) | P0 before wide rollout | Two-account switch, reauth, offline |
| Production enablement review for `FormaAbTest.Settings.dataDeletionEnabled` | P0 | Already `true` in `FormaAbTestSnapshot.allEnabled` — confirm prod snapshot |
| Coach message **cloud** deletion paths | P3 | Only if Phase 5b uploads coach data |
| Raw meal image storage + deletion policy | P3 | Only if product adds cloud image storage |
| Remote-only deletion scope | Low | `allowRemoteOnlyDelete` remains false |
| Compaction / tombstone purge jobs | P3 | Post-deletion Firestore hygiene |
| GDPR data portability legal review | P2 | Export JSON format review |

---

## Data path audit checklist

Use this table when reviewing deletion completeness:

| Data store | Full account | Local-only | Cross-user safe |
|------------|--------------|------------|-----------------|
| Firestore `users/{uid}/profile/current` | Remote delete | No | Yes |
| Firestore `users/{uid}/syncMetadata/current` | Remote delete | No | Yes |
| Firestore `users/{uid}/dailyLogs/**` | Remote delete | No | Yes |
| Firestore `users/{uid}/weightEntries/**` | Remote delete | No | Yes |
| Firestore `users/{uid}/dailyReviews/**` | Remote delete | No | Yes |
| Firestore `users/{uid}/health*/**` | Remote delete | No | Yes |
| Firebase Auth user | Auth delete | No | Yes |
| SwiftData nutrition + profile | Local wipe | Local wipe | Yes (`ownerUID`) |
| SwiftData coach transcript/timeline | Local wipe | Local wipe | Yes (`userId`) |
| SwiftData sync outbox mutations | Local wipe | Local wipe | Yes |
| UserDefaults restore/sync/health state | Local wipe | Local wipe | Per-uid |
| Health cache directory | Local wipe | Local wipe | Per-uid path |
| Google account | **Never** | **Never** | N/A |
| Apple Health / HealthKit | **Never** | **Never** | N/A |
| Raw meal images (local files) | Not targeted* | Not targeted* | N/A |

\*Local meal image files are not explicitly enumerated for deletion in Phase 6 unless stored under a UID-scoped path added in a future phase. Cloud image deletion is out of scope.

---

*End of Phase 6 documentation.*
