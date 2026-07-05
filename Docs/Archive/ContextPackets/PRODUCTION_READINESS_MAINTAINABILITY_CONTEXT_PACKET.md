# Production Readiness and Maintainability Context Packet

**Repository:** FitnessCoach (`Fitness Coach/` iOS app + `functions/` Firebase backend)  
**Generated:** 2026-07-04  
**Git HEAD audited:** `4f1e38103a179700fabf58dd05a5577b1fc6be56` (detached)  
**Method:** Read-only static audit — docs, `rg` searches, file inventory, backend `npm test`. No app behavior changes.  
**Claim tags:** **Confirmed** (direct code/doc evidence), **Likely** (inferred from structure/tests), **Unknown** (not verifiable in this environment).

**Primary docs read:**
- `PRD.md`
- `USER_DATA_STORAGE_CONTEXT_PACKET.md` (partially stale vs current branch — see §3)
- `FULL_APP_PRODUCT_LOOP_GAP_CONTEXT_PACKET.md`
- `WEEKLY_PROGRESS_LOOP_CONTEXT_PACKET.md` (referenced in search; product-loop overlap)
- `COACH_ACCURACY_TRUST_CONTEXT_PACKET.md` (referenced)
- `../SprintReports/ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`, `../SprintReports/ACCOUNT_PERSISTENCE_EXECUTION_MAP.md`, `../SprintReports/ACCOUNT_PERSISTENCE_PHASE_READINESS.md`
- `Docs/AccountPersistence/PHASE_2_CLOUD_SCHEMA_AND_RULES.md` through `PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md`
- `Docs/JourneyArchitecture.md`, `Docs/FormaCalculationSpec.md`, `Docs/Architecture.md`, `Docs/DeadCodeAudit.md`, `Docs/PersistenceCleanupNotes.md`
- `Docs/Coach/COACH_CONTEXT_PACKET_V2.md`
- `Docs/HealthIntelligence/*` (release readiness, cleanup, sync contract, phase audits)
- `Fitness CoachTests/TESTING.md`

**Repo scale (Confirmed):**
- `Fitness Coach/`: **1,133** Swift source files
- `Fitness CoachTests/`: **506** Swift test/support files (~463 `*Tests.swift`)
- `Application/StateBuilders/`: **81** builder files
- `functions/src/`: **17** TypeScript modules + `accountDeletion/` cluster

---


## 9. Firebase / Backend Maintainability Audit

| Backend Area | Current State | Risk | Recommendation |
|--------------|---------------|------|----------------|
| `functions/src/index.ts` | Monolithic `aiGateway` HTTPS router (~1100 LOC) + exports `accountDataDeletion` | Medium — hard to navigate | Extract route modules per path |
| `gatewayGuardrails.ts` | Auth, quota, body size, payload validation | Low | Keep |
| `coachContextPacketV2.ts` | Server-side context rules | Low | Keep |
| `accountDeletion/*` | Handler, service, guardrails, paths | Medium | Keep; ensure deployed |
| `firestore.rules` | Profile + account persistence nutrition paths + health (**Confirmed** expanded vs old storage doc) | Medium — deploy drift Unknown | Emulator CI |
| `firestore.indexes.json` | Present | Unknown deploy | Document |
| Function tests | 20 Jest suites; **572/603 pass** in audit run | Medium — 2 emulator suites fail without env | CI with emulator |
| Env vars | `OPENAI_API_KEY` secret; client uses `FORMA_AI_BACKEND_URL` | Medium | Document in `Docs/BackendAPI.md` |
| Model config | `openAIReasoningEffort.ts` guards unsupported params | Low | Keep |
| Error mapping | `GatewayError`, category mapping | Low | Keep |

### Answers

- **Functions modular enough?** **Partial** — helpers extracted; routing centralized in `index.ts`.
- **Routes too centralized?** **Yes** — single `handleAiGatewayRequest` switch.
- **Schemas shared or duplicated?** **Duplicated** between iOS `AIContracts.swift` and TS handlers — contract tests exist (`aiGateway.contract.test.ts`).
- **Env vars documented?** **Yes** — `Docs/BackendAPI.md`, `AIBackendConfiguration.swift`.
- **Unsupported model params guarded?** **Yes** — `openAIReasoningEffort.test.ts`.
- **Account deletion functions tested?** **Yes** — `accountDeletion.test.ts` (**Confirmed** file exists).
- **Firestore rules complete?** **Likely** for account persistence + profile; verify deployed rules match repo.
- **Indexes documented?** **Partial** — `firestore.indexes.json` only.

## 10. State Builder / Presentation Builder Audit

**Total builder files:** 81 under `Application/StateBuilders/`.

| Builder | Input Sources | Output State | Complexity | Duplication | Recommendation |
|---------|---------------|--------------|------------|-------------|----------------|
| `TodayPresentationBuilder` | Daily log, food, profile, activity, HI | `TodayDashboardState` | High | Shares nutrition mapper with Coach | Keep; extract date window helper |
| `TodayHealthIntelligencePresentationBuilder` | HI snapshot, flags | HI section state | High | Duplicates Journey/Plan HI builders | Consolidate HI presentation core |
| `TodayMissionControlStateBuilder` | Nutrition summary, engines | Mission hero | Medium | — | Keep |
| `JourneyPresentationBuilder` | Journey inputs, milestones | `JourneyDashboardState` | High | Weekly review overlap | Keep |
| `JourneyWeeklyReviewBuilder` | Daily logs, weights | Habit rows | Medium | Overlaps HI weekly review | Unify weekly UX |
| `WeeklyReviewPresentationBuilder` | HI weekly review | Card UI state | Medium | Duplicates Journey weekly | Merge paths |
| `PlanPresentationBuilder` | Profile, calculation bridge | Plan dashboard | High | Many sub-builders (30 Plan files) | Group edit-wizard builders |
| `PlanHealthIntelligenceSectionLoader` | HI snapshot | Plan HI section | Medium | Same as Today/Journey loaders | Extract shared loader |
| `DailyReviewSummaryBuilder` | Daily log, reviews | Review copy | Medium | Used by Today wrap-up | Keep |
| `CoachContextPacketV2Builder` | Profile, today, HI, timeline, chat | AI transport packet | **Very high** | Fallback builder exists | Keep; monitor size |
| `CoachResponseBuilder` | Nutrition summary, intents | Chat responses | High | — | Keep |
| `CoachHealthIntelligenceSnapshotLoader` | HI service | Coach context | Medium | Triplicated across tabs | Shared loader module |

### Flags

- **Builders doing too much:** `CoachContextPacketV2Builder`, `TodayPresentationBuilder`, `JourneyPresentationBuilder`.
- **Duplicate weekly review logic:** Journey vs HI (**Confirmed**).
- **Duplicate plan/target logic:** Plan edit wizard builders share validation patterns.
- **Duplicate date window logic:** Multiple builders use calendar week policies.
- **Duplicate confidence logic:** Plan confidence + HI plan confidence.
- **Mixed UI copy and domain:** Some builders embed `FormaProductCopy` strings.
- **Hidden dependencies:** HI loaders depend on feature flags silently.

## 11. View Model / Model Maintainability Audit

| Model | Responsibilities | Too Large? | Async Risk | Testability | Refactor Recommendation |
|-------|------------------|------------|------------|-------------|------------------------|
| `TodayModel` (528 LOC) | Load dashboard, HI, refresh, restore pending | Borderline | `Task` reload races | Good — protocol readers | Extract cross-device refresh |
| `CoachModel` (1609 LOC) | Chat UI, pipeline, mutations, images, tracing | **Yes** | High — many `Task` | Partial — integration heavy | Split: ChatState + PipelineCoordinator |
| `JourneyModel` (505 LOC) | Dashboard load, HI, training | Borderline | Medium | Good | Dedupe weekly review load |
| `PlanModel` (679 LOC) | Dashboard, edit wizard, HI, settings sheets | **Yes** | Medium | Good | Extract wizard coordinator |
| `OnboardingModel` (695 LOC) | 14-step flow, plan gen, auth handoff | **Yes** | Medium | Good tests | Already partially extracted to UseCases |
| `AuthGateCoordinator` (1331 LOC) | Auth, bootstrap, restore, conflict, analytics | **Yes** | High | Policy tests exist | Split session vs reconcile |
| `AccountRestoreViewModel` | Restore UI | No | Medium | Good | Keep |
| `Settings* VMs` | Presentation builders | No | Low | Good | Keep |
| `RootModel` | Onboarding vs main | No | Low | Good | Keep |

### Answers

- **Overloaded:** CoachModel, AuthGateCoordinator, PlanModel, OnboardingModel.
- **UI + domain + persistence:** CoachModel, OnboardingModel (improving).
- **Unsafe async transitions:** CoachModel, AuthGateCoordinator — need audit of cancellation.
- **Split candidates:** Coach → `CoachChatReducer` + `CoachPipelineCoordinator`; Auth → `AuthSessionController` + `ProfileReconcileCoordinator`.

## 12. Design System and UI Consistency Audit

| UI Area | Current Pattern | Duplicates | Risk | Recommendation |
|---------|----------------|------------|------|----------------|
| Screen chrome | `FormaScreenChrome`, `FormaFeatureLayout` | — | Low | Keep |
| Cards | `FormaCardChrome`, `FormaPlanCard`, `FormaFormCard`, `FormaEmptyStateCard` | 3-layer card stack | Medium | Optional `FormaCard` unification |
| Loading/error | `FormaScreenLoadingView`, `FormaScreenErrorView` | Coach inline `CoachErrorView`; auth `AuthGateProfileErrorView` | Medium | Consolidate with copy injection |
| Theme | `ThemeStore` + `FormaRootThemeModifier` | Onboarding/Coach scoped tokens | Low | Keep scoped tokens |
| Dynamic Type | `FormaTokens.Typography` where used | Not universal | Medium | Expand token usage |
| Accessibility | `ThemeAccessibilityAdaptationPolicy` TODOs | Increased contrast not shipped | Medium | Implement TODOs |
| HI cards | `HealthIntelligenceCardLayout` | Per-tab wrappers | Low | Keep |
| Onboarding | `OnboardingTheme` separate | Parallel to Forma tokens | Low | Keep isolated |

### Answers

- **Major surfaces using design system?** **Yes** — Today, Plan, Journey, Settings (**Likely**).
- **Empty/loading/error consistent?** **Mostly** — Coach/auth exceptions.
- **Destructive actions consistent?** Account deletion flow dedicated UI (**Confirmed**).
- **Theme changes live?** **Yes** — `ThemeStore` reactive (**Confirmed** tests).
- **Accessibility labels?** **Partial** — theme settings policy exists; HI partial.

## 13. Test Suite Health Audit

| Test Area | Coverage | Stability Risk | Missing Tests | Refactor Need |
|-----------|----------|----------------|---------------|---------------|
| Plan calculation | Extensive `FormaCalculation*` | Low | — | Keep |
| Coach routing | `CoachRoutingTests` large suite | Medium | — | Keep as safety net |
| Account sync/restore | 40+ dedicated tests | Medium | Deployed rules integration | Harness stability |
| Auth routing | Policy tests without UI | Low | — | Keep |
| Onboarding | 50+ tests | Medium | Full AppContainer E2E flaky | Keep |
| Health Intelligence | Phase 11/16-20 tests | Medium | Device HealthKit | Flag default tests need prod snapshot |
| SwiftData migration | V7/V8/CoachV2 tests | Low | V9 specific | Add if V9 fields grow |
| Theme guardrails | Hardcoded color guards | Low | Light ship matrix | Keep |
| Backend functions | 603 Jest tests | Medium (emulator) | — | CI emulator job |
| UI tests | **None dedicated** | — | Snapshot framework absent | Optional snapshot target |

### Answers

- **Critical paths tested:** Coach routing, plan math, auth policy, sync outbox, restore coordinator (**Confirmed**).
- **Missing tests:** Production analytics sink; Release logging audit; archive build; weight delete API.
- **Likely flaky:** Full suite, AppContainer+Firebase integration, `ProfilePlanConflictFlowTests` simulator crash noted in DeadCodeAudit.
- **Async deterministic?** **Likely** — test support uses injected clocks in many suites.
- **Fake stores reusable?** **Yes** — `TestingSupport/` (40 files).
- **Fixture duplication?** **Some** — profile fixtures, coach context fixtures.
- **Fast pre-merge command:** `xcodebuild test -scheme "Fitness Coach" -testPlan Fast-Core` (**Confirmed** TESTING.md).
- **Full release command:** `xcodebuild test -scheme "Fitness Coach CI"` (**Confirmed**).

## 14. Build Health and CI Readiness Audit

| Build Area | Current State | Risk | Recommendation |
|------------|---------------|------|----------------|
| Xcode schemes | `Fitness Coach`, `Fitness Coach CI` | Low | Keep |
| Targets | App + Tests | Low | Keep |
| SPM deps | Firebase*, GoogleSignIn, SwiftHorizontalRuler | Medium — FirebaseAnalytics unused? | Audit linked products |
| Swift concurrency | Unknown warning count | Unknown | Run xcodebuild |
| Test plans | Fast-Core, Integration, Full, PlanRevealSnapshots | Low | Regenerate script |
| CI workflow | **None in `.github/`** | **High** | Add CI |
| Functions build | `npm run build` + lint predeploy | Low | CI job |
| Firestore emulator tests | Exist but fail without emulator | Medium | `firebase emulators:exec` |
| Release/archive | Unknown | Unknown | Manual archive check |

### Answers

- **Clean build?** **Unknown** — no Xcode in audit environment.
- **Missing packages?** **Unknown**.
- **Warnings?** **Unknown**.
- **CI workflow?** **No** (**Confirmed**).
- **Backend tests in CI?** **No** in-repo workflow.
- **Firestore rules tested?** **Yes** locally via Jest (needs emulator).
- **Release checks?** **Unknown**.

## 15. Dead Code, Stubs, and TODO Audit

| Priority | File | Symbol / Comment | Type | Risk | Action |
|----------|------|------------------|------|------|--------|
| P0 | `Configuration/FormaAbTest.swift` | `allEnabled` all true | unused flag semantics | **High** | document / add `production` snapshot |
| P0 | `Features/Settings/Model/SettingsExportDataActionHandler.swift` | TODO wire export | stub | Medium | implement or hide UI |
| P0 | `Data/Repositories/WeightLogService.swift` | no delete API | missing feature | Medium | implement |
| P1 | `Infrastructure/Persistence/SwiftData/Entities/WeeklyReviewEntity.swift` | entity file | migration-only | High | keep with comment |
| P1 | `Infrastructure/Persistence/SwiftData/Entities/ChatMessageEntity.swift` | entity file | migration-only | High | keep |
| P1 | `Infrastructure/Persistence/SwiftData/Entities/WorkoutEntryEntity.swift` | entity file | migration-only | High | keep |
| P1 | `Infrastructure/AI/AIContext.swift` | `@deprecated` | deprecated | Low | delete after migration window |
| P1 | `Domain/Copy/FormaProductCopy.swift` | 4326 LOC monolith | duplicate/v1 aliases | Medium | split by domain |
| P2 | `Domain/Legal/FormaLegalCopy.swift` | TODO published URLs | TODO | **High** for ship | implement now |
| P2 | `DesignSystem/Theme/ThemeAccessibilityAdaptationPolicy.swift` | increasedContrastTODO | TODO | Medium | defer |
| P2 | `Features/Settings/Model/SettingsSupportConfiguration.swift` | TODO support email | TODO | Medium | implement |
| P2 | `Health/Models/HealthIntelligenceSnapshot+Preview.swift` | placeholder | preview | Low | keep |
| P2 | `Application/UseCases/Coach/Pipeline/LocalNoAPIGuard.swift` | NoOp responses | intentional | Low | keep |
| P2 | `Infrastructure/Cloud/NoOpCloudUserProfileStore.swift` | NoOp store | test stub | Low | keep |
| P2 | `Infrastructure/Diagnostics/NoOp*AnalyticsLogger.swift` | Release sink | intentional | Medium | replace for prod |
| P3 | `TestingSupport/StubTrainingIntegrationProvider.swift` | stub | preview/test | Low | keep |
| P3 | `CoachTimelineRecorder.swift` | `NoOpCoachTimelineRecorder` | fallback | Low | keep |
| P3 | `functions/src/index.ts` | large monolith | structural debt | Medium | defer modularization |

*See `Docs/DeadCodeAudit.md` for completed deletion history (2026-06-28 through 2026-07-03).*

## 16. Refactor Candidate Scoring

| Candidate | Developer Impact | Production Risk Reduction | Complexity | Regression Risk | Score (1-10) |
|-----------|------------------|--------------------------|------------|-----------------|--------------|
| AppContainer/domain DI split | 9 | 6 | 7 | 7 | **8** |
| Feature flag cleanup (production snapshot) | 8 | 9 | 4 | 5 | **9** |
| Analytics production sink | 7 | 9 | 5 | 4 | **8** |
| Logging redaction contract | 6 | 8 | 4 | 3 | **7** |
| SwiftData entity cleanup (migration folder) | 5 | 4 | 6 | 8 | **5** |
| State builder simplification | 7 | 3 | 8 | 7 | **6** |
| Weekly review duplication cleanup | 6 | 5 | 6 | 6 | **6** |
| Health Intelligence flag simplification | 7 | 8 | 5 | 5 | **8** |
| Coach model split | 8 | 5 | 8 | 8 | **7** |
| Test fixture/fake infrastructure cleanup | 6 | 4 | 5 | 4 | **6** |
| Backend route modularization | 5 | 4 | 5 | 4 | **5** |
| Design system consistency pass | 5 | 2 | 6 | 5 | **4** |
| Dead code deletion (non-migration) | 4 | 3 | 3 | 4 | **5** |

## 17. Recommended Refactor Sprint Scope

### Production Readiness + Developer Experience Refactor v1

**Sprint title:** PRDX v1 — Safe Cleanup & Production Instrumentation  
**Goal:** Improve maintainability and production readiness **without user-facing behavior changes**, except documented flag default corrections.

#### P0 tasks

1. Introduce `FormaAbTestSnapshot.production` with documented defaults; keep `allEnabled` for internal/debug only; update `HealthIntelligenceFeatureFlags` docs/tests to match.
2. Add shared `FormaLogRedactor` and audit any Release `Logger` calls for PII.
3. Implement production analytics sink behind existing `*AnalyticsLogging` protocols (Firebase Analytics or pluggable).
4. Add `WeightLogService.deleteWeightEntry` + tests; wire tombstone sync if missing.
5. Fix or document `SettingsDataExportCapability` vs `FormaAbTest.Settings.dataExportEnabled` mismatch; hide export row until implemented.
6. Add GitHub Actions CI: `functions npm test` + `xcodebuild test -scheme "Fitness Coach CI"` (macOS runner).
7. Resolve `USER_DATA_STORAGE_CONTEXT_PACKET.md` staleness — add header pointer to V7+ ownership.
8. Dead code pass: remove `@deprecated AIContext` if zero references; move migration-only entities to `Infrastructure/Persistence/SwiftData/LegacyEntities/` folder (no schema change).

#### P1 tasks

1. Extract `SyncContainer`, `HealthContainer`, `AnalyticsContainer` from `AppContainer` (composition only).
2. Consolidate HI `*SectionLoader` into `Application/StateBuilders/HealthIntelligence/`.
3. Split `CoachModel` — extract `CoachImagePipelineController` (no behavior change).
4. Unify weekly review presentation contract (Journey + HI).
5. Decompose `FormaProductCopy.swift` into `Domain/Copy/{Today,Coach,Journey,Plan,Onboarding}.swift`.
6. Backend: extract `aiGateway` routes from `index.ts` into `routes/` modules.
7. Add Firestore emulator step to functions CI.

#### Excluded tasks

- Schema migration beyond folder moves
- Coach AI behavior changes
- Onboarding flow changes
- New product features (notifications, widgets)
- Light/System theme ship flip
- Removing migration-only entities from disk

#### Files likely involved

`FormaAbTest.swift`, `AppContainer.swift`, `Infrastructure/Diagnostics/*`, `Domain/*/Analytics*.swift`, `WeightLogService.swift`, `SettingsFeatureAvailability.swift`, `HealthIntelligenceFeatureFlags.swift`, `.github/workflows/ci.yml`, `functions/src/index.ts`, `FormaProductCopy.swift`, `CoachModel.swift`.

#### Tests required

- Update `HealthIntelligenceFeatureFlagsTests` for production snapshot
- Weight delete tests
- Analytics sink integration test (mock backend)
- CI green Fast-Core + Full
- `functions npm test` with emulator for rules suites

#### Risk controls

- One domain per PR
- No migration without dedicated migration tests
- Feature flags default changes behind `production` snapshot only
- Preserve account persistence behavior — run `AccountRestoreEndToEndTests`, `CrossDeviceEndToEndSyncTests`

#### Rollback strategy

- Flag snapshot revert in `FormaAbTest.swift`
- Analytics sink disable flag
- CI optional until stable

#### Success criteria

- `FormaAbTestSnapshot.production` documented and tested
- Release builds emit analytics to real sink (or documented opt-in)
- No PII in Release logs (audit checklist pass)
- Weight delete API exists
- CI green on main
- Zero compiler warnings goal — **Unknown** baseline

## 18. Refactor Safety Rules

1. **No user-facing behavior change** unless explicitly documented in PR and release notes.
2. **No schema migration** unless required; no destructive data migration.
3. **Each refactor** should have tests before/after; extend existing suites over new parallel harnesses.
4. **One domain at a time** — e.g., flags, then analytics, then DI split.
5. **No broad rename** without compiler coverage (run Full test plan).
6. **Do not delete migration-only entities** from disk without schema proof and migration tests.
7. **Every removed file** must be justified in PR with `rg` reference search.
8. **Every changed public protocol** must update fakes in `Fitness CoachTests/TestingSupport/`.
9. **Preserve account persistence behavior** — sync outbox, restore, cross-device, deletion flows.
10. **Preserve Coach behavior** — `CoachRoutingTests` and image workflow E2E must pass.
11. **Preserve weekly progress sprint compatibility** — Journey weekly habit rows + HI weekly review flags.

## 20. Unknowns / Manual Verification

| Item | Status |
|------|--------|
| Production build settings (Release optimizations, stripping) | **Unknown** |
| Deployed Firebase functions version | **Unknown** |
| Deployed Firestore rules vs `firestore.rules` | **Unknown** |
| App Store feature flags / remote config | **None in repo** — N/A |
| Real analytics backend | **None wired** — **Confirmed** NoOp |
| CI status on team infra | **Unknown** — no `.github/workflows` |
| Build warning count | **Unknown** |
| Test flakiness from real runs | **Likely flaky** per TESTING.md — needs fresh macOS run |
| Archive readiness / signing | **Unknown** |
| Privacy review (App Store) | **Unknown** |
| App Store review readiness (legal URLs) | **Blocked** — TODOs in `FormaLegalCopy.swift` |
| Firebase Analytics SDK actually linked | **Likely** in SPM — **Confirmed** unused in Swift |
| `pullRecentDataEnabled = false` impact on cross-device | **Needs product verification** |
| HI UI default in App Store build | **Needs verification** — code defaults all true |


## 19. Files Reviewed

Complete Swift file inventory from `Fitness Coach/` (1,133 files). Grouped by top-level module.

### App root

- `Fitness Coach/App/AIBackendConfiguration.swift`
- `Fitness Coach/App/AppContainer.swift`
- `Fitness Coach/App/AppRefreshCenter.swift`
- `Fitness Coach/App/CoachContextInspectorSupport.swift`
- `Fitness Coach/App/Fitness_CoachApp.swift`
- `Fitness Coach/App/MainTabView.swift`
- `Fitness Coach/App/RootModel.swift`
- `Fitness Coach/App/Routing/AppRouteResolver.swift`
- `Fitness Coach/App/Routing/AppShellRoutingLogger.swift`
- `Fitness Coach/App/Routing/AuthGateRoutingPolicy.swift`
- `Fitness Coach/App/Routing/OnboardingRoutingConfiguration.swift`
- `Fitness Coach/App/Routing/OnboardingShellRouteResolver.swift`
- `Fitness Coach/App/Routing/ProfileBootstrapCoordinator.swift`
- `Fitness Coach/App/Routing/ProfileOwnershipResolver.swift`
- `Fitness Coach/App/Routing/ProfileOwnershipTypes.swift`
- `Fitness Coach/App/Routing/PublicEntryRoute.swift`
- `Fitness Coach/App/Routing/SignedInProfileReconcileBridge.swift`

### DI / container

- `Fitness Coach/App/AppContainer.swift`
- `Fitness Coach/Configuration/FormaAbTest.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountPersistenceFeatureFlags.swift`
- `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift`

### Auth / onboarding

- `Fitness Coach/Features/Auth/AccountProfileMismatchView.swift`
- `Fitness Coach/Features/Auth/AccountRestoreFailedView.swift`
- `Fitness Coach/Features/Auth/AppSignOutEnvironment.swift`
- `Fitness Coach/Features/Auth/AuthGateView.swift`
- `Fitness Coach/Features/Auth/CloudProfileUploadFailedView.swift`
- `Fitness Coach/Features/Auth/Components/AccountRestorePendingStateView.swift`
- `Fitness Coach/Features/Auth/Components/PublicEntryComponents.swift`
- `Fitness Coach/Features/Auth/Components/PublicEntryPreviewScreens.swift`
- `Fitness Coach/Features/Auth/Coordinator/AuthGateCoordinator.swift`
- `Fitness Coach/Features/Auth/ExistingUserProfileLookupFailedView.swift`
- `Fitness Coach/Features/Auth/ExistingUserSignInView.swift`
- `Fitness Coach/Features/Auth/LaunchLoadingView.swift`
- `Fitness Coach/Features/Auth/Model/AccountRestoreViewModel.swift`
- `Fitness Coach/Features/Auth/NoExistingProfileFoundView.swift`
- `Fitness Coach/Features/Auth/OnboardingCloudCheckFailedView.swift`
- `Fitness Coach/Features/Auth/ProfilePlanConflictView.swift`
- `Fitness Coach/Features/Auth/PublicWelcomeTheme.swift`
- `Fitness Coach/Features/Auth/PublicWelcomeView.swift`
- `Fitness Coach/Features/Auth/Views/AccountRestoreView.swift`
- `Fitness Coach/Features/Auth/Views/AuthGateOnboardingShellView.swift`
- `Fitness Coach/Features/Auth/Views/AuthGateProfileErrorView.swift`
- `Fitness Coach/Features/Auth/Views/AuthGateProfilePlanConflictHost.swift`
- `Fitness Coach/Features/Auth/Views/AuthGateRouteView.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingActivityLevelCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingActivityLevelExplanationCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingAppleHealthBenefitCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingAppleHealthHeroIcon.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingAppleHealthPermissionSummaryCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingAppleHealthPrivacyCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingAppleHealthStatusBanner.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingBiologicalSexSelector.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingBirthdayAgePreviewCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingBirthdayTrustCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingBottomBar.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingComponentsPreview.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingFeatureBulletRow.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingFieldNavigator.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingFooterMetrics.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingFormaProofPathVisual.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingGeneratingPlanHeroView.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingHaptics.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingInfoCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingInlineWheelPicker.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingIntroProofHeroSection.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingKeyboardMonitor.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingKeyboardToolbar.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingLoadingView.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingMaintenancePreviewCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPageShell.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanBlueprintAnticipationSection.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanBlueprintGeneratedSummaryRow.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanBlueprintGoalCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanBlueprintVisualCanvas.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealCardChrome.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealCoachCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealFirstWeekCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealFooterReserve.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealGoalHeroCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealHeroIllustration.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealJourneyCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealLayout.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealNutritionCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingPlanRevealProductionPreviewShell.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingProofCards.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingProtectProgressSignInReassurance.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingProtectProgressSignInTrustRows.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingSaveBenefitsCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingSavePlanErrorSlot.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingSavePlanGoogleCTA.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingSavePlanInlineError.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingSavePlanLayoutMetrics.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingSavePlanPrivacyNote.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingSavePlanSummaryCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingStageProgressHeader.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingTargetEncouragementBenefitsSection.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingTargetEncouragementReassuranceCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingTargetWeightGuidanceCard.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingTargetWeightHeroSummary.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingTargetWeightRulerHaptics.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingTargetWeightRulerSelector.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingWarningBanner.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingWeightTrajectoryHeroChart.swift`
- `Fitness Coach/Features/Onboarding/Components/PremiumWeightRulerScrollView.swift`
- `Fitness Coach/Features/Onboarding/Components/PremiumWeightRulerView.swift`
- `Fitness Coach/Features/Onboarding/Formatting/OnboardingFormatter.swift`
- `Fitness Coach/Features/Onboarding/Formatting/OnboardingGoalProjectionBuilder.swift`
- `Fitness Coach/Features/Onboarding/Formatting/OnboardingPersonalizationSummaryBuilder.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingFormState.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingGeneratingPlanTiming.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingGenerationDelayProviding.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingModel.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingPlanRevealTiming.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingPreviewData.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingStep.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingViewState.swift`
- `Fitness Coach/Features/Onboarding/OnboardingView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingActivityLevelStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingAlmostThereStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingAppleHealthStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingBirthdayStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingFormaProofStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingGeneratingPlanStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingHeightWeightStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingIntroProofStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingPersonalizationSummaryStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingPlanGenerationRevealHandoffView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingPlanRevealStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingSavePlanStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingStepContainer.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingStepLayoutMetrics.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingTargetEncouragementStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingTargetWeightStepView.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingWeightLossPaceStepView.swift`
- `Fitness Coach/App/Routing/AppRouteResolver.swift`
- `Fitness Coach/App/Routing/AppShellRoutingLogger.swift`
- `Fitness Coach/App/Routing/AuthGateRoutingPolicy.swift`
- `Fitness Coach/App/Routing/OnboardingRoutingConfiguration.swift`
- `Fitness Coach/App/Routing/OnboardingShellRouteResolver.swift`
- `Fitness Coach/App/Routing/ProfileBootstrapCoordinator.swift`
- `Fitness Coach/App/Routing/ProfileOwnershipResolver.swift`
- `Fitness Coach/App/Routing/ProfileOwnershipTypes.swift`
- `Fitness Coach/App/Routing/PublicEntryRoute.swift`
- `Fitness Coach/App/Routing/SignedInProfileReconcileBridge.swift`
- `Fitness Coach/Application/Services/Auth/AuthManager.swift`
- `Fitness Coach/Application/Services/Auth/AuthManagerError.swift`
- `Fitness Coach/Application/Services/Auth/AuthPresenter.swift`
- `Fitness Coach/Application/Services/Auth/AuthSignInSupport.swift`
- `Fitness Coach/Application/Services/Auth/AuthState.swift`
- `Fitness Coach/Application/Services/Auth/InMemoryAccountAuthDeleting.swift`
- `Fitness Coach/Application/UseCases/Onboarding/OnboardingAnalyticsTracker.swift`
- `Fitness Coach/Application/UseCases/Onboarding/OnboardingAppleHealthCoordinator.swift`
- `Fitness Coach/Application/UseCases/Onboarding/OnboardingCoachingContextStore.swift`
- `Fitness Coach/Application/UseCases/Onboarding/OnboardingPlanGenerationExecutor.swift`
- `Fitness Coach/Application/UseCases/Onboarding/OnboardingProfileCommitter.swift`
- `Fitness Coach/Application/UseCases/Onboarding/OnboardingSessionBootstrap.swift`
- `Fitness Coach/Domain/Onboarding/AccountMismatchOutcome.swift`
- `Fitness Coach/Domain/Onboarding/ActivityTrainingDefaultsResolver.swift`
- `Fitness Coach/Domain/Onboarding/BirthDateAgeResolver.swift`
- `Fitness Coach/Domain/Onboarding/CloudProfileLookupContext.swift`
- `Fitness Coach/Domain/Onboarding/CloudProfilePresence.swift`
- `Fitness Coach/Domain/Onboarding/CloudProfileResolutionResult.swift`
- `Fitness Coach/Domain/Onboarding/CloudProfileUploadFailureContext.swift`
- `Fitness Coach/Domain/Onboarding/CloudProfileWriteIntent.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingActivityLevelExplanationBuilder.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingActivityLevelValues.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingAlmostThereValues.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingAnalyticsLogging.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingAnalyticsStepSlug.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingAppleHealthFlow.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingAppleHealthPresentationState.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingBirthdayAgePreviewBuilder.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingBirthdayValues.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingCoachingContext.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingCommittedProfileRestorer.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingCompletionPolicy.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingDailyStepsBand.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingDraftBridge.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingDraftMigration.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingDraftStepResolver.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingEntry.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingFormaProofBuilder.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingGeneratingPlanCopyBuilder.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingGoalWeightBounds.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingHeightWeightMaintenanceEstimator.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingHeightWeightValues.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingInteractionPolicy.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingLoggingPreference.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingMotivation.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingPickerDefaults.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingPickerValueSequence.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingPlanBlueprintBuilder.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingPlanBlueprintLaunchTiming.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingPlanRevealBuilder.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingPlanRevealState.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingPlanRevealStatus.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingStage.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingTargetEncouragementCopyBuilder.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingTargetWeightGuidanceBuilder.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingTargetWeightValues.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingWheelColumn.swift`
- `Fitness Coach/Domain/Onboarding/ProfileConflictResolutionContext.swift`
- `Fitness Coach/Domain/Onboarding/ProfilePlanConflictSummary.swift`
- `Fitness Coach/Domain/PublicEntry/ExistingUserSignInPolicy.swift`
- `Fitness Coach/Domain/PublicEntry/ExistingUserSignInResolutionResult.swift`
- `Fitness Coach/Domain/PublicEntry/NoExistingProfileFoundPolicy.swift`
- `Fitness Coach/Domain/PublicEntry/PublicEntryAnalyticsContextBuilder.swift`
- `Fitness Coach/Domain/PublicEntry/PublicEntryAnalyticsLogging.swift`
- `Fitness Coach/Domain/PublicEntry/PublicEntryCopyGuardrail.swift`
- `Fitness Coach/Domain/PublicEntry/PublicEntrySessionStore.swift`
- `Fitness Coach/Domain/PublicEntry/WelcomeOnboardingHandoffPolicy.swift`
- `Fitness Coach/Domain/Auth/ProfileSignInCopyPolicy.swift`
- `Fitness Coach/Domain/Auth/ProfileSignInIntent.swift`

### Today

- `Fitness Coach/Features/Today/Components/FoodEntryFormConfiguration.swift`
- `Fitness Coach/Features/Today/Components/FoodEntryFormError.swift`
- `Fitness Coach/Features/Today/Components/FoodEntryFormState.swift`
- `Fitness Coach/Features/Today/Components/FoodEntryFormView.swift`
- `Fitness Coach/Features/Today/Components/FoodEntryProvenanceBanner.swift`
- `Fitness Coach/Features/Today/Components/HealthIntelligence/TodayAdaptiveNutritionCard.swift`
- `Fitness Coach/Features/Today/Components/HealthIntelligence/TodayDailyMissionCard.swift`
- `Fitness Coach/Features/Today/Components/HealthIntelligence/TodayHealthIntelligenceCardSupport.swift`
- `Fitness Coach/Features/Today/Components/HealthIntelligence/TodayHealthIntelligenceSection.swift`
- `Fitness Coach/Features/Today/Components/HealthIntelligence/TodayHealthWorkoutCard.swift`
- `Fitness Coach/Features/Today/Components/HealthIntelligence/TodayNextBestActionCard.swift`
- `Fitness Coach/Features/Today/Components/HealthIntelligence/TodayRecoveryCard.swift`
- `Fitness Coach/Features/Today/Components/TodayActivitySection.swift`
- `Fitness Coach/Features/Today/Components/TodayCoachPrompt.swift`
- `Fitness Coach/Features/Today/Components/TodayDashboardHeader.swift`
- `Fitness Coach/Features/Today/Components/TodayDashboardSkeletonView.swift`
- `Fitness Coach/Features/Today/Components/TodayEditFoodEntrySheet.swift`
- `Fitness Coach/Features/Today/Components/TodayEmptyStateView.swift`
- `Fitness Coach/Features/Today/Components/TodayEndOfDayWrapUpSection.swift`
- `Fitness Coach/Features/Today/Components/TodayGoalConnectionRow.swift`
- `Fitness Coach/Features/Today/Components/TodayHaptics.swift`
- `Fitness Coach/Features/Today/Components/TodayInlineEmptyCard.swift`
- `Fitness Coach/Features/Today/Components/TodayLogMealSheet.swift`
- `Fitness Coach/Features/Today/Components/TodayLogWeightSheet.swift`
- `Fitness Coach/Features/Today/Components/TodayMealsPreview.swift`
- `Fitness Coach/Features/Today/Components/TodayMissionHero.swift`
- `Fitness Coach/Features/Today/Components/TodayNextActionSection.swift`
- `Fitness Coach/Features/Today/Components/TodayNutritionProgressCard.swift`
- `Fitness Coach/Features/Today/Components/TodayPreviewScreens.swift`
- `Fitness Coach/Features/Today/Components/TodayQuickActionsSection.swift`
- `Fitness Coach/Features/Today/Components/TodayReadOnlyProgressSection.swift`
- `Fitness Coach/Features/Today/Components/TodayReadOnlyView.swift`
- `Fitness Coach/Features/Today/Components/TodaySmartCoachBanner.swift`
- `Fitness Coach/Features/Today/Components/TodayVictorySection.swift`
- `Fitness Coach/Features/Today/Components/TodayWaterQuickLogSection.swift`
- `Fitness Coach/Features/Today/Formatting/EndOfDayWrapUpFormatting.swift`
- `Fitness Coach/Features/Today/Formatting/FoodEntryFormFormatter.swift`
- `Fitness Coach/Features/Today/Formatting/TodayActivitySectionFormatting.swift`
- `Fitness Coach/Features/Today/Formatting/TodayDashboardHeaderFormatting.swift`
- `Fitness Coach/Features/Today/Formatting/TodayEmptyStateFormatting.swift`
- `Fitness Coach/Features/Today/Formatting/TodayGoalConnectionFormatting.swift`
- `Fitness Coach/Features/Today/Formatting/TodayMealsSectionFormatting.swift`
- `Fitness Coach/Features/Today/Formatting/TodayMissionHeroFormatting.swift`
- `Fitness Coach/Features/Today/Formatting/TodayNextActionFormatting.swift`
- `Fitness Coach/Features/Today/Formatting/TodayNutritionProgressFormatting.swift`
- `Fitness Coach/Features/Today/Formatting/TodayTargetsFormatter.swift`
- `Fitness Coach/Features/Today/Model/DailyVictoryEngine.swift`
- `Fitness Coach/Features/Today/Model/EndOfDayWrapUpEngine.swift`
- `Fitness Coach/Features/Today/Model/NextBestActionEngine.swift`
- `Fitness Coach/Features/Today/Model/SmartCoachEngine.swift`
- `Fitness Coach/Features/Today/Model/TodayActionCoordinator.swift`
- `Fitness Coach/Features/Today/Model/TodayCrossDeviceRefreshPolicy.swift`
- `Fitness Coach/Features/Today/Model/TodayDashboardSectionOrder.swift`
- `Fitness Coach/Features/Today/Model/TodayDashboardState.swift`
- `Fitness Coach/Features/Today/Model/TodayHealthIntelligencePresentationState.swift`
- `Fitness Coach/Features/Today/Model/TodayHealthIntelligencePreviewData.swift`
- `Fitness Coach/Features/Today/Model/TodayMealsGroupingEngine.swift`
- `Fitness Coach/Features/Today/Model/TodayModel.swift`
- `Fitness Coach/Features/Today/Model/TodayPhotoScanAvailability.swift`
- `Fitness Coach/Features/Today/Model/TodayPreviewData.swift`
- `Fitness Coach/Features/Today/Model/TodayQuickActionKind.swift`
- `Fitness Coach/Features/Today/Model/TodayQuickActionPolicy.swift`
- `Fitness Coach/Features/Today/Model/TodayReadOnlyCompositionPolicy.swift`
- `Fitness Coach/Features/Today/Model/TodayTransientFeedback.swift`
- `Fitness Coach/Features/Today/TodayInteractionStyles.swift`
- `Fitness Coach/Features/Today/TodayLayout.swift`
- `Fitness Coach/Features/Today/TodayView.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayDashboardNutritionMapper.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayFocusBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayGoalsBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayHealthIntelligencePresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayMissionControlStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayPresentationBuilder.swift`

### Coach

- `Fitness Coach/Features/Coach/CoachView.swift`
- `Fitness Coach/Features/Coach/Components/AIFoodConfirmationSheet.swift`
- `Fitness Coach/Features/Coach/Components/CoachAccessibilityIdentifiers.swift`
- `Fitness Coach/Features/Coach/Components/CoachAttachmentMenu.swift`
- `Fitness Coach/Features/Coach/Components/CoachBottomAccessoryStack.swift`
- `Fitness Coach/Features/Coach/Components/CoachChatPhotoMessageView.swift`
- `Fitness Coach/Features/Coach/Components/CoachComposer.swift`
- `Fitness Coach/Features/Coach/Components/CoachConfirmationBar.swift`
- `Fitness Coach/Features/Coach/Components/CoachConversationScrollCoordinator.swift`
- `Fitness Coach/Features/Coach/Components/CoachConversationView.swift`
- `Fitness Coach/Features/Coach/Components/CoachEmptyState.swift`
- `Fitness Coach/Features/Coach/Components/CoachErrorView.swift`
- `Fitness Coach/Features/Coach/Components/CoachHaptics.swift`
- `Fitness Coach/Features/Coach/Components/CoachHeader.swift`
- `Fitness Coach/Features/Coach/Components/CoachInputAttachmentPreview.swift`
- `Fitness Coach/Features/Coach/Components/CoachLaunchChips.swift`
- `Fitness Coach/Features/Coach/Components/CoachLayoutPreviewFixtures.swift`
- `Fitness Coach/Features/Coach/Components/CoachMealPhotoThumbnail.swift`
- `Fitness Coach/Features/Coach/Components/CoachMessagePresenter.swift`
- `Fitness Coach/Features/Coach/Components/CoachMessageView.swift`
- `Fitness Coach/Features/Coach/Components/CoachPendingFoodCardPresentation.swift`
- `Fitness Coach/Features/Coach/Components/CoachPhotoCapture.swift`
- `Fitness Coach/Features/Coach/Components/CoachStarterChips.swift`
- `Fitness Coach/Features/Coach/Components/CoachStarterPrompt.swift`
- `Fitness Coach/Features/Coach/Components/CoachTodayContextCard.swift`
- `Fitness Coach/Features/Coach/Components/CoachTypingIndicatorView.swift`
- `Fitness Coach/Features/Coach/Components/FoodLogEditFormState.swift`
- `Fitness Coach/Features/Coach/Components/NutritionComparisonCard.swift`
- `Fitness Coach/Features/Coach/Components/NutritionEstimateCard.swift`
- `Fitness Coach/Features/Coach/Formatting/AIFoodConfirmationDraft.swift`
- `Fitness Coach/Features/Coach/Formatting/AIFoodConfirmationFormatter.swift`
- `Fitness Coach/Features/Coach/Formatting/CoachPendingCopyFormatter.swift`
- `Fitness Coach/Features/Coach/Formatting/FoodComponentDisplayFormatter.swift`
- `Fitness Coach/Features/Coach/Formatting/FoodMealDisplayNameFormatter.swift`
- `Fitness Coach/Features/Coach/Formatting/NutritionEstimateCardFormatter.swift`
- `Fitness Coach/Features/Coach/Model/CoachAttachmentImportCoordinator.swift`
- `Fitness Coach/Features/Coach/Model/CoachCameraAccess.swift`
- `Fitness Coach/Features/Coach/Model/CoachChatTranscriptStore.swift`
- `Fitness Coach/Features/Coach/Model/CoachHealthContextStatus.swift`
- `Fitness Coach/Features/Coach/Model/CoachHealthIntelligenceContext.swift`
- `Fitness Coach/Features/Coach/Model/CoachImagePickFlowController.swift`
- `Fitness Coach/Features/Coach/Model/CoachImageUploadState.swift`
- `Fitness Coach/Features/Coach/Model/CoachInputAttachment.swift`
- `Fitness Coach/Features/Coach/Model/CoachInputState.swift`
- `Fitness Coach/Features/Coach/Model/CoachLaunchChip.swift`
- `Fitness Coach/Features/Coach/Model/CoachLaunchIntent.swift`
- `Fitness Coach/Features/Coach/Model/CoachLaunchPresentation.swift`
- `Fitness Coach/Features/Coach/Model/CoachMealPhotoError.swift`
- `Fitness Coach/Features/Coach/Model/CoachMealPhotoPipeline.swift`
- `Fitness Coach/Features/Coach/Model/CoachModel.swift`
- `Fitness Coach/Features/Coach/Model/CoachModelTimelineSupport.swift`
- `Fitness Coach/Features/Coach/Model/CoachPendingConfirmation.swift`
- `Fitness Coach/Features/Coach/Model/CoachPendingImageLocalSourceStore.swift`
- `Fitness Coach/Features/Coach/Model/CoachPendingImageState.swift`
- `Fitness Coach/Features/Coach/Model/CoachPhotoPickerPresentation.swift`
- `Fitness Coach/Features/Coach/Model/CoachPhotoPickerTransfer.swift`
- `Fitness Coach/Features/Coach/Model/CoachPreviewData.swift`
- `Fitness Coach/Features/Coach/Model/CoachSpeechAccess.swift`
- `Fitness Coach/Features/Coach/Model/CoachSpeechError.swift`
- `Fitness Coach/Features/Coach/Model/CoachSpeechRecognizerService.swift`
- `Fitness Coach/Features/Coach/Model/CoachTodayContextState.swift`
- `Fitness Coach/Features/Coach/Model/ImageAnalysisSession.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePickFlowState.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline+Camera.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline+ImportedImageProcessing.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline+PhotoLibrary.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline+ProcessedImageImport.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipelineEncoding.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipelineError.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipelineResult.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImageProcessingConfig.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImageUploadConfig.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachProcessedImage.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachAIActivityContextResolver.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachAIResponseContextAdapter.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachCompositionPolicy.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextCompactionMetadata.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextCorrectnessValidator.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextFoodMemoryBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2FallbackBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2TimelineCompactionPolicy.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachDailyStatusBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachEntryReferenceResolver.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachHealthContextStatusResolver.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachHealthGuidanceFormatter.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachHealthIntelligenceContextBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachHealthIntelligenceSnapshotLoader.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachNutritionSummaryFormatter.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachResponseBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachTodayContextBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/NutritionEstimateContextBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/NutritionEstimateCopyValidator.swift`

### Journey

- `Fitness Coach/Features/Journey/Components/HealthIntelligence/JourneyHealthIntelligenceCardSupport.swift`
- `Fitness Coach/Features/Journey/Components/HealthIntelligence/JourneyHealthIntelligenceSection.swift`
- `Fitness Coach/Features/Journey/Components/HealthIntelligence/JourneyHealthProgressCard.swift`
- `Fitness Coach/Features/Journey/Components/HealthIntelligence/JourneyMilestonesCard.swift`
- `Fitness Coach/Features/Journey/Components/HealthIntelligence/JourneyRecoveryTimelineCard.swift`
- `Fitness Coach/Features/Journey/Components/HealthIntelligence/JourneyWorkoutHistoryCard.swift`
- `Fitness Coach/Features/Journey/Components/HealthIntelligence/JourneyWorkoutHistoryRow.swift`
- `Fitness Coach/Features/Journey/Components/JourneyCTAButton.swift`
- `Fitness Coach/Features/Journey/Components/JourneyChapterSection.swift`
- `Fitness Coach/Features/Journey/Components/JourneyDashboardContent.swift`
- `Fitness Coach/Features/Journey/Components/JourneyEmptyStateView.swift`
- `Fitness Coach/Features/Journey/Components/JourneyGoalProjectionSection.swift`
- `Fitness Coach/Features/Journey/Components/JourneyHeaderSection.swift`
- `Fitness Coach/Features/Journey/Components/JourneyInsightsSection.swift`
- `Fitness Coach/Features/Journey/Components/JourneyMilestonesSection.swift`
- `Fitness Coach/Features/Journey/Components/JourneyMomentumStrip.swift`
- `Fitness Coach/Features/Journey/Components/JourneyMonthlyRecapSection.swift`
- `Fitness Coach/Features/Journey/Components/JourneyPreviewScreens.swift`
- `Fitness Coach/Features/Journey/Components/JourneyStartingEmptyStateView.swift`
- `Fitness Coach/Features/Journey/Components/JourneyStoryTimelineSection.swift`
- `Fitness Coach/Features/Journey/Components/JourneyTransformationHeroSection.swift`
- `Fitness Coach/Features/Journey/Components/JourneyWeeklyReviewSection.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewCard.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewCardSupport.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewConfidenceFooter.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewDetailPresentation.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewDetailView.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewFocusList.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewInsightList.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewStatsGrid.swift`
- `Fitness Coach/Features/Journey/Formatting/JourneyFormatter.swift`
- `Fitness Coach/Features/Journey/JourneyDesign.swift`
- `Fitness Coach/Features/Journey/JourneyLayout.swift`
- `Fitness Coach/Features/Journey/JourneyView.swift`
- `Fitness Coach/Features/Journey/Model/JourneyAnalyticsCoordinator.swift`
- `Fitness Coach/Features/Journey/Model/JourneyBaselineResolver.swift`
- `Fitness Coach/Features/Journey/Model/JourneyCTA.swift`
- `Fitness Coach/Features/Journey/Model/JourneyCrossDeviceRefreshPolicy.swift`
- `Fitness Coach/Features/Journey/Model/JourneyDashboardCompositionPolicy.swift`
- `Fitness Coach/Features/Journey/Model/JourneyDashboardState.swift`
- `Fitness Coach/Features/Journey/Model/JourneyDashboardTypes.swift`
- `Fitness Coach/Features/Journey/Model/JourneyHealthIntelligencePresentationState.swift`
- `Fitness Coach/Features/Journey/Model/JourneyHealthIntelligencePreviewData.swift`
- `Fitness Coach/Features/Journey/Model/JourneyLogMetrics.swift`
- `Fitness Coach/Features/Journey/Model/JourneyModel.swift`
- `Fitness Coach/Features/Journey/Model/JourneyPresentationTypes.swift`
- `Fitness Coach/Features/Journey/Model/JourneyPreviewData.swift`
- `Fitness Coach/Features/Journey/Model/JourneyProductLayout.swift`
- `Fitness Coach/Features/Journey/Model/JourneyViewState.swift`
- `Fitness Coach/Features/Journey/Model/JourneyWeeklyTrainingStatus.swift`
- `Fitness Coach/Features/Journey/Model/WeeklyReviewPresentationPreviewData.swift`
- `Fitness Coach/Features/Journey/Model/WeeklyReviewPresentationState.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyChapterBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyDashboardBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyGoalProjectionBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyHealthIntelligencePresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyHealthIntelligenceSectionLoader.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyHeroBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyMilestonesBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyMonthlyRecapBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyNextMilestoneBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyPersonalizedInsightsBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyPresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyStreakBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyTimelineBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyTrainingSummaryBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyWeeklyPatternBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyWeeklyReviewBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/WeeklyReviewPresentationBuilder.swift`

### Plan

- `Fitness Coach/Features/Plan/Components/HealthIntelligence/PlanAssumptionsCard.swift`
- `Fitness Coach/Features/Plan/Components/HealthIntelligence/PlanDataQualityCard.swift`
- `Fitness Coach/Features/Plan/Components/HealthIntelligence/PlanHealthConfidenceCard.swift`
- `Fitness Coach/Features/Plan/Components/HealthIntelligence/PlanHealthIntelligenceCardSupport.swift`
- `Fitness Coach/Features/Plan/Components/HealthIntelligence/PlanHealthIntelligenceSection.swift`
- `Fitness Coach/Features/Plan/Components/HealthIntelligence/PlanHealthSignalsCard.swift`
- `Fitness Coach/Features/Plan/Components/PlanAdjustPlanCTASection.swift`
- `Fitness Coach/Features/Plan/Components/PlanAdjustmentRulesSection.swift`
- `Fitness Coach/Features/Plan/Components/PlanAssumptionsSection.swift`
- `Fitness Coach/Features/Plan/Components/PlanConfidenceSection.swift`
- `Fitness Coach/Features/Plan/Components/PlanDailyTargetsSection.swift`
- `Fitness Coach/Features/Plan/Components/PlanDashboardContent.swift`
- `Fitness Coach/Features/Plan/Components/PlanEmptyStateView.swift`
- `Fitness Coach/Features/Plan/Components/PlanHeaderSection.swift`
- `Fitness Coach/Features/Plan/Components/PlanMissionControlHeroSection.swift`
- `Fitness Coach/Features/Plan/Components/PlanPreviewScreens.swift`
- `Fitness Coach/Features/Plan/Components/PlanRationaleSection.swift`
- `Fitness Coach/Features/Plan/Components/PlanReviewSection.swift`
- `Fitness Coach/Features/Plan/Components/PlanStatusSection.swift`
- `Fitness Coach/Features/Plan/Formatting/PlanFormatter.swift`
- `Fitness Coach/Features/Plan/Model/PlanCrossDeviceRefreshPolicy.swift`
- `Fitness Coach/Features/Plan/Model/PlanDashboardCompositionPolicy.swift`
- `Fitness Coach/Features/Plan/Model/PlanDashboardContext.swift`
- `Fitness Coach/Features/Plan/Model/PlanDashboardState.swift`
- `Fitness Coach/Features/Plan/Model/PlanEditWizardFlow.swift`
- `Fitness Coach/Features/Plan/Model/PlanFormState.swift`
- `Fitness Coach/Features/Plan/Model/PlanHealthIntelligencePresentationPreviewData.swift`
- `Fitness Coach/Features/Plan/Model/PlanHealthIntelligencePresentationState.swift`
- `Fitness Coach/Features/Plan/Model/PlanMissionControlFixtures.swift`
- `Fitness Coach/Features/Plan/Model/PlanModel.swift`
- `Fitness Coach/Features/Plan/Model/PlanPresentationModels.swift`
- `Fitness Coach/Features/Plan/Model/PlanPreviewData.swift`
- `Fitness Coach/Features/Plan/Model/PlanProductLayout.swift`
- `Fitness Coach/Features/Plan/Model/PlanViewState.swift`
- `Fitness Coach/Features/Plan/PlanLayout.swift`
- `Fitness Coach/Features/Plan/PlanView.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanDifficultyBadge.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanEditComponentModels.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanHeroCard.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanInputField.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanMacroSummaryCard.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanMetricPill.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanProjectionCard.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanSegmentedControl.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanSelectableCard.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanSuccessCard.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanTimelinePreview.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/Components/PlanWarningCard.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/PlanEditAccessibility.swift`
- `Fitness Coach/Features/Plan/UI/EditPlan/PlanEditMotion.swift`
- `Fitness Coach/Features/Plan/UI/PlanActivityExpertAdjustmentsCard.swift`
- `Fitness Coach/Features/Plan/UI/PlanActivityLevelCard.swift`
- `Fitness Coach/Features/Plan/UI/PlanActivityTargetPreviewCard.swift`
- `Fitness Coach/Features/Plan/UI/PlanBodyBaselineSummaryCard.swift`
- `Fitness Coach/Features/Plan/UI/PlanBodyMetricInputField.swift`
- `Fitness Coach/Features/Plan/UI/PlanCalculationDetailsSheet.swift`
- `Fitness Coach/Features/Plan/UI/PlanEditActivityStepView.swift`
- `Fitness Coach/Features/Plan/UI/PlanEditBodyBaselineStepView.swift`
- `Fitness Coach/Features/Plan/UI/PlanEditReviewCards.swift`
- `Fitness Coach/Features/Plan/UI/PlanEditReviewStepView.swift`
- `Fitness Coach/Features/Plan/UI/PlanEditSaveSuccessView.swift`
- `Fitness Coach/Features/Plan/UI/PlanEditSelectionChrome.swift`
- `Fitness Coach/Features/Plan/UI/PlanEditShell.swift`
- `Fitness Coach/Features/Plan/UI/PlanEditWizard.swift`
- `Fitness Coach/Features/Plan/UI/PlanGoalSelectionCard.swift`
- `Fitness Coach/Features/Plan/UI/PlanGoalSelectionView.swift`
- `Fitness Coach/Features/Plan/UI/PlanGoalWeightInputField.swift`
- `Fitness Coach/Features/Plan/UI/PlanPaceOutcomeCard.swift`
- `Fitness Coach/Features/Plan/UI/PlanProjectionCards.swift`
- `Fitness Coach/Features/Plan/UI/PlanTransformationSummaryCard.swift`
- `Fitness Coach/Features/Plan/UI/TargetRegenerationSheet.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanActivityLevelPresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanActivityTargetPreviewBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanAdjustPlanCTAStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanAdjustmentRulesStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanAssumptionsStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanBodyBaselineMaintenanceEstimator.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanBodyBaselineSummaryBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanBodyBaselineValidationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanConfidenceStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanEditDifficultyLabelBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanEditFinalPlanSummaryBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanEditHeroStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanEditReviewBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanEditSaveSuccessBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanEditTimelineCopy.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanEditWarningCopyMapper.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanEditWizardStepGate.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanExplanationStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanGoalSelectionBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanGoalWeightValidationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanHeaderStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanHealthIntelligenceLoadResult.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanHealthIntelligencePresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanHealthIntelligenceSectionLoader.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanMissionHeroCopyBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanPaceOutcomeBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanPresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanProjectionBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanReviewStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanStatusStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanTransformationSummaryBuilder.swift`

### Settings / privacy

- `Fitness Coach/Features/Settings/Formatting/AccountDeletionErrorFormatting.swift`
- `Fitness Coach/Features/Settings/Formatting/AccountDeletionStatusFormatting.swift`
- `Fitness Coach/Features/Settings/Formatting/SettingsPrivacyDataTimestampFormatter.swift`
- `Fitness Coach/Features/Settings/Model/AccountDeletionPresentation.swift`
- `Fitness Coach/Features/Settings/Model/AccountDeletionPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/AccountDeletionViewModel.swift`
- `Fitness Coach/Features/Settings/Model/AccountSettingsLogoutHandler.swift`
- `Fitness Coach/Features/Settings/Model/AccountSettingsPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/AccountSettingsPresentationModels.swift`
- `Fitness Coach/Features/Settings/Model/AccountSignInProvider.swift`
- `Fitness Coach/Features/Settings/Model/AppleHealthSettingsActionHandler.swift`
- `Fitness Coach/Features/Settings/Model/AppleHealthSettingsEnvironment.swift`
- `Fitness Coach/Features/Settings/Model/AppleHealthSettingsLastSyncFormatter.swift`
- `Fitness Coach/Features/Settings/Model/AppleHealthSettingsPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/AppleHealthSettingsPresentationModels.swift`
- `Fitness Coach/Features/Settings/Model/AppleHealthSettingsViewModel.swift`
- `Fitness Coach/Features/Settings/Model/BodyDetailsSettingsActionHandler.swift`
- `Fitness Coach/Features/Settings/Model/BodyDetailsSettingsPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/BodyDetailsSettingsPresentationModels.swift`
- `Fitness Coach/Features/Settings/Model/CoachContextInspectionReport.swift`
- `Fitness Coach/Features/Settings/Model/CoachContextPacketV2DebugRedactor.swift`
- `Fitness Coach/Features/Settings/Model/FormaAppMetadata.swift`
- `Fitness Coach/Features/Settings/Model/FormaBuildConfiguration.swift`
- `Fitness Coach/Features/Settings/Model/FormaLegalShippingPolicy.swift`
- `Fitness Coach/Features/Settings/Model/SettingsAboutPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/SettingsAccountDeletionEnvironment.swift`
- `Fitness Coach/Features/Settings/Model/SettingsAnalyticsContextBuilder.swift`
- `Fitness Coach/Features/Settings/Model/SettingsAnalyticsCoordinator.swift`
- `Fitness Coach/Features/Settings/Model/SettingsAnalyticsEnvironment.swift`
- `Fitness Coach/Features/Settings/Model/SettingsChromeAccessibility.swift`
- `Fitness Coach/Features/Settings/Model/SettingsDataDeletionCapability.swift`
- `Fitness Coach/Features/Settings/Model/SettingsDeleteDataActionHandler.swift`
- `Fitness Coach/Features/Settings/Model/SettingsDeveloperPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/SettingsFeatureAvailability.swift`
- `Fitness Coach/Features/Settings/Model/SettingsLegalAvailability.swift`
- `Fitness Coach/Features/Settings/Model/SettingsPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/SettingsPresentationModels.swift`
- `Fitness Coach/Features/Settings/Model/SettingsPrivacyDataEnvironment.swift`
- `Fitness Coach/Features/Settings/Model/SettingsPrivacyDataPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/SettingsPrivacyDataStatusProvider.swift`
- `Fitness Coach/Features/Settings/Model/SettingsPrivacyDataStatusSnapshot.swift`
- `Fitness Coach/Features/Settings/Model/SettingsProductionVisibility.swift`
- `Fitness Coach/Features/Settings/Model/SettingsRowStatusFormatter.swift`
- `Fitness Coach/Features/Settings/Model/SettingsSupportConfiguration.swift`
- `Fitness Coach/Features/Settings/Model/SettingsSupportDeviceInfo.swift`
- `Fitness Coach/Features/Settings/Model/SettingsSupportDiagnostics.swift`
- `Fitness Coach/Features/Settings/Model/SettingsSupportMailURLBuilder.swift`
- `Fitness Coach/Features/Settings/Model/SettingsSupportPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/SettingsUnitsDisplayFormatter.swift`
- `Fitness Coach/Features/Settings/Model/UnitsSettingsPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/UnitsSettingsPresentationModels.swift`
- `Fitness Coach/Features/Settings/SettingsRootView.swift`
- `Fitness Coach/Features/Settings/UI/AccountRestoreDebugEnvironment.swift`
- `Fitness Coach/Features/Settings/UI/AccountRestoreDiagnosticsView.swift`
- `Fitness Coach/Features/Settings/UI/AccountSettingsView.swift`
- `Fitness Coach/Features/Settings/UI/AccountSyncDebugEnvironment.swift`
- `Fitness Coach/Features/Settings/UI/AccountSyncDiagnosticsView.swift`
- `Fitness Coach/Features/Settings/UI/AppleHealthIntegrationView.swift`
- `Fitness Coach/Features/Settings/UI/AppleHealthIntegrationViewPreviews.swift`
- `Fitness Coach/Features/Settings/UI/AppleHealthRemoteSyncSettingsView.swift`
- `Fitness Coach/Features/Settings/UI/AuthDiagnosticsView.swift`
- `Fitness Coach/Features/Settings/UI/CoachContextDebugEnvironment.swift`
- `Fitness Coach/Features/Settings/UI/CoachContextInspectorView.swift`
- `Fitness Coach/Features/Settings/UI/DebugAuthDiagnosticsView.swift`
- `Fitness Coach/Features/Settings/UI/HealthIntelligenceDebugEnvironment.swift`
- `Fitness Coach/Features/Settings/UI/HealthIntelligenceDiagnosticsView.swift`
- `Fitness Coach/Features/Settings/UI/MacroTargetSettingsView.swift`
- `Fitness Coach/Features/Settings/UI/PipelineDiagnosticsView.swift`
- `Fitness Coach/Features/Settings/UI/PipelineTraceDetailView.swift`
- `Fitness Coach/Features/Settings/UI/PlanBodyDetailsSettingsView.swift`
- `Fitness Coach/Features/Settings/UI/SettingsLegalDocumentView.swift`
- `Fitness Coach/Features/Settings/UI/SettingsRootViewPreviews.swift`
- `Fitness Coach/Features/Settings/UI/SettingsSupportMailComposer.swift`
- `Fitness Coach/Features/Settings/UI/ThemeSettingsHaptics.swift`
- `Fitness Coach/Features/Settings/UI/ThemeSettingsLivePreview.swift`
- `Fitness Coach/Features/Settings/UI/ThemeSettingsPickerAccessibility.swift`
- `Fitness Coach/Features/Settings/UI/ThemeSettingsView.swift`
- `Fitness Coach/Features/Settings/UI/UnitsSettingsScreen.swift`
- `Fitness Coach/Features/Settings/UI/WeightLossPaceSettingsView.swift`
- `Fitness Coach/Features/Settings/View/AccountDeletionView.swift`
- `Fitness Coach/Features/Settings/View/SettingsPrivacyDataAccountStatusView.swift`
- `Fitness Coach/Features/Settings/View/SettingsPrivacyDataHealthNoteView.swift`
- `Fitness Coach/Features/Settings/View/SettingsPrivacyDataSyncStatusView.swift`
- `Fitness Coach/Application/Privacy/AccountDataExportModels.swift`
- `Fitness Coach/Application/Privacy/AccountDataExportPolicy.swift`
- `Fitness Coach/Application/Privacy/AccountDataExportService.swift`
- `Fitness Coach/Application/Privacy/AccountDeletionCoordinator.swift`
- `Fitness Coach/Application/Privacy/AccountDeletionModels.swift`
- `Fitness Coach/Application/Privacy/AccountDeletionPolicy.swift`
- `Fitness Coach/Application/Privacy/DeferredAccountDeletionRouter.swift`
- `Fitness Coach/Application/Privacy/LocalAccountDataWipeService.swift`
- `Fitness Coach/Application/Deletion/AccountDeletionGuard.swift`
- `Fitness Coach/Application/Deletion/AccountDeletionShutdownCoordinator.swift`
- `Fitness Coach/Domain/Settings/SettingsAnalyticsLogging.swift`

### Health

- `Fitness Coach/Health/Cache/AuthUIDCache.swift`
- `Fitness Coach/Health/Cache/HealthCachePolicy.swift`
- `Fitness Coach/Health/Cache/HealthCacheRecords.swift`
- `Fitness Coach/Health/Cache/HealthCacheStore.swift`
- `Fitness Coach/Health/Cache/HealthCacheStoreLogger.swift`
- `Fitness Coach/Health/Cache/HealthCacheUserProviding.swift`
- `Fitness Coach/Health/Cache/LocalHealthCacheStore.swift`
- `Fitness Coach/Health/Compatibility/NormalizedWorkout+HealthWorkoutRecord.swift`
- `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift`
- `Fitness Coach/Health/HealthKit/HealthKitManager+Fetching.swift`
- `Fitness Coach/Health/HealthKit/HealthKitManager.swift`
- `Fitness Coach/Health/HealthKit/HealthKitReadTypeRegistry.swift`
- `Fitness Coach/Health/HealthKit/HealthKitSampleMapper.swift`
- `Fitness Coach/Health/Intelligence/AdaptiveNutritionEngine.swift`
- `Fitness Coach/Health/Intelligence/Baselines/HealthBaselineService.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceBaseline.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceComposeMode.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceContext+Composition.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceContextBuilder.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceEngine.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceEngineLogger.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceProviding.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceSnapshotLogger.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceSnapshotService.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceSnapshotVerifier.swift`
- `Fitness Coach/Health/Intelligence/HealthNextBestActionEngine.swift`
- `Fitness Coach/Health/Intelligence/HealthNormalizedSampleDeriver.swift`
- `Fitness Coach/Health/Intelligence/RecoveryEngine.swift`
- `Fitness Coach/Health/Intelligence/TrainingLoadEngine.swift`
- `Fitness Coach/Health/Intelligence/WeeklyReviewEngine.swift`
- `Fitness Coach/Health/Intelligence/WeeklyReviewService.swift`
- `Fitness Coach/Health/Intelligence/WeeklyReviewWeekPolicy.swift`
- `Fitness Coach/Health/Intelligence/WorkoutIntelligenceEngine.swift`
- `Fitness Coach/Health/Models/DailyHealthMetrics.swift`
- `Fitness Coach/Health/Models/HealthIntelligenceMocks.swift`
- `Fitness Coach/Health/Models/HealthIntelligencePresentationLifecycle.swift`
- `Fitness Coach/Health/Models/HealthIntelligencePresentationStateMapper.swift`
- `Fitness Coach/Health/Models/HealthIntelligenceSnapshot+Preview.swift`
- `Fitness Coach/Health/Models/HealthIntelligenceSnapshot.swift`
- `Fitness Coach/Health/Models/HealthIntelligenceSummaryModels.swift`
- `Fitness Coach/Health/Models/HealthKitRecords.swift`
- `Fitness Coach/Health/Models/HealthNormalizedSample.swift`
- `Fitness Coach/Health/Models/HealthPermissionStatus.swift`
- `Fitness Coach/Health/Models/HealthQuantityNormalization.swift`
- `Fitness Coach/Health/Models/HealthSampleNormalizer.swift`
- `Fitness Coach/Health/Models/HealthSignalAccess.swift`
- `Fitness Coach/Health/Models/HealthSignalKind.swift`
- `Fitness Coach/Health/Models/HealthStableIdentifier.swift`
- `Fitness Coach/Health/Models/HealthUnitSymbol.swift`
- `Fitness Coach/Health/Models/HealthWorkoutCategoryMapping.swift`
- `Fitness Coach/Health/Permissions/HealthPermissionCategory.swift`
- `Fitness Coach/Health/Permissions/HealthPermissionCopy.swift`
- `Fitness Coach/Health/Permissions/HealthPermissionDisplayModel.swift`
- `Fitness Coach/Health/Permissions/HealthPermissionLogger.swift`
- `Fitness Coach/Health/Permissions/HealthPermissionService.swift`
- `Fitness Coach/Health/Permissions/HealthPrivacyCopy.swift`
- `Fitness Coach/Health/Repository/HealthDataAvailability.swift`
- `Fitness Coach/Health/Repository/HealthDataRepository.swift`
- `Fitness Coach/Health/Repository/HealthDataRepositoryDefaults.swift`
- `Fitness Coach/Health/Repository/HealthDataRepositoryLogger.swift`
- `Fitness Coach/Health/Repository/HealthOSLogFormatting.swift`
- `Fitness Coach/Health/Sync/HealthSummaryRemoteSyncState.swift`
- `Fitness Coach/Health/Sync/HealthSummaryRemoteSyncStateStore.swift`
- `Fitness Coach/Health/Sync/HealthSummarySyncConsentState.swift`
- `Fitness Coach/Health/Sync/HealthSummarySyncConsentStore.swift`
- `Fitness Coach/Health/Sync/HealthSummarySyncDebugLogger.swift`
- `Fitness Coach/Health/Sync/HealthSummarySyncService.swift`
- `Fitness Coach/Health/Sync/HealthSyncError.swift`
- `Fitness Coach/Health/Sync/HealthSyncLogger.swift`
- `Fitness Coach/Health/Sync/HealthSyncService.swift`
- `Fitness Coach/Health/Sync/HealthSyncState.swift`
- `Fitness Coach/Health/Sync/HealthSyncStateStore.swift`
- `Fitness Coach/Health/Sync/Remote/HealthDailySummarySyncPayload.swift`
- `Fitness Coach/Health/Sync/Remote/HealthSummaryRemoteSyncClient.swift`
- `Fitness Coach/Health/Sync/Remote/HealthSummarySyncEnvelope.swift`
- `Fitness Coach/Health/Sync/Remote/HealthSummarySyncError.swift`
- `Fitness Coach/Health/Sync/Remote/HealthSummarySyncSchemaVersion.swift`
- `Fitness Coach/Health/Sync/Remote/HealthSyncMetadataPayload.swift`
- `Fitness Coach/Health/Sync/Remote/HealthWorkoutSummarySyncPayload.swift`
- `Fitness Coach/Health/Sync/Remote/RecoverySummarySyncPayload.swift`
- `Fitness Coach/Health/Sync/Remote/WeeklyHealthReviewSyncPayload.swift`
- `Fitness Coach/Health/UIState/HealthFallbackReason.swift`
- `Fitness Coach/Health/UIState/HealthInsightAvailability.swift`
- `Fitness Coach/Health/UIState/HealthIntelligenceUIState.swift`
- `Fitness Coach/Features/HealthIntelligence/HealthIntelligenceAnalyticsCoordinator.swift`
- `Fitness Coach/Domain/HealthIntelligence/HealthIntelligenceAnalyticsLogging.swift`
- `Fitness Coach/Domain/HealthIntelligence/HealthIntelligencePipelineAnalytics.swift`
- `Fitness Coach/Domain/HealthIntelligence/HealthIntelligencePresentationTextSanitizer.swift`

### Sync / restore

- `Fitness Coach/Application/Sync/AccountDataNamespaceService.swift`
- `Fitness Coach/Application/Sync/AccountDataRefreshEventBus.swift`
- `Fitness Coach/Application/Sync/AccountDataSyncStamping.swift`
- `Fitness Coach/Application/Sync/AccountIncrementalPuller.swift`
- `Fitness Coach/Application/Sync/AccountLocalMutationTracker.swift`
- `Fitness Coach/Application/Sync/AccountMigrationBackfillReport.swift`
- `Fitness Coach/Application/Sync/AccountMigrationDebugLogger.swift`
- `Fitness Coach/Application/Sync/AccountMigrationService.swift`
- `Fitness Coach/Application/Sync/AccountRealtimeChangeListener.swift`
- `Fitness Coach/Application/Sync/AccountSyncCoordinator.swift`
- `Fitness Coach/Application/Sync/AccountSyncCursorStore.swift`
- `Fitness Coach/Application/Sync/AccountSyncDiagnostics.swift`
- `Fitness Coach/Application/Sync/AccountSyncLifecycle.swift`
- `Fitness Coach/Application/Sync/AccountSyncMergePolicy.swift`
- `Fitness Coach/Application/Sync/AccountSyncMutationModels.swift`
- `Fitness Coach/Application/Sync/AccountSyncOutboxStore.swift`
- `Fitness Coach/Application/Sync/AccountSyncPayloadBuilder.swift`
- `Fitness Coach/Application/Sync/AccountSyncPuller.swift`
- `Fitness Coach/Application/Sync/AccountSyncUploader.swift`
- `Fitness Coach/Application/Sync/AccountUIDProviding.swift`
- `Fitness Coach/Application/Sync/CrossDeviceSyncCoordinator.swift`
- `Fitness Coach/Application/Sync/CrossDeviceSyncLifecycle.swift`
- `Fitness Coach/Application/Sync/CrossDeviceSyncModels.swift`
- `Fitness Coach/Application/Sync/CrossDeviceSyncPolicy.swift`
- `Fitness Coach/Application/Sync/UserDataOwnership.swift`
- `Fitness Coach/Application/Restore/AccountInitialRestoreService.swift`
- `Fitness Coach/Application/Restore/AccountLocalDataInspector.swift`
- `Fitness Coach/Application/Restore/AccountRemoteDataInspector.swift`
- `Fitness Coach/Application/Restore/AccountRestoreCoordinator.swift`
- `Fitness Coach/Application/Restore/AccountRestoreDiagnostics.swift`
- `Fitness Coach/Application/Restore/AccountRestoreModels.swift`
- `Fitness Coach/Application/Restore/AccountRestoreOutcomeSupport.swift`
- `Fitness Coach/Application/Restore/AccountRestorePolicy.swift`
- `Fitness Coach/Application/Restore/AccountRestoreSessionState.swift`
- `Fitness Coach/Application/Restore/AccountRestoreStateStore.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/AccountDataRemoteStore.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/CloudAccountDataEnvelope.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/CloudAccountDataMappers.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/CloudDailyLogDocument.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/CloudDailyReviewDocument.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/CloudFoodEntryDocument.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/CloudSyncMetadataDocument.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/CloudWaterEntryDocument.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/CloudWeightEntryDocument.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/FirestoreAccountDataRemoteStore.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountData/FirestoreAccountRealtimeChangeListener.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountDataCloudPaths.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountDataCloudSchema.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountDeletionRemoteClient.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountPersistenceFeatureFlags.swift`
- `Fitness Coach/Infrastructure/Cloud/CloudNutritionDocumentMapping.swift`
- `Fitness Coach/Infrastructure/Cloud/CloudUserProfileDocument.swift`
- `Fitness Coach/Infrastructure/Cloud/CloudUserProfileStoring.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreCloudUserProfileStore.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreHealthSummaryRemoteSyncClient.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreNutritionRemoteSyncClients.swift`
- `Fitness Coach/Infrastructure/Cloud/FirestoreNutritionSyncSupport.swift`
- `Fitness Coach/Infrastructure/Cloud/NoOpCloudUserProfileStore.swift`
- `Fitness Coach/Infrastructure/Cloud/NutritionRemoteSyncing.swift`
- `Fitness Coach/Infrastructure/Cloud/NutritionSyncError.swift`
- `Fitness Coach/Domain/Sync/AccountDataSyncStatus.swift`

### Persistence

- `Fitness Coach/Infrastructure/Persistence/SwiftData/AccountDataSyncMetadata.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/AccountSyncMutationEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/ChatMessageEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/CoachChatTranscriptMessageEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/CoachTimelineEventEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/DailyLogEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/DailyReviewEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/DebugRecordEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/ExerciseSetEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/FoodEntryEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/UserDataEntitySchema.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/UserProfileEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/WaterEntryEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/WeeklyReviewEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/WeightEntryEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/WorkoutEntryEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/CoachChatTranscriptMessageEntity+Mapping.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/CoachTimelineEventEntity+Mapping.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/CoachTimelineEventPayloadCodec.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/CoachTimelineEventSummaryBuilder.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/DailyLogEntity+Mapping.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/DailyReviewEntity+Mapping.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/FoodEntryEntity+Mapping.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/UserProfileEntity+Mapping.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/WaterEntryEntity+Mapping.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/WeightEntryEntity+Mapping.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelContainer.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelMigration.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaSwiftDataMigrationGate.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/SwiftDataError.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/SwiftDataStore.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/UserDataOwnerScope.swift`
- `Fitness Coach/Data/DTOs/ExerciseSetDraft.swift`
- `Fitness Coach/Data/DTOs/FoodComponent.swift`
- `Fitness Coach/Data/DTOs/FoodDraft.swift`
- `Fitness Coach/Data/DTOs/FoodDraftNutritionCompleter.swift`
- `Fitness Coach/Data/DTOs/FoodEntryUpdate.swift`
- `Fitness Coach/Data/DTOs/FoodLogDraft.swift`
- `Fitness Coach/Data/DTOs/FoodLogDraftMapper.swift`
- `Fitness Coach/Data/DTOs/FoodLogDraftNutritionCompleter.swift`
- `Fitness Coach/Data/DTOs/Onboarding/OnboardingDraft.swift`
- `Fitness Coach/Data/DTOs/Onboarding/OnboardingDraftStore.swift`
- `Fitness Coach/Data/DTOs/UserProfileDraft.swift`
- `Fitness Coach/Data/DTOs/UserProfileUpdate.swift`
- `Fitness Coach/Data/DTOs/WaterDraft.swift`
- `Fitness Coach/Data/DTOs/WeightDraft.swift`
- `Fitness Coach/Data/DTOs/WorkoutDraft.swift`
- `Fitness Coach/Data/Repositories/CoachChatTranscriptPersistenceRepository.swift`
- `Fitness Coach/Data/Repositories/CoachTimelinePersistenceRepository.swift`
- `Fitness Coach/Data/Repositories/DailyLogService.swift`
- `Fitness Coach/Data/Repositories/FoodLogService.swift`
- `Fitness Coach/Data/Repositories/ProfileCloudSyncStore.swift`
- `Fitness Coach/Data/Repositories/ReviewService.swift`
- `Fitness Coach/Data/Repositories/UserProfileService.swift`
- `Fitness Coach/Data/Repositories/WaterLogService.swift`
- `Fitness Coach/Data/Repositories/WeightLogService.swift`

### Backend / functions

- `functions/package-lock.json`
- `functions/package.json`
- `functions/scripts/smoke-ai-gateway-auth.mjs`
- `functions/src/accountDeletion/accountDeletionGuardrails.ts`
- `functions/src/accountDeletion/accountDeletionHandler.ts`
- `functions/src/accountDeletion/accountDeletionPaths.ts`
- `functions/src/accountDeletion/accountDeletionService.ts`
- `functions/src/accountDeletion/accountDeletionTypes.ts`
- `functions/src/coachContextPacketV2.ts`
- `functions/src/coachContextPromptRules.ts`
- `functions/src/coachIntentPhraseGuard.ts`
- `functions/src/coachIntentSanitizer.ts`
- `functions/src/coachPromptInstructions.ts`
- `functions/src/foodCompoundDish.ts`
- `functions/src/foodEstimateExtraction.ts`
- `functions/src/gatewayGuardrails.ts`
- `functions/src/index.ts`
- `functions/src/mealImageAnalysis.ts`
- `functions/src/nutritionResponseSanitizer.ts`
- `functions/src/openAIReasoningEffort.ts`
- `functions/test/accountDeletion.test.ts`
- `functions/test/accountPersistenceFirestoreRules.test.ts`
- `functions/test/aiGateway.contract.test.ts`
- `functions/test/coachContextPacketV2.test.ts`
- `functions/test/coachContextPromptRules.test.ts`
- `functions/test/coachContextV2Contract.test.ts`
- `functions/test/coachIntentPhraseGuard.test.ts`
- `functions/test/coachIntentRegressionFixture.test.ts`
- `functions/test/coachIntentSanitizer.test.ts`
- `functions/test/coachPromptSnapshots.test.ts`
- `functions/test/fixtures/coach-context-v2/analyze-meal-image-request.json`
- `functions/test/fixtures/coach-context-v2/degraded-context.json`
- `functions/test/fixtures/coach-context-v2/index.ts`
- `functions/test/fixtures/coach-context-v2/minimal-context.json`
- `functions/test/fixtures/coach-context-v2/rich-context.json`
- `functions/test/fixtures/coach-context-v2/sanitization-probe-context.json`
- `functions/test/fixtures/coachContextPacketV2.ts`
- `functions/test/fixtures/foodLoggingGoldenCases.ts`
- `functions/test/fixtures/openaiFixtures.ts`
- `functions/test/fixtures/singaporeFoodEstimationFixtureSupport.ts`
- `functions/test/foodCompoundDish.test.ts`
- `functions/test/foodEstimateExtraction.test.ts`
- `functions/test/foodLoggingGolden.test.ts`
- `functions/test/gatewayGuardrails.test.ts`
- `functions/test/helpers/accountPersistenceRulesFixtures.ts`
- `functions/test/helpers/coachPromptCriticalRules.ts`
- `functions/test/helpers/inMemoryFirestore.ts`
- `functions/test/helpers/mockHttp.ts`
- `functions/test/mealImageAnalysis.test.ts`
- `functions/test/nutritionResponseSanitizer.test.ts`
- `functions/test/nutritionSchema.test.ts`
- `functions/test/nutritionSyncContract.test.ts`
- `functions/test/openAIReasoningEffort.test.ts`
- `functions/test/singaporeFoodEstimationFixture.test.ts`
- `functions/tsconfig.dev.json`
- `functions/tsconfig.json`
- `functions/tsconfig.test.json`

### Design system

- `Fitness Coach/DesignSystem/Coach/CoachDesignTokens.swift`
- `Fitness Coach/DesignSystem/Coach/CoachFlowLayout.swift`
- `Fitness Coach/DesignSystem/Components/FormaActionRow.swift`
- `Fitness Coach/DesignSystem/Components/FormaBrandMark.swift`
- `Fitness Coach/DesignSystem/Components/FormaCardChrome.swift`
- `Fitness Coach/DesignSystem/Components/FormaEmptyStateCard.swift`
- `Fitness Coach/DesignSystem/Components/FormaEstimateContextBanner.swift`
- `Fitness Coach/DesignSystem/Components/FormaFormCard.swift`
- `Fitness Coach/DesignSystem/Components/FormaGoogleSignInButton.swift`
- `Fitness Coach/DesignSystem/Components/FormaInlineEmptyState.swift`
- `Fitness Coach/DesignSystem/Components/FormaLabeledField.swift`
- `Fitness Coach/DesignSystem/Components/FormaMacroInputGrid.swift`
- `Fitness Coach/DesignSystem/Components/FormaMetricRow.swift`
- `Fitness Coach/DesignSystem/Components/FormaPickerRow.swift`
- `Fitness Coach/DesignSystem/Components/FormaPlanCard.swift`
- `Fitness Coach/DesignSystem/Components/FormaScreenChrome.swift`
- `Fitness Coach/DesignSystem/Components/FormaScreenErrorView.swift`
- `Fitness Coach/DesignSystem/Components/FormaScreenLoadingView.swift`
- `Fitness Coach/DesignSystem/Components/FormaSectionLabel.swift`
- `Fitness Coach/DesignSystem/Components/FormaSettingsRows.swift`
- `Fitness Coach/DesignSystem/Components/FormaTransientBanner.swift`
- `Fitness Coach/DesignSystem/Components/HealthIntelligenceCardLayout.swift`
- `Fitness Coach/DesignSystem/Layout/FormaFeatureLayout.swift`
- `Fitness Coach/DesignSystem/Layout/FormaMainTabLayout.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingBenefitGrid.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingFooterMessage.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingGoalCard.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingHeroSection.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingIllustrationContainer.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingMarketingAtmosphere.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingMarketingDesignSystemPreview.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingMetricHighlight.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingPrimaryCTA.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingTransformationCard.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingVisionScreenShell.swift`
- `Fitness Coach/DesignSystem/Onboarding/Components/OnboardingVisionZoneLayout.swift`
- `Fitness Coach/DesignSystem/Onboarding/OnboardingDesignTokens.swift`
- `Fitness Coach/DesignSystem/Onboarding/OnboardingTheme.swift`
- `Fitness Coach/DesignSystem/Preview/CoachLayoutPreviewScreens.swift`
- `Fitness Coach/DesignSystem/Preview/FormaThemeAppearanceMatrixPreviews.swift`
- `Fitness Coach/DesignSystem/Preview/HealthIntelligenceThemeMatrixPreviews.swift`
- `Fitness Coach/DesignSystem/Preview/MainTabThemePreviewScreens.swift`
- `Fitness Coach/DesignSystem/Theme/AppAppearanceMode.swift`
- `Fitness Coach/DesignSystem/Theme/AppThemeDisplayCopy.swift`
- `Fitness Coach/DesignSystem/Theme/AppThemePalette.swift`
- `Fitness Coach/DesignSystem/Theme/AppThemePreferences.swift`
- `Fitness Coach/DesignSystem/Theme/AppThemeShippingPolicy.swift`
- `Fitness Coach/DesignSystem/Theme/FormaBrandColorTokens.swift`
- `Fitness Coach/DesignSystem/Theme/FormaColorContrast.swift`
- `Fitness Coach/DesignSystem/Theme/FormaColorPalette.swift`
- `Fitness Coach/DesignSystem/Theme/FormaPaletteCatalog.swift`
- `Fitness Coach/DesignSystem/Theme/FormaThemeAccess.swift`
- `Fitness Coach/DesignSystem/Theme/FormaThemeColors.swift`
- `Fitness Coach/DesignSystem/Theme/FormaThemeEnvironment.swift`
- `Fitness Coach/DesignSystem/Theme/FormaThemePalette.swift`
- `Fitness Coach/DesignSystem/Theme/FormaThemeScreenModifier.swift`
- `Fitness Coach/DesignSystem/Theme/NeutralAppearanceColors.swift`
- `Fitness Coach/DesignSystem/Theme/ResolvedAppTheme.swift`
- `Fitness Coach/DesignSystem/Theme/ThemeAccessibilityAdaptationPolicy.swift`
- `Fitness Coach/DesignSystem/Theme/ThemeAnalyticsLogging.swift`
- `Fitness Coach/DesignSystem/Theme/ThemeColorProvider.swift`
- `Fitness Coach/DesignSystem/Theme/ThemePalette.swift`
- `Fitness Coach/DesignSystem/Theme/ThemePaletteCatalog.swift`
- `Fitness Coach/DesignSystem/Theme/ThemePalettePersistence.swift`
- `Fitness Coach/DesignSystem/Theme/ThemeResolver.swift`
- `Fitness Coach/DesignSystem/Theme/ThemeStore.swift`
- `Fitness Coach/DesignSystem/Tokens/FormaPlanColors.swift`
- `Fitness Coach/DesignSystem/Tokens/FormaPlanTokens.swift`
- `Fitness Coach/DesignSystem/Tokens/FormaTokens.swift`
- `Fitness Coach/DesignSystem/Tokens/PlanThemeColorProvider.swift`

### Analytics

- `Fitness Coach/Infrastructure/Diagnostics/AccountDeletionCoordinatorLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/AccountRestoreLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/AccountSyncLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/AuthSignInDebugLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/CoachAccuracyObservability.swift`
- `Fitness Coach/Infrastructure/Diagnostics/CoachFoodEstimateDebugLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/CoachImageAnalysisDebugLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/CoachImageProcessingLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/CoachTodaySyncDebugLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/CrossDeviceSyncLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/FormaPipelineTracer.swift`
- `Fitness Coach/Infrastructure/Diagnostics/NoOpHealthIntelligenceAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/NoOpJourneyAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/NoOpOnboardingAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/NoOpPlanAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/NoOpPublicEntryAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/NoOpSettingsAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/NoOpThemeAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/NoOpTodayAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/OSLogHealthIntelligenceAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/OSLogJourneyAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/OSLogOnboardingAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/OSLogPlanAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/OSLogPublicEntryAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/OSLogSettingsAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/OSLogThemeAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/OSLogTodayAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/ProfileBootstrapDebugLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/ThemePersistenceDebugLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/TodayHydrationDebugLogger.swift`
- `Fitness Coach/Domain/Today/TodayAnalyticsContextBuilder.swift`
- `Fitness Coach/Domain/Today/TodayAnalyticsLogging.swift`
- `Fitness Coach/Domain/Plan/PlanAnalyticsContextBuilder.swift`
- `Fitness Coach/Domain/Plan/PlanAnalyticsLogging.swift`
- `Fitness Coach/Domain/Journey/JourneyAnalyticsLogging.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingAnalyticsLogging.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingAnalyticsStepSlug.swift`
- `Fitness Coach/Domain/PublicEntry/PublicEntryAnalyticsContextBuilder.swift`
- `Fitness Coach/Domain/PublicEntry/PublicEntryAnalyticsLogging.swift`
- `Fitness Coach/Domain/Coach/CoachAnalyticsLogging.swift`
- `Fitness Coach/DesignSystem/Theme/ThemeAnalyticsLogging.swift`

### Tests

*(506 files — listing first 100 alphabetically; full target on disk)*

- `Fitness CoachTests/AIBackendConfigurationTests.swift`
- `Fitness CoachTests/AIBackendErrorMappingTests.swift`
- `Fitness CoachTests/AccountAuthDeletionTests.swift`
- `Fitness CoachTests/AccountBackgroundBackfillCoordinatorTests.swift`
- `Fitness CoachTests/AccountDataCloudPathsTests.swift`
- `Fitness CoachTests/AccountDataExportPolicyTests.swift`
- `Fitness CoachTests/AccountDataExportServiceTests.swift`
- `Fitness CoachTests/AccountDataNamespaceServiceTests.swift`
- `Fitness CoachTests/AccountDataRefreshEventBusTests.swift`
- `Fitness CoachTests/AccountDataRemoteStoreIncrementalFetchTests.swift`
- `Fitness CoachTests/AccountDataSyncStatusTests.swift`
- `Fitness CoachTests/AccountDeletionCancellationTests.swift`
- `Fitness CoachTests/AccountDeletionCoordinatorTests.swift`
- `Fitness CoachTests/AccountDeletionEndToEndTests.swift`
- `Fitness CoachTests/AccountDeletionRemoteClientTests.swift`
- `Fitness CoachTests/AccountDeletionViewModelTests.swift`
- `Fitness CoachTests/AccountIncrementalPullerTests.swift`
- `Fitness CoachTests/AccountInitialRestoreServiceTests.swift`
- `Fitness CoachTests/AccountLocalDataInspectorTests.swift`
- `Fitness CoachTests/AccountLocalMutationTrackingTests.swift`
- `Fitness CoachTests/AccountMigrationServiceTests.swift`
- `Fitness CoachTests/AccountPersistenceAuthLifecycleTests.swift`
- `Fitness CoachTests/AccountProfileMismatchTests.swift`
- `Fitness CoachTests/AccountRealtimeChangeListenerTests.swift`
- `Fitness CoachTests/AccountRemoteDataInspectorTests.swift`
- `Fitness CoachTests/AccountRestoreCoordinatorTests.swift`
- `Fitness CoachTests/AccountRestoreEndToEndTests.swift`
- `Fitness CoachTests/AccountRestoreLoggerTests.swift`
- `Fitness CoachTests/AccountRestoreOutcomeSupportTests.swift`
- `Fitness CoachTests/AccountRestorePolicyTests.swift`
- `Fitness CoachTests/AccountRestoreSessionStateTests.swift`
- `Fitness CoachTests/AccountRestoreStateStoreTests.swift`
- `Fitness CoachTests/AccountRestoreViewModelTests.swift`
- `Fitness CoachTests/AccountSettingsPresentationBuilderTests.swift`
- `Fitness CoachTests/AccountSyncCoordinatorTests.swift`
- `Fitness CoachTests/AccountSyncCursorStoreTests.swift`
- `Fitness CoachTests/AccountSyncDiagnosticsTests.swift`
- `Fitness CoachTests/AccountSyncLifecycleWiringTests.swift`
- `Fitness CoachTests/AccountSyncLoggerTests.swift`
- `Fitness CoachTests/AccountSyncMergePolicyTests.swift`
- `Fitness CoachTests/AccountSyncMutationCoalescingTests.swift`
- `Fitness CoachTests/AccountSyncMutationIntegrationTests.swift`
- `Fitness CoachTests/AccountSyncOutboxStoreTests.swift`
- `Fitness CoachTests/AccountSyncPayloadBuilderTests.swift`
- `Fitness CoachTests/AccountSyncPullerTests.swift`
- `Fitness CoachTests/AccountSyncRemoteIntegrationTests.swift`
- `Fitness CoachTests/AccountSyncUploaderTests.swift`
- `Fitness CoachTests/ActionRowBehaviorTests.swift`
- `Fitness CoachTests/ActivityTrainingDefaultsResolverTests.swift`
- `Fitness CoachTests/AdaptiveNutritionEngineTests.swift`
- `Fitness CoachTests/AppAppearanceModeTests.swift`
- `Fitness CoachTests/AppContainerAccountDataRemoteStoreWiringTests.swift`
- `Fitness CoachTests/AppLifecycleCrossDeviceSyncTests.swift`
- `Fitness CoachTests/AppRouteResolverGuardrailTests.swift`
- `Fitness CoachTests/AppThemePaletteTests.swift`
- `Fitness CoachTests/AppleHealthSettingsPresentationBuilderTests.swift`
- `Fitness CoachTests/AppleHealthTrainingStrategyTests.swift`
- `Fitness CoachTests/AuthGateRoutingPolicyTests.swift`
- `Fitness CoachTests/AuthManagerErrorTests.swift`
- `Fitness CoachTests/AuthProfileRouteSafetyTests.swift`
- `Fitness CoachTests/AuthRestoreRoutingTests.swift`
- `Fitness CoachTests/AuthRoutingTests.swift`
- `Fitness CoachTests/AuthSignInRegressionTests.swift`
- `Fitness CoachTests/BirthDateAgeResolverTests.swift`
- `Fitness CoachTests/BodyDetailsSettingsTests.swift`
- `Fitness CoachTests/CloudAccountDataDocumentTests.swift`
- `Fitness CoachTests/CloudAccountDataMapperTests.swift`
- `Fitness CoachTests/CloudNutritionDocumentMappingTests.swift`
- `Fitness CoachTests/CloudProfileResolutionTests.swift`
- `Fitness CoachTests/CloudProfileUploadFailureTests.swift`
- `Fitness CoachTests/CloudProfileWriteGuardTests.swift`
- `Fitness CoachTests/CloudUserProfileDocumentTests.swift`
- `Fitness CoachTests/CoachAIHealthIntelligenceIntegrationTests.swift`
- `Fitness CoachTests/CoachAccuracyObservabilityTests.swift`
- `Fitness CoachTests/CoachAttachmentFlowStateTests.swift`
- `Fitness CoachTests/CoachCameraCaptureTests.swift`
- `Fitness CoachTests/CoachChatTranscriptPersistenceTests.swift`
- `Fitness CoachTests/CoachCompositionPolicyTests.swift`
- `Fitness CoachTests/CoachContextCorrectnessValidatorTests.swift`
- `Fitness CoachTests/CoachContextFoodMemoryBuilderTests.swift`
- `Fitness CoachTests/CoachContextHealthIntelligenceDefaultOnTests.swift`
- `Fitness CoachTests/CoachContextHealthIntelligenceHardeningTests.swift`
- `Fitness CoachTests/CoachContextInspectorTests.swift`
- `Fitness CoachTests/CoachContextPacketV2BuilderTests.swift`
- `Fitness CoachTests/CoachContextPacketV2CompactionTests.swift`
- `Fitness CoachTests/CoachContextPacketV2FallbackTests.swift`
- `Fitness CoachTests/CoachContextPacketV2Tests.swift`
- `Fitness CoachTests/CoachContextV2ContractTests.swift`
- `Fitness CoachTests/CoachConversationScrollCoordinatorTests.swift`
- `Fitness CoachTests/CoachDailyStatusBuilderTests.swift`
- `Fitness CoachTests/CoachEntryReferenceResolverTests.swift`
- `Fitness CoachTests/CoachFoodEstimateDebugLogFormatterTests.swift`
- `Fitness CoachTests/CoachFoodLoggingRegressionTests.swift`
- `Fitness CoachTests/CoachHealthContextCopyTests.swift`
- `Fitness CoachTests/CoachHealthContextStatusTests.swift`
- `Fitness CoachTests/CoachHealthIntelligenceContextBuilderTests.swift`
- `Fitness CoachTests/CoachHealthIntelligenceContextTests.swift`
- `Fitness CoachTests/CoachImageAnalysisDebugLogFormatterTests.swift`
- `Fitness CoachTests/CoachImagePickFlowQATests.swift`
- `Fitness CoachTests/CoachImagePickFlowRetryTests.swift`
- … *406 more test/support files*

### Docs

- `../SprintReports/ACCOUNT_PERSISTENCE_EXECUTION_MAP.md`
- `../SprintReports/ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`
- `../SprintReports/ACCOUNT_PERSISTENCE_PHASE_READINESS.md`
- `ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`
- `COACH_ACCURACY_TRUST_CONTEXT_PACKET.md`
- `Docs/AccountPersistence/PHASE_2_CLOUD_SCHEMA_AND_RULES.md`
- `Docs/AccountPersistence/PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md`
- `Docs/AccountPersistence/PHASE_4_FRESH_INSTALL_RESTORE.md`
- `Docs/AccountPersistence/PHASE_5_CROSS_DEVICE_REFRESH.md`
- `Docs/AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md`
- `Docs/Architecture.md`
- `Docs/BackendAPI.md`
- `Docs/Coach/COACH_ACCURACY_HARDENING_FINAL_REPORT.md`
- `Docs/Coach/COACH_ACCURACY_HARDENING_IMPLEMENTATION.md`
- `Docs/Coach/COACH_ACCURACY_HARDENING_QA.md`
- `Docs/Coach/COACH_ACCURACY_HARDENING_SPRINT_AUDIT.md`
- `Docs/Coach/COACH_CONTEXT_PACKET_V2.md`
- `Docs/Coach/COACH_FULL_CONTEXT_PACKET.md`
- `Docs/Coach/COACH_KEYBOARD_LAYOUT_IMPLEMENTATION.md`
- `Docs/Coach/COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md`
- `Docs/Coach/COACH_TIMELINE_CONTEXT_V2_QA.md`
- `Docs/Coach/COACH_TIMELINE_V2_ARCHITECTURE.md`
- `Docs/Coach/COACH_TIMELINE_V2_MIGRATION.md`
- `Docs/Coach/COACH_TIMELINE_V2_PRE_IMPLEMENTATION_AUDIT.md`
- `Docs/Coach/COACH_V2_SWIFTDATA_MIGRATION_NOTES.md`
- `Docs/Coach/Fixtures/COACH_INTENT_REGRESSION_FIXTURE.md`
- `Docs/Coach/archive/COACH_FULL_CONTEXT_PACKET_PRE_V2_2026-07-04.md`
- `Docs/CoachNutritionEstimateCards.md`
- `Docs/CursorOnboardingPaceContextPacket.md`
- `Docs/DeadCodeAudit.md`
- `Docs/FormaCalculationSpec.md`
- `Docs/HealthIntelligence/CLEANUP_STATUS.md`
- `Docs/HealthIntelligence/HEALTH_SUMMARY_SYNC_CONTRACT.md`
- `Docs/HealthIntelligence/MASTER_VERIFICATION.md`
- `Docs/HealthIntelligence/PHASE_11_15_UI_INTEGRATION.md`
- `Docs/HealthIntelligence/PHASE_16_20_AUDIT.md`
- `Docs/HealthIntelligence/PHASE_16_20_FINAL_SUMMARY.md`
- `Docs/HealthIntelligence/PHASE_19_QA_TEST_MATRIX.md`
- `Docs/HealthIntelligence/PHASE_1_5_AUDIT.md`
- `Docs/HealthIntelligence/PHASE_1_5_IMPLEMENTATION.md`
- `Docs/HealthIntelligence/PHASE_20_RELEASE_READINESS.md`
- `Docs/HealthIntelligence/PHASE_6_10_ENGINE_AUDIT.md`
- `Docs/HealthIntelligence/PHASE_6_10_IMPLEMENTATION.md`
- `Docs/JourneyArchitecture.md`
- `Docs/PersistenceCleanupNotes.md`
- `Docs/ReleaseAI.md`
- `Docs/TodayMealLogging.md`
- `FORMA_AI_API_SERVER_CONTEXT_PACKET.md`
- `FULL_APP_PRODUCT_LOOP_GAP_CONTEXT_PACKET.md`
- `PRD.md`
- `PRODUCTION_READINESS_MAINTAINABILITY_CONTEXT_PACKET.md`
- `USER_DATA_STORAGE_CONTEXT_PACKET.md`
- `WEEKLY_PROGRESS_LOOP_CONTEXT_PACKET.md`
- `../SprintReports/arch.md`

### Additional modules reviewed


**Fitness Coach/Application/UseCases** (40 files)

- `Fitness Coach/Application/UseCases/Coach/CoachAIRouteHandler.swift`
- `Fitness Coach/Application/UseCases/Coach/CoachActionResult.swift`
- `Fitness Coach/Application/UseCases/Coach/CoachMealImageAIRequestBuilder.swift`
- `Fitness Coach/Application/UseCases/Coach/CoachMealImageUploadAttachment.swift`
- `Fitness Coach/Application/UseCases/Coach/CoachMealPhotoAnalyzer.swift`
- `Fitness Coach/Application/UseCases/Coach/CoachMutationExecutor.swift`
- `Fitness Coach/Application/UseCases/Coach/CoachMutationTimelineContext.swift`
- `Fitness Coach/Application/UseCases/Coach/CoachPendingConfirmationPresenter.swift`
- `Fitness Coach/Application/UseCases/Coach/MealImageAnalysisMapper.swift`
- `Fitness Coach/Application/UseCases/Coach/NutritionEstimateResponseParser.swift`
- `Fitness Coach/Application/UseCases/Coach/NutritionSuggestedActionHandler.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/CheapLLMIntentClassifier.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachInputSafety.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachIntentConfidenceGate.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachIntentPhraseGuard.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachIntentResult.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachIntentRouter.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachMutationHistory.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachRouteDebugLogger.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachRouteDecider.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/ConfirmationPolicy.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/InputNormalizer.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/LocalNoAPIGuard.swift`
- `Fitness Coach/Application/UseCases/Coach/Pipeline/LocalNutritionEstimator.swift`
- `Fitness Coach/Application/UseCases/CoachTimeline/CoachTimelineRecorder.swift`
- `Fitness Coach/Application/UseCases/Commands/CommandIntent.swift`
- `Fitness Coach/Application/UseCases/Commands/CommandKeywordFuzzyMatcher.swift`
- `Fitness Coach/Application/UseCases/Commands/CommandParseResult.swift`
- `Fitness Coach/Application/UseCases/Commands/CommandParserError.swift`
- `Fitness Coach/Application/UseCases/Commands/CommandParserUtilities.swift`
- … *10 more*

**Fitness Coach/Application/Services** (15 files)

- `Fitness Coach/Application/Services/AIService.swift`
- `Fitness Coach/Application/Services/Auth/AuthManager.swift`
- `Fitness Coach/Application/Services/Auth/AuthManagerError.swift`
- `Fitness Coach/Application/Services/Auth/AuthPresenter.swift`
- `Fitness Coach/Application/Services/Auth/AuthSignInSupport.swift`
- `Fitness Coach/Application/Services/Auth/AuthState.swift`
- `Fitness Coach/Application/Services/Auth/InMemoryAccountAuthDeleting.swift`
- `Fitness Coach/Application/Services/CoachTimelineBackfillService.swift`
- `Fitness Coach/Application/Services/CoachTimelineStore.swift`
- `Fitness Coach/Application/Services/DateProvider.swift`
- `Fitness Coach/Application/Services/ProfileCloudUploadFailureNotifier.swift`
- `Fitness Coach/Application/Services/ServiceError.swift`
- `Fitness Coach/Application/Services/SwiftDataCoachChatTranscriptStore.swift`
- `Fitness Coach/Application/Services/TargetService.swift`
- `Fitness Coach/Application/Services/TrainingInsightsStore.swift`

**Fitness Coach/Application/StateBuilders** (81 files)

- `Fitness Coach/Application/StateBuilders/Coach/CoachAIActivityContextResolver.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachAIResponseContextAdapter.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachCompositionPolicy.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextCompactionMetadata.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextCorrectnessValidator.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextFoodMemoryBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2FallbackBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2TimelineCompactionPolicy.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachDailyStatusBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachEntryReferenceResolver.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachHealthContextStatusResolver.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachHealthGuidanceFormatter.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachHealthIntelligenceContextBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachHealthIntelligenceSnapshotLoader.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachNutritionSummaryFormatter.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachResponseBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachTodayContextBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/NutritionEstimateContextBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Coach/NutritionEstimateCopyValidator.swift`
- `Fitness Coach/Application/StateBuilders/Coaching/DailyBriefBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyChapterBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyDashboardBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyGoalProjectionBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyHealthIntelligencePresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyHealthIntelligenceSectionLoader.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyHeroBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyMilestonesBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyMonthlyRecapBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyNextMilestoneBuilder.swift`
- … *51 more*

**Fitness Coach/Domain** (153 files)

- `Fitness Coach/Domain/Analytics/ProgressProjectionCalculator.swift`
- `Fitness Coach/Domain/Analytics/StreakCalculator.swift`
- `Fitness Coach/Domain/Analytics/WeightTrendCalculator.swift`
- `Fitness Coach/Domain/Auth/ProfileSignInCopyPolicy.swift`
- `Fitness Coach/Domain/Auth/ProfileSignInIntent.swift`
- `Fitness Coach/Domain/Coach/CoachAnalyticsLogging.swift`
- `Fitness Coach/Domain/Coach/CoachChatTranscriptRetentionPolicy.swift`
- `Fitness Coach/Domain/Coach/NutritionEstimateModels.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineCompactionPolicy.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineDay.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineEvent.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineEventConfidence.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineEventLink.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineEventPayload.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineEventSource.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineEventStatus.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineEventType.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelinePruningPolicy.swift`
- `Fitness Coach/Domain/CoachTimeline/CoachTimelineQuery.swift`
- `Fitness Coach/Domain/Copy/FormaProductCopy.swift`
- `Fitness Coach/Domain/HealthIntelligence/HealthIntelligenceAnalyticsLogging.swift`
- `Fitness Coach/Domain/HealthIntelligence/HealthIntelligencePipelineAnalytics.swift`
- `Fitness Coach/Domain/HealthIntelligence/HealthIntelligencePresentationTextSanitizer.swift`
- `Fitness Coach/Domain/Journey/JourneyAnalyticsLogging.swift`
- `Fitness Coach/Domain/Legal/FormaLegalCopy.swift`
- `Fitness Coach/Domain/Models/CalculationResultModels.swift`
- `Fitness Coach/Domain/Models/ChatMessage.swift`
- `Fitness Coach/Domain/Models/ChatMessageImageAttachment.swift`
- `Fitness Coach/Domain/Models/DailyLog.swift`
- `Fitness Coach/Domain/Models/DailyReview.swift`
- … *123 more*

**Fitness Coach/Infrastructure/AI** (26 files)

- `Fitness Coach/Infrastructure/AI/AICoachResponse.swift`
- `Fitness Coach/Infrastructure/AI/AICommandAction.swift`
- `Fitness Coach/Infrastructure/AI/AICommandParser.swift`
- `Fitness Coach/Infrastructure/AI/AIConfidence.swift`
- `Fitness Coach/Infrastructure/AI/AIContext.swift`
- `Fitness Coach/Infrastructure/AI/AIContracts.swift`
- `Fitness Coach/Infrastructure/AI/AIGatewayPayloadLimits.swift`
- `Fitness Coach/Infrastructure/AI/AIParsedCommand.swift`
- `Fitness Coach/Infrastructure/AI/AIPromptBuilder.swift`
- `Fitness Coach/Infrastructure/AI/AIResponseValidator.swift`
- `Fitness Coach/Infrastructure/AI/AIServiceError.swift`
- `Fitness Coach/Infrastructure/AI/AIUsageMetadata.swift`
- `Fitness Coach/Infrastructure/AI/CoachAIRequestContextLogging.swift`
- `Fitness Coach/Infrastructure/AI/CoachContextPacketV2+Review.swift`
- `Fitness Coach/Infrastructure/AI/CoachContextPacketV2.swift`
- `Fitness Coach/Infrastructure/AI/FallbackLLMClient.swift`
- `Fitness Coach/Infrastructure/AI/FoodCompoundDishDetector.swift`
- `Fitness Coach/Infrastructure/AI/FoodEstimateResponseValidator.swift`
- `Fitness Coach/Infrastructure/AI/FoodListedIngredientCounter.swift`
- `Fitness Coach/Infrastructure/AI/FormaAIBackendClient.swift`
- `Fitness Coach/Infrastructure/AI/LLMClient.swift`
- `Fitness Coach/Infrastructure/AI/LLMClientError.swift`
- `Fitness Coach/Infrastructure/AI/LLMEndpoint.swift`
- `Fitness Coach/Infrastructure/AI/MealImageAnalysisResponseValidator.swift`
- `Fitness Coach/Infrastructure/AI/MockLLMClient.swift`
- `Fitness Coach/Infrastructure/AI/UnavailableLLMClient.swift`

**Fitness Coach/Infrastructure/Health** (17 files)

- `Fitness Coach/Infrastructure/Health/HealthAppSettingsNavigator.swift`
- `Fitness Coach/Infrastructure/Health/HealthKitStepReading.swift`
- `Fitness Coach/Infrastructure/Health/HealthKitTrainingAuthorizing.swift`
- `Fitness Coach/Infrastructure/Health/HealthKitWorkoutReading.swift`
- `Fitness Coach/Infrastructure/Health/HealthTrainingAuthorizationStatus.swift`
- `Fitness Coach/Infrastructure/Health/HealthTrainingDebugLogger.swift`
- `Fitness Coach/Infrastructure/Health/HealthTrainingReaderFactory.swift`
- `Fitness Coach/Infrastructure/Health/HealthTrainingService.swift`
- `Fitness Coach/Infrastructure/Health/HealthWorkoutActivityFormatter.swift`
- `Fitness Coach/Infrastructure/Health/MockHealthKitStepReader.swift`
- `Fitness Coach/Infrastructure/Health/MockHealthKitTrainingAuthorizing.swift`
- `Fitness Coach/Infrastructure/Health/MockHealthKitWorkoutReader.swift`
- `Fitness Coach/Infrastructure/Health/SystemHealthKitStepReader.swift`
- `Fitness Coach/Infrastructure/Health/SystemHealthKitTrainingAuthorization.swift`
- `Fitness Coach/Infrastructure/Health/SystemHealthKitWorkoutReader.swift`
- `Fitness Coach/Infrastructure/Health/TrainingIntegrationProviding.swift`
- `Fitness Coach/Infrastructure/Health/UnavailableHealthKitTrainingAuthorization.swift`

**Fitness Coach/Features/TrainingInsights** (9 files)

- `Fitness Coach/Features/TrainingInsights/Components/TrainingInsightsConnectedHeader.swift`
- `Fitness Coach/Features/TrainingInsights/Components/TrainingInsightsConnectedView.swift`
- `Fitness Coach/Features/TrainingInsights/Components/TrainingInsightsEmptyConnectedView.swift`
- `Fitness Coach/Features/TrainingInsights/Components/TrainingInsightsGateView.swift`
- `Fitness Coach/Features/TrainingInsights/Components/TrainingLayout.swift`
- `Fitness Coach/Features/TrainingInsights/Formatting/TrainingInsightsFormatter.swift`
- `Fitness Coach/Features/TrainingInsights/Formatting/TrainingInsightsPreviewData.swift`
- `Fitness Coach/Features/TrainingInsights/Model/TrainingInsightsModel.swift`
- `Fitness Coach/Features/TrainingInsights/TrainingInsightsView.swift`

**Fitness Coach/TestingSupport** (1 files)

- `Fitness Coach/TestingSupport/StubTrainingIntegrationProvider.swift`
