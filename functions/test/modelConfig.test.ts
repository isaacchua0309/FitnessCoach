import {
  allowedModelNames,
  DEFAULT_MODELS,
  readModelConfig,
  resolveModel,
} from "../src/modelConfig";

describe("modelConfig", () => {
  const envKeys = [
    "OPENAI_MODEL",
    "OPENAI_CLASSIFIER_MODEL",
    "OPENAI_STRONG_MODEL",
    "OPENAI_FALLBACK_MODEL",
  ] as const;

  const originalEnv: Record<string, string | undefined> = {};

  beforeEach(() => {
    for (const key of envKeys) {
      originalEnv[key] = process.env[key];
      delete process.env[key];
    }
  });

  afterEach(() => {
    for (const key of envKeys) {
      if (originalEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = originalEnv[key];
      }
    }
  });

  describe("readModelConfig", () => {
    it("returns built-in defaults when env is unset", () => {
      expect(readModelConfig()).toEqual(DEFAULT_MODELS);
    });

    it("reads overrides from env", () => {
      process.env.OPENAI_MODEL = "custom-default";
      process.env.OPENAI_CLASSIFIER_MODEL = "custom-cheap";
      process.env.OPENAI_STRONG_MODEL = "custom-strong";
      process.env.OPENAI_FALLBACK_MODEL = "custom-fallback";

      expect(readModelConfig()).toEqual({
        cheap: "custom-cheap",
        default: "custom-default",
        strong: "custom-strong",
        fallback: "custom-fallback",
      });
    });

    it("falls back cheap tier to OPENAI_MODEL then default", () => {
      process.env.OPENAI_MODEL = "from-model";
      expect(readModelConfig().cheap).toBe("from-model");

      delete process.env.OPENAI_MODEL;
      expect(readModelConfig().cheap).toBe(DEFAULT_MODELS.cheap);
    });
  });

  describe("resolveModel", () => {
    it("selects tier models from config", () => {
      process.env.OPENAI_CLASSIFIER_MODEL = "tier-cheap";
      process.env.OPENAI_STRONG_MODEL = "tier-strong";

      expect(resolveModel({tier: "cheap"})).toBe("tier-cheap");
      expect(resolveModel({tier: "strong"})).toBe("tier-strong");
    });

    it("honors client modelName only when allowlisted", () => {
      process.env.OPENAI_MODEL = "gpt-5-nano";
      process.env.OPENAI_STRONG_MODEL = "gpt-5.4-nano";

      expect(resolveModel({modelName: "gpt-5.4-nano"})).toBe("gpt-5.4-nano");
      expect(resolveModel({modelName: "gpt-4o-mini"})).toBe("gpt-5-nano");
    });

    it("ignores unsupported client model names", () => {
      process.env.OPENAI_MODEL = "allowed-default";
      const allowed = [...allowedModelNames()];
      const unsupported = "gpt-4o-mini";

      expect(allowed).not.toContain(unsupported);
      expect(resolveModel({modelName: unsupported})).toBe("allowed-default");
    });
  });
});
