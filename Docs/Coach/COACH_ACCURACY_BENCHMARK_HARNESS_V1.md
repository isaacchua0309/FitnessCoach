# Coach Accuracy Benchmark Harness v1

Repeatable benchmark suite for Coach food estimate **accuracy** and **trust behavior**.

The harness validates schema, calorie ranges, component decomposition, confirmation requirements, clarification behavior, and trust metadata (assumptions / uncertainty keywords). It is designed for CI without live OpenAI by default.

## Fixture location

| File | Purpose |
|------|---------|
| `Docs/Coach/Fixtures/coach_accuracy_benchmark_v1_cases.json` | Benchmark v1 cases (40 scenarios) |
| `Docs/Coach/Fixtures/singapore_food_estimation_cases.json` | Extended Singapore/local range pack (50 cases) |
| `functions/test/fixtures/generateCoachAccuracyBenchmarkV1Cases.js` | Regenerate benchmark JSON |

## Categories (v1)

1. **singapore_hawker** — chicken rice, nasi lemak, char kway teow, laksa, bak chor mee, duck rice, caifan, mala, yong tau foo, curry rice, fish soup noodles, prata
2. **meal_prep** — exact-gram chicken/rice/broccoli/salmon, protein shake
3. **drinks** — kopi o, milk, bubble tea, milo dinosaur, latte, sugar cane
4. **desserts** — tiramisu, brownie, ice cream, cake slice, madeleine
5. **photo_scenario** — mocked image analysis responses (cropped plate, multiple plates, hidden sauce, buffet, drink+food, mixed economy rice)
6. **correction_flow** — chicken 300g, rice half portion, add chili sauce, steamed not roasted, remove sauce

## Case schema

Each case defines:

- `prompt` / scenario text
- `expectedRoute` — `estimate_food`, `photo_analysis`, etc.
- `shouldLogAutomatically` — always `false` in v1
- `shouldRequireConfirmation` — always `true` in v1
- `shouldAskClarification` or `allowLowConfidencePending`
- `expectedConfidenceBand` — `{ min, max }`
- `expectedCaloriesRange` / macro ranges (where applicable)
- `requiredUncertaintyKeywords` / `requiredAssumptionKeywords`
- `expectedComponents`
- `mockImageAnalysisResponse` (photo scenarios)
- `baselinePrompt` (correction flows)
- optional `singaporeFixtureId` link to Singapore pack

## Metrics

The harness reports:

- `totalCases`, `passedCases`, `failedCases`
- `routeFailures`
- `rangeFailures`
- `missingAssumptionFailures`
- `missingUncertaintyFailures`
- `overconfidenceFailures`
- `clarificationFailures`
- `confirmationFailures`
- `schemaFailures`
- `componentFailures`

## How to run

### Firebase / Node (deterministic — default CI)

```bash
cd functions
npm run test:benchmark
```

Or explicitly:

```bash
cd functions
npm test -- --testPathPatterns='coachAccuracyBenchmarkHarness|singaporeFoodEstimationFixture'
```

### Firebase live benchmark (opt-in)

Requires credentials; **not run in default CI**.

```bash
cd functions
RUN_LIVE_FOOD_BENCHMARK=1 OPENAI_API_KEY=sk-... npm run test:benchmark:live
```

When `OPENAI_API_KEY` or `FORMA_AI_GATEWAY_URL` is unavailable, the live suite validates the scoring pipeline only and does not fail CI.

### iOS benchmark tests

```bash
xcodebuild -scheme "Fitness Coach" -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:Fitness\ CoachTests/CoachAccuracyBenchmarkHarnessTests \
  -only-testing:Fitness\ CoachTests/SingaporeFoodEstimationFixtureTests test
```

### Regenerate fixtures

```bash
node functions/test/fixtures/generateCoachAccuracyBenchmarkV1Cases.js
node functions/test/fixtures/generateSingaporeFoodEstimationCases.js
```

## Architecture

```
coach_accuracy_benchmark_v1_cases.json
        │
        ├─ functions/test/fixtures/coachAccuracyBenchmarkSupport.ts
        │     ├─ buildReferenceExtractionForBenchmark()
        │     ├─ scoreBenchmarkCase()
        │     └─ runDeterministicBenchmark()
        │
        └─ Fitness CoachTests/TestingSupport/CoachAccuracyBenchmarkSupport.swift
              └─ runDeterministicBenchmark() (iOS parity)
```

**Deterministic mode** builds QA reference extractions at range midpoints (or uses linked Singapore fixtures / mocked photo responses) and asserts the scoring rubric passes.

**Live mode** (opt-in) is wired for gateway evaluation; v1 keeps CI offline and documents the env flags for manual/scheduled runs.

## Pass/fail rules (v1)

| Dimension | Pass when |
|-----------|-----------|
| Route | `expectedRoute` matches scenario class |
| Range | totals within `expected*Range` |
| Components | keywords appear in meal/components/assumptions |
| Assumptions | `requiredAssumptionKeywords` present |
| Uncertainty | `requiredUncertaintyKeywords` present when specified |
| Confidence | actual confidence within `expectedConfidenceBand` |
| Confirmation | `requiresConfirmation === shouldRequireConfirmation` |
| Clarification | clarifying question present/absent per flags |
| Schema | `validateFoodExtraction` passes (relaxed for QA reference macros) |
| Photo trust | `needsUserReview === true` on mocked photo responses |

## Related tests

- `functions/test/singaporeFoodEstimationFixture.test.ts` — 50-case Singapore pack
- `functions/test/coachAccuracyBenchmarkHarness.test.ts` — 40-case v1 harness
- `functions/test/coachAccuracyBenchmarkLive.test.ts` — opt-in live guard
- `Fitness CoachTests/CoachAccuracyBenchmarkHarnessTests.swift`
- `Fitness CoachTests/SingaporeFoodEstimationFixtureTests.swift`
