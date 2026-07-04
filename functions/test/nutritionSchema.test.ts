import {openAIOutputBySchemaName} from "./fixtures/openaiFixtures";

const REQUIRED_PAYLOAD_KEYS = [
  "foodName",
  "caloriesKcal",
  "proteinGrams",
  "carbsGrams",
  "fatGrams",
  "leftFoodName",
  "rightFoodName",
  "query",
];

describe("nutrition estimate schema fixtures", () => {
  it("uses strict nullable payload keys for all suggested actions", () => {
    const schemas = [
      "nutrition_estimate_response",
      "nutrition_comparison_response",
    ] as const;

    for (const schemaName of schemas) {
      const response = openAIOutputBySchemaName[schemaName];
      const actions = response.suggestedActions as Array<{payload: Record<string, unknown>}>;
      for (const action of actions) {
        expect(Object.keys(action.payload).sort()).toEqual([...REQUIRED_PAYLOAD_KEYS].sort());
        for (const key of REQUIRED_PAYLOAD_KEYS) {
          const value = action.payload[key];
          expect(value === null || typeof value === "string").toBe(true);
        }
      }
    }
  });
});
