export const minimalCoachContextV2 = {
  meta: {
    schemaVersion: 2,
    generatedAt: "2026-07-03T12:00:00.000Z",
    timezoneIdentifier: "UTC",
    localDate: "2026-07-03",
    localTime: "12:00",
  },
  timeline: {recentEvents: []},
  recentMealsStructured: [],
  commonFoods: [],
  missingData: {},
  assumptions: [],
  generationMode: "live",
} as const;

export const workoutAwareCoachContextV2 = {
  ...minimalCoachContextV2,
  training: {
    workoutsToday: 1,
    workouts: [{
      title: "Run",
      type: "running",
      start: "2026-07-03T08:00:00.000Z",
      end: "2026-07-03T08:35:00.000Z",
      durationMinutes: 35,
      activeEnergyKcal: 320,
      source: "healthKit",
      confidence: "medium",
    }],
    trainingLoad: "normal",
    recoveryStatus: "moderate",
    readiness: "moderate",
  },
  today: {
    steps: {value: 8000, source: "healthKit", confidence: "medium"},
    nutrition: {
      caloriesConsumed: 1200,
      caloriesRemaining: 800,
      proteinConsumed: 80,
      proteinRemaining: 70,
    },
  },
  recentMealsStructured: [{
    name: "Salad",
    calories: 420,
    proteinGrams: 28,
    carbsGrams: 30,
    fatGrams: 14,
    localDate: "2026-07-03",
    source: "manual",
    confidence: "high",
  }],
} as const;
