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

  it("sanitizes chat messages with text and timestamp fields", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      recentChatMessages: [
        {
          id: "msg-1",
          role: "user",
          text: "  How am I doing?  ",
          timestamp: "2026-07-03T10:00:00.000Z",
          hasPhotoAttachment: false,
        },
      ],
      currentUserMessage: "  Log lunch  ",
    });

    const messages = sanitized?.recentChatMessages as Array<Record<string, unknown>>;
    expect(messages).toHaveLength(1);
    expect(messages[0].text).toBe("How am I doing?");
    expect(messages[0].timestamp).toBe("2026-07-03T10:00:00.000Z");
    expect(messages[0]).not.toHaveProperty("textPreview");
    expect(sanitized?.currentUserMessage).toBe("Log lunch");
  });

  it("accepts legacy chat preview fields during sanitization", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      recentChatMessages: [
        {
          id: "msg-1",
          role: "assistant",
          textPreview: "You have room for a snack.",
          sentAt: "2026-07-03T10:05:00.000Z",
        },
      ],
    });

    const messages = sanitized?.recentChatMessages as Array<Record<string, unknown>>;
    expect(messages[0].text).toBe("You have room for a snack.");
    expect(messages[0].timestamp).toBe("2026-07-03T10:05:00.000Z");
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

  it("preserves linkedEntryId on recent meals during sanitization", () => {
    const entryId = "meal-entry-42";
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      recentMealsStructured: [{
        name: "Salad",
        calories: 420,
        proteinGrams: 28,
        linkedEntryId: entryId,
      }],
    });

    const meals = sanitized?.recentMealsStructured as Array<{linkedEntryId?: string}>;
    expect(meals[0].linkedEntryId).toBe(entryId);
  });

  it("preserves linkedEntryId on timeline events during sanitization", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {
        recentEvents: [{
          id: "evt-1",
          type: "foodLogged",
          status: "confirmed",
          source: "coachUI",
          summary: "Logged salad",
          timestamp: "2026-07-03T10:00:00.000Z",
          linkedEntryId: "entry-salad",
        }],
      },
    });

    const events = (sanitized?.timeline as {recentEvents: Array<{linkedEntryId?: string}>})
      .recentEvents;
    expect(events[0].linkedEntryId).toBe("entry-salad");
  });

  it("filters rejected and failed timeline events from prompt embedding", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {
        recentEvents: [
          {
            id: "rejected-1",
            type: "foodRejected",
            status: "rejected",
            source: "aiBackend",
            summary: "Rejected chicken estimate",
            timestamp: "2026-07-03T09:00:00.000Z",
          },
          {
            id: "confirmed-1",
            type: "foodLogged",
            status: "confirmed",
            source: "coachUI",
            summary: "Logged eggs",
            timestamp: "2026-07-03T10:00:00.000Z",
            linkedEntryId: "entry-eggs",
          },
        ],
      },
    });

    const events = (sanitized?.timeline as {recentEvents: Array<{type: string}>})
      .recentEvents;
    expect(events).toHaveLength(1);
    expect(events[0].type).toBe("foodLogged");
  });

  it("retains pending confirmation events with pending status", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {
        recentEvents: [
          {
            id: "pending-1",
            type: "pendingConfirmationCreated",
            status: "pending",
            source: "aiBackend",
            summary: "Pending bowl estimate",
            timestamp: "2026-07-03T09:30:00.000Z",
          },
          {
            id: "confirmed-1",
            type: "foodLogged",
            status: "confirmed",
            source: "coachUI",
            summary: "Logged eggs",
            timestamp: "2026-07-03T10:00:00.000Z",
          },
        ],
      },
    });

    const events = (sanitized?.timeline as {recentEvents: Array<{type: string; status: string}>})
      .recentEvents;
    expect(events).toHaveLength(2);
    expect(events.some((event) => event.type === "pendingConfirmationCreated" && event.status === "pending"))
      .toBe(true);
  });

  it("preserves foodEdited and foodDeleted timeline events under limit pressure", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {
        recentEvents: [
          {
            id: "edited-1",
            type: "foodEdited",
            status: "confirmed",
            source: "coachUI",
            summary: "Edited salad",
            timestamp: "2026-07-03T10:00:00.000Z",
            linkedEntryId: "entry-salad",
          },
          {
            id: "deleted-1",
            type: "foodDeleted",
            status: "confirmed",
            source: "coachUI",
            summary: "Deleted snack",
            timestamp: "2026-07-03T10:05:00.000Z",
            linkedEntryId: "entry-snack",
          },
          ...Array.from({length: 25}, (_, index) => ({
            id: `assistant-${index}`,
            type: "assistantMessage",
            status: "confirmed",
            source: "aiBackend",
            summary: `Assistant ${index}`,
            timestamp: `2026-07-03T11:${String(index).padStart(2, "0")}:00.000Z`,
          })),
        ],
      },
    });

    const events = (sanitized?.timeline as {
      recentEvents: Array<{type: string; linkedEntryId?: string}>;
    }).recentEvents;
    expect(events.some((event) => event.type === "foodEdited" && event.linkedEntryId === "entry-salad"))
      .toBe(true);
    expect(events.some((event) => event.type === "foodDeleted" && event.linkedEntryId === "entry-snack"))
      .toBe(true);
    expect(events.length).toBeLessThanOrEqual(20);
  });

  it("retains dailyFoodSummary timeline events", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {
        recentEvents: [
          {
            id: "summary-1",
            type: "dailyFoodSummary",
            status: "confirmed",
            source: "system",
            summary: "Earlier food logs today: 8 meals, 3200 kcal total.",
            timestamp: "2026-07-03T09:00:00.000Z",
            compactPayload: {mealCount: "8", totalKcal: "3200"},
          },
          ...Array.from({length: 25}, (_, index) => ({
            id: `assistant-${index}`,
            type: "assistantMessage",
            status: "confirmed",
            source: "aiBackend",
            summary: `Assistant ${index}`,
            timestamp: `2026-07-03T11:${String(index).padStart(2, "0")}:00.000Z`,
          })),
        ],
      },
    });

    const events = (sanitized?.timeline as {recentEvents: Array<{type: string}>}).recentEvents;
    expect(events.some((event) => event.type === "dailyFoodSummary")).toBe(true);
    expect(events.length).toBeLessThanOrEqual(20);
  });

  it("rejects malformed timeline recentEvents type", () => {
    expect(() => validateCoachContextPacketV2({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {recentEvents: "not-an-array"},
    })).toThrow("timeline.recentEvents");
  });
});
