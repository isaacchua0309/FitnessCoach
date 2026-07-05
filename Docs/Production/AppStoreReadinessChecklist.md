# App Store readiness checklist

Final gate before App Store Connect submission. Use with [PrivacyReviewChecklist.md](./PrivacyReviewChecklist.md) and [ProductionReadinessChecklist.md](./ProductionReadinessChecklist.md).

---

## 1. Account deletion visible

| # | Check | How to verify | Pass criteria |
|---|-------|---------------|---------------|
| 1.1 | Privacy & Data section exists | Settings → scroll to Privacy & Data | Section visible on RC |
| 1.2 | **Delete account** row | `FormaAbTest.Settings.dataDeletionEnabled == true` | Row opens deletion flow |
| 1.3 | Confirmation UX | Type `DELETE` | Cannot proceed without exact phrase |
| 1.4 | App Store guideline 5.1.1(v) | Review notes mention in-app deletion path | Reviewer can find deletion without support email |

**Reference:** [PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md](../AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md)

---

## 2. No placeholder settings

| # | Check | How to verify | Pass criteria |
|---|-------|---------------|---------------|
| 2.1 | Export row | Settings → Export account data | Shows intentional "Not available" **or** working export — not `TODO` / blank screen |
| 2.2 | Legal links | Terms / Privacy | Opens valid URL or in-app copy — not `example.com` |
| 2.3 | Support contact | Settings / About | Valid support path if shown |
| 2.4 | Units / theme / notifications | Each settings row | Completes an action or shows disabled state with copy |

---

## 3. No debug-only UI

| # | Check | How to verify | Pass criteria |
|---|-------|---------------|---------------|
| 3.1 | Developer section hidden | Settings | `FormaAbTest.Settings.developerSectionVisible == false` on App Store archive |
| 3.2 | Internal build flag | `FormaAbTest.Build.internalBuildEnabled` | `false` for submission binary |
| 3.3 | Debug menus / shake gestures | Explore Settings and main tabs | No hidden debug screens |
| 3.4 | Coach pipeline trace | Coach session | `FormaAbTest.Coach.pipelineTraceEnabled` off — no verbose trace overlay |
| 3.5 | HI debug fetch flags | Today/Journey/Plan | `todayDebugFetchEnabled` etc. off unless internal build |

---

## 4. Permissions copy

| Permission | Plist key | In-app copy aligned? |
|------------|-----------|----------------------|
| Apple Health read | `NSHealthShareUsageDescription` | Onboarding + Settings connect flow |
| Apple Health write | `NSHealthUpdateUsageDescription` | N/A if unused |
| Photo library (if meal photo) | `NSPhotoLibraryUsageDescription` | Coach photo picker |
| Camera (if used) | `NSCameraUsageDescription` | Meal capture flow |
| Tracking (if ATT used) | `NSUserTrackingUsageDescription` | Only if IDFA collected |

**Action:** Read plist strings aloud against UI — wording must match what the app actually does.

---

## 5. Privacy copy

| # | Check | Pass criteria |
|---|-------|---------------|
| 5.1 | In-app Privacy Policy link | Opens published policy |
| 5.2 | Account deletion copy | States Firebase/Forma data removed; Google / Apple Health limitations clear |
| 5.3 | Health Intelligence disclosure | If engines run, copy states Health data used for insights (even when HI UI off) |
| 5.4 | AI disclosure | Coach uses cloud AI; no on-device model claim unless true |
| 5.5 | App Privacy questionnaire | Matches [PrivacyReviewChecklist.md](./PrivacyReviewChecklist.md) |

**Apple Health review notes (template):**

> Health Intelligence UI is feature-flagged per build. Raw HealthKit samples are never uploaded. Nutrition and coaching work without Apple Health. Users can revoke Health access in iOS Settings.

---

## 6. Crash-free smoke test

Run on **physical device**, Release or TestFlight build, **15 minutes** minimum:

| # | Flow | Pass criteria |
|---|------|---------------|
| 6.1 | Cold launch ×3 | No crash |
| 6.2 | Sign in → main tabs | No crash |
| 6.3 | Log food + water | No crash |
| 6.4 | Coach prompt (online) | Response or user-safe error |
| 6.5 | Journey + Plan tabs | Load completely |
| 6.6 | Background → foreground ×5 | No crash |
| 6.7 | Settings open / close | No crash |

**Optional:** Monitor Xcode Organizer / Crashlytics for RC build symbolication.

**Expanded script:** [ReleaseTestPlan.md](./ReleaseTestPlan.md)

---

## 7. Release flags

Confirm **App Store archive** uses shipping defaults (not test `allEnabled` snapshot):

| Flag / area | Expected for public ship | Verify |
|-------------|--------------------------|--------|
| `FormaAbTest.Build.internalBuildEnabled` | `false` | Settings has no dev section |
| `FormaAbTest.Settings.developerSectionVisible` | `false` | — |
| `FormaAbTest.Settings.dataDeletionEnabled` | `true` | Deletion visible |
| `AccountDataExportPolicy.accountDataExportEnabled` | `false` unless export ships | Export row disabled copy |
| `HealthIntelligenceFeatureFlags` UI | Per ship plan (often **off**) | [PHASE_20_RELEASE_READINESS.md](../HealthIntelligence/PHASE_20_RELEASE_READINESS.md) |
| HI remote summary sync | **Off** unless privacy sign-off | Consent + flag |
| `AccountPersistenceFeatureFlags` | Sync + cross-device per rollout | Two-device smoke |
| `FormaAbTest.Coach.pipelineTrace*` | `false` | No debug trace noise |
| `FormaAbTest.Diagnostics.*` | `false` | No verbose OSLog analytics |
| `FORMA_AI_BACKEND_URL` | Production gateway | [ReleaseAI.md](../ReleaseAI.md) |

**Source files:** `FormaAbTest.swift`, `AccountPersistenceFeatureFlags.swift`, `HealthIntelligenceFeatureFlags.swift`.

---

## App Store Connect submission packet

| Item | Ready? | Link / note |
|------|--------|-------------|
| Screenshots (6.7" + 6.5" or required sizes) | | |
| App description & keywords | | |
| Privacy Policy URL | | |
| Support URL | | |
| Review notes (deletion + Health + AI) | | |
| Export compliance | | |
| Age rating questionnaire | | |

---

## Sign-off

| Role | Name | Date | Version submitted | Approved |
|------|------|------|-----------------|----------|
| Engineering | | | | |
| Release | | | | |
| Legal / Privacy (if applicable) | | | | |
