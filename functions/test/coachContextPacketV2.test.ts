import {GatewayError} from "../src/gatewayGuardrails";
import {
  assertCoachContextEncodedSizeWithinLimit,
  assertNoImageDataInCoachContext,
  COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION,
  coachContextLogFields,
  parseCoachContextForPrompt,
  validateCoachContextPacketV2,
} from "../src/coachContextPacketV2";
import {
  minimalCoachContextV2,
  richCoachContextV2,
  workoutAwareCoachContextV2,
} from "./fixtures/coachContextPacketV2";

const mealEntryId = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
const timelineEntryId = "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff";

describe("coachContextPacketV2", () => {
  it("accepts valid minimal v2 context", () => {
    expect(() => validateCoachContextPacketV2(minimalCoachContextV2)).not.toThrow();
    const sanitized = parseCoachContextForPrompt(minimalCoachContextV2);
    expect(sanitized?.meta.schemaVersion).toBe(COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION);
  });

  it("accepts valid rich v2 context", () => {
    expect(() => validateCoachContextPacketV2(richCoachContextV2)).not.toThrow();
    const sanitized = parseCoachContextForPrompt(richCoachContextV2);
    expect(sanitized).toHaveProperty("training");
    expect(sanitized).toHaveProperty("recentMealsStructured");
  });

  it("rejects empty context objects", () => {
    expect(() => validateCoachContextPacketV2({}))
      .toThrow("Missing or invalid context.");
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
      expect((error as GatewayError).message).toBe("Invalid context.");
    }
  });

  it("rejects v1 context where v2 is required", () => {
    expect(() => parseCoachContextForPrompt({meta: {schemaVersion: 1}}, {required: true}))
      .toThrow("Invalid context.");
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

  it("truncates oversized list fields during sanitization", () => {
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
      recentChatMessages: Array.from({length: 15}, (_, index) => ({
        id: `msg-${index}`,
        role: "user",
        text: `Message ${index}`,
      })),
      timeline: {
        recentEvents: Array.from({length: 25}, (_, index) => ({
          id: String(index),
          type: "foodLogged",
          status: "confirmed",
          source: "coachUI",
          summary: `Meal ${index}`,
          timestamp: "2026-07-03T10:00:00.000Z",
        })),
      },
    });

    expect((sanitized?.recentMealsStructured as unknown[]).length).toBe(10);
    expect((sanitized?.commonFoods as unknown[]).length).toBe(10);
    expect((sanitized?.recentChatMessages as unknown[]).length).toBe(12);
    expect((sanitized?.timeline as {recentEvents: unknown[]}).recentEvents.length)
      .toBeLessThanOrEqual(20);
  });

  it("rejects oversized encoded context with 413", () => {
    const oversized = {
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      profile: {
        goalType: "x".repeat(30_000),
      },
    };

    expect(() => assertCoachContextEncodedSizeWithinLimit(oversized)).toThrow(GatewayError);
    try {
      validateCoachContextPacketV2(oversized);
    } catch (error) {
      expect(error).toBeInstanceOf(GatewayError);
      expect((error as GatewayError).status).toBe(413);
      expect((error as GatewayError).message).toBe("Context payload too large.");
    }
  });

  it("rejects raw image bytes inside context", () => {
    expect(() => assertNoImageDataInCoachContext({
      meta: {schemaVersion: 2},
      imageJPEGBase64: "abc",
    })).toThrow("Invalid context.");

    expect(() => validateCoachContextPacketV2({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {
        recentEvents: [{
          id: "1",
          type: "photoAttached",
          status: "confirmed",
          source: "coachUI",
          summary: "photo",
          compactPayload: {
            base64: "/9j/" + "A".repeat(300),
          },
        }],
      },
    })).toThrow("Invalid context.");
  });

  it("allows image bytes only outside context validation path", () => {
    expect(() => assertNoImageDataInCoachContext({
      meta: {schemaVersion: 2},
      note: "no image here",
    })).not.toThrow();
  });

  it("sanitizes unknown event compact payload values", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {
        recentEvents: [{
          id: "1",
          type: "foodLogged",
          status: "confirmed",
          source: "coachUI",
          summary: "Logged meal",
          timestamp: "2026-07-03T10:00:00.000Z",
          compactPayload: {
            nested: {secret: "value"},
            ok: "yes",
          },
        }],
      },
    });

    const payload = (sanitized?.timeline as {
      recentEvents: Array<{compactPayload?: Record<string, string>}>;
    }).recentEvents[0].compactPayload;
    expect(payload?.nested).toBe("[sanitized]");
    expect(payload?.ok).toBe("yes");
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
    const fields = coachContextLogFields({
      ...workoutAwareCoachContextV2,
      missingData: {
        stepsMissing: true,
        contextGenerationFailed: true,
      },
    });

    expect(fields.contextPresent).toBe(true);
    expect(fields.contextSchemaVersion).toBe(2);
    expect(fields.contextRecentMeals).toBe(1);
    expect(fields.contextMissingDataFlags).toBe("contextGenerationFailed,stepsMissing");
    expect(fields.contextGenerationFailed).toBe(true);
    expect(JSON.stringify(fields)).not.toContain("Salad");
    expect(JSON.stringify(fields)).not.toContain("8000");
  });

  it("preserves linkedEntryId on recent meals during sanitization", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      recentMealsStructured: [{
        name: "Salad",
        calories: 420,
        proteinGrams: 28,
        linkedEntryId: mealEntryId,
      }],
    });

    const meals = sanitized?.recentMealsStructured as Array<{linkedEntryId?: string}>;
    expect(meals[0].linkedEntryId).toBe(mealEntryId);
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
          linkedEntryId: timelineEntryId,
        }],
      },
    });

    const events = (sanitized?.timeline as {recentEvents: Array<{linkedEntryId?: string}>})
      .recentEvents;
    expect(events[0].linkedEntryId).toBe(timelineEntryId);
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
            id: "failed-food",
            type: "foodLogged",
            status: "failed",
            source: "coachUI",
            summary: "Failed log attempt",
            timestamp: "2026-07-03T09:30:00.000Z",
          },
          {
            id: "confirmed-1",
            type: "foodLogged",
            status: "confirmed",
            source: "coachUI",
            summary: "Logged eggs",
            timestamp: "2026-07-03T10:00:00.000Z",
            linkedEntryId: timelineEntryId,
          },
        ],
      },
    });

    const events = (sanitized?.timeline as {recentEvents: Array<{type: string}>})
      .recentEvents;
    expect(events).toHaveLength(1);
    expect(events[0].type).toBe("foodLogged");
  });

  it("does not treat rejected-status foodLogged events as consumed facts", () => {
    const sanitized = parseCoachContextForPrompt({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      timeline: {
        recentEvents: [{
          id: "pending-food",
          type: "foodLogged",
          status: "pending",
          source: "coachUI",
          summary: "Pending food",
          timestamp: "2026-07-03T10:00:00.000Z",
        }],
      },
    });

    expect((sanitized?.timeline as {recentEvents: unknown[]}).recentEvents).toHaveLength(0);
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
    })).toThrow("Invalid context.");
  });

  it("rejects invalid linkedEntryId format during validation", () => {
    expect(() => validateCoachContextPacketV2({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      recentMealsStructured: [{
        name: "Salad",
        linkedEntryId: "not-a-uuid",
      }],
    })).toThrow("Invalid context.");
  });

  it("rejects assumptions detail that exceeds max length", () => {
    expect(() => validateCoachContextPacketV2({
      meta: {schemaVersion: COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION},
      assumptions: [{
        key: "test",
        detail: "x".repeat(300),
      }],
    })).toThrow("Invalid context.");
  });
});
