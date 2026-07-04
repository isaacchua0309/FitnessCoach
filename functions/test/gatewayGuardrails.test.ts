import {
  normalizeGatewayText,
  resetGatewayGuardrailsForTests,
} from "../src/gatewayGuardrails";
import {minimalCoachContextV2} from "./fixtures/coachContextPacketV2";
import {openAIOutputTextForSchema} from "./fixtures/openaiFixtures";
import {createMockRequest, createMockResponse} from "./helpers/mockHttp";

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

describe("gatewayGuardrails normalization", () => {
  const fetchMock = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
    resetGatewayGuardrailsForTests();
    delete process.env.FORMA_AI_REQUIRE_AUTH;
    verifyIdTokenMock.mockResolvedValue({uid: "test-user"});
    global.fetch = fetchMock as unknown as typeof fetch;
    fetchMock.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({output_text: "{}"}),
    });
  });

  it("accepts nutrition estimate requests with question field", async () => {
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

    const request = createMockRequest({
      path: "/v1/ai/generate-nutrition-estimate",
      headers: {Authorization: "Bearer test-token"},
      body: {
        question: "Calories in a Big Mac",
        context: {...minimalCoachContextV2},
      },
    });
    const response = createMockResponse();

    await handleAiGatewayRequest(request, response);

    expect(response.statusCode).toBe(200);
    expect(fetchMock).toHaveBeenCalled();
    const requestBody = JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body));
    const input = JSON.parse(requestBody.input);
    expect(input.question).toBe("Calories in a Big Mac");
  });

  it("accepts nutrition estimate requests with legacy text field", async () => {
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

    const request = createMockRequest({
      path: "/v1/ai/generate-nutrition-estimate",
      headers: {Authorization: "Bearer test-token"},
      body: {
        text: "Calories in a Big Mac",
        context: {...minimalCoachContextV2},
      },
    });
    const response = createMockResponse();

    await handleAiGatewayRequest(request, response);

    expect(response.statusCode).toBe(200);
    expect(fetchMock).toHaveBeenCalled();
    const requestBody = JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body));
    const input = JSON.parse(requestBody.input);
    expect(input.question).toBe("Calories in a Big Mac");
  });

  it("strips zero-width characters and normalizes full-width digits", () => {
    expect(normalizeGatewayText("５００ml wa\u200Bter")).toBe("500ml water");
  });

  it("returns 400 for empty text after normalization", async () => {
    const request = createMockRequest({
      path: "/v1/ai/classify-coach-intent",
      headers: {Authorization: "Bearer test-token"},
      body: {text: "   \u200B", context: {...minimalCoachContextV2}},
    });
    const response = createMockResponse();

    await handleAiGatewayRequest(request, response);

    expect(response.statusCode).toBe(400);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("accepts full-width digit input within the text limit", async () => {
    const request = createMockRequest({
      path: "/v1/ai/classify-coach-intent",
      headers: {Authorization: "Bearer test-token"},
      body: {text: "５００ml water", context: {...minimalCoachContextV2}, modelName: "gpt-5-nano", modelConfig: {}},
    });
    const response = createMockResponse();

    await handleAiGatewayRequest(request, response);

    expect(response.statusCode).toBe(200);
    const requestBody = JSON.parse(String(fetchMock.mock.calls[0]?.[1]?.body));
    const input = JSON.parse(requestBody.input);
    expect(input.text).toBe("500ml water");
  });

  it("returns 400 when normalized text exceeds the max length", async () => {
    const request = createMockRequest({
      path: "/v1/ai/classify-coach-intent",
      headers: {Authorization: "Bearer test-token"},
      body: {text: "a".repeat(4001), context: {...minimalCoachContextV2}},
    });
    const response = createMockResponse();

    await handleAiGatewayRequest(request, response);

    expect(response.statusCode).toBe(400);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("returns 413 for image body above the 2MB limit", async () => {
    process.env.FORMA_AI_MAX_BODY_BYTES_WITH_IMAGE = `${2 * 1024 * 1024}`;
    const request = createMockRequest({
      path: "/v1/ai/estimate-food",
      headers: {Authorization: "Bearer test-token"},
      body: {
        text: "meal photo",
        imageJPEGBase64: "a".repeat(100),
        context: {...minimalCoachContextV2},
      },
      rawBody: Buffer.alloc(2 * 1024 * 1024 + 1, "a"),
    });
    const response = createMockResponse();

    await handleAiGatewayRequest(request, response);

    expect(response.statusCode).toBe(413);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("returns 413 for analyze-meal-image body above the 2MB limit", async () => {
    process.env.FORMA_AI_MAX_BODY_BYTES_WITH_IMAGE = `${2 * 1024 * 1024}`;
    const request = createMockRequest({
      path: "/v1/ai/analyze-meal-image",
      headers: {Authorization: "Bearer test-token"},
      body: {
        image: {
          mimeType: "image/png",
          base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
        },
      },
      rawBody: Buffer.alloc(2 * 1024 * 1024 + 1, "a"),
    });
    const response = createMockResponse();

    await handleAiGatewayRequest(request, response);

    expect(response.statusCode).toBe(413);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
