import {deriveCalorieRange, resolveCalorieRange, validateCalorieRangeBounds} from "../src/foodCalorieRange";

describe("foodCalorieRange", () => {
  it("derives wider ranges for lower confidence", () => {
    const high = deriveCalorieRange(500, "high");
    const medium = deriveCalorieRange(500, "medium");
    const low = deriveCalorieRange(500, "low");

    expect(high.upper - high.lower).toBeLessThan(medium.upper - medium.lower);
    expect(medium.upper - medium.lower).toBeLessThan(low.upper - low.lower);
  });

  it("prefers explicit bounds when valid", () => {
    const range = resolveCalorieRange(520, "medium", 450, 750);
    expect(range).toEqual({lower: 450, upper: 750});
  });

  it("falls back to derived range for invalid explicit bounds", () => {
    const range = resolveCalorieRange(300, "medium", 400, 200);
    expect(range.lower).toBeLessThan(300);
    expect(range.upper).toBeGreaterThan(300);
  });

  it("rejects ranges where lower exceeds estimated calories", () => {
    const errors = validateCalorieRangeBounds(500, 520, 650, "medium", "meal");
    expect(errors.some((error) => error.includes("lower bound exceeds estimated calories"))).toBe(true);
  });

  it("rejects ranges that are too narrow for low confidence", () => {
    const errors = validateCalorieRangeBounds(600, 590, 610, "low", "meal");
    expect(errors.some((error) => error.includes("too narrow"))).toBe(true);
  });
});
