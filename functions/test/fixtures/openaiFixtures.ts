const nullEntities = {
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
};

const sampleFoodDraft = {
  mealType: "lunch",
  name: "Eggs",
  quantity: 2,
  unit: "count",
  calories: 140,
  protein: 12,
  carbs: 1,
  fat: 10,
  fiber: null,
  sodium: null,
  source: "aiTextEstimate",
  confidence: "medium",
  imageUrl: null,
  notes: null,
};

const sampleWorkoutDraft = {
  name: "Run",
  durationMinutes: 30,
  estimatedCaloriesBurned: 250,
  intensity: "moderate",
  recoveryDemand: "moderate",
  notes: null,
  exerciseSets: [],
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
    entities: nullEntities,
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
  ai_food_estimate_response: {
    foodDrafts: [sampleFoodDraft],
    confidence: "medium",
    requiresConfirmation: true,
    assistantMessage: null,
  },
  ai_coach_response: {
    message: "A banana has about 105 calories.",
    confidence: "high",
    followUpSuggestions: [],
  },
  ai_workout_parse_response: {
    workoutDraft: sampleWorkoutDraft,
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
