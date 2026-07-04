# Test Strategy

**Last updated:** 2026-07-04  
**Related:** `Fitness CoachTests/TESTING.md`, [AppArchitectureOverview.md](./AppArchitectureOverview.md), [../../PRDX_V1_IMPLEMENTATION_MAP.md](../../PRDX_V1_IMPLEMENTATION_MAP.md)

---

## 1. Goals

1. Catch regressions in **account persistence**, **Coach routing**, and **plan math** before merge.
2. Keep local feedback fast (Fast-Core ~3–4 min).
3. Gate refactors with **parity tests** — same inputs → same outputs.
4. Document known infra flakes honestly.

---

## 2. Test Targets

| Target | Path | ~Files |
|--------|------|--------|
| Unit / integration tests | `Fitness CoachTests/` | ~506 Swift |
| Backend tests | `functions/test/` | 20 Jest suites |
| Test support | `Fitness CoachTests/TestingSupport/` | 40 helpers |

**No dedicated UI test target** or snapshot framework (**Confirmed**). Rendering guardrails are unit-level (`TodayReadOnlyCompositionTests`, etc.).

---

## 3. Xcode Test Plans

| Plan | Scheme | Purpose | ~Classes |
|------|--------|---------|----------|
| **Fast-Core** | Fitness Coach | Daily dev (⌘U default) | ~180 |
| **Integration** | Fitness Coach | Harness, SwiftData, cloud mocks | ~66 |
| **Full** | Fitness Coach CI | Complete regression | ~219 |
| **PlanRevealSnapshots** | Fitness Coach | Onboarding plan reveal | Subset |

Regenerate plans after adding test files:

```bash
python3 Scripts/generate_test_plans.py
```

Add new integration-heavy files to `INTEGRATION_FILES` in that script.

---

## 4. Test Commands

### iOS — local development

```bash
DESTINATION='platform=iOS Simulator,name=iPhone 17'

# Fast (default)
xcodebuild test -scheme "Fitness Coach" \
  -destination "$DESTINATION" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO

# Integration
xcodebuild test -scheme "Fitness Coach" \
  -destination "$DESTINATION" \
  -testPlan Integration \
  -parallel-testing-enabled NO

# Full CI
xcodebuild test -scheme "Fitness Coach CI" \
  -destination "$DESTINATION" \
  -parallel-testing-enabled NO
```

### iOS — single test class

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" \
  -only-testing:"Fitness CoachTests/FormaCalculationEngineTests"
```

### Backend

```bash
cd functions && npm ci && npm run lint && npm test
```

### Firestore rules (emulator required)

```bash
# Planned PRDX P1 — currently fails without emulator
firebase emulators:exec --only firestore "cd functions && npm test -- accountPersistenceFirestoreRules"
```

---

## 5. Coverage by Domain

| Domain | Representative tests | Plan |
|--------|---------------------|------|
| Plan calculation | `FormaCalculationEngineTests`, `WeightLossPaceTests` | Fast-Core |
| Today builders | `TodayPresentationBuilderTests`, `TodayLoggingFlowTests` | Fast-Core |
| Journey | `JourneyDashboardBuilderTests`, `JourneyWeeklyReviewBuilderTests` | Fast-Core |
| Coach routing | `CoachRoutingTests`, `CoachImageWorkflowE2ETests` | Fast-Core + Integration |
| Coach context v2 | `CoachContextPacketV2BuilderTests`, `CoachContextV2ContractTests` | Fast-Core |
| Auth routing | `AuthGateRoutingPolicyTests`, `AuthProfileRouteSafetyTests` | Fast-Core / Integration |
| Onboarding | `OnboardingModelTests`, `OnboardingCompletionTests` | Fast-Core / Integration |
| Theme | `ThemeStoreTests`, `HardcodedColorGuardTests` | Fast-Core |
| Account sync | `AccountSyncCoordinatorTests`, `AccountSyncUploaderTests` | Integration |
| Account restore | `AccountRestoreCoordinatorTests`, `AccountRestoreEndToEndTests` | Integration |
| Cross-device | `CrossDeviceEndToEndSyncTests`, `CrossDeviceSyncCoordinatorTests` | Integration |
| Account deletion | `AccountDeletionCoordinatorTests`, `AccountDeletionEndToEndTests` | Integration |
| Health Intelligence | `HealthIntelligenceEngineTests`, `HealthIntelligenceFeatureFlagsTests` | Fast-Core |
| SwiftData migration | `FormaSchemaV7MigrationTests`, `CoachV2SwiftDataMigrationTests` | Integration |
| Backend AI | `aiGateway.contract.test.ts`, `coachContextPacketV2.test.ts` | npm test |

---

## 6. Refactor Safety Rules

These rules apply to **all** PRDX and maintainability refactors.

### Behavior preservation

1. **No user-facing behavior change** unless documented in PR + release notes and approved.
2. **No Coach behavior change** — `CoachRoutingTests`, `CoachImageWorkflowE2ETests`, `CoachMealPhotoAnalysisTests` must pass.
3. **No Weekly Progress behavior change** — `JourneyWeeklyReviewBuilderTests`, `JourneyDashboardBuilderTests`, `WeeklyReviewServiceTests` must pass; do not merge Journey habit rows with HI weekly review in PRDX.
4. **Preserve account persistence phases 1–6** — do not change `AccountPersistenceFeatureFlags` constants or coordinator ordering without full E2E suite.

### Technical safety

5. **No destructive SwiftData migration** without version bump + migration tests.
6. **One domain per PR** — flags, logging, DI, copy split, etc.
7. **No broad rename** without Full test plan green.
8. **Every deletion** justified with `rg` reference search in PR description.
9. **Public protocol changes** require fake/mock updates in `TestingSupport/`.
10. **Tests before risky refactors** — add parity/guard tests in commit N, refactor in N+1.

### DI / composition refactors

11. `AppContainer` extractions must pass `AppContainerAccountDataRemoteStoreWiringTests`.
12. Init order changes require Integration plan.

### Flags

13. Runtime flag default changes require explicit product sign-off (separate PR from `production` snapshot definition).

---

## 7. PR Merge Gates

### Every Swift PR

- [ ] Fast-Core green (serial)
- [ ] No new compiler warnings (goal — baseline **Unknown**)

### PRDX P0 PRs

- [ ] `HealthIntelligenceFeatureFlagsTests`
- [ ] `AccountSyncCoordinatorTests` (smoke)
- [ ] `CoachRoutingTests` (unit methods)
- [ ] `JourneyWeeklyReviewBuilderTests`

### PRDX P1 PRs

- [ ] Full CI scheme
- [ ] `AccountRestoreEndToEndTests`
- [ ] `CrossDeviceEndToEndSyncTests`
- [ ] `AccountDeletionCoordinatorTests`
- [ ] Domain-specific parity tests (HI loaders, copy guardrails)

### Functions PRs

- [ ] `npm run lint && npm test`
- [ ] Contract tests unchanged snapshots unless intentional

---

## 8. Known Instability (**Confirmed** `TESTING.md`)

| Issue | Symptom | Mitigation |
|-------|---------|------------|
| Duplicate Firebase/GTM ObjC classes | XCTest crash restarts | `-parallel-testing-enabled NO` |
| Stale test bundle after prod edits | `dlopen` / missing symbol | Clean build folder |
| Simulator flake | `ProfilePlanConflictFlowTests` crash | Re-run serial; treat as infra |

**Do not claim CI green** until `TEST SUCCEEDED` with zero crash restarts.

---

## 9. Test Doubles and Fixtures

| Helper | Location | Use |
|--------|----------|-----|
| `CapturingAnalyticsLoggers` | `TestingSupport/` | Analytics assertions |
| `AccountRestoreTestSupport` | `TestingSupport/` | Restore flows |
| `CrossDeviceSyncTestSupport` | `TestingSupport/` | Cross-device E2E |
| `CoachImageWorkflowTestSupport` | `TestingSupport/` | Coach image pipeline |
| `FormaSwiftDataMigrationTestSupport` | `TestingSupport/` | Schema migrations |
| `InMemoryAccountDataRemoteStore` | Infrastructure / tests | Cloud without Firestore |
| `MockLLMClient` | `Infrastructure/AI/` | Coach without backend |

**Inject via:** `AppContainer(inMemory: true, accountDataRemoteStore: …, …AnalyticsLogger: …)`.

---

## 10. Backend Test Layout

```
functions/test/
├── aiGateway.contract.test.ts
├── accountDeletion.test.ts
├── accountPersistenceFirestoreRules.test.ts  # needs emulator
├── coachContextPacketV2.test.ts
├── nutritionSyncContract.test.ts
└── helpers/                                   # mockHttp, inMemoryFirestore
```

---

## 11. What Is Not Tested (gaps)

| Gap | Priority |
|-----|----------|
| Release analytics sink | PRDX P0 when added |
| Release logging PII audit | PRDX P0 `ReleaseLoggingGuardTests` |
| Archive / signing | Manual |
| Deployed Firestore rules drift | Emulator CI (P1) |
| Weight local delete API | P1 when implemented |
| Full UI snapshot suite | Not planned |

---

## 12. Revision History

| Date | Change |
|------|--------|
| 2026-07-04 | Initial test strategy for PRDX v1 |
