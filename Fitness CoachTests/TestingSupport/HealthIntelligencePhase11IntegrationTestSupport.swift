//
//  HealthIntelligencePhase11IntegrationTestSupport.swift
//  Fitness CoachTests
//
//  Shared harness, fixtures, and mocks for Phase 11–15 Health Intelligence integration tests.
//

import Foundation
@testable import Fitness_Coach

enum HealthIntelligencePhase11FlagPreset: Equatable {
    case off
    case fullRollout

    var loadEnabled: Bool {
        switch self {
        case .off: return false
        case .fullRollout: return true
        }
    }

    var uiEnabled: Bool {
        switch self {
        case .off: return false
        case .fullRollout: return true
        }
    }

    var coachContextEnabled: Bool {
        switch self {
        case .off: return false
        case .fullRollout: return true
        }
    }

    var weeklyReviewEnabled: Bool {
        switch self {
        case .off: return false
        case .fullRollout: return true
        }
    }

    #if DEBUG
    var testFlags: TestHealthIntelligenceFeatureFlags {
        TestHealthIntelligenceFeatureFlags(
            healthIntelligenceEnabled: true,
            healthIntelligenceEnginesEnabled: true,
            healthIntelligenceUIEnabled: uiEnabled,
            healthIntelligenceCoachContextEnabled: coachContextEnabled,
            healthIntelligenceWeeklyReviewEnabled: weeklyReviewEnabled
        )
    }
    #endif
}

enum HealthIntelligencePhase11SnapshotScenario {
    case fullHealth
    case partialNoSleepNoHRV
    case workoutsOnly
    case stepsOnly
    case noHealthData
}

enum HealthIntelligencePhase11IntegrationTestSupport {

    static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static func referenceDay(calendar: Calendar = makeCalendar()) -> Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
    }

    static func snapshot(
        _ scenario: HealthIntelligencePhase11SnapshotScenario,
        on day: Date,
        calendar: Calendar = makeCalendar()
    ) -> HealthIntelligenceSnapshot {
        let dayStart = calendar.startOfDay(for: day)

        switch scenario {
        case .fullHealth:
            return HealthIntelligenceSnapshot(
                date: dayStart,
                recovery: RecoverySummary(
                    score: 84,
                    status: .ready,
                    title: "Ready to train",
                    explanation: "Sleep and recovery signals look supportive for your usual plan today.",
                    recommendedTraining: "Your usual training plan looks reasonable today.",
                    recommendedNutrition: "Stick with your normal protein and hydration rhythm.",
                    confidence: .high,
                    contributingFactors: [],
                    missingSignals: []
                ),
                workout: WorkoutSummary(
                    hasWorkout: true,
                    primaryWorkoutType: .strength,
                    title: "Strength training",
                    workoutCount: 1,
                    totalDurationMinutes: 45,
                    totalActiveCalories: 320,
                    intensity: .moderate,
                    demand: .moderate,
                    latestWorkoutStart: dayStart.addingTimeInterval(3_600),
                    latestWorkoutEnd: dayStart.addingTimeInterval(6_600),
                    nutritionAdvice: "Aim for 20–35g protein in your next meal.",
                    hydrationAdviceMl: 500,
                    explanation: "Strength training added solid volume today.",
                    confidence: .high,
                    sourceSummary: "Based on synced workouts."
                ),
                activity: ActivitySummary(steps: 8_450, activeEnergyKcal: 420, exerciseMinutes: 45),
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: PlanHealthConfidence(score: 0.82, label: "Strong fit"),
                nextBestAction: NextBestAction(
                    id: "log-protein",
                    title: "Log protein",
                    message: "Add a protein-rich meal to support recovery.",
                    ctaTitle: "Log meal",
                    destination: .logMeal,
                    priority: 1,
                    reason: .postWorkoutRecovery,
                    createdAt: dayStart,
                    expiresAt: nil
                )
            )

        case .partialNoSleepNoHRV:
            return HealthIntelligenceSnapshot(
                date: dayStart,
                recovery: RecoverySummary(
                    score: nil,
                    status: .unknown,
                    title: "Limited recovery estimate",
                    explanation: "Workout data is available, but sleep and HRV are missing.",
                    recommendedTraining: "Train based on how you feel.",
                    recommendedNutrition: "Stay on your usual plan.",
                    confidence: .low,
                    contributingFactors: [],
                    missingSignals: [.sleep, .hrv, .restingHeartRate]
                ),
                workout: WorkoutSummary(
                    hasWorkout: true,
                    primaryWorkoutType: .running,
                    title: "Running",
                    workoutCount: 1,
                    totalDurationMinutes: 35,
                    totalActiveCalories: 280,
                    intensity: .moderate,
                    demand: .moderate,
                    latestWorkoutStart: dayStart.addingTimeInterval(3_600),
                    latestWorkoutEnd: dayStart.addingTimeInterval(5_700),
                    nutritionAdvice: "Refuel with protein and carbs.",
                    hydrationAdviceMl: 400,
                    explanation: "Running logged today.",
                    confidence: .moderate,
                    sourceSummary: "Based on synced workouts."
                ),
                activity: ActivitySummary(steps: 6_200, activeEnergyKcal: nil, exerciseMinutes: 35),
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: PlanHealthConfidence(score: 0.52, label: "Limited fit"),
                nextBestAction: .none
            )

        case .workoutsOnly:
            return HealthIntelligenceSnapshot(
                date: dayStart,
                recovery: RecoverySummary(
                    score: nil,
                    status: .unknown,
                    title: "Recovery unclear",
                    explanation: "Workout data is available without broader recovery signals.",
                    recommendedTraining: "Use how you feel before adding intensity.",
                    recommendedNutrition: "Stay on your usual plan.",
                    confidence: .low,
                    contributingFactors: [],
                    missingSignals: [.sleep, .hrv, .restingHeartRate, .activity]
                ),
                workout: WorkoutSummary(
                    hasWorkout: true,
                    primaryWorkoutType: .cycling,
                    title: "Cycling",
                    workoutCount: 1,
                    totalDurationMinutes: 40,
                    totalActiveCalories: 260,
                    intensity: .moderate,
                    demand: .moderate,
                    latestWorkoutStart: dayStart.addingTimeInterval(3_600),
                    latestWorkoutEnd: dayStart.addingTimeInterval(6_000),
                    nutritionAdvice: "Refuel after your ride.",
                    hydrationAdviceMl: 450,
                    explanation: "Cycling logged today.",
                    confidence: .moderate,
                    sourceSummary: "Based on synced workouts."
                ),
                activity: ActivitySummary(steps: nil, activeEnergyKcal: nil, exerciseMinutes: 40),
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: PlanHealthConfidence(score: 0.45, label: "Limited fit"),
                nextBestAction: .none
            )

        case .stepsOnly:
            return HealthIntelligenceSnapshot(
                date: dayStart,
                recovery: RecoverySummary(
                    score: nil,
                    status: .unknown,
                    title: "Recovery unclear",
                    explanation: "Steps are available, but recovery signals are still building.",
                    recommendedTraining: "Use how you feel before adding intensity.",
                    recommendedNutrition: "Stay on your usual plan.",
                    confidence: .low,
                    contributingFactors: [],
                    missingSignals: [.sleep, .hrv, .restingHeartRate, .workouts, .trainingLoad]
                ),
                workout: nil,
                activity: ActivitySummary(steps: 11_500, activeEnergyKcal: nil, exerciseMinutes: nil),
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: PlanHealthConfidence(score: 0.48, label: "Limited fit"),
                nextBestAction: .none
            )

        case .noHealthData:
            return HealthIntelligenceSnapshot(
                date: dayStart,
                recovery: .unknown,
                workout: nil,
                activity: .empty,
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: .unknown,
                nextBestAction: NextBestAction(
                    id: "connect-health",
                    title: "Connect Apple Health",
                    message: "Enable Apple Health to unlock recovery and activity insights.",
                    ctaTitle: "Connect",
                    destination: .none,
                    priority: 1,
                    reason: .connectHealth,
                    createdAt: dayStart,
                    expiresAt: nil
                )
            )
        }
    }

    static func availability(
        connected: Bool,
        cachedDayCount: Int = 0,
        permission: HealthSignalAccess = .available
    ) -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: connected,
            permissionStatus: connected
                ? .uniform(permission, isHealthDataAvailable: true)
                : .uniform(.denied, isHealthDataAvailable: true),
            cachedDayCount: cachedDayCount
        )
    }

    static func stepsOnlyAvailability() -> HealthDataAvailability {
        HealthIntelligencePipelineFixtures.stepsOnlyAvailability()
    }

    static func workoutsOnlyAvailability() -> HealthDataAvailability {
        HealthIntelligencePipelineFixtures.workoutsOnlyAvailability()
    }

    static func deniedAvailability() -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.denied, isHealthDataAvailable: true),
            cachedDayCount: 0
        )
    }

    static func completedWeeklyReview(endingOn day: Date, calendar: Calendar = makeCalendar()) -> WeeklyHealthReview {
        let weekEnd = calendar.startOfDay(for: day)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Solid training week",
            summary: "You logged consistent workouts and kept protein on track most days.",
            stats: WeeklyStats(
                totalWorkouts: 4,
                totalWorkoutMinutes: 210,
                totalActiveCalories: 1_420,
                averageSteps: 8_200,
                totalSteps: 57_400,
                proteinHitDays: 5,
                calorieTargetHitDays: 4,
                waterHitDays: 3,
                averageRecoveryScore: 68,
                lowRecoveryDays: 1,
                weightChangeKg: -0.3,
                loggingConsistencyDays: 6
            ),
            wins: ["4 workouts logged"],
            risks: ["Hydration dipped mid-week"],
            nextWeekFocus: ["Front-load water"],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: weekEnd
        )
    }

    @MainActor
    static func makeReviewService(harness: FitnessActionCenterTestSupport.Harness) -> ReviewService {
        ReviewService(
            store: harness.store,
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.base.foodLogService,
            waterLogService: harness.base.waterLogService,
            weightLogService: harness.weightLogService,
            healthActivityQuery: harness.healthActivityQuery,
            userProfileService: harness.profileService,
            aiService: AIService(llmClient: MockLLMClient())
        )
    }

    @MainActor
    static func makeTrainingStore(connected: Bool) -> TrainingInsightsStore {
        TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(
                refreshResult: connected ? .connected : .notConnected
            )
        )
    }

    @MainActor
    static func makeTodayModel(
        harness: FitnessActionCenterTestSupport.Harness,
        flags: HealthIntelligencePhase11FlagPreset,
        snapshotProvider: Phase11TrackingSnapshotService,
        hydrationContext: TodayHydrationContext? = nil,
        healthRepository: Phase11MockHealthDataRepository? = nil
    ) -> TodayModel {
        let resolvedContext = hydrationContext ?? TodayHydrationGate.resolve(
            authState: .signedIn(uid: "test-user-1"),
            profile: try? harness.profileService.getCurrentProfile(),
            calendar: Calendar.current,
            now: harness.today
        )

        return TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: makeReviewService(harness: harness),
            userProfileReader: harness.profileService,
            healthActivityQuery: harness.healthActivityQuery,
            healthIntelligenceSnapshotProvider: snapshotProvider,
            healthDataRepository: healthRepository,
            hydrationContextProvider: { resolvedContext },
            authStateProvider: { .signedIn(uid: "test-user-1") },
            healthIntelligenceLoadEnabled: { flags.loadEnabled },
            healthIntelligenceUIEnabled: { flags.uiEnabled }
        )
    }

    @MainActor
    static func makeJourneyModel(
        harness: FitnessActionCenterTestSupport.Harness,
        flags: HealthIntelligencePhase11FlagPreset,
        snapshotProvider: Phase11TrackingSnapshotService,
        weeklyReviewService: Phase11TrackingWeeklyReviewService,
        healthRepository: Phase11MockHealthDataRepository,
        trainingConnected: Bool = true,
        workouts: [HealthWorkoutRecord] = []
    ) -> JourneyModel {
        JourneyModel(
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            userProfileReader: harness.profileService,
            trainingInsightsStore: makeTrainingStore(connected: trainingConnected),
            workoutReader: MockHealthKitWorkoutReader(workouts: workouts),
            healthIntelligenceSnapshotProvider: snapshotProvider,
            weeklyReviewService: weeklyReviewService,
            healthIntelligenceEngine: NoOpHealthIntelligenceEngine(),
            healthCacheStore: MemoryHealthCacheStore(),
            healthActivityQuery: harness.healthActivityQuery,
            healthDataRepository: healthRepository,
            healthIntelligenceLoadEnabled: { flags.loadEnabled },
            healthIntelligenceUIEnabled: { flags.uiEnabled }
        )
    }

    @MainActor
    static func makePlanModel(
        harness: FitnessActionCenterTestSupport.Harness,
        flags: HealthIntelligencePhase11FlagPreset,
        snapshotProvider: Phase11TrackingSnapshotService,
        baselineProvider: Phase11MockBaselineProvider,
        healthRepository: Phase11MockHealthDataRepository,
        trainingConnected: Bool = true
    ) -> PlanModel {
        PlanModel(
            actionCenter: harness.actionCenter,
            userProfileReader: harness.profileService,
            planTargetCalculator: harness.targetService,
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            trainingInsightsStore: makeTrainingStore(connected: trainingConnected),
            healthBaselineService: baselineProvider,
            healthIntelligenceSnapshotProvider: snapshotProvider,
            healthDataRepository: healthRepository,
            healthIntelligenceLoadEnabled: { flags.loadEnabled },
            healthIntelligenceUIEnabled: { flags.uiEnabled }
        )
    }

    static func healthIntelligenceProductionSourcePaths() -> [String] {
        [
            "Fitness Coach/Features/Today/Components/HealthIntelligence/",
            "Fitness Coach/Features/Journey/Components/HealthIntelligence/",
            "Fitness Coach/Features/Plan/Components/HealthIntelligence/",
            "Fitness Coach/DesignSystem/Components/HealthIntelligenceCardLayout.swift",
        ]
    }
}

// MARK: - Tracking mocks

final class Phase11TrackingSnapshotService: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?
    var shouldFailLoad = false
    private(set) var loadCallCount = 0
    private(set) var refreshCallCount = 0

    func refreshTodaySnapshot(calendar: Calendar) async {
        refreshCallCount += 1
    }

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        loadCallCount += 1
        if shouldFailLoad {
            return nil
        }
        return snapshot
    }
}

final class Phase11TrackingWeeklyReviewService: WeeklyReviewServing, @unchecked Sendable {
    var latestReview: WeeklyHealthReview?
    private(set) var getLatestCallCount = 0
    private(set) var generateCallCount = 0
    var lastForceRefresh = false

    func getLatestCompletedWeeklyReview(calendar: Calendar) async -> WeeklyHealthReview? {
        getLatestCallCount += 1
        return latestReview
    }

    func getWeeklyReview(for weekStartDate: Date, calendar: Calendar) async -> WeeklyHealthReview? {
        latestReview
    }

    func generateWeeklyReview(
        for weekStartDate: Date,
        forceRefresh: Bool,
        allowPreview: Bool,
        calendar: Calendar
    ) async -> WeeklyHealthReview? {
        generateCallCount += 1
        lastForceRefresh = forceRefresh
        return latestReview
    }
}

final class Phase11MockHealthDataRepository: HealthDataRepositorying, @unchecked Sendable {
    var availability: HealthDataAvailability

    init(availability: HealthDataAvailability) {
        self.availability = availability
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] { [] }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        .empty(for: date)
    }

    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] {
        []
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { [] }

    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] {
        []
    }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }

    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] {
        []
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }

    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] {
        []
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        availability
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: 0, refreshedAt: Date())
    }
}

struct Phase11MockBaselineProvider: HealthBaselineProviding {
    var context: HealthBaselineContext = .empty(for: Date())

    func buildContext(for targetDate: Date, calendar: Calendar) async -> HealthBaselineContext {
        context
    }
}
