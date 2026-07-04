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

export const richCoachContextV2 = {
  ...workoutAwareCoachContextV2,
  profile: {
    age: 32,
    sex: "female",
    heightCm: 168,
    currentWeightKg: 68,
    goalWeightKg: 64,
    activityLevel: "moderatelyActive",
    trainingFrequencyPerWeek: 4,
    goalType: "Lose Fat",
  },
  recentChatMessages: [
    {
      id: "msg-1",
      role: "user",
      text: "How am I doing today?",
      timestamp: "2026-07-03T10:00:00.000Z",
    },
    {
      id: "msg-2",
      role: "assistant",
      text: "You are on track for protein.",
      timestamp: "2026-07-03T10:01:00.000Z",
    },
  ],
  currentUserMessage: "What should I eat next?",
  timeline: {
    recentEvents: [
      {
        id: "evt-food",
        type: "foodLogged",
        status: "confirmed",
        source: "coachUI",
        summary: "Logged salad",
        timestamp: "2026-07-03T09:00:00.000Z",
        linkedEntryId: "cccccccc-dddd-4eee-8fff-000000000001",
      },
      {
        id: "evt-steps",
        type: "stepsUpdated",
        status: "confirmed",
        source: "healthKit",
        summary: "Steps updated: 8000",
        timestamp: "2026-07-03T08:00:00.000Z",
      },
    ],
  },
  commonFoods: [{
    name: "salad",
    displayName: "Salad",
    frequency: 4,
    typicalCalories: 420,
  }],
  assumptions: [{
    key: "stepsSource",
    detail: "Steps sourced from HealthKit.",
    confidence: "medium",
  }],
  missingData: {
    sleepMissing: true,
  },
  healthIntelligence: {
    recoveryStatus: "moderate",
    workoutSummaryText: "Moderate run this morning.",
  },
  sourceAttribution: {
    generationMode: "live",
    sources: ["dailyLog", "healthKit"],
  },
} as const;
