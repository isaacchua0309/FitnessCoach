import {GatewayError} from "../src/gatewayGuardrails";
import {
  COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION,
  COACH_CONTEXT_LIMITS,
  parseCoachContextForPrompt,
  validateCoachContextPacketV2,
} from "../src/coachContextPacketV2";
import {validatePayload} from "../src/gatewayGuardrails";
import {validateAnalyzeMealImagePayload} from "../src/mealImageAnalysis";
import {
  coachContextV2Fixtures,
  coachEndpointRequestFixtures,
  rejectedContextFixtures,
} from "./fixtures/coach-context-v2";

const COACH_ENDPOINT_KEYS = [
  "classify-coach-intent",
  "estimate-food",
  "generate-meal-advice",
  "generate-daily-review",
  "parse-edit-delete",
  "parse-multi-action",
  "analyze-meal-image",
] as const;

describe("coachContextV2 contract fixtures", () => {
  describe("canonical context packets", () => {
    it.each([
      ["minimal", coachContextV2Fixtures.minimal],
      ["rich", coachContextV2Fixtures.rich],
      ["degraded", coachContextV2Fixtures.degraded],
    ] as const)("accepts %s context fixture", (_label, fixture) => {
      expect(() => validateCoachContextPacketV2(fixture)).not.toThrow();
      const meta = fixture.meta as {schemaVersion: number};
      expect(meta.schemaVersion).toBe(COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION);
    });

    it("analyze-meal-image request fixture has schemaVersion 2 context", () => {
      const request = coachContextV2Fixtures.analyzeMealImageRequest;
      const context = request.context as {meta: {schemaVersion: number}};
      expect(context.meta.schemaVersion).toBe(2);
    });
  });

  describe("endpoint payload validation", () => {
    it.each(COACH_ENDPOINT_KEYS.map((key) => [key, coachEndpointRequestFixtures[key]]))(
      "validates %s request fixture",
      (_label, fixture) => {
        const body = structuredClone(fixture.body) as Record<string, unknown>;

        if (fixture.path === "/v1/ai/analyze-meal-image") {
          expect(() => validateAnalyzeMealImagePayload(body)).not.toThrow();
        } else {
          expect(() => validatePayload(fixture.path, body)).not.toThrow();
        }

        const context = body.context as {meta?: {schemaVersion?: number}} | undefined;
        expect(context?.meta?.schemaVersion).toBe(COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION);
      }
    );
  });

  describe("schema version and legacy rejection", () => {
    it.each([
      ["schemaVersion 1", rejectedContextFixtures.schemaVersionOne],
      ["legacy AIContext shape", rejectedContextFixtures.legacyAIContextShape],
      ["empty object", rejectedContextFixtures.emptyObject],
    ] as const)("rejects %s", (_label, context) => {
      expect(() => validateCoachContextPacketV2(context)).toThrow(GatewayError);
    });

    it("rejects v1 context on classify-coach-intent via validatePayload", () => {
      expect(() => validatePayload("/v1/ai/classify-coach-intent", {
        text: "hello",
        context: {...rejectedContextFixtures.schemaVersionOne},
      })).toThrow(GatewayError);
    });

    it("rejects legacy AIContext on estimate-food via validatePayload", () => {
      expect(() => validatePayload("/v1/ai/estimate-food", {
        text: "2 eggs",
        context: {...rejectedContextFixtures.legacyAIContextShape},
      })).toThrow(GatewayError);
    });
  });

  describe("analyze-meal-image context requirement", () => {
    it("rejects missing context on analyze-meal-image fixture shape", () => {
      const body = structuredClone(coachContextV2Fixtures.analyzeMealImageRequest);
      delete body.context;

      expect(() => validateAnalyzeMealImagePayload(body)).toThrow("Missing or invalid context.");
    });

    it("accepts photo request with v2 context fixture", () => {
      const body = structuredClone(coachContextV2Fixtures.analyzeMealImageRequest);
      expect(() => validateAnalyzeMealImagePayload(body)).not.toThrow();

      const image = body.image as {base64: string; mimeType: string};
      expect(image.mimeType).toBe("image/png");
      expect(image.base64.length).toBeGreaterThan(0);

      const contextString = JSON.stringify(body.context);
      expect(contextString).not.toContain(image.base64);
    });
  });

  describe("context sanitization contract", () => {
    it("keeps confirmed food events, structured meals, missingData, training, linkedEntryId", () => {
      const probe = structuredClone(coachContextV2Fixtures.sanitizationProbe);
      const sanitized = parseCoachContextForPrompt(probe);

      const events = (sanitized?.timeline as {recentEvents: Array<Record<string, unknown>>})
        .recentEvents;
      expect(events.some((event) => event.type === "foodLogged")).toBe(true);
      expect(events.some((event) => event.type === "systemRefresh")).toBe(false);
      expect(events[0].linkedEntryId).toBe("11111111-1111-4111-8111-111111111111");

      const meals = sanitized?.recentMealsStructured as Array<{linkedEntryId?: string}>;
      expect(meals[0].linkedEntryId).toBe("11111111-1111-4111-8111-111111111111");

      const missingData = sanitized?.missingData as {stepsMissing?: boolean};
      expect(missingData.stepsMissing).toBe(true);

      const training = sanitized?.training as {workoutsToday?: number};
      expect(training.workoutsToday).toBe(1);
    });

    it("truncates oversized chat messages and strips unknown large payloads", () => {
      const probe = structuredClone(coachContextV2Fixtures.sanitizationProbe);
      const sanitized = parseCoachContextForPrompt(probe);

      expect(sanitized).not.toHaveProperty("unexpectedLargeBlob");

      const messages = sanitized?.recentChatMessages as Array<{text: string}>;
      expect(messages[0].text.length).toBeLessThanOrEqual(
        COACH_CONTEXT_LIMITS.maxChatPreviewLength + 1
      );

      const serialized = JSON.stringify(sanitized);
      expect(serialized).not.toContain("rawImageBase64");
      expect(serialized).not.toContain("unexpectedLargeBlob");
    });

    it("rich fixture survives sanitization with schemaVersion 2", () => {
      const sanitized = parseCoachContextForPrompt(coachContextV2Fixtures.rich);
      const meta = sanitized?.meta as {schemaVersion: number};
      expect(meta.schemaVersion).toBe(2);
      expect(sanitized).toHaveProperty("training");
      expect(sanitized).toHaveProperty("recentMealsStructured");
    });

    it("degraded fixture preserves missingData flags after sanitization", () => {
      const sanitized = parseCoachContextForPrompt(coachContextV2Fixtures.degraded);
      const missingData = sanitized?.missingData as {
        stepsMissing?: boolean;
        noRecentMeals?: boolean;
        healthKitUnavailable?: boolean;
      };
      expect(missingData.stepsMissing).toBe(true);
      expect(missingData.noRecentMeals).toBe(true);
      expect(missingData.healthKitUnavailable).toBe(true);
      expect(sanitized?.generationMode).toBe("degraded");
    });
  });
});
