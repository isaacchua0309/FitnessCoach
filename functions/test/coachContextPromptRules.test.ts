import {
  analyzeMealImagePromptRules,
  classifyCoachIntentPromptRules,
  coachContextHealthRules,
  coachContextV2Rules,
  dailyReviewPromptRules,
  editDeletePromptRules,
  estimateFoodPromptRules,
  mealAdvicePromptRules,
} from "../src/coachContextPromptRules";

describe("coachContextPromptRules", () => {
  it("includes shared CoachContextPacketV2 rules", () => {
    const rules = coachContextV2Rules();
    expect(rules).toContain("Structured context is the source of truth");
    expect(rules).toContain("Timeline confirmed events override chat text");
    expect(rules).toContain("must not be treated as logged facts");
    expect(rules).toContain("localDate and context.meta.timezoneIdentifier");
    expect(rules).toContain("recentEvents for chronological ordering");
    expect(rules).toContain("recentChatMessages and currentUserMessage for conversational continuity only");
    expect(rules).toContain("timeline.recentEvents and context.today aggregates for factual claims");
    expect(rules).toContain("recentMealsStructured");
    expect(rules).toContain("missingData");
    expect(rules).toContain("Do not diagnose medical conditions");
    expect(rules).toContain("Do not mutate app state");
  });

  it("includes health rules for HealthKit availability", () => {
    const rules = coachContextHealthRules();
    expect(rules).toContain("healthKitDenied");
    expect(rules).toContain("missingData");
    expect(rules).toContain("do not invent those signals");
  });

  it("includes classify-coach-intent endpoint rules", () => {
    const rules = classifyCoachIntentPromptRules();
    expect(rules).toContain("current user text as the primary intent signal");
    expect(rules).toContain("linkedEntryId");
    expect(rules).toContain("Do not copy nutrition values from context.recentChatMessages");
    expect(rules).toContain("currentUserMessage");
    expect(rules).toContain("timeline.recentEvents and context.today aggregates for factual claims");
  });

  it("includes estimate-food endpoint rules", () => {
    const rules = estimateFoodPromptRules();
    expect(rules).toContain("same as breakfast");
    expect(rules).toContain("Do not treat rejected estimates");
  });

  it("includes meal-advice endpoint rules", () => {
    const rules = mealAdvicePromptRules();
    expect(rules).toContain("remaining calories/protein/water");
    expect(rules).toContain("post-workout");
    expect(rules).toContain("recovery");
  });

  it("includes analyze-meal-image endpoint rules", () => {
    const rules = analyzeMealImagePromptRules();
    expect(rules).toContain("needsUserReview");
    expect(rules).toContain("Do not infer hidden foods from context");
  });

  it("includes edit/delete endpoint rules", () => {
    const rules = editDeletePromptRules();
    expect(rules).toContain("linkedEntryId");
    expect(rules).toContain("Never delete or edit based only on assistant chat text");
  });

  it("includes daily-review endpoint rules", () => {
    const rules = dailyReviewPromptRules();
    expect(rules).toContain("today aggregates");
    expect(rules).toContain("missingData");
  });
});
