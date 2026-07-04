import {logger} from "firebase-functions";
import {GatewayError} from "../src/gatewayGuardrails";
import {
  isOpenAIModelConfigError,
  MODEL_CONFIG_INVALID_MESSAGE,
  normalizeReasoningEffort,
  reasoningConfigForModel,
  supportedReasoningEffortsForModel,
} from "../src/openAIReasoningEffort";

jest.mock("firebase-functions", () => ({
  logger: {
    warn: jest.fn(),
    info: jest.fn(),
    error: jest.fn(),
  },
}));

const warnMock = logger.warn as jest.Mock;

describe("openAIReasoningEffort", () => {
  const originalEffort = process.env.OPENAI_REASONING_EFFORT;

  afterEach(() => {
    if (originalEffort === undefined) {
      delete process.env.OPENAI_REASONING_EFFORT;
    } else {
      process.env.OPENAI_REASONING_EFFORT = originalEffort;
    }
    warnMock.mockClear();
  });

  describe("supportedReasoningEffortsForModel", () => {
    it("returns supported efforts for gpt-5.4-nano", () => {
      const supported = supportedReasoningEffortsForModel("gpt-5.4-nano");
      expect(supported).toEqual(new Set(["none", "low", "medium", "high", "xhigh"]));
    });

    it("returns undefined for non-gpt-5 models", () => {
      expect(supportedReasoningEffortsForModel("gpt-4o-mini")).toBeUndefined();
    });
  });

  describe("normalizeReasoningEffort", () => {
    it("normalizes minimal to low for gpt-5.4-nano", () => {
      expect(normalizeReasoningEffort("gpt-5.4-nano", "minimal")).toBe("low");
      expect(warnMock).toHaveBeenCalledWith(
        "Normalizing unsupported reasoning effort",
        expect.objectContaining({
          model: "gpt-5.4-nano",
          requestedEffort: "minimal",
          normalizedEffort: "low",
        })
      );
    });

    it("passes valid efforts through unchanged", () => {
      for (const effort of ["none", "low", "medium", "high", "xhigh"] as const) {
        expect(normalizeReasoningEffort("gpt-5.4-nano", effort)).toBe(effort);
      }
      expect(warnMock).not.toHaveBeenCalled();
    });

    it("fails locally for unsupported efforts", () => {
      expect(() => normalizeReasoningEffort("gpt-5.4-nano", "turbo"))
        .toThrow(GatewayError);
      try {
        normalizeReasoningEffort("gpt-5.4-nano", "turbo");
      } catch (error) {
        expect(error).toBeInstanceOf(GatewayError);
        expect((error as GatewayError).category).toBe("model_config_invalid");
        expect((error as GatewayError).message).toBe(MODEL_CONFIG_INVALID_MESSAGE);
      }
    });
  });

  describe("reasoningConfigForModel", () => {
    it("defaults analyze-meal-image strong model to low effort", () => {
      delete process.env.OPENAI_REASONING_EFFORT;
      expect(reasoningConfigForModel("gpt-5.4-nano")).toEqual({effort: "low"});
    });

    it("never returns minimal even when env requests it", () => {
      process.env.OPENAI_REASONING_EFFORT = "minimal";
      expect(reasoningConfigForModel("gpt-5.4-nano")).toEqual({effort: "low"});
    });

    it("returns undefined for non-gpt-5 models", () => {
      expect(reasoningConfigForModel("gpt-4o-mini")).toBeUndefined();
    });
  });

  describe("isOpenAIModelConfigError", () => {
    it("detects unsupported reasoning effort errors from OpenAI", () => {
      expect(isOpenAIModelConfigError(
        "Unsupported value: 'minimal' is not supported with the 'gpt-5.4-nano' model."
      )).toBe(true);
      expect(isOpenAIModelConfigError("Rate limit exceeded")).toBe(false);
    });
  });
});
