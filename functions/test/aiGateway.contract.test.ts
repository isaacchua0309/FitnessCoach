import {openAIOutputTextForSchema} from "./fixtures/openaiFixtures";
import {createMockRequest, createMockResponse} from "./helpers/mockHttp";
import {resetGatewayGuardrailsForTests} from "../src/gatewayGuardrails";

const verifyIdTokenMock = jest.fn();

jest.mock("firebase-admin/app", () => ({
  initializeApp: jest.fn(),
}));

jest.mock("firebase-admin/auth", () => ({
  getAuth: jest.fn(() => ({
    verifyIdToken: verifyIdTokenMock,
  })),
}));

jest.mock("firebase-functions", () => ({
  logger: {
    info: jest.fn(),
    error: jest.fn(),
  },
  setGlobalOptions: jest.fn(),
}));

jest.mock("firebase-functions/v2/https", () => ({
  onRequest: jest.fn((_options: unknown, handler: unknown) => handler),
}));

jest.mock("firebase-functions/params", () => ({
  defineSecret: jest.fn(() => ({
    value: jest.fn(() => "test-openai-key"),
  })),
}));

import {handleAiGatewayRequest} from "../src/index";

const AI_GATEWAY_ROUTES = [
  {
    path: "/v1/ai/classify-coach-intent",
    body: {
      text: "hello",
      context: {},
      modelName: "gpt-5-nano",
      modelConfig: {
        cheapClassifierModel: "gpt-5-nano",
        cheapAnswerModel: "gpt-5-nano",
        strongCoachModel: "gpt-5.4-nano",
      },
    },
    assertShape: (body: Record<string, unknown>) => {
      expect(body).toHaveProperty("intentResult");
    },
  },
  {
    path: "/v1/ai/parse-command",
    body: {text: "log water", context: {}},
    assertShape: (body: Record<string, unknown>) => {
      expect(body).toHaveProperty("parsedCommand");
    },
  },
  {
    path: "/v1/ai/estimate-food",
    body: {text: "2 eggs", context: {}},
    assertShape: (body: Record<string, unknown>) => {
      expect(body).toHaveProperty("foodDrafts");
      expect(body).toHaveProperty("confidence");
      expect(body).toHaveProperty("requiresConfirmation");
      expect(body).not.toHaveProperty("intentResult");
    },
  },
  {
    path: "/v1/ai/generate-meal-advice",
    body: {question: "Should I eat pasta?", context: {}},
    assertShape: (body: Record<string, unknown>) => {
      expect(body).toHaveProperty("response");
    },
  },
  {
    path: "/v1/ai/generate-daily-review",
    body: {
      input: {
        date: "2026-07-02T12:00:00.000Z",
        calorieTarget: 2000,
        caloriesConsumed: 1500,
        caloriesRemaining: 500,
        isOverCalorieTarget: false,
        proteinTarget: 150,
        proteinConsumed: 120,
        proteinRemaining: 30,
        hasMetProteinTarget: false,
        carbsTarget: 200,
        carbsConsumed: 180,
        carbsRemaining: 20,
        fatTarget: 65,
        fatConsumed: 50,
        fatRemaining: 15,
        waterTargetMl: 2500,
        waterConsumedMl: 1800,
        waterRemainingMl: 700,
        hasMetWaterTarget: false,
        weightKg: null,
        latestWeightKg: null,
        steps: null,
        workoutCount: 0,
        workoutCaloriesBurned: 0,
        foodEntryCount: 2,
        lowConfidenceFoodCount: 0,
        topProteinFoodNames: [],
        deterministicNotes: [],
      },
      context: {},
    },
    assertShape: (body: Record<string, unknown>) => {
      expect(body).toHaveProperty("response");
    },
  },
  {
    path: "/v1/ai/parse-workout",
    body: {text: "ran 30 minutes", context: {}},
    assertShape: (body: Record<string, unknown>) => {
      expect(body).toHaveProperty("workoutDraft");
      expect(body).toHaveProperty("confidence");
      expect(body).not.toHaveProperty("parsedCommand");
    },
  },
  {
    path: "/v1/ai/parse-edit-delete",
    body: {text: "delete my last meal", context: {}},
    assertShape: (body: Record<string, unknown>) => {
      expect(body).toHaveProperty("parsedCommand");
    },
  },
  {
    path: "/v1/ai/parse-multi-action",
    body: {text: "log water and log weight", context: {}},
    assertShape: (body: Record<string, unknown>) => {
      expect(body).toHaveProperty("parsedCommand");
    },
  },
] as const;

describe("aiGateway contract", () => {
  const fetchMock = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
    resetGatewayGuardrailsForTests();
    delete process.env.FORMA_AI_REQUIRE_AUTH;
    delete process.env.FORMA_AI_BURST_PER_MINUTE;
    delete process.env.FORMA_AI_DAILY_REQUEST_LIMIT;
    delete process.env.FORMA_AI_MAX_BODY_BYTES;
    verifyIdTokenMock.mockResolvedValue({uid: "test-user"});
    global.fetch = fetchMock as unknown as typeof fetch;

    fetchMock.mockImplementation(async (_url, init) => {
      const requestBody = JSON.parse(String(init?.body));
      const schemaName = requestBody?.text?.format?.name as string;
      return {
        ok: true,
        status: 200,
        json: async () => ({
          output_text: openAIOutputTextForSchema(schemaName),
        }),
      };
    });
  });

  describe("routes", () => {
    it.each(AI_GATEWAY_ROUTES.map((route) => [route.path, route]))(
      "handles %s",
      async (_label, route) => {
        const request = createMockRequest({
          path: route.path,
          headers: {Authorization: "Bearer test-token"},
          body: route.body as Record<string, unknown>,
        });
        const response = createMockResponse();

        await handleAiGatewayRequest(request, response);

        expect(response.statusCode).toBe(200);
        expect(response.body).toBeDefined();
        route.assertShape(response.body as Record<string, unknown>);
        expect(fetchMock).toHaveBeenCalled();
      }
    );
  });

  describe("auth", () => {
    it("returns 401 when auth is required and token is missing", async () => {
      const request = createMockRequest({
        path: "/v1/ai/classify-coach-intent",
        headers: {},
      });
      const response = createMockResponse();

      await handleAiGatewayRequest(request, response);

      expect(response.statusCode).toBe(401);
      expect(response.body).toEqual({error: "Missing Firebase ID token."});
      expect(verifyIdTokenMock).not.toHaveBeenCalled();
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("allows unauthenticated requests only when FORMA_AI_REQUIRE_AUTH=0", async () => {
      process.env.FORMA_AI_REQUIRE_AUTH = "0";

      const request = createMockRequest({
        path: "/v1/ai/classify-coach-intent",
        headers: {},
      });
      const response = createMockResponse();

      await handleAiGatewayRequest(request, response);

      expect(response.statusCode).toBe(200);
      expect(verifyIdTokenMock).not.toHaveBeenCalled();
      expect((response.body as Record<string, unknown>)).toHaveProperty("intentResult");
    });
  });

  describe("routing errors", () => {
    it("returns 404 for unknown routes when authenticated", async () => {
      const request = createMockRequest({
        path: "/v1/ai/does-not-exist",
        headers: {Authorization: "Bearer test-token"},
      });
      const response = createMockResponse();

      await handleAiGatewayRequest(request, response);

      expect(response.statusCode).toBe(404);
      expect(response.body).toEqual({error: "Endpoint not found."});
      expect(fetchMock).not.toHaveBeenCalled();
    });
  });

  describe("OpenAI failures", () => {
    it("maps upstream OpenAI failure to a safe 500 backend error", async () => {
      fetchMock.mockResolvedValueOnce({
        ok: false,
        status: 500,
        json: async () => ({
          error: {
            message: "The model `gpt-5-nano` does not exist",
            type: "invalid_request_error",
            code: "model_not_found",
          },
        }),
      });

      const request = createMockRequest({
        path: "/v1/ai/classify-coach-intent",
        headers: {Authorization: "Bearer test-token"},
      });
      const response = createMockResponse();

      await handleAiGatewayRequest(request, response);

      expect(response.statusCode).toBe(500);
      expect(response.body).toEqual({
        error: "The model `gpt-5-nano` does not exist",
      });
      expect(JSON.stringify(response.body)).not.toContain("test-openai-key");
    });
  });

  describe("guardrails", () => {
    it("returns 400 when required text is missing", async () => {
      const request = createMockRequest({
        path: "/v1/ai/classify-coach-intent",
        headers: {Authorization: "Bearer test-token"},
        body: {context: {}},
      });
      const response = createMockResponse();

      await handleAiGatewayRequest(request, response);

      expect(response.statusCode).toBe(400);
      expect(response.body).toEqual({error: "Missing or invalid text."});
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("returns 413 when the request body exceeds the size limit", async () => {
      process.env.FORMA_AI_MAX_BODY_BYTES = "32";
      const request = createMockRequest({
        path: "/v1/ai/classify-coach-intent",
        headers: {Authorization: "Bearer test-token"},
        body: {text: "hello", context: {}},
        rawBody: Buffer.alloc(64, "a"),
      });
      const response = createMockResponse();

      await handleAiGatewayRequest(request, response);

      expect(response.statusCode).toBe(413);
      expect((response.body as {error: string}).error).toContain("Request body too large");
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("returns 429 when burst quota is exceeded", async () => {
      process.env.FORMA_AI_BURST_PER_MINUTE = "2";
      process.env.FORMA_AI_DAILY_REQUEST_LIMIT = "0";

      for (let i = 0; i < 2; i++) {
        const okResponse = createMockResponse();
        await handleAiGatewayRequest(
          createMockRequest({
            path: "/v1/ai/classify-coach-intent",
            headers: {Authorization: "Bearer test-token"},
            body: {text: "hello", context: {}, modelName: "gpt-5-nano", modelConfig: {}},
          }),
          okResponse
        );
        expect(okResponse.statusCode).toBe(200);
      }

      const throttled = createMockResponse();
      await handleAiGatewayRequest(
        createMockRequest({
          path: "/v1/ai/classify-coach-intent",
          headers: {Authorization: "Bearer test-token"},
          body: {text: "hello again", context: {}, modelName: "gpt-5-nano", modelConfig: {}},
        }),
        throttled
      );

      expect(throttled.statusCode).toBe(429);
      expect(throttled.body).toEqual({
        error: "Too many AI requests. Please wait a moment and try again.",
      });
    });
  });
});
