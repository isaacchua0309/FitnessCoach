import fs from "node:fs";
import path from "node:path";
import {applyCoachIntentPhraseGuard} from "../src/coachIntentPhraseGuard";
import {sanitizeCoachIntentResult} from "../src/coachIntentSanitizer";

type FixtureCase = {
  id: string;
  category: string;
  input: string;
  expectedIntent: string;
  shouldCreateMutation: boolean;
  shouldRequireConfirmation: boolean;
  notes: string;
  edgeReason: string;
  verificationLayers: string[];
  misclassifiedIntent?: string;
  classifierConfidence?: number;
  expectedRouteHandler?: string;
  forbiddenRouteHandlers?: string[];
};

type FixtureDocument = {
  schemaVersion: number;
  minimumCaseCount: number;
  categories: string[];
  caseCount: number;
  cases: FixtureCase[];
};

function loadFixture(): FixtureDocument {
  const fixturePath = path.resolve(
    __dirname,
    "../../Docs/Coach/Fixtures/coach_intent_regression_cases.json"
  );
  const raw = fs.readFileSync(fixturePath, "utf8");
  return JSON.parse(raw) as FixtureDocument;
}

function misclassifiedPayload(intent = "log_food") {
  return {
    intent,
    confidence: 0.95,
    domain: "nutrition",
    requiresAppMutation: intent === "log_food",
    requiresUserContext: true,
    canAnswerWithCheapModel: true,
    requiresEscalation: false,
    entities: {food: "fixture food"},
    action: intent === "log_food" ? {
      type: "log_food",
      foodDraft: {name: "fixture food", quantity: 1, unit: "serving"},
      waterDraft: null,
      weightDraft: null,
      workoutDraft: null,
      selector: null,
      undoTarget: null,
    } : null,
    reason: "Fixture misclassification stub.",
  };
}

describe("coachIntentRegressionFixture", () => {
  const fixture = loadFixture();

  it("loads at least 80 regression cases", () => {
    expect(fixture.caseCount).toBeGreaterThanOrEqual(fixture.minimumCaseCount);
    expect(fixture.cases.length).toBeGreaterThanOrEqual(80);
  });

  it("includes all required categories", () => {
    const required = [
      "should_not_log_food",
      "should_log_food",
      "nutrition_lookup",
      "meal_decision",
      "daily_summary",
      "edit_delete_reference",
      "water_logging",
      "weight_logging",
      "workout_redirect",
      "unsupported",
    ];
    for (const category of required) {
      expect(fixture.categories).toContain(category);
    }
  });

  it("includes Singapore and local food examples", () => {
    const joined = fixture.cases.map((c) => c.input).join(" ").toLowerCase();
    const foods = [
      "chicken rice", "nasi lemak", "cai fan", "mala", "fish soup", "ban mian",
      "yong tau foo", "prata", "kaya toast", "kopi", "bubble tea", "sushi",
      "ramen", "mcspicy", "subway", "protein shake",
    ];
    for (const food of foods) {
      expect(joined).toContain(food);
    }
  });

  describe("phrase_guard layer", () => {
    const cases = fixture.cases.filter((c) => c.verificationLayers.includes("phrase_guard"));

    it.each(cases.map((c) => [c.id, c]))("corrects or preserves intent for %s", (_id, fixtureCase) => {
      const misclassified = fixtureCase.misclassifiedIntent ?? "log_food";
      if (misclassified !== "log_food") {
        return;
      }

      const guarded = applyCoachIntentPhraseGuard(
        misclassifiedPayload("log_food"),
        fixtureCase.input
      );

      if (fixtureCase.category === "should_log_food") {
        expect(guarded.intent).toBe("log_food");
        expect(guarded.requiresAppMutation).toBe(true);
        expect(guarded.action).not.toBeNull();
        return;
      }

      expect(guarded.intent).toBe(fixtureCase.expectedIntent);
      expect(guarded.requiresAppMutation).toBe(false);
      expect(guarded.action).toBeNull();
    });
  });

  describe("backend_sanitizer layer", () => {
    const cases = fixture.cases.filter((c) => c.verificationLayers.includes("backend_sanitizer"));

    it.each(cases.map((c) => [c.id, c]))("sanitizer aligns with fixture for %s", (_id, fixtureCase) => {
      const sanitized = sanitizeCoachIntentResult(
        misclassifiedPayload("log_food"),
        fixtureCase.input
      );

      if (fixtureCase.category === "should_log_food") {
        expect(sanitized.intent).toBe("log_food");
        return;
      }

      expect(sanitized.intent).toBe(fixtureCase.expectedIntent);
      expect(sanitized.requiresAppMutation).toBe(false);
      expect(sanitized.action).toBeNull();
    });
  });

  it("documents manual live-classifier verification requirement", () => {
    const docPath = path.resolve(
      __dirname,
      "../../Docs/Coach/Fixtures/COACH_INTENT_REGRESSION_FIXTURE.md"
    );
    const doc = fs.readFileSync(docPath, "utf8");
    expect(doc).toContain("Manual verification required");
    expect(doc).toContain("classify-coach-intent");
  });
});
