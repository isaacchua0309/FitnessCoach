# Code Depth, Anti-Patterns, Dead Code, and Bloat Context Packet

**Repository:** FitnessCoach (`Fitness Coach/` iOS + `functions/` Firebase)  
**Generated:** 2026-07-05  
**Git HEAD audited:** `364a383d` (`Add Correction Memory v1 for Coach food estimates`)  
**Method:** Read-only static audit — docs, `rg`, `git ls-files`, Python line counts, `npm run build|lint|test`. No source changes.  
**Claim tags:** **Confirmed** (direct evidence), **Likely** (inferred), **Unknown** (not verifiable here).

**Primary docs read:**
- `PRD.md`, `../SprintReports/arch.md`, `../SprintReports/PRDX_V1_IMPLEMENTATION_MAP.md`
- `USER_DATA_STORAGE_CONTEXT_PACKET.md`, `../SprintReports/ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`, `../SprintReports/ACCOUNT_PERSISTENCE_EXECUTION_MAP.md`, `../SprintReports/ACCOUNT_PERSISTENCE_PHASE_READINESS.md`, `ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`
- `FULL_APP_PRODUCT_LOOP_GAP_CONTEXT_PACKET.md`, `WEEKLY_PROGRESS_LOOP_CONTEXT_PACKET.md`, `COACH_ACCURACY_TRUST_CONTEXT_PACKET.md`, `PRODUCTION_READINESS_MAINTAINABILITY_CONTEXT_PACKET.md`
- `Docs/Architecture/*` (incl. `SourceOfTruthMap.md`, `FeatureFlagRegistry.md`, `DependencyInjectionMap.md`, `AppArchitectureOverview.md`, `TestStrategy.md`)
- `Docs/DeadCodeAudit.md`, `Docs/TechnicalDebt/TechnicalDebtRegister.md`, `Docs/PersistenceCleanupNotes.md`
- `Docs/Coach/*`, `Docs/HealthIntelligence/*`, `Docs/AccountPersistence/*`, `Docs/Production/*`, `Docs/Backend/*`

---

## 1. Executive Summary

### Current state (evidence-backed)

| Dimension | Assessment | Evidence |
|-----------|------------|----------|
| Codebase size | **Large** for a single-team iOS app | **Confirmed:** 1,993 tracked files; 1,711 `*.swift`; 541 test Swift files (~116,615 LOC in `Fitness CoachTests/`); `functions/src/index.ts` 1,073 LOC |
| Architecture complexity | **High but documented** | **Confirmed:** `AppContainer` split across 3 files (1,632 LOC total); 87 `StateBuilders` files; 10 analytics protocols + 21 NoOp + 12 OSLog loggers; account persistence + HI + Coach v2 stacks |
| Maintainability strength | **Moderate** | **Confirmed:** `Docs/Architecture/SourceOfTruthMap.md`, `FeatureFlagRegistry.md`, `TechnicalDebtRegister.md`, `DeadCodeAudit.md` exist; DI refactored into `AppContainer+Construction.swift` / `+FeatureFactories.swift` |
| Developer experience risk | **Moderate–High** | **Likely:** 1,631-line `CoachModel.swift`, 1,415-line `CoachContextPacketV2Builder.swift`, triplicated HI presentation builders (~971 LOC each), 116k test LOC |
| Build-time risk | **High (unmeasured)** | **Unknown:** `xcodebuild` unavailable (Command Line Tools only). **Likely:** 4,408-line `FormaProductCopy.swift`, 330 `@MainActor` annotations, heavy SwiftUI `#Preview` surface |
| Dead-code risk | **Moderate** | **Confirmed:** prior `DeadCodeAudit.md` (2026-06-28); deprecated `AIContext`; 5 migration-only SwiftData entities; FitPilot header strings remain |
| Duplication risk | **High** | **Confirmed:** `TodayHealthIntelligencePresentationBuilder`, `PlanHealthIntelligencePresentationBuilder`, `JourneyHealthIntelligencePresentationBuilder` (~971–1,316 LOC each); TD-HI-001/002 in register |
| Test friction risk | **Moderate–High** | **Confirmed:** 541 test files; async `Task.sleep` in account deletion/sync tests; backend 13 failing tests (snapshots) on current HEAD |

### Biggest cleanup opportunities (highest ROI)

1. **State builder / HI presentation consolidation** — TD-HI-002; three near-duplicate ~1k LOC builders (**Confirmed** `TechnicalDebtRegister.md` TD-HI-002).
2. **God-model splits** — `CoachModel.swift` (1,631 LOC), `AuthGateCoordinator.swift` (1,331 LOC) (**Confirmed** line counts).
3. **Copy monolith decomposition** — `FormaProductCopy.swift` (4,408 LOC) (**Confirmed** TD-COPY-001).
4. **Backend route modularization** — `functions/src/index.ts` (1,073 LOC) (**Confirmed** TD-BACKEND-001).
5. **Feature-flag production wiring** — runtime uses `allEnabled` while `production` snapshot differs (**Confirmed** `FeatureFlagRegistry.md` § Runtime vs production intent).
6. **Test fixture consolidation** — 116k test LOC, large integration suites (**Confirmed**).

### Safest cleanup opportunities

1. Remove deprecated `AIContext` after test migration (**Confirmed** TD-AI-001, zero production Coach path).
2. Archive stale root context packets superseded by `Docs/Architecture/*` (**Likely**).
3. Consolidate NoOp analytics construction in `AppContainer+Construction.buildAnalytics` (**Confirmed** 8 domain loggers × NoOp + OSLog pairs).
4. Backend snapshot test refresh or isolate prompt snapshot suite (**Confirmed** 7 snapshot failures in `coachPromptSnapshots.test.ts`).
5. Preview-data files kept out of hot compile paths where possible (**Likely** — `JourneyPreviewData.swift` 1,447 LOC).

### Riskiest cleanup opportunities

1. SwiftData migration-only entities (`ChatMessageEntity`, `WeeklyReviewEntity`, etc.) (**Confirmed** `SourceOfTruthMap.md` § migration-only).
2. Account persistence sync/restore coordinators (`AccountDeletionCoordinator` 920 LOC, `AccountRestoreCoordinator` 744 LOC).
3. `FormaAbTest` production snapshot wiring (behavior change) (**Confirmed** contradiction documented).
4. `CoachContextPacketV2Builder` compaction/limits (AI contract) (**Confirmed** 1,415 LOC, functions mirror in `coachContextPacketV2.ts` 788 LOC).
5. Nutrition/plan calculation paths (`NutritionSanityValidator` 894 LOC, `MaintenanceEstimateCalculator` 655 LOC).

### Highest-ROI cleanup sprint recommendation

**Sprint title:** Developer Experience Refactor v1 — State Builder + DI Consolidation  
**Focus:** Extract shared Health Intelligence presentation module, reduce `CoachModel`/`AuthGateCoordinator` surface area, consolidate test fixtures — **no product behavior changes**.

### Verdict

**Current maintainability / developer-readiness: Moderate**

**Why:** Strong documentation, explicit technical-debt register, and recent DI refactor offset very large models/builders, triplicated HI logic, and heavy test surface. Not **Weak** because architecture boundaries and SSOT maps exist. Not **Strong** because file-size hotspots, flag contradictions, and unmeasured iOS build times block confident velocity.

### Recommended next cleanup sprint (pick one)

| # | Sprint | Rationale |
|---|--------|-----------|
| **1** | Dead Code + Bloat Reduction | Safe wins: `AIContext`, preview orphans, doc archive |
| **2** | **AppContainer / DI Cleanup** | **Recommended first** — recent refactor incomplete; analytics/HI wiring still dense |
| 3 | Feature Flag Cleanup | Production snapshot not wired; debug flags on in runtime |
| **4** | **State Builder Simplification** | **Highest code-volume ROI** — 87 builders, HI triplication |
| 5 | Test Infrastructure Cleanup | 116k LOC; sleep-based async tests |
| 6 | Build-Time Optimization | Blocked on Xcode timing data |
| 7 | Logging / Analytics Cleanup | 33 analytics impl files; intentional but verbose |
| 8 | Backend Modularization | `index.ts` monolith; tests mostly green |
| 9 | SwiftData Entity Cleanup | Migration-sensitive; document-only sprint safer |
| 10 | Docs archive + SSOT refresh | Low risk, high clarity |

**Primary recommendation:** **#4 State Builder Simplification** with **#2 AppContainer/DI** as parallel track — evidence: TD-HI-002, 87 builder files, 1,632 LOC AppContainer cluster.

---

## 2. Codebase Size and Complexity Metrics

| Metric | Value | Method / Command | Notes |
|--------|-------|------------------|-------|
| Total tracked files | 1,993 | `git ls-files \| wc -l` | **Confirmed** |
| Total tracked Swift files | 1,711 | `git ls-files "*.swift" \| wc -l` | Includes tests + app |
| Swift files (workspace find) | 2,826 | `find . -name "*.swift"` | **Likely** includes `.agents/` skill scripts; use git count as SSOT |
| TypeScript files | 57 | `find . -name "*.ts" -not -path "*/node_modules/*"` | **Confirmed** |
| Test Swift files | 541 | `git ls-files Fitness CoachTests/*.swift` | **Confirmed** |
| Test Swift LOC | ~116,615 | Python `wc` over `Fitness CoachTests/` | **Confirmed** |
| Docs (`Docs/**/*.md`) | 62 | `git ls-files` | **Confirmed** |
| Root markdown packets | 13 | `git ls-files *.md` at repo root | **Confirmed** |
| `StateBuilders` Swift files | 87 | `git ls-files` path filter | **Confirmed** |
| `*Model.swift` files | 11 | filename scan | **Confirmed** |
| `*Coordinator.swift` files | 17 | filename scan | **Confirmed** |
| `*PresentationBuilder*.swift` | 32 | filename scan | **Confirmed** |
| Largest Swift file | 4,408 lines | `FormaProductCopy.swift` | **Confirmed** |
| Largest test file | 1,111 lines | `HealthIntelligenceUIStateTests.swift` | **Confirmed** |
| Largest TS file | 1,119 lines | `functions/test/fixtures/foodLoggingGoldenCases.ts` | Fixture data |
| `TODO` in `Fitness Coach/` Swift | 0 | `rg '\bTODO\b' --glob '*.swift'` | **Confirmed** — debt tracked via `TD-*` ids instead |
| `FIXME` / `HACK` in Swift app | 0 | `rg` | **Confirmed** |
| `fatalError(` | 4 matches, 3 files | `rg 'fatalError\(' Fitness Coach` | **Confirmed** |
| `try!` | 21 matches, 14 files | `rg 'try!' Fitness Coach` | **Confirmed** |
| `as!` | 0 | `rg 'as!' Fitness Coach` | **Confirmed** |
| `@MainActor` | 330 matches, 135 files | `rg '@MainActor' Fitness Coach` | **Confirmed** |
| `Task {` | 140 matches, 54 files | `rg 'Task \{' Fitness Coach` | **Confirmed** |
| `UserDefaults` refs | 71 matches, 25 files | `rg 'UserDefaults' Fitness Coach` | **Confirmed** |
| Analytics `*Logging` protocols | 10 | `rg 'protocol.*AnalyticsLogging'` | **Confirmed** |
| NoOp logger files | 21 | `rg -l 'NoOp.*Logger\|NoOp.*Analytics'` | **Confirmed** |
| OSLog analytics files | 12 | `rg -l 'OSLog.*Analytics'` | **Confirmed** |
| SwiftData `@Model` entity files | 14 | `rg '@Model' --glob '*.swift'` | **Confirmed** |
| Active schema entities | 9 | `SourceOfTruthMap.md` § FormaSchemaV9 | **Confirmed** |
| Migration-only entities | 5 | `ChatMessageEntity`, `WeeklyReviewEntity`, `WorkoutEntryEntity`, `ExerciseSetEntity`, `DebugRecordEntity` | **Confirmed** |
| Backend HTTPS exports | 2 | `aiGateway`, `accountDataDeletion` | **Confirmed** `BackendRouteMap.md` |
| AI gateway routes | 11 POST paths | `Docs/Backend/BackendRouteMap.md` | **Confirmed** |
| `#Preview` blocks (app target) | 200+ occurrences | `rg '#Preview' Fitness Coach` | **Confirmed** — compile-time cost **Unknown** |
| iOS build time | N/A | `xcodebuild -list` | **Failed:** `xcode-select` → Command Line Tools only |
| Backend `npm run build` | Success | `tsc` ~sub-second | **Confirmed** |
| Backend `npm run lint` | Success | `eslint` | **Confirmed** |
| Backend `npm test` | 666 pass, 13 fail, 2 skip / 3.58s | `npm test` (default ignores firestore-rules) | **Confirmed** — snapshot drift in `coachPromptSnapshots.test.ts` |

### Largest folders by file count (`Fitness Coach/`)

| Files | Path |
|-------|------|
| 90 | `Fitness Coach/Features/Onboarding` |
| 87 | `Fitness Coach/Application/StateBuilders` |
| 83 | `Fitness Coach/Features/Settings` |
| 75 | `Fitness Coach/Features/Coach` |
| 74 | `Fitness Coach/Features/Plan` |
| 69 | `Fitness Coach/Features/Today` |
| 57 | `Fitness Coach/Features/Journey` |

---

## 3. Largest Files and Code Depth Hotspots

### Top 30 Swift files (production + shared)

| Rank | File | Lines | Domain | Why Large | Risk | Suggested Action |
|------|------|-------|--------|-----------|------|------------------|
| 1 | `Domain/Copy/FormaProductCopy.swift` | 4,408 | Copy SSOT | All user-facing strings in one enum | Medium compile | Split by domain (TD-COPY-001) |
| 2 | `Features/Coach/Model/CoachModel.swift` | 1,631 | Coach VM | Routing, photo pipeline, mutations, analytics | High churn | Extract coordinators (TD-COACH-001) |
| 3 | `Features/Journey/Model/JourneyPreviewData.swift` | 1,447 | Preview | Canvas/preview fixtures | Low runtime | Move to preview-only module **Likely** |
| 4 | `Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` | 1,415 | AI context | Multi-domain packet assembly | High | Split sub-builders; keep contract tests |
| 5 | `Features/Auth/Coordinator/AuthGateCoordinator.swift` | 1,331 | Auth | Restore, bootstrap, routing | High | Split by lifecycle phase |
| 6 | `Application/StateBuilders/Journey/JourneyHealthIntelligencePresentationBuilder.swift` | 1,316 | HI UI state | Tab-specific HI cards | Medium | Shared HI module (TD-HI-002) |
| 7 | `Health/Repository/HealthDataRepository.swift` | 1,163 | Health | Cache + HK routing | Medium | Stable; document |
| 8 | `Application/StateBuilders/Coach/CoachContextCorrectnessValidator.swift` | 1,147 | AI QA | Outbound packet validation | Medium | Keep; test-heavy |
| 9 | `Application/UseCases/CoachTimeline/CoachTimelineRecorder.swift` | 1,090 | Coach | Event recording + backfill hooks | Medium | Review dead branches |
| 10 | `Application/Restore/AccountInitialRestoreService.swift` | 1,075 | Account | Cloud pull + mapping | High | Do not split without E2E |
| 11 | `Application/StateBuilders/Journey/UnifiedWeeklyReviewPresentationBuilder.swift` | 1,010 | Journey/HI | Weekly review UX | Medium | Consolidate with `WeeklyReviewPresentationBuilder` |
| 12 | `Application/StateBuilders/Today/TodayHealthIntelligencePresentationBuilder.swift` | 971 | HI UI | Duplicate of Plan/Journey | High duplication | Extract shared core |
| 13 | `Application/StateBuilders/Plan/PlanHealthIntelligencePresentationBuilder.swift` | 971 | HI UI | Duplicate | High duplication | Extract shared core |
| 14 | `Domain/Nutrition/NutritionSanityValidator.swift` | 894 | Coach/nutrition | Business rules | Medium | Keep; golden tests |
| 15 | `Infrastructure/AI/CoachContextPacketV2.swift` | 865 | AI contract | Codable + limits | Medium | Keep synchronized with TS |
| 16 | `Health/Cache/LocalHealthCacheStore.swift` | 837 | Health | JSON cache per UID | Medium | Stable |
| 17 | `App/AppContainer+Construction.swift` | 834 | DI | Domain construction bundles | Medium | Further factory extraction |
| 18 | `Application/Sync/AccountSyncPuller.swift` | 825 | Sync | Pull + merge | High | Test before refactor |
| 19 | `Application/UseCases/Coach/CoachAIRouteHandler.swift` | 805 | Coach AI | Intent routing + presentation | High | Already partial extract |
| 20 | `Features/Plan/Model/PlanModel.swift` | 791 | Plan VM | Dashboard + edit flows | Medium | Monitor |
| 21 | `Features/Plan/UI/PlanEditWizard.swift` | 768 | Plan UI | Multi-step wizard | Medium | UI split acceptable |
| 22 | `Application/Restore/AccountRestoreCoordinator.swift` | 744 | Account | Blocking restore UX | High | Do not touch lightly |
| 23 | `Application/StateBuilders/WeeklyProgress/WeeklyProgressSummaryBuilder.swift` | 739 | Weekly progress | New domain | Medium | Young; keep cohesive |
| 24 | `Application/StateBuilders/Journey/JourneyNextMilestoneBuilder.swift` | 714 | Journey | Milestone logic | Low | Keep |
| 25 | `Features/Onboarding/Model/OnboardingModel.swift` | 695 | Onboarding | Wizard state machine | Medium | Stable |
| 26 | `Infrastructure/AI/AIContracts.swift` | 687 | AI DTOs | Shared request/response types | Medium | Keep |
| 27 | `Application/StateBuilders/Plan/PlanProjectionBuilder.swift` | 682 | Plan math | Projections | Medium | SSOT with `FormaCalculationSpec` |
| 28 | `Application/Sync/CrossDeviceSyncCoordinator.swift` | 660 | Sync | Realtime + refresh | High | E2E coverage exists |
| 29 | `Domain/WeeklyProgress/MaintenanceEstimateCalculator.swift` | 655 | Weekly progress | Calorie math | Medium | Unit test |
| 30 | `Health/Intelligence/WeeklyReviewEngine.swift` | 612 | HI engine | Review generation | Medium | Flag-gated |

### Top TypeScript files

| Rank | File | Lines | Classification | Action |
|------|------|-------|----------------|--------|
| 1 | `test/fixtures/foodLoggingGoldenCases.ts` | 1,119 | Generated/static data | Keep; exclude from hot path |
| 2 | `src/index.ts` | 1,073 | Backend router | Split routes (TD-BACKEND-001) |
| 3 | `src/coachContextPacketV2.ts` | 788 | AI context rules | Keep; sync with iOS |
| 4 | `src/foodEstimateExtraction.ts` | 678 | Food parsing | Keep |
| 5 | `src/mealImageAnalysis.ts` | 643 | Vision pipeline | Keep |
| 6 | `test/fixtures/coachAccuracyBenchmarkSupport.ts` | 569 | Test support | Keep |
| 7 | `test/aiGateway.contract.test.ts` | 534 | Contract tests | Keep |

### Classifications summary

- **Should split:** `CoachModel`, `AuthGateCoordinator`, HI presentation trio, `FormaProductCopy`, `functions/src/index.ts`
- **Should leave alone:** `NutritionSanityValidator`, `AccountDeletionCoordinator`, `CoachContextPacketV2` contract files, migration plan
- **Acceptable large:** `PlanEditWizard` (UI wizard), golden fixture TS files
- **Preview bloat:** `JourneyPreviewData.swift` (1,447 LOC) — not production path **Confirmed** filename

---

## 4. Churn Hotspots

**Source:** `git log --since="90 days ago" --name-only` (commit count per file)

| File | Changes (90d) | Domain | Why Churns | Risk | Refactor Opportunity |
|------|---------------|--------|------------|------|----------------------|
| `Domain/Copy/FormaProductCopy.swift` | 129 | Copy | Product copy edits across features | Low | Split file to reduce merge conflicts |
| `App/AppContainer.swift` | 72 | DI | Central wiring | High | Continue bundle extraction **Confirmed** recent `+Construction` |
| `Features/Coach/Model/CoachModel.swift` | 64 | Coach | Feature velocity | High | Split before more Coach work |
| `App/MainTabView.swift` | 35 | Shell | Tab/analytics wiring | Medium | Stable after PRDX |
| `Features/Coach/CoachView.swift` | 31 | Coach UI | Layout/attachments | Medium | — |
| `Application/UseCases/Coach/CoachAIRouteHandler.swift` | 26 | Coach AI | Trust/hardening | High | Keep focused |
| `functions/src/index.ts` | 27 | Backend | New routes | Medium | Modularize |
| `Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` | 15+ | AI context | Context v2 expansion | High | Sub-builder extraction |
| `Fitness Coach.xcodeproj/project.pbxproj` | 19 | Build | File adds | Low | Folder sync reduces edits **Likely** |

**High-churn + high-complexity (refactor before features):** `CoachModel`, `CoachContextPacketV2Builder`, `AuthGateCoordinator`, `AppContainer+Construction`

**Do not touch without full regression:** `AccountDeletionCoordinator`, `AccountRestoreCoordinator`, `FormaMigrationPlan`, `NutritionSanityValidator`

---

## 5. Dead Code and Unused Surface Audit

| Priority | File / Symbol | Evidence | Risk if Removed | Suggested Action |
|----------|---------------|----------|-----------------|------------------|
| P1 | `AIContext` struct | `@available(*, deprecated)` + TD-AI-001; Coach uses `CoachContextPacketV2` | Low in prod; tests may break | Migrate test doubles; delete |
| P1 | Migration-only entities | `SourceOfTruthMap.md` lists 5 not in V9 schema | **High** — lightweight migration | **Keep**; document only |
| P2 | `Infrastructure/AI/AIContext.swift` helpers | `CoachContextV2ContractTests` references **Likely** | Test breakage | Verify `rg AIContext` before delete |
| P2 | `NoOpCloudUserProfileStore` | Used when cloud off **Confirmed** `AppContainer` wiring | Medium | Keep — intentional stub |
| P2 | `MockLLMClient` | DEBUG/in-memory builds **Confirmed** `AppContainer+Construction.buildAI` | Low | Keep |
| P2 | Duplicate preview screens | `*PreviewScreens.swift`, `*PreviewData.swift` | Low runtime | Consolidate fixtures |
| P3 | FitPilot header strings | 200+ files still say `FitPilot AI` in file headers | None functional | Rename comments in cosmetic sprint |
| P3 | `TrainingInsightsView` | Mounted from Settings/HI gate **Confirmed** exists | Low | Not dead — verify product intent |
| P3 | `DebugRecordEntity` | Migration-only | High | Keep |
| P2 | `pullRecentDataEnabled = false` | `AccountPersistenceFeatureFlags` — flag exists, off | Medium if removed | Rollout-hold, not dead |
| P2 | `JourneyPreviewData` (1,447 LOC) | `#Preview` / dev only **Likely** | Low | Isolate from release compile **Unknown** target membership |

**Categories:**
- **Unused Swift types:** No strong `rg` zero-ref types found without deeper per-symbol analysis — **Unknown** at scale; `DeadCodeAudit.md` Stage 3 marked several **done**.
- **Migration-sensitive:** All V1–V3 entities per `Docs/PersistenceCleanupNotes.md`.
- **Feature flags:** None confirmed zero-reference; `FeatureFlagRegistry.md` catalogs all.

---

## 6. TODO / FIXME / Stub Audit

**Swift production `TODO`/`FIXME`/`HACK`:** **Confirmed 0 matches** in `Fitness Coach/` (`rg`).

Debt is tracked via **`TD-*` register comments** instead:

| Priority | File | Symbol / Line | Marker | Meaning | Production Risk | Action |
|----------|------|---------------|--------|---------|-----------------|--------|
| P0 | `Domain/Legal/FormaLegalCopy.swift` | `FormaLegalURLs` | TD-LEGAL-001/002 | Hosted legal URLs nil | **App Store blocker** | Publish URLs before release |
| P0 | `Features/Settings/Model/SettingsSupportConfiguration.swift` | support email | TD-SETTINGS-001 | Ops confirmation | Medium | Confirm inbox |
| P1 | `Features/Settings/Model/SettingsDeleteDataActionHandler.swift` | export row | TD-SETTINGS-002 | Export UI not wired | Medium | Implement export sprint |
| P1 | `Infrastructure/AI/AIContext.swift` | `AIContext` | TD-AI-001 | Legacy Codable | Low in prod | Test migration |
| P2 | `DesignSystem/Theme/ThemeAccessibilityAdaptationPolicy.swift` | contrast/transparency | TD-THEME-001/002 | A11y stubs | Medium a11y | Implement palettes |
| P2 | `Data/Repositories/WeightLogService.swift` | delete API | TD-DATA-001 (register) | No local delete | Medium sync | Account persistence phase |

**Backend:** No `TODO` in `functions/src/`; legacy *compatibility* paths documented in tests (`gatewayGuardrails.test.ts` legacy `text` field).

**Stub patterns (intentional):**
- `NoOp*AnalyticsLogger` — DI default for tests/previews **Confirmed**
- `UnavailableLLMClient` — missing backend URL **Confirmed**
- `InMemoryAccountAuthDeleting` — test double **Confirmed**

---

## 7. Architecture Anti-Patterns Audit

| Anti-Pattern | Location | Evidence | Impact | Severity | Recommended Fix |
|--------------|----------|----------|--------|----------|-----------------|
| God ViewModel | `CoachModel.swift` (1,631 LOC) | Line count; TD-COACH-001 | Hard to test/change | High | Extract `CoachMealPhotoPipeline`, mutation executor wiring |
| God coordinator | `AuthGateCoordinator.swift` (1,331 LOC) | Line count | Auth/restore conflicts | High | Split bootstrap vs gate routing |
| AppContainer size | 1,632 LOC across 3 files | `AppContainer.swift` + extensions | Cognitive load | Medium | **Improved** vs monolith; continue bundles |
| Builder god-object | `CoachContextPacketV2Builder` (1,415 LOC) | Line count | AI contract risk | High | Extract food/timeline/HI sub-builders |
| Triplicated HI builders | Today/Plan/Journey `*HealthIntelligencePresentationBuilder` | ~971–1,316 LOC each; TD-HI-002 | 3× maintenance | High | Shared `HealthIntelligencePresentationCore` |
| Feature flags scattered | 135+ files reference flags | `rg FormaAbTest\|FeatureFlags` | Inconsistent gating | Medium | Centralize per-domain policy objects |
| Runtime vs production flags | `FormaAbTestSnapshot.allEnabled` default | `FeatureFlagRegistry.md` | Ship risk | **High** | Wire `production` snapshot for Release |
| Legacy typealiases | `TodayDashboardState` `legacyWorkoutSummary` | `TodayDashboardState.swift` ~L232 | Confusion | Low | Document or remove after HK routing stable |
| Deprecated transport | `AIContext` | `AIContext.swift` | Test debt | Low | Delete post-migration |
| Monolithic backend router | `functions/src/index.ts` | 1,073 LOC; TD-BACKEND-001 | Review friction | Medium | `routes/aiGateway.ts` per path |
| Direct UserDefaults | 25 files | `rg UserDefaults` | Scoping risk | Medium | Audit keys against `SourceOfTruthMap.md` |
| Protocol explosion (analytics) | 10 protocols × 2 impls | `Infrastructure/Diagnostics/` | Boilerplate | Low | Factory + single OSLog backend |
| Silent fallbacks | `CoachContextPacketV2FallbackBuilder` | Used on build failure | AI quality | Medium | Metrics on fallback rate |
| `@MainActor` breadth | 135 files | 330 annotations | Swift 6 friction | Medium | Isolate non-UI services |
| Dual coach memory | Transcript entity + `CoachModel.messages` | `SourceOfTruthMap.md` § Coach chat | Sync complexity | Medium | Document SSOT; already noted |
| Missing weight delete | `WeightLogService` | TD-DATA-001 | Data integrity | Medium | Implement delete API |

**Not observed (good):**
- Widespread `as!` — **Confirmed 0**
- Singleton `static let shared` — **Confirmed 1** (`AIPromptBuilder` only)

---

## 8. Duplicated Logic and Reusability Audit

| Duplicated Concept | Locations | Current Difference | Risk | Reusable Abstraction Candidate |
|-------------------|-----------|--------------------|------|--------------------------------|
| HI presentation cards | `TodayHealthIntelligencePresentationBuilder`, `PlanHealthIntelligencePresentationBuilder`, `JourneyHealthIntelligencePresentationBuilder` | Tab-specific section ordering | High drift | `HealthIntelligenceCardCatalog` + tab policy |
| HI section loaders | `PlanHealthIntelligenceSectionLoader`, `JourneyHealthIntelligenceSectionLoader`, Today inline | Loading gates | Medium | `HealthIntelligenceSectionLoader` protocol impl |
| Weekly review presentation | `UnifiedWeeklyReviewPresentationBuilder`, `WeeklyReviewPresentationBuilder`, `JourneyWeeklyReviewBuilder` | Journey habits vs HI review | Medium | TD-HI-001 |
| Date window (7d) | Journey weekly, Weekly progress, HI review | Slightly different anchors | Medium | `RollingWindowCalculator` (domain) |
| Confidence badges | Coach, Plan, Journey cards | Copy differs | Low | `ConfidenceBadgePresentation` |
| Empty/loading states | `*EmptyStateView` across tabs | Visual variants | Low | Design system components exist |
| Analytics bucketing | Per-domain `*AnalyticsContextBuilder` | Event-specific | Medium | Shared `AnalyticsBucket` helpers |
| Feature flag checks | Direct `FormaAbTest` / `HealthIntelligenceFeatureFlags` | Nested guards | Medium | Policy structs per screen |
| SwiftData ownerUID predicates | Multiple repositories | Repeated filter | Medium | `OwnerScopedFetch` helper |
| Firestore DTO mapping | `CloudAccountDataMappers.swift` (618 LOC) | Centralized **Confirmed** | Low | Already SSOT |
| Coach response parsing | `CoachAIRouteHandler`, `CoachMutationExecutor`, `CoachMealPhotoAnalyzer` | Overlap | Medium | Shared `CoachActionResultPresenter` |
| Test profile fixtures | `ProfileTestFixtures`, `TodayDashboardFixtures`, onboarding tests | Overlap | High test cost | `TestFixtures` module |
| Preview fixtures | `JourneyPreviewData`, `TodayPreviewData`, `CoachPreviewData` | Large static data | Compile time | Preview-only target **Unknown** |

---

## 9. AppContainer and Dependency Injection Depth Audit

**Total LOC:** `AppContainer.swift` 453 + `AppContainer+Construction.swift` 834 + `AppContainer+FeatureFactories.swift` 345 = **1,632** (**Confirmed**)

| Dependency Area | Constructed Where | Consumers | Testability | Complexity Risk | Refactor Candidate |
|-----------------|-------------------|-----------|-------------|-----------------|-------------------|
| Session/auth | `buildSession` | App shell, onboarding | Good — injectable defaults | Medium | Keep bundle |
| Persistence/sync | `buildPersistence` | All log services | `AppContainerConstructionTests` | High | Keep |
| Health + HI | `buildHealth`, `buildHealthIntelligence` | Today/Journey/Plan/Coach | Flag overrides in tests | High | Document graph |
| Coach platform | `buildCoachPlatform` | Coach, context builder | In-memory stores | Medium | Added `foodCorrectionMemoryStore` at `364a383d` |
| Account lifecycle | `buildAccountLifecycle` | Auth, Settings | E2E tests | **High** | No change |
| Analytics (8 domains) | `buildAnalytics` | All tabs | `CapturingAnalyticsLoggers` | Medium | Single factory map |
| AI / LLM | `buildAI` | Coach, reviews | `MockLLMClient` | Medium | Keep |
| Feature models | `AppContainer+FeatureFactories` | Views via `MainTabView` | Partial | Medium | Extract `CoachDependencies` struct |

### Answers

| Question | Answer | Tag |
|----------|--------|-----|
| Is AppContainer too large? | **Moderate** — split helps; construction file still 834 LOC | Confirmed |
| Child containers? | Bundles exist (`SessionBundle`, `PersistenceBundle`, …) | Confirmed |
| Dependencies created repeatedly? | Feature factories create new `CoachContextPacketV2Builder` per `makeCoachModel()` | Confirmed |
| Services in views? | **Rare** — models receive deps via factories | Likely |
| Fakes injectable? | `FormaAbTest.testOverride`, `HealthIntelligenceFeatureFlags.testOverride`, in-memory `AppContainer(inMemory:)` | Confirmed |
| Previews use production services? | Previews use fixture data; some use `StubTrainingIntegrationProvider` | Likely |
| Hidden singletons? | Essentially none (`AIPromptBuilder.shared` only) | Confirmed |
| Circular dependencies? | Not detected statically | Unknown |
| Async coordinator ownership | `AccountRestoreCoordinator`, `CrossDeviceSyncCoordinator` owned by container | Confirmed |

**Recommendations:** `domain child container` for Coach deps; `protocol extraction` for `FoodCorrectionMemoryStoring` (done); consolidate analytics construction.

---

## 10. Feature Flag Bloat and Configuration Audit

**Sources:** `FormaAbTest.swift`, `AccountPersistenceFeatureFlags.swift`, `HealthIntelligenceFeatureFlags.swift`, `Docs/Architecture/FeatureFlagRegistry.md`

| Flag | File | Runtime Default | Production Intent | References | Status | Risk | Action |
|------|------|-----------------|-------------------|------------|--------|------|--------|
| `allEnabled` resolver | `FormaAbTest.swift` | All `true` | N/A | Global | **active rollout** | HI UI on in dev | Wire `production` for Release |
| `HealthIntelligence.uiEnabled` | FormaAbTest | `true` | `false` | Today/Journey/Plan | contradictory docs | Ship surface area | Release pass |
| `remoteSummarySyncEnabled` | FormaAbTest | `true` | `false` | Health sync | off in prod intent | Privacy/cost | Confirm before ship |
| `pullRecentDataEnabled` | AccountPersistenceFeatureFlags | `false` | `false` | Sync puller | rollout-hold | Low | Keep until restore proven |
| `restoreOnLoginEnabled` | AccountPersistence | `true` | `true` | Auth gate | production-critical | High if off | Keep |
| `Coach.pipelineTraceVerbose` | FormaAbTest | `true` | `false` | Diagnostics | debug-only | Privacy | Disable in prod |
| `Coach.foodEstimateDebugLog` | FormaAbTest | `true` | `false` | Logging | debug-only | PII in logs | Disable in prod |
| `Today.scanFoodEnabled` | FormaAbTest | `true` | `true` | Today QA | shipped | Low | Keep |
| `Theme.shipsLightAndSystemAppearance` | FormaAbTest | per snapshot | per snapshot | Theme store | product behavior | Medium | Document |

**No Firebase Remote Config** — **Confirmed** `FeatureFlagRegistry.md` § Overview.

**Flags always true in runtime:** Most `allEnabled` fields — **Confirmed**.

**Testing impact:** Tests rely on `allEnabled`; production-critical tests use `FormaAbTestSnapshot.production` — **Confirmed** `FormaAbTestProductionCriticalFlagsTests.swift`.

---

## 11. SwiftData Entity and Migration Bloat Audit

**Schema:** `FormaSchemaV9` via `FormaModelContainer.schema` — **Confirmed**

| Entity | Active | ownerUID | Sync Fields | Referenced By | Migration Role | Delete Risk | Recommendation |
|--------|--------|----------|-------------|---------------|----------------|-------------|----------------|
| `UserProfileEntity` | Yes | Yes | Yes | Profile, Plan, bootstrap | Current | High | Keep |
| `DailyLogEntity` | Yes | Yes | Yes | Today, sync | Current | High | Keep |
| `FoodEntryEntity` | Yes | Yes | Yes | Food log, Coach | Current | High | Keep |
| `WaterEntryEntity` | Yes | Yes | Yes | Water log | Current | Medium | Keep |
| `WeightEntryEntity` | Yes | Yes | Yes | Weight log | Current | Medium | Keep |
| `DailyReviewEntity` | Yes | Yes | Yes | Reviews | Current | Medium | Keep |
| `CoachTimelineEventEntity` | Yes | Optional userId | Yes | Coach timeline | Current | Medium | Keep |
| `CoachChatTranscriptMessageEntity` | Yes | Optional userId | Yes | Coach chat | Current | Medium | Keep |
| `AccountSyncMutationEntity` | Yes | N/A | Outbox | Sync engine | Current | High | Keep |
| `ChatMessageEntity` | No (V9) | — | — | Migration only | V1→V2 | **Critical** | **Do not delete** |
| `WeeklyReviewEntity` | No | — | — | Migration only | V1→V2 | **Critical** | **Do not delete** |
| `WorkoutEntryEntity` | No | — | — | Migration only | V2→V3 | **Critical** | **Do not delete** |
| `ExerciseSetEntity` | No | — | — | Migration only | V2→V3 | **Critical** | **Do not delete** |
| `DebugRecordEntity` | No | — | — | Migration only | V1→V2 | **Critical** | **Do not delete** |

**File cache (non-SwiftData):** `FoodCorrectionMemoryStore` JSON per UID — **Confirmed** added `364a383d`.

---

## 12. Backend Code Bloat and Anti-Patterns Audit

| Backend File | Lines | Responsibility | Anti-Pattern | Risk | Action |
|--------------|-------|----------------|--------------|------|--------|
| `src/index.ts` | 1,073 | AI gateway router + exports | God router | Medium | Split per `BackendRouteMap.md` path |
| `src/coachContextPacketV2.ts` | 788 | Context validation/rules | Large but cohesive | Low | Keep |
| `src/foodEstimateExtraction.ts` | 678 | Parsing | — | Low | Keep |
| `src/mealImageAnalysis.ts` | 643 | Vision | — | Low | Keep |
| `src/gatewayGuardrails.ts` | 263 | Auth/quota | Good separation | Low | Keep |
| `accountDeletion/accountDeletionService.ts` | 228 | Recursive delete | Complex | High | Keep; emulator tests |

### Backend route map (Confirmed `Docs/Backend/BackendRouteMap.md`)

| Export | Paths |
|--------|-------|
| `aiGateway` | 11 `/v1/ai/*` POST routes |
| `accountDataDeletion` | `/v1/account/delete-data` |

### Test coverage (Confirmed `npm test` 2026-07-05)

| Suite area | Files | Status |
|------------|-------|--------|
| Coach context v2 | `coachContextPacketV2.test.ts` | Pass |
| AI gateway contract | `aiGateway.contract.test.ts` | Pass |
| Account deletion | `accountDeletion.test.ts` | Pass |
| Benchmark harness | `coachAccuracyBenchmarkHarness.test.ts` | Pass |
| Prompt snapshots | `coachPromptSnapshots.test.ts` | **7 snapshot failures** |
| Firestore rules | ignored in default `npm test` | Requires emulator |

### Env vars (Confirmed `Docs/Backend/EnvironmentVariables.md`)

- `OPENAI_API_KEY`, `FORMA_AI_REQUIRE_AUTH`, model config via `modelConfig.ts`

---

## 13. Test Code Bloat and Fixture Duplication Audit

| Test Area | Files / LOC | Duplication | Flakiness Risk | Build Time Risk | Recommendation |
|-----------|-------------|-------------|----------------|-----------------|----------------|
| Health Intelligence UI | `HealthIntelligenceUIStateTests.swift` 1,111 LOC | State matrix | Low | High compile | Split by tab |
| Coach routing | `CoachRoutingTests.swift` 961 LOC | Intent fixtures | Low | High | Keep; golden |
| Account deletion E2E | `AccountDeletionEndToEndTests.swift` 795 LOC | Full stack | **Task.sleep** | Slow | Prefer `AsyncTestSupport` polling |
| Account restore E2E | `AccountRestoreEndToEndTests.swift` 691 LOC | Full stack | Sleep-based | Slow | Same |
| Coach context builder | `CoachContextPacketV2BuilderTests.swift` 798 LOC | Packet fixtures | Low | Medium | Shared fixture JSON |
| HI integration | `HealthIntelligencePhase11IntegrationTests.swift` 902 LOC | Pipeline | Medium | High | Mark expensive in test plan |
| Backend golden | `foodLoggingGoldenCases.ts` 1,119 LOC | Static | Low | npm only | OK |
| Layout guards | `CoachLayoutGuardTests`, `HardcodedColorGuardTests` | Meta-tests | Low | Low | Keep |

**Test plans (Confirmed):** `TestPlans/Fast-Core.xctestplan`, `Integration.xctestplan`, `Full.xctestplan`, `PlanRevealSnapshots.xctestplan`

**Focused npm scripts (Confirmed `functions/package.json`):**
- `test:coach`, `test:food`, `test:benchmark`, `test:account-persistence`, `test:gateway`

**Recommendations:**
- Consolidate `TestingSupport/` into namespaced modules
- Replace fixed `Task.sleep` in deletion tests with condition polling where possible
- Tag >500 LOC suites as integration in `Docs/Testing/TestCommandCheatsheet.md`

---

## 14. Build-Time and Compile-Time Audit

| Build-Time Factor | Evidence | Impact | Recommendation |
|------------------|----------|--------|----------------|
| Largest Swift file | `FormaProductCopy.swift` 4,408 LOC | Slow typecheck **Likely** | Split enums by feature |
| Large SwiftUI views | `PlanEditWizard` 768, `CoachView` + components | Body type-check **Likely** | Extract subviews |
| `@MainActor` saturation | 330 uses / 135 files | Actor isolation overhead | Narrow scope |
| `#Preview` volume | 200+ in app target | Compile in DEBUG **Unknown** | Preview target split |
| Generic-heavy AI contracts | `CoachContextPacketV2.swift` 865 | Medium | Keep |
| Firebase SPM products | Xcode project | Link time **Unknown** | Audit unused products |
| Test target size | 116k LOC | CI time High **Likely** | Fast-Core plan |
| TS build | `tsc` fast | Low | OK |
| iOS build timing | `xcodebuild` failed | **Unknown** | Run `-showBuildTimingSummary` on dev machine |
| Monolithic copy | Single file edits invalidate copy module | Medium | Split files |

---

## 15. UI Bloat and Design System Duplication Audit

| UI Pattern | Locations | Duplicate Risk | Reusable Component | Action |
|------------|-----------|----------------|---------------------|--------|
| Empty states | `TodayEmptyStateView`, `PlanEmptyStateView`, `JourneyEmptyStateView`, `CoachEmptyState` | Medium | `FormaEmptyStateCard` partial | Consolidate |
| Preview screens | `TodayPreviewScreens`, `JourneyPreviewScreens`, `PlanPreviewScreens`, `PublicEntryPreviewScreens` | High | Shared scaffold | Merge helpers |
| HI section shells | Today/Plan/Journey `*HealthIntelligenceSection` | High | `HealthIntelligenceCardLayout` exists | Use consistently |
| Progress rings / macros | Today nutrition card, Plan daily targets | Medium | Plan/Today formatters differ | Shared `MacroProgressRing` |
| Sync status capsules | Settings privacy views | Low | Settings-specific | OK |
| Confidence badges | Coach pending food, weekly review | Medium | Trust formatters post-#154 | Consolidate |
| Theme matrix previews | `MainTabThemePreviewScreens` 20 previews | Compile cost | Design system | Keep in DEBUG |
| Onboarding preview gallery | `OnboardingComponentsPreview` 23 previews | Compile cost | Onboarding only | OK |

**Large bodies:** `CoachComposer.swift`, `JourneyDashboardContent.swift` — monitor extraction.

**Design tokens:** `CoachDesignTokens`, `FormaThemeEnvironment` — **Confirmed**; guard tests `HardcodedColorGuardTests` enforce usage.

---

## 16. Documentation Bloat and Staleness Audit

| Doc | Status | References Current Code? | Stale Sections | Action |
|-----|--------|--------------------------|----------------|--------|
| `Docs/Architecture/SourceOfTruthMap.md` | **source of truth** | Yes (2026-07-04) | Notes `USER_DATA_STORAGE` partial staleness | Keep; link from root |
| `Docs/Architecture/FeatureFlagRegistry.md` | **source of truth** | Yes | Documents allEnabled vs production | Keep |
| `Docs/DeadCodeAudit.md` | historical + active | Partial (Stage 3 done) | Pre-PRDX paths | Update or archive Stage 3 |
| `Docs/TechnicalDebt/TechnicalDebtRegister.md` | **source of truth** | Yes | Open P0 legal | Keep |
| Root `*CONTEXT_PACKET*.md` (10 files) | sprint artifacts | Partial | Overlap with Docs/ | Move to `Docs/Sprints/` or `Docs/Archive/` |
| `PRODUCTION_READINESS_MAINTAINABILITY_CONTEXT_PACKET.md` | snapshot | HEAD `4f1e381` vs current `364a383d` | Correction memory missing | Refresh or archive |
| `Docs/Coach/archive/*` | archive | No | Pre-v2 | Keep in Archive |
| `Docs/HealthIntelligence/PHASE_*` | phase reports | Mostly | Many phases complete | Index in `MASTER_VERIFICATION.md` |
| `../SprintReports/ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md` | plan | Mostly | Phase status | Keep until all phases shipped |
| `PRD.md` | product | High-level | — | Keep |

### Recommended docs structure (from user request)

```
Docs/Architecture/     ← SSOT maps, DI, flags (exists)
Docs/Production/       ← checklists (exists)
Docs/Features/         ← create: Coach, Journey, Today, Plan feature docs
Docs/Sprints/          ← move root CONTEXT_PACKETs
Docs/TechnicalDebt/    ← exists
Docs/Archive/          ← expand Coach/archive, old packets
```

---

## 17. Build Hygiene / Project Organization Audit

| Area | Current State | Risk | Action |
|------|---------------|------|--------|
| Folder vs group | Feature folders under `Fitness Coach/Features/` | Low | **Confirmed** consistent |
| FitPilot folder | 0 tracked `FitPilot/` paths | Low | Removed; headers remain |
| Test plans | 4 xctestplans | Low | Document in `TestStrategy.md` |
| Agent skills `.agents/` | Large non-app tree | None in app target | Exclude from audits |
| `functions/node_modules` | gitignored | Low | OK |
| CI config | **Unknown** — no `.github/workflows` verified | Unknown | Manual verify |
| Schemes | **Unknown** — xcodebuild failed | Unknown | List in Xcode |
| Firebase packages | Via SPM | Link time Unknown | Audit products |
| Scripts | `functions/test/fixtures/generate*.js` | Low | Document in Coach benchmark doc |

---

## 18. Prioritized Cleanup Backlog

### P0

| Item | Evidence | Dev Impact | Prod Risk | Build Impact | Regression Risk | Sprint |
|------|----------|------------|-----------|--------------|-----------------|--------|
| Wire `FormaAbTestSnapshot.production` for Release | FeatureFlagRegistry contradiction | High | **High** — HI UI/sync | Low | Medium | Feature Flag Cleanup |
| Legal URLs (TD-LEGAL-001/002) | `FormaLegalCopy.swift` | Low | **App Store blocker** | None | Low | Production |
| HI presentation builder triplication | 3× ~1k LOC files | **High** | Medium | Medium compile | Medium | State Builder v1 |
| `CoachModel` decomposition | 1,631 LOC; churn 64/90d | **High** | Medium | Medium | High | Coach refactor |
| Backend prompt snapshot failures | 7 failing snapshots | Medium | Low | None | Low | Backend hygiene |
| Account deletion test sleeps | `AccountDeletionViewModelTests` Task.sleep | CI flake | Medium | Slow tests | Medium | Test stability |
| Debug logging flags on in runtime | `foodEstimateDebugLog`, `pipelineTraceVerbose` | Low | **Privacy** | None | Low | Flag cleanup |

### P1

| Item | Evidence | Dev Impact | Prod Risk | Build Impact | Regression Risk | Sprint |
|------|----------|------------|-----------|--------------|-----------------|--------|
| Split `FormaProductCopy.swift` | 4,408 LOC | Medium | Low | **High** compile win | Low | Copy split |
| Modularize `functions/src/index.ts` | TD-BACKEND-001 | Medium | Low | Low | Medium | Backend |
| Consolidate test fixtures | 116k test LOC | **High** | Low | CI time | Low | Test infra |
| Remove `AIContext` | TD-AI-001 | Low | Low | Low | Low | Dead code |
| Archive root context packets | 13 root MD files | Medium clarity | None | None | None | Docs |
| Analytics logger factory | 33 logger files | Medium | Low | Low | Low | DI cleanup |
| `AuthGateCoordinator` split | 1,331 LOC | High | Medium | Medium | High | Auth refactor |

### P2

| Item | Evidence | Dev Impact | Prod Risk | Build Impact | Regression Risk | Sprint |
|------|----------|------------|-----------|--------------|-----------------|--------|
| FitPilot header string cleanup | 200+ file headers | Cosmetic | None | None | None | Chore |
| Preview target separation | 200+ `#Preview` | Low | None | **Unknown** compile | Low | Build opt |
| `JourneyPreviewData` isolation | 1,447 LOC | Low | None | Likely compile | Low | Build opt |
| Theme a11y stubs TD-THEME | register | Medium a11y | Medium | None | Low | A11y sprint |
| Weight delete API TD-DATA-001 | register | Medium | Medium | None | Medium | Account data |

---

## 19. Recommended Cleanup Sprint

### Sprint: **State Builder Simplification v1** (with DI hygiene)

**Goal:** Reduce duplicated Health Intelligence presentation logic and shrink AppContainer construction surface **without changing user-visible behavior**.

**Why first:** TD-HI-002 is documented; three ~1k-line builders drive merge conflicts and test duplication (2,000+ LOC of HI builder tests combined). Evidence: line counts + `TechnicalDebtRegister.md`.

### P0 scope (this sprint)

1. Create `Application/StateBuilders/HealthIntelligence/HealthIntelligencePresentationCore.swift` — extract shared card builders from Today/Plan/Journey files.
2. Replace duplicated date-window helpers with existing domain calculators where SSOT exists (`WeightTrendCalculator`, `StreakCalculator`).
3. Add characterization tests before extraction: run `TodayHealthIntelligencePresentationBuilderTests`, `PlanHealthIntelligencePresentationBuilderTests`, `JourneyHealthIntelligencePresentationBuilderTests` — **Confirmed** exist.
4. Refresh backend prompt snapshots OR quarantine failing suite — 7 failures **Confirmed**.

### P1 scope (same sprint if capacity)

1. Analytics construction map in `AppContainer+Construction.buildAnalytics` (reduce NoOp/OSLog duplication).
2. Delete `AIContext` after migrating `CoachContextV2ContractTests` mocks.
3. Move 3–5 superseded root `*CONTEXT_PACKET*.md` to `Docs/Archive/`.

### Exclusions

- No SwiftData schema changes
- No `FormaAbTest` production wiring (separate release sprint)
- No Coach AI behavior changes
- No account persistence sync semantics changes
- No nutrition/plan formula changes

### Files likely involved

- `TodayHealthIntelligencePresentationBuilder.swift`
- `PlanHealthIntelligencePresentationBuilder.swift`
- `JourneyHealthIntelligencePresentationBuilder.swift`
- `PlanHealthIntelligenceSectionLoader.swift`, `JourneyHealthIntelligenceSectionLoader.swift`
- `AppContainer+Construction.swift`
- `Infrastructure/AI/AIContext.swift`
- `functions/test/coachPromptSnapshots.test.ts`

### Risk controls

- Characterization tests must pass before/after each extraction PR
- One tab at a time (Today → Plan → Journey)
- No public API changes to feature models
- Feature flags unchanged

### Test strategy

- iOS: HI builder test trio + `HealthIntelligenceCompositionTests`
- Backend: `npm run test:coach`; fix snapshots explicitly
- Manual: Today/Journey/Plan HI sections with `allEnabled` flags

### Build timing strategy

- Measure compile before/after `FormaProductCopy` touch (deferred)
- Record `xcodebuild -showBuildTimingSummary` on developer Mac — **Unknown** here

### Success criteria

- ≥30% LOC reduction across HI presentation builders combined
- Zero diff in HI snapshot/characterization test assertions
- No new warnings
- `npm test` green (or snapshots intentionally updated with review)

### Rollback plan

- Revert per-tab PR; builders are self-contained
- Git bisect on `Application/StateBuilders/HealthIntelligence/`

### Suggested commit sequence

1. `test: add HI presentation core characterization fixtures`
2. `refactor: extract HealthIntelligencePresentationCore from Today builder`
3. `refactor: migrate Plan HI builder to core`
4. `refactor: migrate Journey HI builder to core`
5. `chore: remove AIContext test references`
6. `test: refresh coach prompt snapshots` (if needed)

---

## 20. Refactor Safety Rules

1. **No product behavior changes** unless documented in PR and validated by characterization tests.
2. **No schema migration** unless required and reviewed against `FormaMigrationPlan`.
3. **No deleting migration-only entities** (`ChatMessageEntity`, `WeeklyReviewEntity`, `WorkoutEntryEntity`, `ExerciseSetEntity`, `DebugRecordEntity`) without proof from `FormaModelContainer` + migration tests.
4. **No broad renames** without full compile + `Fast-Core` test plan.
5. **No public protocol changes** without updating fakes in `Fitness CoachTests/TestingSupport/`.
6. **No feature-flag removal** without `rg` zero-reference proof + registry update.
7. **No analytics property changes** that expose PII — follow `LoggingAndPrivacyContract.md`.
8. **No account persistence behavior changes** in a bloat sprint — sync/restore/deletion are out of scope.
9. **No Coach AI routing changes** without `CoachRoutingTests` + gateway contract tests.
10. **No plan calculation changes** — `FormaCalculationSpec.md` is SSOT.
11. **No weekly progress formula changes** without `WeeklyProgressSummaryBuilder` tests.
12. **Every deletion needs evidence** — `rg` references, test grep, or `DeadCodeAudit.md` entry.
13. **Every refactor needs focused tests** or compile proof on device/simulator.
14. **One domain at a time** — HI builders before `CoachModel` split.
15. **Small commits** — reviewable diffs (<400 LOC preferred).

---

## 21. Files Reviewed

### App root / configuration
- `Fitness Coach/Configuration/FormaAbTest.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountPersistenceFeatureFlags.swift`
- `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift`
- `functions/package.json`

### AppContainer / DI
- `Fitness Coach/App/AppContainer.swift`
- `Fitness Coach/App/AppContainer+Construction.swift`
- `Fitness Coach/App/AppContainer+FeatureFactories.swift`
- `Fitness Coach/App/MainTabView.swift`
- `Fitness Coach/App/CoachContextInspectorSupport.swift`
- `Docs/Architecture/DependencyInjectionMap.md`

### Auth / onboarding
- `Fitness Coach/Features/Auth/Coordinator/AuthGateCoordinator.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingModel.swift`
- `Fitness Coach/Application/UseCases/ProfileBootstrapService.swift`

### Today
- `Fitness Coach/Features/Today/Model/TodayModel.swift`
- `Fitness Coach/Features/Today/Model/TodayDashboardState.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayHealthIntelligencePresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayPresentationBuilder.swift`

### Coach
- `Fitness Coach/Features/Coach/Model/CoachModel.swift`
- `Fitness Coach/Application/UseCases/Coach/CoachAIRouteHandler.swift`
- `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift`
- `Fitness Coach/Infrastructure/AI/CoachContextPacketV2.swift`
- `Fitness Coach/Infrastructure/AI/AIContext.swift`
- `Fitness Coach/Application/Services/FoodCorrectionMemoryStore.swift`
- `Docs/Coach/COACH_ACCURACY_TRUST_HARDENING_V1_FINAL_REPORT.md`

### Journey
- `Fitness Coach/Features/Journey/Model/JourneyModel.swift`
- `Fitness Coach/Features/Journey/Model/JourneyPreviewData.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyHealthIntelligencePresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/UnifiedWeeklyReviewPresentationBuilder.swift`
- `Docs/JourneyArchitecture.md`

### Plan
- `Fitness Coach/Features/Plan/Model/PlanModel.swift`
- `Fitness Coach/Features/Plan/UI/PlanEditWizard.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanHealthIntelligencePresentationBuilder.swift`
- `Docs/FormaCalculationSpec.md`

### Settings / privacy
- `Fitness Coach/Features/Settings/Model/SettingsPresentationBuilder.swift`
- `Fitness Coach/Application/Privacy/AccountDeletionCoordinator.swift`
- `Fitness Coach/Domain/Legal/FormaLegalCopy.swift`
- `Docs/AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md`

### Health Intelligence
- `Fitness Coach/Health/Repository/HealthDataRepository.swift`
- `Fitness Coach/Health/Intelligence/WeeklyReviewEngine.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceSnapshotService.swift`
- `Docs/HealthIntelligence/PHASE_20_RELEASE_READINESS.md`
- `Docs/HealthIntelligence/CLEANUP_STATUS.md`

### Sync / restore
- `Fitness Coach/Application/Sync/AccountSyncPuller.swift`
- `Fitness Coach/Application/Sync/CrossDeviceSyncCoordinator.swift`
- `Fitness Coach/Application/Restore/AccountRestoreCoordinator.swift`
- `Fitness Coach/Application/Restore/AccountInitialRestoreService.swift`

### SwiftData / persistence
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelContainer.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/*.swift` (14 entity files)
- `Docs/PersistenceCleanupNotes.md`

### Firebase / backend
- `functions/src/index.ts`
- `functions/src/coachContextPacketV2.ts`
- `functions/src/gatewayGuardrails.ts`
- `functions/src/accountDeletion/accountDeletionService.ts`
- `Docs/Backend/BackendRouteMap.md`
- `Docs/Backend/EnvironmentVariables.md`

### Analytics / diagnostics
- `Fitness Coach/Infrastructure/Diagnostics/*Analytics*.swift` (33 files sampled)
- `Fitness CoachTests/TestingSupport/CapturingAnalyticsLoggers.swift`
- `Docs/Architecture/LoggingAndPrivacyContract.md`
- `Docs/Architecture/AnalyticsReadinessChecklist.md`

### Design system
- `Fitness Coach/Domain/Copy/FormaProductCopy.swift`
- `Fitness Coach/DesignSystem/Theme/ThemeStore.swift`
- `Fitness Coach/DesignSystem/Preview/MainTabThemePreviewScreens.swift`

### Tests
- `Fitness CoachTests/HealthIntelligenceUIStateTests.swift`
- `Fitness CoachTests/CoachRoutingTests.swift`
- `Fitness CoachTests/AccountDeletionEndToEndTests.swift`
- `Fitness CoachTests/FormaAbTestProductionCriticalFlagsTests.swift`
- `Fitness CoachTests/TestingSupport/AsyncTestSupport.swift`
- `TestPlans/*.xctestplan`
- `Docs/Testing/TestCommandCheatsheet.md`

### Docs / project
- All files listed in §16
- `Docs/DeadCodeAudit.md`
- `Docs/TechnicalDebt/TechnicalDebtRegister.md`
- `PRODUCTION_READINESS_MAINTAINABILITY_CONTEXT_PACKET.md`
- `PRD.md`, `../SprintReports/PRDX_V1_IMPLEMENTATION_MAP.md`

### Commands run
- `git ls-files`, `git log --since=90 days`, `python3` line counts
- `rg` pattern searches (TODO, flags, @MainActor, etc.)
- `npm --prefix functions run build|lint|test`
- `xcodebuild -list` (**failed**)

---

## 22. Unknowns / Manual Verification

| Item | Why Unknown | How to verify |
|------|-------------|---------------|
| iOS full build time | `xcodebuild` requires full Xcode | `xcodebuild -showBuildTimingSummary` on dev machine |
| Slow Swift compile units | No timing summary | Xcode build timeline / `-debug-time-function-bodies` sample |
| CI pipeline status | `.github/workflows` not audited | Check GitHub Actions |
| Production feature flags on App Store build | Runtime uses `allEnabled` | Release build + `FormaAbTest.resolved` logging |
| Deployed Firebase functions version | Not queried | `firebase functions:list` |
| Deployed Firestore rules vs repo | Not compared | Rules emulator + deploy diff |
| Test flakiness rate | Single `npm test` run | Repeated CI history |
| Archive / distribution warnings | Not built | Xcode Archive |
| Simulator-specific failures | Not run | `Fast-Core.xctestplan` locally |
| Preview compile cost in app target | Theoretical | Compare DEBUG build with/without previews |
| Per-symbol dead code | Scale of codebase | Swift unused-code analysis / Periphery |
| Xcode indexing performance | Subjective | Developer feedback |
| `find` vs `git` Swift count delta | `.agents` swift scripts | Exclude non-app paths in future audits |

---

*End of packet. Ready to paste into ChatGPT for maintainability/refactor sprint planning.*
