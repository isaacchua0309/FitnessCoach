import {GatewayError} from "../src/gatewayGuardrails";
import {
  COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION,
  coachContextLogFields,
  parseCoachContextForPrompt,
  validateCoachContextPacketV2,
} from "../src/coachContextPacketV2";
import {
  minimalCoachContextV2,
  workoutAwareCoachContextV2,
} from "./fixtures/coachContextPacketV2";

describe("coachContextPacketV2", () => {
  it("accepts partial but valid v2 context", () => {
    expect(() => validateCoachContextPacketV2(minimalCoachContextV2)).not.toThrow();
  });

  it("rejects empty context objects", () => {
    expect(() => validateCoachContextPacketV2({}))
      .toThrow("Missing or invalid context.meta.");
  });

  it("rejects invalid schema version with 400", () => {
    expect(() => validateCoachContextPacketV2({
      meta: {schemaVersion: 1},
    })).toThrow(GatewayError);

    try {
      validateCoachContextPacketV2({meta: {schemaVersion: 1}});
    } catch (error) {
      expect(error).toBeInstanceOf(GatewayError);
      expect((error as GatewayError).status).toBe(400);
      expect((error as GatewayError).message).toContain("schemaVersion");
    }
  });

  it("sanitizes timeline summaries and preserves protected events", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {
        recentEvents: [
          {
            id: "1",
            type: "foodLogged",
            status: "confirmed",
            source: "coachUI",
            summary: "x".repeat(300),
            timestamp: "2026-07-03T10:00:00.000Z",
          },
          {
            id: "2",
            type: "systemRefresh",
            status: "confirmed",
            source: "system",
            summary: "refresh",
            timestamp: "2026-07-03T09:00:00.000Z",
          },
        ],
      },
    });

    const events = (sanitized?.timeline as {recentEvents: Array<{summary: string; type: string}>})
      .recentEvents;
    expect(events).toHaveLength(1);
    expect(events[0].type).toBe("foodLogged");
    expect(events[0].summary.length).toBeLessThanOrEqual(181);
  });

  it("limits recent meals and common foods for prompt embedding", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      recentMealsStructured: Array.from({length: 12}, (_, index) => ({
        name: `Meal ${index}`,
        calories: 400,
        proteinGrams: 20,
      })),
      commonFoods: Array.from({length: 12}, (_, index) => ({
        name: `food-${index}`,
        frequency: index,
      })),
    });

    expect((sanitized?.recentMealsStructured as unknown[]).length).toBe(10);
    expect((sanitized?.commonFoods as unknown[]).length).toBe(10);
  });

  it("strips unknown top-level payloads before prompt embedding", () => {
    const sanitized = parseCoachContextForPrompt({
      ...workoutAwareCoachContextV2,
      unexpectedLargeBlob: {nested: "secret"},
    });

    expect(sanitized).not.toHaveProperty("unexpectedLargeBlob");
    expect(sanitized).toHaveProperty("training");
  });

  it("coachContextLogFields avoids raw health/nutrition payloads", () => {
    const fields = coachContextLogFields(workoutAwareCoachContextV2);

    expect(fields.contextPresent).toBe(true);
    expect(fields.contextSchemaVersion).toBe(2);
    expect(fields.contextRecentMeals).toBe(1);
    expect(JSON.stringify(fields)).not.toContain("Salad");
    expect(JSON.stringify(fields)).not.toContain("8000");
  });
});
