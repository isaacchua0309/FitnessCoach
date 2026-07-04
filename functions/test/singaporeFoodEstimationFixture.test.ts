import {
  buildReferenceExtraction,
  loadSingaporeFoodEstimationFixture,
  validateExtractionAgainstFixture,
  validateFixtureCaseShape,
  validateFixturePromptAnalysis,
  validateReferenceExtractionPipeline,
  valueInRange,
  midpoint,
  componentKeywordsMatch,
  assumptionKeywordsMatch,
  confidenceMatches,
} from "./fixtures/singaporeFoodEstimationFixtureSupport";

describe("singaporeFoodEstimationCases fixture pack", () => {
  const fixture = loadSingaporeFoodEstimationFixture();

  it("loads at least 50 Singapore/local food cases", () => {
    expect(fixture.version).toBe(1);
    expect(fixture.cases.length).toBeGreaterThanOrEqual(50);
    expect(fixture.caseCount).toBe(fixture.cases.length);
  });

  it("has unique case ids", () => {
    const ids = fixture.cases.map((item) => item.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  describe.each(fixture.cases)("$id shape", (fixtureCase) => {
    it("defines valid fixture metadata", () => {
      const errors = validateFixtureCaseShape(fixtureCase);
      expect(errors).toEqual([]);
      expect(fixtureCase.shouldRequireConfirmation).toBe(true);
      expect(fixtureCase.notes.trim().length).toBeGreaterThan(0);
    });
  });

  describe.each(fixture.cases)("$id reference extraction", (fixtureCase) => {
    it("builds a QA reference extraction that satisfies range helpers", () => {
      const extraction = buildReferenceExtraction(fixtureCase);
      const result = validateExtractionAgainstFixture(extraction, fixtureCase);
      expect(result.errors).toEqual([]);
      expect(result.ok).toBe(true);
    });

    it("passes structural food extraction validation for reference extraction", () => {
      const result = validateReferenceExtractionPipeline(fixtureCase);
      expect(result.errors).toEqual([]);
      expect(result.ok).toBe(true);
    });

    it("aligns compound prompt analysis with fixture component expectations", () => {
      const result = validateFixturePromptAnalysis(fixtureCase);
      expect(result.errors).toEqual([]);
      expect(result.ok).toBe(true);
    });
  });

  describe("range helper utilities", () => {
    it("checks numeric ranges without exact equality", () => {
      expect(valueInRange(500, [450, 750])).toBe(true);
      expect(valueInRange(800, [450, 750])).toBe(false);
      expect(midpoint([450, 750])).toBe(600);
    });

    it("matches component and assumption keywords loosely", () => {
      expect(componentKeywordsMatch(
        ["fragrant rice", "poached chicken", "chili sauce"],
        ["rice", "chicken", "sauce"]
      )).toBe(true);
      expect(assumptionKeywordsMatch(
        ["Assumption (portion): medium plate"],
        ["portion"]
      )).toBe(true);
    });

    it("evaluates confidence as max or exact", () => {
      expect(confidenceMatches("low", "medium", "max")).toBe(true);
      expect(confidenceMatches("high", "medium", "max")).toBe(false);
      expect(confidenceMatches("high", "high", "exact")).toBe(true);
    });
  });

  it("includes all requested user-facing food scenarios", () => {
    const texts = fixture.cases.map((item) => item.inputText.toLowerCase());
    const mustInclude = [
      "chicken rice",
      "roasted chicken rice",
      "steamed chicken rice",
      "char siew rice",
      "cai fan",
      "nasi lemak",
      "fish soup",
      "ban mian",
      "yong tau foo",
      "mala",
      "economic bee hoon",
      "prata",
      "kaya toast",
      "kopi",
      "teh",
      "bubble tea",
      "sushi",
      "sashimi",
      "ramen",
      "udon",
      "mcspicy",
      "mcdonald",
      "subway",
      "protein shake",
      "greek yogurt",
      "200g cooked chicken breast",
      "300g cooked chicken breast",
      "half bowl rice",
      "one bowl rice",
      "mixed rice",
      "bibimbap",
      "curry rice",
      "gyudon",
      "poke bowl",
      "caesar salad",
      "egg yolks",
      "tiramisu",
      "breadtalk",
      "luckin",
    ];
    for (const phrase of mustInclude) {
      expect(texts.some((text) => text.includes(phrase))).toBe(true);
    }
  });
});
