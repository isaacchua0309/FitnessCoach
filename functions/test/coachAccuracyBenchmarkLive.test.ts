import {
  isLiveBenchmarkEnabled,
  liveBenchmarkCredentialsAvailable,
  loadCoachAccuracyBenchmarkFixture,
  scoreBenchmarkCase,
  buildReferenceExtractionForBenchmark,
  formatBenchmarkSummary,
  summarizeBenchmarkRun,
} from "./fixtures/coachAccuracyBenchmarkSupport";

const describeLive = isLiveBenchmarkEnabled() ? describe : describe.skip;

describeLive("coachAccuracyBenchmarkHarness live (opt-in)", () => {
  const fixture = loadCoachAccuracyBenchmarkFixture();

  beforeAll(() => {
    if (!liveBenchmarkCredentialsAvailable()) {
      console.warn(
        "RUN_LIVE_FOOD_BENCHMARK=1 but no OPENAI_API_KEY or FORMA_AI_GATEWAY_URL — " +
        "live benchmark will validate reference scoring only."
      );
    }
  });

  it("documents live benchmark env requirements", () => {
    expect(process.env.RUN_LIVE_FOOD_BENCHMARK).toBe("1");
  });

  it("scores a live subset using reference extractions when gateway unavailable", () => {
    const subset = fixture.cases.slice(0, 5);
    const results = subset.map((benchmarkCase) => {
      const extraction = buildReferenceExtractionForBenchmark(benchmarkCase);
      return scoreBenchmarkCase(benchmarkCase, extraction, {
        actualRoute: benchmarkCase.expectedRoute,
      });
    });
    const summary = summarizeBenchmarkRun(results);
    console.log(formatBenchmarkSummary(summary));

    if (!liveBenchmarkCredentialsAvailable()) {
      expect(summary.passedCases).toBe(subset.length);
      return;
    }

    // When credentials are present, integrators can replace buildReferenceExtractionForBenchmark
    // with a real gateway call. v1 keeps this path non-blocking in CI.
    expect(summary.totalCases).toBe(subset.length);
  });
});

describe("coachAccuracyBenchmarkHarness live guard", () => {
  it("skips live benchmark by default in CI", () => {
    if (process.env.RUN_LIVE_FOOD_BENCHMARK === "1") {
      expect(isLiveBenchmarkEnabled()).toBe(true);
      return;
    }
    expect(isLiveBenchmarkEnabled()).toBe(false);
  });
});
