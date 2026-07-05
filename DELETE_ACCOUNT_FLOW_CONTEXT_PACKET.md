# Delete Account Flow Context Packet

> **Audit date:** 2026-07-05  
> **Repo:** Fitness Coach (Forma) iOS app + Firebase Functions backend  
> **Scope:** Read-only code audit — no runtime device testing performed in this pass  
> **Labels used:** **Confirmed in code** · **Likely but unconfirmed** · **Unknown / needs runtime verification**

---

## 1. Executive Summary

### What the delete account flow currently appears to do

**Confirmed in code:** Full account deletion (Phase 6) is implemented as a multi-step orchestration:

1. Stop sync / realtime listeners / restore work (`AccountDeletionCoordinator.prepareForDeletion`)
2. Delete remote Firestore user subtree via HTTPS backend (`AccountDeletionRemoteClient` → `POST …/v1/account/delete-data`)
3. Delete Firebase Auth user on device (`AuthManager.deleteCurrentAuthAccount()`)
4. Wipe local SwiftData + UID-scoped preferences + health cache for that UID (`LocalAccountDataWipeService`)
5. Route to signed-out shell (`DeferredAccountDeletionRouter` → `AuthGateCoordinator.resetShellAfterAccountDeletion`)

A separate **local device-only** flow wipes local data and signs out without deleting cloud or Auth.

### What parts are implemented

| Layer | Status | Evidence |
|-------|--------|----------|
| Settings UI entry + confirmation sheet | **Implemented** | `SettingsRootView`, `AccountDeletionView`, `AccountDeletionViewModel` |
| Orchestrator | **Implemented** | `AccountDeletionCoordinator` (~920 LOC) |
| Remote Firestore deletion | **Implemented** | `AccountDeletionRemoteClient` + `functions/src/accountDeletion/*` |
| Firebase Auth deletion | **Implemented (Google only)** | `AuthManager.deleteCurrentAuthAccount()` |
| Google reauthentication | **Implemented** | `reauthenticateForAccountDeletion()` + coordinator retry path |
| Local wipe | **Implemented (partial entity coverage)** | `LocalAccountDataWipeService` |
| Post-deletion navigation / shell reset | **Implemented** | `AuthGateCoordinator.resetShellAfterAccountDeletion` |
| Unit / integration tests | **Extensive** | `AccountDeletion*Tests`, `accountDeletion.test.ts` |
| Manual device QA | **Documented as incomplete** | `Docs/AccountPersistence/PHASE_6_*`, `ProductionReadinessChecklist.md` §7 |

### What parts are missing or broken

**Confirmed in code gaps / risks:**

- **Google-only Auth deletion** — non-Google Firebase sessions are rejected (`AuthAccountDeletionPolicy`, `AuthSessionPolicy.rejectNonGoogleSession`). No Apple/email/anonymous delete path.
- **No Firebase Auth `onDelete` trigger** — no automatic backend cleanup if client skips remote step.
- **No Firebase Storage deletion** — meal photos stored as JPEG blobs in SwiftData coach transcript, not cloud Storage.
- **Local wipe does not clear onboarding draft** — `OnboardingDraftStore` not referenced in `LocalAccountDataWipeService`.
- **Production `LocalAccountDataWipeService` wiring omits `clearInMemoryCoachState`** — defaults to no-op in `AppContainer+Construction.swift`.
- **Legacy SwiftData entities** (`WorkoutEntryEntity`, `WeeklyReviewEntity`, `ChatMessageEntity`) not targeted by wipe (migration-only tables per file headers).
- **Manual end-to-end device validation** explicitly still open in project docs.

**Unknown / needs runtime verification:**

- Whether production Cloud Function URL + path (`accountDataDeletion/v1/account/delete-data`) returns 200 on real devices.
- Whether the user's observed failure is remote-step, reauth-step, routing-step, or nil-coordinator.
- Whether `requiresRecentLogin` is the dominant failure mode in the field.

### Bug category assessment

| Category | Likelihood | Notes |
|----------|------------|-------|
| **UI-level** | Low–Medium | UI is wired; failure surfaces error/retry/reauth states. Nil coordinator would show “Deletion isn't available”. |
| **Auth-level** | **High** | Google-only + `requiresRecentLogin` + reauth UX dependency. |
| **Backend-level** | **High** | Remote step is gate #1; offline/401/503/404 abort before Auth/local. |
| **Firestore cleanup-level** | Medium | Backend Admin SDK handles subtree; client rules not used for delete. Partial timeout returns `ok: false`. |
| **State-reset-level** | Medium | Shell reset exists; in-memory tab models destroyed on route change; some device prefs (theme, tab) intentionally persist. |

### Is account deletion safe to ship?

**Likely but unconfirmed: No — not without runtime verification.**

**Confirmed in code:** Architecture and tests exist; production checklist marks manual QA (§7.1–7.4) as required and not evidenced as complete in repo.

**Confirmed in code:** Partial deletion is an explicit designed state (remote deleted, Auth remains) when reauth fails or user cancels.

---

## 2. User-Facing Delete Account Flow

### Where the button is shown

**Confirmed in code:**

- **Path:** Plan tab → gear icon → Settings → **Privacy & Data** section → **Delete Account**
- **Files:**
  - `Fitness Coach/Features/Plan/PlanView.swift` — opens settings sheet
  - `Fitness Coach/Features/Settings/SettingsRootView.swift` — row handler `openAccountDeletion(scope: .fullAccount)`
  - `Fitness Coach/Features/Settings/Model/SettingsPrivacyDataPresentationBuilder.swift` — builds `.deleteAccount` row
  - `FormaProductCopy.Settings.Rows.deleteAccount` = `"Delete Account"`

Secondary row: **Delete local device data** (same section, scope `.localDeviceOnly`).

**Not on Account screen:** `AccountSettingsView` only has **Log out**, not delete account.

### Confirmation dialogs

**Confirmed in code:**

- Tapping delete opens a **sheet** (`AccountDeletionView`), not a simple alert.
- **Typed confirmation:** user must type exactly `DELETE` (`AccountDeletionPolicy.confirmationPhrase`).
- **Consequence bullets** from `FormaProductCopy.Settings.PrivacyData.deleteAccountConsequenceBullets`:
  - Permanent account + app data removal
  - Cannot be undone
  - Does not delete Apple Health data
  - Does not delete Google account
- **Destructive action button:** “Delete account” (disabled until phrase matches).
- **Cancel** in toolbar; interactive dismiss disabled while performing.

### Loading / error / success states

**Confirmed in code:**

| State | Implementation |
|-------|----------------|
| Loading / progress | `AccountDeletionViewModel.Phase.performing` + `AccountDeletionStatusFormatting` labels |
| Success | Progress shows checkmark; after 750ms `onSuccess()` dismisses settings |
| Error | `errorSection` with `AccountDeletionErrorFormatting.userFacingMessage` |
| Reauth | `requiresReauthentication` → “Reauthenticate and continue” button |
| Retry | `allowsRetry` for `.failed`, `.partial`, `.offline`, `.reauthenticationRequired` |
| Unavailable | Alert if `SettingsDeleteDataActionHandler` returns `.unavailable` |

Progress phases (full account): Preparing → Deleting account data → Deleting account → Removing local data → Completed.

### Repeated taps during deletion

**Confirmed in code:**

- `isPerformingDeletion = true` hides confirm UI and shows progress.
- Sheet `interactiveDismissDisabled(viewModel.isPerformingDeletion)`.
- Cancel disabled after `.completed`.
- Coordinator uses `activeDeletionToken` + `AccountDeletionGuard` to invalidate stale runs.

### Sign-out and navigation after deletion

**Confirmed in code (full account):**

1. `AuthManager.deleteCurrentAuthAccount()` calls `applySignedOut()` after Firebase user delete.
2. `router.routeToSignedOutAfterFullAccountDeletion()` → `AuthGateCoordinator.resetShellAfterAccountDeletion`.
3. Resets `RootModel`, clears onboarding model, rotates `signedInSessionID`, sets `publicEntryDestination` to welcome (via `AuthLogoutPolicy`).
4. Settings sheet dismisses on success.

**Local device-only:** calls `signOutCurrentSession()` then same router hook for local wipe scope.

---

## 3. Current Delete Account Entry Points

| File | Symbol | Called by | UI reachable? | Real delete vs sign-out | Async-safe? |
|------|--------|-----------|---------------|-------------------------|-------------|
| `SettingsRootView.swift` | `openAccountDeletion(scope:)` | Delete Account row tap | **Yes** | Opens flow (delegates) | Yes (opens sheet) |
| `SettingsDeleteDataActionHandler.swift` | `perform(scope:)` | Settings row gate | **Yes** | Gate only | Sync |
| `AccountDeletionViewModel.swift` | `confirmDeletion()` | Delete button | **Yes** | Starts async deletion | Yes (`Task`) |
| `AccountDeletionViewModel.swift` | `retryDeletion()` | Retry / Reauth buttons | **Yes** | Retries coordinator | Yes |
| `AccountDeletionCoordinator.swift` | `deleteAccount(confirmation:onProgress:)` | ViewModel | **Yes** | Full orchestration | Yes (`async`) |
| `AccountDeletionCoordinator.swift` | `deleteLocalDeviceDataOnly(...)` | ViewModel | **Yes** | Local wipe + sign-out | Yes |
| `AccountDeletionCoordinator.swift` | `retryAfterReauthentication(...)` | ViewModel | **Yes** | Resume after reauth | Yes |
| `AccountDeletionCoordinator.swift` | `cancelDeletion()` | ViewModel cancel | **Yes** | Aborts in-flight run | Yes |
| `AccountDeletionRemoteClient.swift` | `deleteRemoteAccountData(confirmation:)` | Coordinator | Indirect | Remote Firestore only | Yes |
| `AuthManager.swift` | `deleteCurrentAuthAccount()` | Coordinator | Indirect | Firebase Auth delete | Yes |
| `AuthManager.swift` | `reauthenticateForAccountDeletion()` | Coordinator retry | Indirect | Google reauth only | Yes |
| `AuthManager.swift` | `signOut()` | Logout + local-only wipe | **Yes** (logout) | Sign-out only | Sync |
| `LocalAccountDataWipeService.swift` | `wipeLocalData(for:scope:authorization:)` | Coordinator | Indirect | Local data wipe | Yes |
| `AuthGateCoordinator.swift` | `resetShellAfterAccountDeletion` | Deletion router | Indirect | Navigation reset | Yes |
| `AuthGateCoordinator.swift` | `signOutFromAccount()` | Account settings logout | **Yes** | Sign-out only | Sync |
| `AccountSettingsLogoutHandler` | `perform(...)` | AccountSettingsView | **Yes** | Sign-out only | Sync |
| `AccountDataNamespaceService.swift` | `prepareForSignOut()` | AppContainer sign-out | Indirect | Namespace prep, not delete | Yes |

**No matches found** for: `deleteProfile`, `removeAccount`, client-side recursive Firestore delete for account wipe (only entry-level deletes in sync layer).

---

## 4. Authentication Architecture

### Stack summary

| Mechanism | Present? | Details |
|-----------|----------|---------|
| **Firebase Auth** | **Yes** | `AuthManager`, `Auth.auth()`, state listener in `startListening()` |
| **Google Sign-In** | **Yes (primary)** | `GIDSignIn`, `GoogleAuthProvider.credential`, only supported provider for deletion |
| **Apple Sign-In** | **No** | Not in codebase |
| **Email/password** | **No** | Not in codebase |
| **Anonymous auth** | **Flag only** | `FormaAbTest.Auth.supportsAnonymousSignIn` — production intent `false`; no anonymous sign-in flow in `AuthManager` |
| **Session store** | **Yes** | Firebase SDK keychain + `PublicEntrySessionStore` (UserDefaults) |
| **Auth gate** | **Yes** | `AuthGateView` → `AuthGateCoordinator` → `AppRouteResolver` / `AuthGateRoutingPolicy` |
| **Auth listener** | **Yes** | `AuthManager.startListening()` → `applyUser` → `@Published authState` |
| **Current UID** | **Yes** | `AuthManager.currentUID` / `AuthManager.user?.uid` |
| **Sign-in** | **Yes** | `AuthManager.signInWithGoogle()` |
| **Sign-out** | **Yes** | `AuthManager.signOut()`, `AuthGateCoordinator.signOutFromAccount()` |

### Auth source of truth for deletion

**Confirmed in code:** Deletion uses the same `AuthManager` instance wired as `authDeleting` in `AccountDeletionCoordinator` (`AppContainer+Construction.swift`). UID for remote delete comes from Firebase ID token (backend verifies); local steps use `AuthAccountUIDProvider(authManager:)`.

### Non-Google session handling

**Confirmed in code:** `AuthSessionPolicy.resolve` → `.rejectNonGoogleSession` → `purgeStaleSession()` + signed out. Account deletion throws `AccountAuthDeletionError.providerMismatch` for non-Google users.

---

## 5. Reauthentication Requirements

### Implementation status

| Requirement | Implemented? | Location |
|-------------|--------------|----------|
| `requiresRecentLogin` / Firebase 17014 | **Yes** | `AuthAccountDeletionErrorClassifier`, `AccountDeletionRemoteClient.isRequiresRecentLoginError` |
| Google reauthentication UI | **Yes** | `AuthManager.reauthenticateForAccountDeletion()` presents `GIDSignIn` |
| Apple reauthentication | **No** | N/A |
| Email/password reauthentication | **No** | N/A |
| User-friendly reauth prompt | **Yes** | `FormaProductCopy.Settings.PrivacyData.deletionReauthenticationMessage` |
| Retry after reauth | **Yes** | `AccountDeletionCoordinator.retryAfterReauthentication` |
| Cancellation handling | **Yes** | `.cancelled` → partial summary, no local wipe |

### Flow when reauth required

**Confirmed in code:**

1. Remote delete may already have succeeded.
2. `deleteCurrentAuthAccount()` throws `.reauthenticationRequired`.
3. Coordinator stores `PendingReauthenticationState` (uid, remote result, token).
4. UI shows reauth CTA; **local wipe deferred** until Auth delete succeeds.
5. Retry path: reauth → `deleteCurrentAuthAccount()` → local wipe → route signed out.

### Can delete fail silently due to missing reauth?

**Confirmed in code: No** — reauth failure maps to terminal `.reauthenticationRequired` or `.partial`/`.cancelled` with user-facing messages via `AccountDeletionErrorFormatting`.

**Unknown / needs runtime verification:** Whether users understand they must tap “Reauthenticate and continue” after cloud data is already gone.

---

## 6. Backend / Firebase Functions Involvement

### Architecture

**Confirmed in code:** **Client remote delete first**, then client Auth delete. **Not** Auth-first. **No** Firestore/Auth trigger for cleanup.

| Component | Path / name |
|-----------|-------------|
| Cloud Function export | `accountDataDeletion` (`functions/src/index.ts`) |
| Handler | `handleAccountDeletionRequest` |
| Service | `deleteAccountFirestoreData` |
| Endpoint path | `POST /v1/account/delete-data` |
| iOS base URL | `https://us-central1-fitness-coach-732fd.cloudfunctions.net/accountDataDeletion` |
| Full client URL | `{baseURL}/v1/account/delete-data` |

### Auth on backend

**Confirmed in code:** `verifyAccountDeletionAuth` requires `Authorization: Bearer <Firebase ID token>`. UID from token only — client-supplied `uid`/`userId` rejected.

### Data deleted remotely

**Confirmed in code** (`accountDeletionService.ts` + paths):

- `users/{uid}/profile/current`
- `users/{uid}/syncMetadata/current`
- `users/{uid}/dailyLogs/{date}` + nested `foodEntries`, `waterEntries`
- `users/{uid}/weightEntries/*`
- `users/{uid}/dailyReviews/*`
- `users/{uid}/healthDaily/*`, `healthWorkouts/*`, `healthRecovery/*`, `healthWeeklyReviews/*`
- `users/{uid}/healthSyncMetadata/current`

**Not deleted remotely:** Firebase Auth (separate iOS step), coach chat (not in Firestore by default), meal images (not uploaded), Google account.

### iOS client wiring

**Confirmed in code:** `AccountDeletionRemoteClient` in `AppContainer+Construction.swift` with `authTokenProvider: authManager.idToken()`.

### Deployed vs local naming

**Confirmed in code:** Export name `accountDataDeletion` matches iOS `AccountDeletionBackendConfiguration.productionURLString`.

**Unknown / needs runtime verification:** Whether deployed function accepts path `/v1/account/delete-data` on the function URL (unit tests mock `request.path = "/v1/account/delete-data"`; Firebase hosting path behavior should be verified live).

### Partial backend timeout

**Confirmed in code:** Backend deadline ~50s; incomplete deletion returns HTTP 503, `ok: false`, `backendErrorCategory: "timeout"`. iOS maps to `AccountDeletionRemoteError.serverUnavailable`.

---

## 7. Firestore / Database User Data

### Cloud (Firestore)

| Collection path | Doc ID strategy | Under userId? | Deleted on account delete? | Client rules allow owner delete? |
|-----------------|-----------------|-----------------|----------------------------|----------------------------------|
| `users/{uid}/profile/current` | fixed `current` | Yes | **Yes** (backend) | Yes (`firestore.rules`) |
| `users/{uid}/syncMetadata/current` | `current` | Yes | **Yes** | Yes |
| `users/{uid}/dailyLogs/{localDate}` | `YYYY-MM-DD` | Yes | **Yes** | Yes |
| `…/foodEntries/{entryId}` | entry UUID | Nested | **Yes** | Yes |
| `…/waterEntries/{entryId}` | entry UUID | Nested | **Yes** | Yes |
| `users/{uid}/weightEntries/{entryId}` | entry UUID | Yes | **Yes** | Yes |
| `users/{uid}/dailyReviews/{localDate}` | date | Yes | **Yes** | Yes |
| `users/{uid}/healthDaily/{dayId}` | day id | Yes | **Yes** | Yes |
| `users/{uid}/healthWorkouts/{workoutId}` | id | Yes | **Yes** | Yes |
| `users/{uid}/healthRecovery/{dayId}` | day id | Yes | **Yes** | Yes |
| `users/{uid}/healthWeeklyReviews/{reviewId}` | id | Yes | **Yes** | Yes |
| `users/{uid}/healthSyncMetadata/current` | `current` | Yes | **Yes** | Yes |

**Not in Firestore (confirmed by Phase 6 policy / code):** coach messages, meal photo blobs, subscriptions.

**Orphan risk:** If remote step fails, cloud data remains. If remote succeeds but Auth delete fails, cloud already gone — **confirmed intentional partial state**.

### Local (SwiftData)

| Entity | ownerUID / userId | Wiped by `LocalAccountDataWipeService`? |
|--------|-------------------|----------------------------------------|
| `UserProfileEntity` | `ownerUID` | **Yes** |
| `DailyLogEntity` | `ownerUID` | **Yes** |
| `FoodEntryEntity` | `ownerUID` | **Yes** |
| `WaterEntryEntity` | `ownerUID` | **Yes** |
| `WeightEntryEntity` | `ownerUID` | **Yes** |
| `DailyReviewEntity` | `ownerUID` | **Yes** |
| `CoachChatTranscriptMessageEntity` | `userId` | **Yes** |
| `CoachTimelineEventEntity` | `userId` | **Yes** |
| `AccountSyncMutationEntity` | `ownerUID` | **Yes** |
| `WorkoutEntryEntity` | via `dailyLog` (legacy) | **No** (migration-only) |
| `WeeklyReviewEntity` | none | **No** (migration-only) |
| `ChatMessageEntity` | none (legacy) | **No** (migration-only) |

Client-side Firestore entry deletes exist in `FirestoreAccountDataRemoteStore` for **sync tombstones**, not account deletion.

---

## 8. Storage / Uploaded Images

**Confirmed in code:**

- **No Firebase Storage usage** found for meal/profile/coach images.
- Meal photos: compressed JPEG in coach flow (`CoachMealPhotoPipeline`, `mealPhotoJPEG` on messages), persisted in `CoachChatTranscriptMessageEntity` locally.
- **Account deletion:** local coach messages deleted; **no cloud blob deletion** (none uploaded).
- Health cache: on-disk under `Application Support/Forma/HealthCache/{userID}/` — cleared by `LocalAccountDataWipeSupport.clearOnDiskHealthCache`.
- Food correction memory file: `FileFoodCorrectionMemoryStore.deleteFile(for: uid)`.

**Orphan risk:** Legacy local JPEG data removed with coach transcript rows; no Storage orphans.

---

## 9. Local Persistence Cleanup

| Store | User-specific? | Cleared on full delete? | Notes |
|-------|----------------|-------------------------|-------|
| SwiftData (active entities) | Yes (`ownerUID`/`userId`) | **Yes** | See §7 |
| `AccountRestoreStateStore` | Per UID | **Yes** | `clear(uid:)` |
| `AccountSyncCursorStore` | Per UID | **Yes** | |
| `HealthSummarySyncConsentStore` | Per UID | **Yes** | |
| `HealthSummaryRemoteSyncStateStore` | Per UID | **Yes** | |
| `ProfileCloudSyncStore` | Session hint | **Yes** if matching UID | |
| `forma.accountDataNamespace.lastActiveUID` | UID key | **Yes** if matches | |
| On-disk health cache | Per UID directory | **Yes** | |
| `FormaPipelineTracer` | Session | **Yes** if current session | |
| `OnboardingDraftStore` | Device | **No** | Not in wipe service |
| `ThemeStore` / theme UserDefaults | Device | **No** | Intentional device preference |
| `forma.mainTab.selectedTab` | Device | **No** | Persists tab selection |
| Firebase Auth keychain session | Auth | **Removed** via Auth delete + sign-out |
| `PublicEntrySessionStore` | Session flags | **Updated** via `AuthLogoutPolicy` on shell reset | |

**App restart required?** **Likely but unconfirmed:** Not required by code — routing reset should rebuild shell; tab `@StateObject` models recreated when leaving `.main` route.

---

## 10. HealthKit / Apple Health State

**Confirmed in code:**

- App **does not delete Apple Health samples** (`AccountDeletionPolicy.deleteRawHealthKitFromAppleHealth = false`).
- Local health cache + remote health **summary** docs deleted; HealthKit permission state in `HealthKitManager` is in-memory cache (TTL 45s), not explicitly cleared on delete.
- `healthConsentStore` + `healthSyncStateStore` cleared for UID.
- `TrainingInsightsStore` integration state lives in memory on `MainTabView` — destroyed when route leaves main.

**Unknown / needs runtime verification:** Whether Apple Health integration UI still shows “connected” after delete + re-login as different user on same device.

---

## 11. App State Reset After Deletion

| Component | Reset on full delete? |
|-----------|----------------------|
| `RootModel` | **Yes** — `resetForSignedOutSession()` |
| `AuthManager.authState` | **Yes** — signed out via Auth delete |
| `AuthGateCoordinator` onboarding/shell flags | **Yes** — `resetShellAfterAccountDeletion` |
| `MainTabView` / tab models | **Yes** — route leaves `.main`; view torn down |
| Tab selection (`selectedTab`) | **No** — UserDefaults persists |
| `TodayModel` / `CoachModel` / etc. | **Destroyed** with MainTabView |
| Sync listeners | **Stopped** — `prepareForDeletion` |
| `AccountDeletionGuard` | **Cleared** — `completeDeletion` / `abortDeletion` |
| In-memory coach state callback | **No-op in production wiring** — `clearInMemoryCoachState` not injected |

**Stale data visible after deletion?** **Confirmed in code:** Unlikely if flow completes — local wipe runs before route. **Partial failure:** remote gone, Auth remains → user still signed in with cloud empty — stale local UI possible until retry.

---

## 12. Error Handling

| Scenario | Current behavior | User-facing copy | Recovery | Logs |
|----------|------------------|------------------|----------|------|
| No current user | `.failed` / `.unauthenticated` | “Sign in is required…” | Sign in | `AccountDeletionCoordinatorLogger` |
| Network failure | `.offline` | Offline message | Retry | Remote client category `offline` |
| `requiresRecentLogin` | `.reauthenticationRequired` | Reauth message + CTA | Reauthenticate & continue | Auth debug logger category |
| Permission denied (403) | `.failed` | Permission message | Retry (limited) | Remote `permission_denied` |
| Firestore delete failure | Remote error before Auth | Generic / offline | Retry | Backend logs uid hash |
| Storage delete failure | N/A | N/A | N/A | N/A |
| Backend function failure | `.failed` / `.offline` | Generic cloud error | Retry | `AccountDeletionRemoteLogger` |
| Partial deletion | `.partial` | Specific partial messages | Retry | Coordinator flowFailed |
| User cancels reauth | `.cancelled` / partial | Close / retry | Retry | `accountReauthCancelled` |
| Multiple delete taps | Guarded by token + UI phase | — | — | — |
| App backgrounded mid-delete | **Unknown** | Task may continue | **Unknown** | — |
| Nil coordinator | `.failed` unavailable | “Account deletion could not start…” | None | — |
| Wrong confirmation phrase | Blocked in UI | — | Type DELETE | — |
| Provider mismatch | `.partial` | “sign-in method cannot be removed here” | **None in app** | `provider_mismatch` |
| Backend timeout (503) | `.failed` | Generic cloud error | Retry | `timeout` |
| Account switched mid-flow | `.failed` `.accountSwitched` | “Account changed before…” | Restart flow | — |

---

## 13. Security and Privacy Concerns

**Confirmed in code:**

- **Client-only deletion is not the model** — remote step uses Admin SDK on backend with ID token auth.
- **Privileged recursive deletion on backend** — appropriate for complete subtree + nested collections.
- **Client Firestore rules** allow owner delete but account deletion doesn't rely on client-side recursive delete.
- **Private data orphan risk** if remote step fails (data remains) or local wipe partial after Auth delete.
- **Accidental deletion** mitigated by typed `DELETE`, consequence copy, destructive styling, sheet dismiss disabled during perform.
- **Analytics/crash identifiers** — no explicit analytics UID reset found on deletion; OSLog-based analytics with privacy policies.

**Do not trust client-only deletion** — backend step is required by coordinator before Auth delete.

---

## 14. Recommended Correct Architecture

### Options comparison (for this app)

| Option | Pros | Cons |
|--------|------|------|
| **1. Client-only** | Simple | Cannot recursively delete Firestore safely; rules/limits; **not suitable** |
| **2. Backend callable + client Auth delete** | **Current design**; Admin SDK; token-scoped UID | Ordering risk if Auth deleted first (avoided: remote first); partial state on reauth |
| **3. Auth delete + onDelete trigger** | Auth removal triggers cleanup | Client loses token for remote calls; needs trigger deployment — **not present** |
| **4. Backend admin deletes Auth after verification** | Single server orchestration | More complex; still needs reauth proof on client |

### Recommendation

**Confirmed facts:** App already implements **Option 2**: `POST /v1/account/delete-data` (Admin SDK) → `currentUser.delete()` → local wipe → shell reset.

**Recommendation (separate from facts):**

1. Keep **remote → Auth → local** order.
2. Add **runtime verification** of Cloud Function URL path on device/staging.
3. Consider **server-side Auth delete** (Admin SDK) after token verification to reduce client reauth fragility — larger change.
4. Wire **`clearInMemoryCoachState`** and **onboarding draft clear** in production wipe.
5. Complete **manual QA matrix** before ship.

---

## 15. Suspected Root Causes

| # | Suspected cause | Evidence | Confidence |
|---|-----------------|----------|------------|
| 1 | **Remote deletion fails** (network, 401, 503, 404 path) | Coordinator aborts before Auth/local on remote error; checklist §7.3 manual POST not evidenced complete | **High** (needs runtime) |
| 2 | **`requiresRecentLogin` without user completing reauth** | Full reauth path exists; partial state leaves Auth + local data | **High** |
| 3 | **Nil `accountDeletionCoordinator` in Settings** | Default env nil; `confirmDeletion` → unavailable summary | Medium — mitigated by `AuthGateView` injection + PlanView re-injection |
| 4 | **Backend partial timeout** | 503 + `ok: false` → client `serverUnavailable` | Medium |
| 5 | **Cloud data deleted but Auth stuck** | By design when reauth fails; user may perceive as “broken” | **High** |
| 6 | **Feature flag off** | `dataDeletionEnabled` false hides rows | Low — true in both `allEnabled` and `production` snapshots |
| 7 | **Delete button confused with Log out** | Delete only under Privacy & Data; logout under Account | Medium (UX) |
| 8 | **Provider mismatch** | Non-Google blocked | Low if only Google shipped |
| 9 | **Router not wired** | `wireAccountDeletionRouter()` in `AuthGateView.task` | Low if AuthGate loads |
| 10 | **Local wipe partial after Auth delete** | Routes signed out anyway (`AccountDeletionCoordinator` lines 466–467) | Medium |
| 11 | **Rate limiting** | Backend 429 daily/burst limits | Low for normal use |

---

## 16. Files Involved

| Area | File | Relevant symbols | Notes |
|------|------|------------------|-------|
| UI | `Features/Settings/SettingsRootView.swift` | `openAccountDeletion`, sheet | Entry point |
| UI | `Features/Settings/View/AccountDeletionView.swift` | body, `errorSection` | Confirmation UX |
| UI | `Features/Settings/Model/AccountDeletionViewModel.swift` | `confirmDeletion`, `retryDeletion` | View state machine |
| UI | `Features/Settings/Model/AccountDeletionPresentationBuilder.swift` | `build(scope:)` | Copy |
| UI | `Features/Settings/Model/SettingsDeleteDataActionHandler.swift` | `perform(scope:)` | Capability gate |
| UI | `Features/Settings/Model/SettingsDataDeletionCapability.swift` | `isImplemented` | Feature flag |
| UI | `Features/Settings/UI/AccountSettingsView.swift` | logout only | Not delete entry |
| UI | `Features/Plan/PlanView.swift` | settings sheet env injection | |
| Auth | `Application/Services/Auth/AuthManager.swift` | `deleteCurrentAuthAccount`, `reauthenticateForAccountDeletion`, `signOut` | Google only |
| Auth | `Application/Services/Auth/AuthSignInSupport.swift` | `AuthAccountDeletionPolicy`, `AuthSessionPolicy` | Provider rules |
| Auth | `Features/Auth/AuthGateView.swift` | env + `wireAccountDeletionRouter` | |
| Auth | `Features/Auth/Coordinator/AuthGateCoordinator.swift` | `resetShellAfterAccountDeletion` | Post-delete routing |
| Orchestration | `Application/Privacy/AccountDeletionCoordinator.swift` | `deleteAccount`, `runDeletion` | Core flow |
| Orchestration | `Application/Privacy/AccountDeletionPolicy.swift` | confirmation, scopes | |
| Orchestration | `Application/Privacy/AccountDeletionModels.swift` | statuses, summary | |
| Orchestration | `Application/Privacy/DeferredAccountDeletionRouter.swift` | routing callbacks | |
| Orchestration | `Application/Deletion/AccountDeletionGuard.swift` | sync block during delete | |
| Firestore | `Infrastructure/Cloud/AccountDeletionRemoteClient.swift` | HTTP client | |
| Firestore | `Infrastructure/Cloud/AccountData/FirestoreAccountDataRemoteStore.swift` | entry deletes | Sync only |
| Firestore | `firestore.rules` | owner rules | |
| Storage | — | — | Not used for user images |
| Backend | `functions/src/accountDeletion/accountDeletionHandler.ts` | `handleAccountDeletionRequest` | |
| Backend | `functions/src/accountDeletion/accountDeletionService.ts` | `deleteAccountFirestoreData` | |
| Backend | `functions/src/accountDeletion/accountDeletionGuardrails.ts` | token verify, quota | |
| Backend | `functions/src/index.ts` | exports `accountDataDeletion` | |
| Local state | `Application/Privacy/LocalAccountDataWipeService.swift` | `wipeLocalData` | |
| Local state | `App/AppContainer+Construction.swift` | DI wiring | Missing coach clear hook |
| Local state | `DesignSystem/Theme/ThemeStore.swift` | theme prefs | Not wiped |
| Routing | `App/RootModel.swift` | `resetForSignedOutSession` | |
| Routing | `App/Routing/AppRouteResolver.swift` | `AuthLogoutPolicy` | |
| Copy | `Domain/Copy/FormaProductCopy+Settings.swift` | `PrivacyData.*` | |
| Formatting | `Features/Settings/Formatting/AccountDeletionErrorFormatting.swift` | safe errors | |
| Tests | `Fitness CoachTests/AccountDeletion*.swift` | coordinator, VM, E2E | |
| Tests | `functions/test/accountDeletion.test.ts` | backend contract | |
| Docs | `Docs/AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md` | spec | |

---

## 17. Existing Tests

### What exists

| Test file | Coverage |
|-----------|----------|
| `AccountDeletionCoordinatorTests.swift` | Phase order, reauth, partial, cancel, local-only |
| `AccountDeletionEndToEndTests.swift` | Full stack with fakes; remote fail before auth; reauth recovery |
| `AccountDeletionViewModelTests.swift` | Confirmation phrase, progress, offline, reauth UI |
| `AccountDeletionRemoteClientTests.swift` | URL composition, auth header, error mapping |
| `AccountDeletionCancellationTests.swift` | Sync/listener races with deletion guard |
| `AccountAuthDeletionTests.swift` | Error classifier, in-memory auth fake |
| `LocalAccountDataWipeServiceTests.swift` | Local wipe behavior |
| `PrivacyDataSettingsTests.swift` / `SettingsPrivacyDataTests.swift` | Settings rows + action handler |
| `FormaAbTestProductionCriticalFlagsTests.swift` | `dataDeletionEnabled` visibility |
| `functions/test/accountDeletion.test.ts` | Auth, confirmation, uid scoping, logging privacy |

### Coverage gaps

- **No UI test** tapping Settings → Delete Account on device/simulator
- **No live network test** against deployed `accountDataDeletion`
- **No test** for nil coordinator from environment in Settings sheet
- **No test** for app backgrounding mid-deletion
- **No test** for onboarding draft persistence after full delete
- Manual QA checklist items **7.1–7.4** not marked done in docs

### Can tests catch the bug?

**Partially.** Unit/integration tests validate orchestration with mocks. They **cannot** catch production URL/path misconfiguration, real Firebase reauth UX, or Cloud Function deployment issues without live tests.

---

## 18. Runtime Verification Checklist

| # | Scenario | Expected behavior | Current likely behavior (from code) |
|---|----------|-------------------|-------------------------------------|
| 1 | Delete after fresh Google sign-in | Remote → Auth → local → welcome | **Should succeed** if backend reachable |
| 2 | Delete with stale session (reauth required) | Reauth CTA → retry → complete | **Partial** until user reauths; cloud may already be deleted |
| 3 | Network disabled | Offline error, no Auth/local destroy | **Confirmed:** remote fails → `.offline`, `abortDeletion` |
| 4 | Delete after meals/water/coach data | All removed local + remote | **Confirmed** if flow completes |
| 5 | Delete after meal photos | Local JPEG in coach transcript removed | **Confirmed**; no cloud images |
| 6 | Delete + relaunch app | Signed out, no prior user data for UID | **Likely** if Auth deleted; **Unknown** if partial |
| 7 | Delete + new account same provider | Fresh empty account | **Expected** new Firebase UID |
| 8 | Apple Health connected | Health samples remain; local cache cleared | **Confirmed** policy |
| 9 | User cancels confirmation | Sheet closes, no deletion | **Confirmed** |
| 10 | User cancels reauth | Partial/cancelled; cloud may be gone | **Confirmed** |

### Reproduction steps (manual)

1. Sign in with Google on a test account.
2. Plan → Settings → Privacy & Data → **Delete Account**.
3. Read consequences → type `DELETE` → **Delete account**.
4. Observe progress labels and terminal state.
5. Verify Firebase Console: Auth user removed; Firestore `users/{uid}` empty.
6. Relaunch app → should land on welcome / sign-in.

**Capture:** Xcode console filters `AccountDeletion`, `AccountDeletionRemote`, `AuthSignInDebugLogger`.

---

## 19. Implementation Risks

| Risk | Severity | Notes |
|------|----------|-------|
| Partial deletion (remote ok, Auth fail) | **High** | Documented; user must reauth |
| Firestore orphan data | Medium | If remote step skipped/fails |
| Auth deleted before data cleanup | Low | Order prevents this |
| Firestore recursive limits | Medium | Backend paginates; 50s deadline may 503 |
| Storage orphan files | None | No cloud storage |
| Stale local cache | Medium | Wipe usually runs; coach in-memory hook noop |
| Reauth UX complexity | **High** | Google-only reauth sheet |
| User stuck in loading | Low | Terminal states + cancel |
| Analytics tied to old user | Low | No UID reset found |
| Theme/tab accidentally wiped / not wiped | Low | Device prefs intentionally kept |
| Onboarding draft leak | Low | Not cleared on delete |
| Backend 429 rate limit | Low | 5/day default |

---

## 20. Final Recommended Next Step

### Concise diagnosis

The codebase contains a **complete Phase 6 delete-account implementation** (UI → coordinator → HTTPS backend → Firebase Auth delete → local wipe → auth shell reset), heavily unit-tested. The flow **does not appear stubbed or sign-out-only**. Failure reports are **most consistent with runtime failures at the remote or Firebase Auth/reauth steps**, or user-facing partial states when reauth is required but not completed.

### Highest-confidence root cause (pre-runtime)

**Likely but unconfirmed:** Step 1 **remote HTTP deletion** fails or step 3 **Firebase Auth `delete()` requires recent login** and the user does not complete Google reauthentication — leaving the account in a partial state that feels “broken.”

### Safest implementation strategy (for fix workflow)

1. **Reproduce on device** with logging enabled; record exact `AccountDeletionSummary.status` and failure category.
2. **Verify live backend** POST to `accountDataDeletion/v1/account/delete-data` with real ID token.
3. If remote works but Auth fails: exercise **reauth retry path** end-to-end.
4. Harden: inject **coach in-memory clear** + **onboarding draft clear**; consider **Admin SDK Auth delete** on backend after token + reauth verification.
5. Complete **ProductionReadinessChecklist §7** before shipping.

### Information still needed before writing the fix workflow

- [ ] Exact user-visible symptom (error message, spinner stuck, still signed in, etc.)
- [ ] Whether remote step returns 200 on device (network trace)
- [ ] Firebase Auth error code on failure (17014 vs other)
- [ ] Session age at time of delete (fresh vs days old)
- [ ] Build configuration (`FormaAbTest` override, feature flags)
- [ ] Whether Firestore data disappears while Auth account remains (partial state confirmation)

---

*End of context packet.*
