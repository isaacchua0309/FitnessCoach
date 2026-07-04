import {
  classifyCoachIntentPromptRules,
  coachContextHealthRules,
  coachContextV2Rules,
  editDeletePromptRules,
  estimateFoodPromptRules,
  mealAdvicePromptRules,
} from "../src/coachContextPromptRules";
import {
  coachIntentClassificationInstructions,
  editDeleteInstructions,
  foodEstimateInstructions,
  mealAdviceInstructions,
  sharedRules,
} from "../src/coachPromptInstructions";
import {mealImageAnalysisInstructions} from "../src/mealImageAnalysis";
import {
  assertCoachPromptMarkers,
  CLASSIFIER_CRITICAL_MARKERS,
  COACH_PROMPT_CRITICAL_MARKERS,
  EDIT_DELETE_CRITICAL_MARKERS,
  missingMarkers,
} from "./helpers/coachPromptCriticalRules";

describe("coach prompt snapshots", () => {
  describe("rule block snapshots", () => {
    it("matches sharedRules snapshot", () => {
      expect(sharedRules()).toMatchSnapshot();
    });

    it("matches coachContextV2Rules snapshot", () => {
      expect(coachContextV2Rules()).toMatchSnapshot();
    });

    it("matches coachContextHealthRules snapshot", () => {
      expect(coachContextHealthRules()).toMatchSnapshot();
    });

    it("matches classifyCoachIntentPromptRules snapshot", () => {
      expect(classifyCoachIntentPromptRules()).toMatchSnapshot();
    });

    it("matches estimateFoodPromptRules snapshot", () => {
      expect(estimateFoodPromptRules()).toMatchSnapshot();
    });

    it("matches mealAdvicePromptRules snapshot", () => {
      expect(mealAdvicePromptRules()).toMatchSnapshot();
    });

    it("matches editDeletePromptRules snapshot", () => {
      expect(editDeletePromptRules()).toMatchSnapshot();
    });
  });

  describe("endpoint instruction snapshots", () => {
    it("matches classifier instructions snapshot", () => {
      expect(coachIntentClassificationInstructions()).toMatchSnapshot();
    });

    it("matches estimate-food instructions snapshot", () => {
      expect(foodEstimateInstructions()).toMatchSnapshot();
    });

    it("matches meal advice instructions snapshot", () => {
      expect(mealAdviceInstructions()).toMatchSnapshot();
    });

    it("matches analyze-meal-image instructions snapshot", () => {
      expect(mealImageAnalysisInstructions()).toMatchSnapshot();
    });

    it("matches edit/delete instructions snapshot", () => {
      expect(editDeleteInstructions()).toMatchSnapshot();
    });
  });

  describe("critical rule presence", () => {
    it("enforces core Coach v2 markers in coachContextV2Rules", () => {
      expect(() => assertCoachPromptMarkers(
        coachContextV2Rules(),
        COACH_PROMPT_CRITICAL_MARKERS,
        "coachContextV2Rules"
      )).not.toThrow();
    });

    it("enforces shared safety markers in sharedRules", () => {
      expect(sharedRules()).toMatch(/never mutate app state/i);
      expect(sharedRules()).toMatch(/Do not diagnose medical conditions/i);
    });

    it.each([
      ["classifier instructions", coachIntentClassificationInstructions()],
      ["estimate-food instructions", foodEstimateInstructions()],
      ["meal advice instructions", mealAdviceInstructions()],
      ["analyze-meal-image instructions", mealImageAnalysisInstructions()],
      ["edit/delete instructions", editDeleteInstructions()],
    ] as const)("enforces core Coach v2 markers in %s", (_label, prompt) => {
      expect(() => assertCoachPromptMarkers(prompt, COACH_PROMPT_CRITICAL_MARKERS, _label))
        .not.toThrow();
    });

    it("enforces classifier-specific markers", () => {
      expect(() => assertCoachPromptMarkers(
        coachIntentClassificationInstructions(),
        CLASSIFIER_CRITICAL_MARKERS,
        "classifier instructions"
      )).not.toThrow();
    });

    it("enforces edit/delete-specific markers", () => {
      expect(() => assertCoachPromptMarkers(
        editDeleteInstructions(),
        EDIT_DELETE_CRITICAL_MARKERS,
        "edit/delete instructions"
      )).not.toThrow();
    });

    it("includes health intelligence guidance in health rules and meal advice", () => {
      expect(coachContextHealthRules()).toMatch(/context\.healthIntelligence is present/i);
      expect(mealAdviceInstructions()).toMatch(/context\.healthIntelligence/i);
    });
  });

  describe("prompt regression guards", () => {
    it("fails when a critical shared rule is removed", () => {
      const stripped = coachIntentClassificationInstructions().replace(
        "Structured context is the source of truth",
        ""
      );
      expect(missingMarkers(stripped, COACH_PROMPT_CRITICAL_MARKERS).map((m) => m.id))
        .toContain("structured-source-of-truth");
    });

    it("fails when the localDate/timezone rule is missing", () => {
      const stripped = foodEstimateInstructions().replace(
        /context\.meta\.localDate and context\.meta\.timezoneIdentifier[^\n]*/i,
        ""
      );
      expect(missingMarkers(stripped, COACH_PROMPT_CRITICAL_MARKERS).map((m) => m.id))
        .toContain("local-date-timezone-today");
    });

    it("fails when the pending/rejected timeline rule is missing", () => {
      const stripped = mealAdviceInstructions().replace(
        /Pending, rejected, failed, or superseded timeline events must not be treated as logged facts\./i,
        ""
      );
      expect(missingMarkers(stripped, COACH_PROMPT_CRITICAL_MARKERS).map((m) => m.id))
        .toContain("pending-rejected-not-logged");
    });

    it("fails when linkedEntryId guidance is missing from edit/delete instructions", () => {
      const stripped = editDeleteInstructions().replace(/linkedEntryId/gi, "entryRef");
      expect(missingMarkers(stripped, EDIT_DELETE_CRITICAL_MARKERS).map((m) => m.id))
        .toContain("linked-entry-id-edit-delete");
    });

    it("fails when classifier nutrition-from-chat guard is removed", () => {
      const stripped = coachIntentClassificationInstructions()
        .replace(/Do not copy nutrition values from context\.recentChatMessages[^\n]*/i, "")
        .replace(/Never copy nutrition from chat history or prior assistant estimates\./i, "");
      expect(missingMarkers(stripped, CLASSIFIER_CRITICAL_MARKERS).map((m) => m.id))
        .toContain("no-nutrition-from-chat");
    });
  });
});

describe("coach prompt snapshot drift detection", () => {
  it("detects accidental coachContextV2Rules drift via snapshot", () => {
    expect(coachContextV2Rules()).toMatchSnapshot("coachContextV2Rules");
  });

  it("detects accidental classifier instruction drift via snapshot", () => {
    expect(coachIntentClassificationInstructions()).toMatchSnapshot("classifierInstructions");
  });
});
