/* eslint-disable @typescript-eslint/no-explicit-any, require-jsdoc, max-len, operator-linebreak */

export interface CompoundDishSpec {
  id: string;
  label: string;
  patterns: RegExp[];
  minComponents: number;
  decompositionHint: string;
}

export interface CompoundFoodPromptAnalysis {
  matchedDishes: CompoundDishSpec[];
  minRequiredComponents: number;
  isAmbiguousServing: boolean;
  requiresAssumptions: boolean;
  hasHugePortionHint: boolean;
  isContextReference: boolean;
}

const COMPOUND_DISHES: CompoundDishSpec[] = [
  {
    id: "chicken_rice",
    label: "chicken rice",
    patterns: [/\bchicken rice\b/i, /\bhainanese chicken\b/i, /\bhainanese\b/i],
    minComponents: 3,
    decompositionHint: "rice, chicken, skin/oil/sauce if relevant",
  },
  {
    id: "nasi_lemak",
    label: "nasi lemak",
    patterns: [/\bnasi lemak\b/i],
    minComponents: 4,
    decompositionHint: "coconut rice, egg, sambal, ikan bilis/peanuts, protein",
  },
  {
    id: "cai_fan",
    label: "cai fan",
    patterns: [/\bcai fan\b/i, /\bcai png\b/i, /\beconomy rice\b/i, /\bmixed rice\b/i],
    minComponents: 2,
    decompositionHint: "rice plus each selected dish",
  },
  {
    id: "mala",
    label: "mala",
    patterns: [/\bmala\b/i, /\bmalatang\b/i],
    minComponents: 3,
    decompositionHint: "noodles/rice if stated, meat, vegetables, oil/sauce",
  },
  {
    id: "ban_mian",
    label: "ban mian",
    patterns: [/\bban mian\b/i, /\bbanmian\b/i],
    minComponents: 2,
    decompositionHint: "noodles, broth/toppings, egg or minced meat if stated",
  },
  {
    id: "yong_tau_foo",
    label: "yong tau foo",
    patterns: [/\byong tau foo\b/i, /\bytf\b/i],
    minComponents: 2,
    decompositionHint: "selected items plus soup/sauce/noodles if stated",
  },
  {
    id: "prata",
    label: "prata",
    patterns: [/\bprata\b/i, /\broti prata\b/i],
    minComponents: 1,
    decompositionHint: "prata plus curry or sugar if stated",
  },
  {
    id: "bubble_tea",
    label: "bubble tea",
    patterns: [/\bbubble tea\b/i, /\bboba\b/i, /\bmilk tea\b/i, /\bpearl milk tea\b/i],
    minComponents: 2,
    decompositionHint: "drink base, milk/sugar, toppings",
  },
];

const HUGE_PORTION_PATTERN =
  /\b(huge|extra large|double|2x|two bowls?|large portion|big portion|super size|upsized)\b/i;

const AMBIGUOUS_SERVING_PATTERNS = [
  /\brice bowl\b/i,
  /\bbowl of rice\b/i,
  /^rice bowl$/i,
  /\bjust a bowl\b/i,
];

const CONTEXT_REFERENCE_PATTERN =
  /\b(same as|like my|like the)\s+(breakfast|lunch|dinner|usual|yesterday)\b/i;

const VAGUE_PORTION_PATTERN =
  /\b(one|a|an|small|medium|large)\s+(bowl|plate|cup|serving|portion)\b/i;

const PROTEIN_SHAKE_PATTERN = /\bprotein shake\b/i;

function countCaiFanDishes(text: string): number {
  const lower = text.toLowerCase();
  if (!COMPOUND_DISHES.find((d) => d.id === "cai_fan")?.patterns.some((p) => p.test(lower))) {
    return 0;
  }

  const withMatch = lower.match(/\bwith\s+(.+)$/i);
  if (!withMatch) {
    return 1;
  }

  const dishPart = withMatch[1];
  const dishes = dishPart
    .split(/\band\b|,|\+/i)
    .map((part) => part.trim())
    .filter((part) => part.length > 2);
  return Math.max(dishes.length, 1);
}

function prataMinComponents(text: string): number {
  const lower = text.toLowerCase();
  if (/\b(with curry|curry|sugar|dhall|dhal)\b/i.test(lower)) {
    return 2;
  }
  return 1;
}

export function matchCompoundDishes(text: string): CompoundDishSpec[] {
  const normalized = text.trim();
  if (PROTEIN_SHAKE_PATTERN.test(normalized)) {
    return [];
  }
  return COMPOUND_DISHES.filter((dish) =>
    dish.patterns.some((pattern) => pattern.test(normalized))
  );
}

export function isKnownCompoundDish(text: string): boolean {
  return matchCompoundDishes(text).length > 0;
}

export function hasHugePortionHint(text: string): boolean {
  return HUGE_PORTION_PATTERN.test(text);
}

export function isAmbiguousServingPrompt(text: string): boolean {
  const normalized = text.trim();
  if (AMBIGUOUS_SERVING_PATTERNS.some((pattern) => pattern.test(normalized))) {
    return true;
  }
  if (/^rice bowl$/i.test(normalized) || /^log rice bowl$/i.test(normalized)) {
    return true;
  }
  return false;
}

export function isContextReferencePrompt(text: string): boolean {
  return CONTEXT_REFERENCE_PATTERN.test(text);
}

export function analyzeCompoundFoodPrompt(text: string): CompoundFoodPromptAnalysis {
  const normalized = text.trim();
  const matchedDishes = matchCompoundDishes(normalized);
  const hasHuge = hasHugePortionHint(normalized);
  const ambiguous = isAmbiguousServingPrompt(normalized);
  const contextRef = isContextReferencePrompt(normalized);

  let minRequiredComponents = 0;
  if (matchedDishes.length > 0) {
    minRequiredComponents = Math.max(
      ...matchedDishes.map((dish) => {
        if (dish.id === "cai_fan") {
          return 1 + countCaiFanDishes(normalized);
        }
        if (dish.id === "prata") {
          return prataMinComponents(normalized);
        }
        return dish.minComponents;
      })
    );
  }

  const requiresAssumptions =
    ambiguous ||
    contextRef ||
    matchedDishes.length > 0 ||
    VAGUE_PORTION_PATTERN.test(normalized);

  return {
    matchedDishes,
    minRequiredComponents,
    isAmbiguousServing: ambiguous,
    requiresAssumptions,
    hasHugePortionHint: hasHuge,
    isContextReference: contextRef,
  };
}

export function compoundDishDecompositionPrompt(): string {
  return COMPOUND_DISHES.map(
    (dish) => `- ${dish.label} → ${dish.decompositionHint}`
  ).join("\n");
}

export function componentNamesMatchCompound(
  componentNames: string[],
  dish: CompoundDishSpec
): boolean {
  const combined = componentNames.join(" ").toLowerCase();
  switch (dish.id) {
  case "chicken_rice":
    return combined.includes("rice") && combined.includes("chicken");
  case "nasi_lemak":
    return combined.includes("rice") &&
      (combined.includes("sambal") || combined.includes("egg") || combined.includes("lemak"));
  case "cai_fan":
    return combined.includes("rice");
  case "mala":
    return (combined.includes("meat") || combined.includes("beef") || combined.includes("pork")
        || combined.includes("chicken") || combined.includes("seafood"))
      && (combined.includes("vegetable") || combined.includes("veg") || combined.includes("mushroom")
        || combined.includes("noodle") || combined.includes("rice"));
  case "ban_mian":
    return combined.includes("noodle") || combined.includes("mian");
  case "yong_tau_foo":
    return combined.includes("tofu") || combined.includes("fish") || combined.includes("item")
      || combined.includes("soup");
  case "prata":
    return combined.includes("prata") || combined.includes("roti");
  case "bubble_tea":
    return combined.includes("tea") || combined.includes("boba") || combined.includes("pearl")
      || combined.includes("milk");
  default:
    return true;
  }
}
