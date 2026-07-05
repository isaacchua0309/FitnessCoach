# Privacy review checklist

Use before App Store submission, enabling **remote health summary sync**, or changing AI / analytics pipelines. Complements [PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md](../AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md) and [HEALTH_SUMMARY_SYNC_CONTRACT.md](../HealthIntelligence/HEALTH_SUMMARY_SYNC_CONTRACT.md).

**Owners:** Engineering (accuracy) + Release (App Privacy questionnaire).

---

## 1. Data collected

| Data category | Collected? | Where | Linked to user? | Notes |
|---------------|------------|-------|-----------------|-------|
| Account identifier (Firebase UID) | Yes | Auth session, Firestore paths | Yes | Required for sync |
| Email / display name | If provider supplies | Firebase Auth, profile doc | Yes | Apple may hide email |
| Nutrition logs (food, water, weight) | Yes | SwiftData + Firestore | Yes | User-entered or AI-estimated |
| Plan targets & profile (age, sex, height, weight, goals) | Yes | SwiftData + Firestore profile | Yes | Onboarding + Plan |
| Daily reviews / coach messages (generated) | Yes | SwiftData / cloud where synced | Yes | AI-generated text |
| Apple Health **normalized** summaries | If permitted | On-device HI cache; optional Firestore summaries | Yes when signed in | Not raw HK samples |
| Device / app diagnostics | Limited | OSLog, Firebase function logs | Often yes (uid hash) | No payloads in production logs |
| Crash data | If Crashlytics enabled | Firebase | Per Crashlytics config | Verify SDK privacy settings |

**Action:** Confirm App Privacy answers match this table for the RC build.

---

## 2. Data stored locally

| Store | Contents | Scoped by UID? | Cleared on |
|-------|----------|----------------|------------|
| SwiftData (`FormaSchema`) | Profile, daily logs, food/water/weight entries, reviews | Yes (UID-filtered reads) | Full deletion, local wipe, uninstall |
| Health cache disk | Normalized HI snapshots | `HealthCache/{uid}/` | UID wipe, uninstall |
| UserDefaults / `@AppStorage` | Theme, onboarding flags, sync cursors | Mixed | Sign-out hygiene per policy |
| Keychain | Auth tokens (Firebase) | Per install | Sign out |

**Verify:** `LocalAccountDataWipeService` removes UID-scoped SwiftData on deletion paths.

---

## 3. Data stored remotely

| Store | Path pattern | Contents | Encryption |
|-------|--------------|----------|------------|
| Firestore | `users/{uid}/profile/current` | Profile + plan DTO | Google default at rest |
| Firestore | `users/{uid}/dailyLogs`, `foodEntries`, … | Nutrition sync DTOs | Same |
| Firestore | `users/{uid}/health*` (if remote HI sync on) | **Aggregated** health summaries only | Same; gated by flag + consent |
| Firebase Auth | — | Credentials | Google managed |

**Not stored remotely by default:** raw meal images, raw HealthKit samples, full Coach chat transcripts (unless a future phase adds them).

**Schema reference:** [PHASE_2_CLOUD_SCHEMA_AND_RULES.md](../AccountPersistence/PHASE_2_CLOUD_SCHEMA_AND_RULES.md)

---

## 4. Data sent to AI

| Flow | Payload (high level) | Provider | Retention |
|------|----------------------|----------|-----------|
| Coach intent / parsing | User text + `CoachContextPacketV2` (structured context) | OpenAI via `aiGateway` | `store: false` on Responses API |
| Food estimate | Text and/or image base64 + context | OpenAI via `aiGateway` | Same |
| Meal image analysis | Image base64 + message + context | OpenAI via `aiGateway` | Same |
| Nutrition cards / daily review | Question + context | OpenAI via `aiGateway` | Same |

**Must not send:** Firebase ID token to OpenAI (token stays between app and gateway); other users' data; raw HealthKit sample arrays (Coach uses summarized HI context when flag-gated).

**Review:** [COACH_CONTEXT_PACKET_V2.md](../Coach/COACH_CONTEXT_PACKET_V2.md), [BackendAPI.md](../BackendAPI.md).

---

## 5. Logs

| Surface | What may appear | Must not appear |
|---------|-----------------|-----------------|
| iOS OSLog (`Forma` subsystem) | Event names, bucketed counts, trace IDs | Food text, workout titles, raw HRV/steps |
| `FormaPipelineTracer` (DEBUG) | Gateway URL detection, stage timing | API keys, tokens |
| Firebase `aiGateway` logs | `traceId`, path, uid, body byte size, model id | Full JSON bodies with user text |
| Account deletion logs | Deletion counts, uid hash prefix | Document payloads |
| Analytics OSLog traces | Gated by `FormaAbTest.Diagnostics.*` | Disabled in App Store builds |

**Action:** Sample production logs for one Coach session and one deletion run before ship.

---

## 6. Analytics

| Area | Implementation | Privacy rule |
|------|----------------|--------------|
| Today | `TodayAnalyticsLogging` | Route/reason enums only — no food strings |
| Journey | `JourneyAnalyticsLogging` | Section viewed / collapsed — no log contents |
| Plan | `PlanAnalyticsLogging` | Target edit events — no PII fields |
| Onboarding | `OnboardingAnalyticsLogging` | Step funnels — no free-text answers |
| Health Intelligence | `HealthIntelligencePipelineAnalytics` | Bucketed signal availability — no raw metrics |
| Settings | `SettingsAnalyticsLogging` | Row taps — no account email |

**Production:** Prefer `NoOp*AnalyticsLogger` defaults; enable vendor analytics only with explicit privacy review.

**Reference:** [PHASE_20_RELEASE_READINESS.md](../HealthIntelligence/PHASE_20_RELEASE_READINESS.md) §15.

---

## 7. Deletion

| User action | Remote | Auth | Local | Google account | Apple Health |
|-------------|--------|------|-------|----------------|--------------|
| **Delete account** | Firestore subtree wiped via backend | Firebase user deleted | SwiftData UID wipe | **Not** deleted | **Not** deleted |
| **Delete local device data** | Unchanged | Unchanged | Wiped for UID | — | — |
| Uninstall app | Unchanged | Session lost locally | Removed with app | — | — |

**Confirmation:** Typed `DELETE` required. Client-supplied `uid` rejected on backend.

**Test:** [ProductionReadinessChecklist.md](./ProductionReadinessChecklist.md) §7.

---

## 8. Export

| Capability | Status | User-facing |
|------------|--------|-------------|
| In-app JSON export | Foundation in `AccountDataExportService` | **Off** — `FormaAbTest.Settings.dataExportEnabled` / `AccountDataExportPolicy` |
| Settings export row | Placeholder when off | Shows "Not available" — not a broken action |

**Action:** If enabling export, add share-sheet QA and update App Privacy "Data Used to Track You" / access answers.

---

## 9. Apple Health

| Topic | Policy |
|-------|--------|
| Read access | Workouts, steps, sleep, heart metrics per product configuration |
| Write access | Not used (empty write set) |
| Raw samples uploaded | **Never** |
| Remote sync | Optional aggregated summaries only; flag + user consent |
| Permission denied | App must remain usable — no crash |
| Info.plist strings | `NSHealthShareUsageDescription` must match in-app copy |

**Review:** [PHASE_20_RELEASE_READINESS.md](../HealthIntelligence/PHASE_20_RELEASE_READINESS.md) §16, [PHASE_19_QA_TEST_MATRIX.md](../HealthIntelligence/PHASE_19_QA_TEST_MATRIX.md).

---

## 10. Google sign-in

| Topic | Policy |
|-------|--------|
| SDK | Google Sign-In via Firebase Auth |
| Tokens | Managed by Firebase; not sent to OpenAI |
| Account deletion | Deletes **Firebase** user, not the user's Google account |
| URL schemes | Reversed client ID in `Info.plist` / URL types — verify for RC |
| App Privacy | Disclose "Contact Info" / "Identifiers" as linked to user if Google email collected |

**User copy:** Settings and deletion flows must state Google account is not deleted ([PHASE_6](../AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md)).

---

## Sign-off

| Question | Answer | Reviewer | Date |
|----------|--------|----------|------|
| App Privacy questionnaire matches tables above | Yes / No | | |
| AI data flow reviewed | Yes / No | | |
| Deletion tested on disposable account | Yes / No | | |
| Health remote sync (if enabled) disclosed | Yes / No / N/A | | |
