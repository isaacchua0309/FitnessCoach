# CoachModel Decomposition v1

**Status:** Complete (behavior-neutral)  
**Date:** 2026-07-05  
**PR scope:** TD-COACH-001 — split `CoachModel` into coordinators without changing user-facing behavior

---

## 1. Motivation

`CoachModel.swift` had grown to ~1,600 LOC mixing SwiftUI surface state, send routing, photo analysis, pending confirmation, transcript persistence, launch chrome, today context, and analytics. That made Coach changes high-risk and hard to test in isolation.

**Goal:** Extract focused coordinators and a dependency assembly type while keeping `CoachModel` as the single `ObservableObject` for `CoachView`.

---

## 2. Before / after

| Metric | Before | After (v1) |
|--------|--------|------------|
| `CoachModel.swift` | ~1,627 LOC | ~350 LOC |
| Coordinator files | 0 | 11 under `Features/Coach/Model/` |
| Primary init parameters | 20+ individual deps | `CoachServices` + `CoachDependencies` |
| Test injection | Long `CoachModel(...)` | `CoachDependencies` overrides or legacy init |

---

## 3. Extraction sequence

Extractions were done incrementally with characterization tests as a behavior freeze:

| Step | Extracted | File |
|------|-----------|------|
| 1 | Composer input state | `CoachInputCoordinator.swift` |
| 2 | Meal photo send / analysis | `CoachPhotoFlowCoordinator.swift` |
| 3 | Pending confirmation | `CoachPendingConfirmationCoordinator.swift` |
| 4 | Transcript + timeline messages | `CoachMessagePersistenceCoordinator.swift` |
| 5 | Text send + routing | `CoachSendFlowCoordinator.swift` |
| 6 | Pure surface transitions | `CoachModelStateReducer.swift` |
| 7 | Today context refresh | `CoachTodayContextCoordinator.swift` |
| 8 | Launch chrome | `CoachLaunchChromeCoordinator.swift` |
| 9 | Nutrition card actions | `CoachNutritionEstimateActionCoordinator.swift` |
| 10 | Context packet assembly | `CoachContextPacketCoordinator.swift` |
| 11 | DI assembly | `CoachDependencies.swift` |

---

## 4. File map (post-v1)

### `CoachModel` façade

| File | Role |
|------|------|
| `CoachModel.swift` | `@Published` state, public API, coordinator wiring |
| `CoachModel+CoordinatorDelegates.swift` | Bridges for launch chrome, pending UI, transcript |
| `CoachModel+LegacyInitialization.swift` | Convenience init for tests |
| `CoachDependencies.swift` | `CoachServices`, `CoachDependencies`, `CoachAssembledPipeline` |

### Coordinators (`Features/Coach/Model/`)

| File | Lines (approx.) |
|------|---------------|
| `CoachInputCoordinator.swift` | ~180 |
| `CoachSendFlowCoordinator.swift` | ~290 |
| `CoachPhotoFlowCoordinator.swift` | ~550 |
| `CoachPendingConfirmationCoordinator.swift` | ~380 |
| `CoachMessagePersistenceCoordinator.swift` | ~180 |
| `CoachContextPacketCoordinator.swift` | ~100 |
| `CoachTodayContextCoordinator.swift` | ~80 |
| `CoachLaunchChromeCoordinator.swift` | ~120 |
| `CoachNutritionEstimateActionCoordinator.swift` | ~70 |
| `CoachModelStateReducer.swift` | ~210 |

### Unchanged application layer

Still in `Application/UseCases/Coach/`:

- `CoachMutationExecutor.swift`
- `CoachAIRouteHandler.swift`
- `CoachMealPhotoAnalyzer.swift`
- `CoachRouteDecider.swift`
- `CoachPendingConfirmationPresenter.swift`
- `Pipeline/*`

Still in `Application/StateBuilders/Coach/`:

- `CoachContextPacketV2Builder.swift`
- `CoachResponseBuilder.swift`
- `CoachTodayContextBuilder.swift`

---

## 5. `CoachModel` new role

`CoachModel` is **not** a state owner for domain data. It:

1. Holds `@Published` fields bound by `CoachView`
2. Exposes the same public methods (`send`, `sendCurrentMessage`, `confirmPendingFromBar`, etc.)
3. Wires coordinators in `init(services:dependencies:)`
4. Implements minimal delegate protocols to apply coordinator output to published state

It does **not**:

- Classify intents directly
- Call `FitnessActionCenter` directly
- Build context packets inline
- Own photo session state

---

## 6. Coordinator ownership matrix

| Concern | Coordinator | Domain handler (if any) |
|---------|-------------|-------------------------|
| Composer text / attachment | `CoachInputCoordinator` | — |
| Text send + AI route | `CoachSendFlowCoordinator` | `CoachRouteDecider`, `CoachAIRouteHandler` |
| Meal photo | `CoachPhotoFlowCoordinator` | `CoachMealPhotoAnalyzer` |
| Pending UI + confirm | `CoachPendingConfirmationCoordinator` | `CoachPendingConfirmationPresenter`, `CoachMutationExecutor` |
| Messages + transcript | `CoachMessagePersistenceCoordinator` | `CoachChatTranscriptStore` |
| Context packet | `CoachContextPacketCoordinator` | `CoachContextPacketV2Builder` |
| Empty-state today | `CoachTodayContextCoordinator` | `CoachTodayContextBuilder` |
| Launch intents | `CoachLaunchChromeCoordinator` | `CoachLaunchPresentationBuilder` |
| Nutrition card taps | `CoachNutritionEstimateActionCoordinator` | `NutritionSuggestedActionHandler` |
| Surface state math | `CoachModelStateReducer` | — |

---

## 7. Dependency injection

### Types

```swift
CoachServices          // App-level readers and health providers (from AppContainer)
CoachDependencies      // Overridable pipeline pieces + stores
CoachAssembledPipeline // Built executors + coordinators (internal to assembly)
```

### Production wiring

```swift
// AppContainer+FeatureFactories.swift
makeCoachServices() → makeCoachDependencies() → CoachModel(services:dependencies:)
```

### Test override example

```swift
var deps = CoachDependencies(
    aiService: stubAIService,
    aiCommandParsingEnabled: true,
    contextPacketBuilder: packetBuilder,
    transcriptStore: CapturingCoachTranscriptStore(),
    timelineRecorder: DefaultCoachTimelineRecorder(store: fakeTimelineStore)
)
let model = CoachModel(services: services, dependencies: deps)
```

---

## 8. Behavior preserved

Verified intent (characterization + manual build):

- Local greeting and food estimate paths without AI
- AI food estimate → pending confirmation
- Text send message append order
- Pending bar confirm/reject and typed confirm words
- Photo send, analysis success/failure, auth failure surface
- Photo retry and clarification recommission
- Transcript restore on init and persist on mutate
- Timeline user/assistant/pending/photo events
- Launch intent chrome and composer placeholder overrides
- Nutrition estimate card analytics and suggested actions
- `isSending` / processing phase gating
- Session failure error presentation (`showsAuthRetry`)

---

## 9. Intentionally not changed

- `CoachView` bindings and property names
- `CoachContextPacketV2` structure and builder logic
- Backend / Firebase function contracts
- `CoachMutationExecutor` mutation paths
- SwiftData schemas (`CoachChatTranscriptMessageEntity`, timeline entities)
- `CoachImagePipeline` (static compression API)
- Routing thresholds in `CoachRouteDecider`
- Product copy / prompts (`FormaProductCopy.Coach`)

---

## 10. Tests added / updated

### New

| File | Purpose |
|------|---------|
| `CoachModelStateReducerTests.swift` | Unit tests for pure reducer transitions |
| `CoachModelDecompositionCharacterizationTests.swift` | Integration behavior freeze |
| `CoachModelCharacterizationTests.swift` | Shared characterization with fakes |

### Updated

| File | Change |
|------|--------|
| `CoachRoutingIntegrationTestSupport.swift` | `makeCoachServices`, `makeCoachDependencies` |
| `CoachModelCharacterizationTestSupport.swift` | Uses `CoachDependencies` |
| `TestCommandCheatsheet.md` | Characterization test commands |

### Recommended pre/post refactor gate

```bash
-only-testing:"Fitness CoachTests/CoachModelDecompositionCharacterizationTests"
-only-testing:"Fitness CoachTests/CoachModelStateReducerTests"
-only-testing:"Fitness CoachTests/CoachRoutingTests"
-only-testing:"Fitness CoachTests/CoachMealPhotoAnalysisTests"
```

---

## 11. Remaining debt

| Item | Notes |
|------|-------|
| Image pick flow | `CoachImagePickFlowController` still coordinates UI + model callbacks |
| Legacy init | `CoachModel+LegacyInitialization.swift` — remove when tests migrate |
| Transcript dual memory | `messages` array + SwiftData — see SourceOfTruthMap |
| Test target CI | Unrelated `AccountSync*` / deletion test compile failures block full suite |
| `CoachContextPacketV2Builder` size | Separate debt; not part of CoachModel split |

TD-COACH-001 status: **partially closed** — primary god-file split done; see TechnicalDebtRegister.

---

## 12. Related documents

- [CoachArchitecture.md](./CoachArchitecture.md) — flows and diagrams
- [COACH_FULL_CONTEXT_PACKET.md](./COACH_FULL_CONTEXT_PACKET.md) — pre-split deep dive (still valid for domain)
- [../Architecture/DependencyInjectionMap.md](../Architecture/DependencyInjectionMap.md) — AppContainer factories

---

## Revision history

| Date | Change |
|------|--------|
| 2026-07-05 | v1 decomposition complete — doc created |
