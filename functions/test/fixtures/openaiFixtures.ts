const sampleFoodExtractionMeal = {
  meal_name: "Eggs",
  meal_type: "lunch",
  components: [
    {
      name: "Eggs",
      quantity: 2,
      unit: "count",
      state: "unknown",
      calories: 140,
      protein_g: 12,
      carbs_g: 1,
      fat_g: 10,
      confidence: "medium",
      source_text: "2 eggs",
    },
  ],
  totals: {
    calories: 140,
    protein_g: 12,
    carbs_g: 1,
    fat_g: 10,
  },
  confidence: "medium",
  assumptions: [],
  warnings: [],
};

export const openAIOutputBySchemaName: Record<string, Record<string, unknown>> = {
  coach_intent_result: {
    intent: "general_conversation",
    confidence: 0.9,
    domain: "general",
    requiresAppMutation: false,
    requiresUserContext: false,
    canAnswerWithCheapModel: true,
    requiresEscalation: false,
    entities: {
      food: null,
      meal: null,
      amountMl: null,
      weightKg: null,
      durationMinutes: null,
      distanceKm: null,
      calories: null,
      proteinGrams: null,
      carbsGrams: null,
      fatGrams: null,
      quantity: null,
      unit: null,
      notes: null,
    },
    action: null,
    reason: null,
  },
  ai_parsed_command: {
    originalText: "log water",
    intent: "logWater",
    actions: [],
    confidence: "high",
    requiresConfirmation: false,
    assistantMessage: null,
    reasoningSummary: null,
  },
  ai_food_extraction_response: {
    meals: [sampleFoodExtractionMeal],
    requiresConfirmation: true,
    assistantMessage: null,
  },
  ai_coach_response: {
    message: "A banana has about 105 calories.",
    confidence: "high",
    followUpSuggestions: [],
  },
  ai_workout_parse_response: {
    workoutDraft: {
      name: "Run",
      durationMinutes: 30,
      estimatedCaloriesBurned: 250,
      intensity: "moderate",
      recoveryDemand: "moderate",
      notes: null,
      exerciseSets: [],
    },
    assistantMessage: "Ready to log this run?",
    confidence: "medium",
  },
};

export function openAIOutputTextForSchema(schemaName: string): string {
  const payload = openAIOutputBySchemaName[schemaName];
  if (!payload) {
    throw new Error(`Missing OpenAI fixture for schema ${schemaName}`);
  }
  return JSON.stringify(payload);
}
