import {
  formatBenchmarkSummary,
  loadCoachAccuracyBenchmarkFixture,
  runDeterministicBenchmark,
  summarizeBenchmarkRun,
  validateBenchmarkCaseShape,
  validateBenchmarkReferencePipeline,
} from "./fixtures/coachAccuracyBenchmarkSupport";

describe("coachAccuracyBenchmarkHarness v1", () => {
  const fixture = loadCoachAccuracyBenchmarkFixture();

  it("loads benchmark fixture with expected categories", () => {
    expect(fixture.version).toBe(1);
    expect(fixture.caseCount).toBe(fixture.cases.length);
    expect(fixture.cases.length).toBeGreaterThanOrEqual(35);
    expect(fixture.categories).toEqual(
      expect.arrayContaining([
        "singapore_hawker",
        "meal_prep",
        "drinks",
        "desserts",
        "photo_scenario",
        "correction_flow",
      ])
    );
  });

  it("has unique benchmark case ids", () => {
    const ids = fixture.cases.map((item) => item.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  describe.each(fixture.cases)("$id shape", (benchmarkCase) => {
    it("defines valid benchmark metadata", () => {
      const errors = validateBenchmarkCaseShape(benchmarkCase);
      expect(errors).toEqual([]);
      expect(benchmarkCase.shouldLogAutomatically).toBe(false);
      expect(benchmarkCase.shouldRequireConfirmation).toBe(true);
      expect(benchmarkCase.notes.trim().length).toBeGreaterThan(0);
    });
  });

  describe.each(fixture.cases)("$id deterministic reference", (benchmarkCase) => {
    it("builds a reference extraction that passes benchmark scoring", () => {
      const result = validateBenchmarkReferencePipeline(benchmarkCase);
      expect(result.errors).toEqual([]);
      expect(result.ok).toBe(true);
    });
  });

  it("runs full deterministic benchmark with zero failures", () => {
    const summary = runDeterministicBenchmark(fixture);
    expect(summary.failedCases).toBe(0);
    expect(summary.passedCases).toBe(summary.totalCases);
    expect(summary.routeFailures).toBe(0);
    expect(summary.rangeFailures).toBe(0);
    expect(summary.missingAssumptionFailures).toBe(0);
    expect(summary.missingUncertaintyFailures).toBe(0);
    expect(summary.overconfidenceFailures).toBe(0);
    expect(summary.clarificationFailures).toBe(0);
    expect(summary.confirmationFailures).toBe(0);
    expect(summary.schemaFailures).toBe(0);
    expect(summary.componentFailures).toBe(0);
  });

  it("includes all requested hawker food scenarios", () => {
    const prompts = fixture.cases
      .filter((item) => item.category === "singapore_hawker")
      .map((item) => item.prompt.toLowerCase());
    const mustInclude = [
      "chicken rice",
      "nasi lemak",
      "char kway teow",
      "laksa",
      "bak chor mee",
      "duck rice",
      "caifan",
      "mala",
      "yong tau foo",
      "curry rice",
      "fish soup",
      "prata",
    ];
    for (const phrase of mustInclude) {
      expect(prompts.some((prompt) => prompt.includes(phrase))).toBe(true);
    }
  });

  it("includes meal prep, drinks, desserts, photo, and correction categories", () => {
    const byCategory = (category: string) =>
      fixture.cases.filter((item) => item.category === category).length;
    expect(byCategory("meal_prep")).toBeGreaterThanOrEqual(5);
    expect(byCategory("drinks")).toBeGreaterThanOrEqual(5);
    expect(byCategory("desserts")).toBeGreaterThanOrEqual(4);
    expect(byCategory("photo_scenario")).toBeGreaterThanOrEqual(5);
    expect(byCategory("correction_flow")).toBeGreaterThanOrEqual(4);
  });

  it("formats benchmark summary for reporting", () => {
    const summary = summarizeBenchmarkRun(
      runDeterministicBenchmark(fixture).results
    );
    const formatted = formatBenchmarkSummary(summary);
    expect(formatted).toContain("Coach Accuracy Benchmark v1");
    expect(formatted).toContain(`total=${summary.totalCases}`);
  });
});
