//
//  AppleHealthTrainingStrategyTests.swift
//  Fitness CoachTests
//
//  Stage 11 — Apple Health-powered training strategy (mocks only, no live HealthKit).
//

import XCTest
@testable import Fitness_Coach

// MARK: - 1. Integration state formatting

@MainActor
final class TrainingIntegrationStateFormattingTests: XCTestCase {

    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "AppleHealthTrainingStrategyTests")!
        userDefaults.removePersistentDomain(forName: "AppleHealthTrainingStrategyTests")
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "AppleHealthTrainingStrategyTests")
        userDefaults = nil
        super.tearDown()
    }

    func testSettingsStatusLabelsForLifecycleStates() {
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsStatusLabel(for: .notConnected),
            TrainingIntegrationCopy.settingsStatusNotConnected
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsStatusLabel(for: .connected),
            TrainingIntegrationCopy.settingsStatusConnected
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsStatusLabel(for: .denied),
            TrainingIntegrationCopy.settingsStatusAccessDenied
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsStatusLabel(for: .unavailable),
            TrainingIntegrationCopy.settingsStatusUnavailable
        )
    }

    func testHealthTrainingServiceMapsAllAuthorizationOutcomesWithMock() async {
        let notConnected = HealthTrainingService(
            authorizer: MockHealthKitTrainingAuthorizing(status: .notDetermined),
            userDefaults: userDefaults
        )
        let notConnectedState = await notConnected.refreshState()
        XCTAssertEqual(notConnectedState, .notConnected)

        let connected = HealthTrainingService(
            authorizer: MockHealthKitTrainingAuthorizing(status: .sharingAuthorized),
            userDefaults: userDefaults
        )
        let connectedState = await connected.refreshState()
        XCTAssertEqual(connectedState, .connected)

        let denied = HealthTrainingService(
            authorizer: MockHealthKitTrainingAuthorizing(status: .sharingDenied),
            userDefaults: userDefaults
        )
        let deniedState = await denied.refreshState()
        XCTAssertEqual(deniedState, .denied)

        let unavailable = HealthTrainingService(
            authorizer: MockHealthKitTrainingAuthorizing(isHealthDataAvailable: false),
            userDefaults: userDefaults
        )
        let unavailableState = await unavailable.refreshState()
        XCTAssertEqual(unavailableState, .unavailable)
    }

    func testIntegrationDetailCopyIsUserFriendly() {
        XCTAssertFalse(
            TrainingIntegrationCopy.settingsDetailDescription(for: .connected)
                .localizedCaseInsensitiveContains("HealthKit")
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsDetailDescription(for: .denied),
            "Turn on workout access in Health → Apps → Forma."
        )
    }

    func testGateFlagsPerIntegrationState() {
        XCTAssertTrue(TrainingIntegrationState.notConnected.showsConnectionGate)
        XCTAssertFalse(TrainingIntegrationState.connected.showsConnectionGate)
        XCTAssertTrue(TrainingIntegrationState.denied.showsConnectionGate)
        XCTAssertFalse(TrainingIntegrationState.unavailable.showsConnectionGate)
        XCTAssertFalse(TrainingIntegrationState.unavailable.isConnected)
    }
}

// MARK: - 2. Training summary aggregation

final class TrainingSummaryAggregationStrategyTests: XCTestCase {

    private let calendar = TrainingStrategyTestSupport.utcCalendar
    private let referenceNow = TrainingStrategyTestSupport.referenceNow

    func testNoWorkoutsProducesInactiveWeeklySummary() {
        let weekly = TrainingInsightsAggregator.weeklySummary(from: [], calendar: calendar)
        XCTAssertFalse(weekly.hasActivity)
        XCTAssertEqual(weekly.workoutDays, 0)
        XCTAssertEqual(weekly.workoutCount, 0)
        XCTAssertEqual(weekly.totalDurationMinutes, 0)
        XCTAssertNil(weekly.activeCalories)
    }

    func testSingleWorkoutThisWeek() {
        let workouts = [
            TrainingStrategyTestSupport.makeWorkout(
                daysAgo: 0,
                minutes: 40,
                calories: 280,
                name: "Strength training",
                calendar: calendar,
                asOf: referenceNow
            )
        ]

        let summary = TrainingInsightsAggregator.summary(
            workouts: workouts,
            asOf: referenceNow,
            calendar: calendar
        )

        XCTAssertEqual(summary.weekly.workoutCount, 1)
        XCTAssertEqual(summary.weekly.workoutDays, 1)
        XCTAssertEqual(summary.weekly.totalDurationMinutes, 40)
        XCTAssertEqual(summary.weekly.activeCalories, 280)
    }

    func testMultipleWorkoutsThisWeekAggregateDaysDurationAndCalories() {
        let workouts = [
            TrainingStrategyTestSupport.makeWorkout(
                daysAgo: 0, minutes: 45, calories: 320, name: "Strength training",
                calendar: calendar, asOf: referenceNow
            ),
            TrainingStrategyTestSupport.makeWorkout(
                daysAgo: 0, minutes: 20, calories: 100, name: "Walking",
                calendar: calendar, asOf: referenceNow
            ),
            TrainingStrategyTestSupport.makeWorkout(
                daysAgo: 3, minutes: 50, calories: 300, name: "Running",
                calendar: calendar, asOf: referenceNow
            )
        ]

        let summary = TrainingInsightsAggregator.summary(
            workouts: workouts,
            asOf: referenceNow,
            calendar: calendar
        )

        XCTAssertEqual(summary.weekly.workoutCount, 3)
        XCTAssertEqual(summary.weekly.workoutDays, 2)
        XCTAssertEqual(summary.weekly.totalDurationMinutes, 115)
        XCTAssertEqual(summary.weekly.activeCalories, 720)
    }

    func testDurationTotalsWithoutActiveCalories() {
        let workouts = [
            TrainingStrategyTestSupport.makeWorkout(
                daysAgo: 1, minutes: 35, calories: nil, name: "Yoga",
                calendar: calendar, asOf: referenceNow
            )
        ]

        let weekly = TrainingInsightsAggregator.weeklySummary(from: workouts, calendar: calendar)
        XCTAssertEqual(weekly.totalDurationMinutes, 35)
        XCTAssertNil(weekly.activeCalories)
    }

    func testInsightsModelUsesMockReaderWithoutHealthKit() async {
        let workout = TrainingStrategyTestSupport.makeWorkout(
            daysAgo: 1, minutes: 30, calories: 200, name: "Run",
            calendar: calendar, asOf: referenceNow
        )
        let reader = await MainActor.run {
            MockHealthKitWorkoutReader(workouts: [workout])
        }
        let model = await MainActor.run {
            TrainingInsightsModel(
                workoutReader: reader,
                dateProvider: FixedStrategyDateProvider(now: referenceNow),
                calendar: calendar
            )
        }

        await model.refresh()

        let state = await MainActor.run { model.viewState }
        await MainActor.run {
            guard case .loaded(let summary) = state else {
                XCTFail("Expected loaded summary, got \(state)")
                return
            }
            XCTAssertEqual(summary.weekly.workoutCount, 1)
            XCTAssertEqual(reader.fetchCallCount, 1)
        }
    }
}

// MARK: - 3. Coach workout intent policy

@MainActor
final class CoachWorkoutIntentPolicyTests: XCTestCase {

    func testWorkoutLogIntentDoesNotCreateMutationOrPendingConfirmation() async throws {
        let container = try AppContainer(inMemory: true)
        try TrainingStrategyTestSupport.seedProfile(in: container)
        container.healthTrainingService.resetStubFlags()

        let service = StrategyStubClassifierAIService(
            classifyResult: TrainingStrategyTestSupport.stubCoachIntent(.logWorkout)
        )
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogService: container.dailyLogService,
            workoutLogService: container.workoutLogService,
            aiService: service,
            userProfileService: container.userProfileService,
            aiCommandParsingEnabled: true,
            trainingInsightsStore: container.trainingInsightsStore
        )

        await model.send("30 min run")

        XCTAssertEqual(service.classifyCoachIntentCallCount, 1)
        XCTAssertEqual(service.parseWorkoutCallCount, 0)
        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(try container.workoutLogService.getWorkouts(for: Date()).count, 0)
    }

    func testWorkoutLogNotConnectedCopy() async throws {
        let container = try AppContainer(inMemory: true)
        try TrainingStrategyTestSupport.seedProfile(in: container)
        container.healthTrainingService.resetStubFlags()
        await container.trainingInsightsStore.refresh()

        let message = await coachWorkoutRedirectMessage(
            container: container,
            classifyResult: TrainingStrategyTestSupport.stubCoachIntent(.logWorkout)
        )

        XCTAssertEqual(message, TrainingIntegrationCopy.coachWorkoutLogNotConnected)
    }

    func testWorkoutLogConnectedCopy() async throws {
        let container = try AppContainer(inMemory: true)
        try TrainingStrategyTestSupport.seedProfile(in: container)
        container.healthTrainingService.setStubConnected(true)
        await container.trainingInsightsStore.refresh()

        let message = await coachWorkoutRedirectMessage(
            container: container,
            classifyResult: TrainingStrategyTestSupport.stubCoachIntent(.logWorkout)
        )

        XCTAssertEqual(message, TrainingIntegrationCopy.coachWorkoutLogConnected)
    }

    func testConfirmationPolicyRejectsWorkoutMutation() {
        let draft = WorkoutDraft(
            name: "Run",
            durationMinutes: 30,
            estimatedCaloriesBurned: 300,
            intensity: nil,
            recoveryDemand: nil,
            notes: nil,
            exerciseSets: []
        )

        if case .reject(let message) = ConfirmationPolicy.decision(forWorkout: draft) {
            XCTAssertEqual(message, TrainingIntegrationCopy.coachWorkoutMutationUnavailable)
        } else {
            XCTFail("Expected workout logging to be rejected")
        }
    }

    private func coachWorkoutRedirectMessage(
        container: AppContainer,
        classifyResult: CoachIntentResult
    ) async -> String {
        let service = StrategyStubClassifierAIService(classifyResult: classifyResult)
        let model = CoachModel(
            actionCenter: container.actionCenter,
            dailyLogService: container.dailyLogService,
            workoutLogService: container.workoutLogService,
            aiService: service,
            userProfileService: container.userProfileService,
            aiCommandParsingEnabled: true,
            trainingInsightsStore: container.trainingInsightsStore
        )
        await model.send("logged a workout")
        return model.messages.last(where: { $0.role == .assistant })?.text ?? ""
    }
}

// MARK: - 4. Today training row

final class TodayTrainingRowStrategyTests: XCTestCase {

    func testNotConnectedShowsConnectAppleHealth() throws {
        let workout = try workoutGoal(
            integration: .notConnected,
            dataSource: .appleHealth,
            appleHealthWorkoutCount: nil
        )
        XCTAssertEqual(workout.label, FormaProductCopy.Training.Integration.connectAppleHealth)
        XCTAssertEqual(workout.tapAction, .openTrainingInsights)
    }

    func testConnectedWithWorkoutTodayShowsRecordedLabel() throws {
        let workout = try workoutGoal(
            integration: .connected,
            dataSource: .appleHealth,
            appleHealthWorkoutCount: 1
        )
        XCTAssertEqual(workout.label, FormaProductCopy.Today.workoutsToday(1))
        XCTAssertTrue(workout.isComplete)
    }

    func testConnectedWithoutWorkoutTodayShowsNeutralCopy() throws {
        let workout = try workoutGoal(
            integration: .connected,
            dataSource: .appleHealth,
            appleHealthWorkoutCount: 0
        )
        XCTAssertEqual(workout.label, FormaProductCopy.Today.statusNoAppleHealthWorkoutToday)
        XCTAssertTrue(workout.isInformational)
        XCTAssertFalse(workout.showsChevron)
        XCTAssertFalse(workout.isActionable)
    }

    private func workoutGoal(
        integration: TrainingIntegrationState,
        dataSource: TrainingDataSource,
        appleHealthWorkoutCount: Int?
    ) throws -> TodayGoalItem {
        let goals = TodayGoalsBuilder.goals(
            from: TodayTrainingRowStrategyTests.dashboardState,
            trainingIntegration: integration,
            trainingDataSource: dataSource,
            appleHealthWorkoutCount: appleHealthWorkoutCount
        )
        return try XCTUnwrap(goals.last { $0.kind == .workout })
    }

    private static let dashboardState = TodayDashboardState(
        date: Date(),
        calorieSummary: CalorieSummary(
            consumed: 500, target: 1_800, remaining: 1_300, progress: 0.28, isOverTarget: false
        ),
        macroSummary: MacroSummary(
            protein: MacroProgress(consumed: 170, target: 180, remaining: 10, progress: 0.94),
            carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
            fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
        ),
        waterSummary: WaterSummary(
            consumedMl: 3_000, targetMl: 3_150, remainingMl: 150,
            progress: Double(3_000) / Double(3_150)
        ),
        weightSummary: TodayWeightSummary(weightKg: 90.15, displayText: "90.15 kg"),
        stepsSummary: nil,
        workoutSummary: TodayWorkoutSummary(
            workoutCaloriesBurned: 0, workoutCount: 0, hasWorkout: false
        ),
        foodEntries: [],
        hasDailyLog: true,
        dailyReview: nil,
        coachingNote: nil,
        todayFocus: FormaProductCopy.Today.focusOnTrack,
        dailyBrief: TodayDailyBrief(
            greeting: "Good morning.", priorities: [], recommendation: "Stay consistent today."
        ),
        streaks: StreakSummary(
            loggingStreak: 0, proteinStreak: 0, hydrationStreak: 0, workoutStreak: 0
        ),
        userName: nil
    )
}

// MARK: - 5. Journey training rows

@MainActor
final class JourneyTrainingRowStrategyTests: XCTestCase {

    private let calendar = TrainingStrategyTestSupport.utcCalendar
    private let referenceNow = TrainingStrategyTestSupport.referenceNow

    func testNotConnectedDoesNotShowMisleadingZeroWorkoutDays() {
        let snapshot = JourneyStateBuilder.weeklySnapshot(
            weekLogs: [],
            training: .locked
        )

        XCTAssertEqual(snapshot.training, .locked)
        XCTAssertEqual(
            TrainingStrategyTestSupport.journeyWorkoutRowLabel(for: snapshot.training),
            FormaProductCopy.Journey.WeeklySnapshot.trainingConnectAppleHealth
        )
        XCTAssertFalse(
            TrainingStrategyTestSupport.journeyWorkoutRowLabel(for: snapshot.training)
                .contains(FormaProductCopy.Journey.workoutNone)
        )
    }

    func testConnectedUsesAppleHealthSummaryForWorkoutDays() {
        let status = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: .connected,
            dataSource: .appleHealth,
            weekWorkouts: TrainingInsightsPreviewData.sampleWorkouts,
            asOf: referenceNow,
            calendar: calendar
        )

        let snapshot = JourneyStateBuilder.weeklySnapshot(weekLogs: [], training: status)

        guard case .connected(let days, _, _) = snapshot.training else {
            return XCTFail("Expected connected training status")
        }
        XCTAssertEqual(days, 2)
        XCTAssertEqual(
            TrainingStrategyTestSupport.journeyWorkoutRowLabel(for: snapshot.training),
            FormaProductCopy.Journey.WeeklySnapshot.workoutDaysLine(days: 2)
        )
    }

    func testConnectedEmptyShowsCalmEmptyCopyNotZeroDays() {
        let snapshot = JourneyStateBuilder.weeklySnapshot(
            weekLogs: [],
            training: .connectedEmpty
        )

        XCTAssertEqual(
            TrainingStrategyTestSupport.journeyWorkoutRowLabel(for: snapshot.training),
            FormaProductCopy.Journey.WeeklySnapshot.statusNotStarted
        )
    }
}

// MARK: - 6. Detailed analytics training section

@MainActor
final class JourneyDetailedAnalyticsTrainingStrategyTests: XCTestCase {

    private let calendar = TrainingStrategyTestSupport.utcCalendar

    func testAnalyticsHiddenWhenNotConnected() {
        let analytics = JourneyTrainingSummaryBuilder.workoutAnalytics(
            integrationState: .notConnected,
            dataSource: .appleHealth,
            workouts: TrainingInsightsPreviewData.sampleWorkouts,
            rangeDays: 28,
            calendar: calendar
        )
        XCTAssertNil(analytics)
        XCTAssertEqual(
            TrainingStrategyTestSupport.journeyTrainingAnalyticsDisplay(
                training: .locked,
                workoutSummary: analytics
            ),
            .hidden
        )
    }

    func testAnalyticsEmptyStateWhenConnectedWithoutWorkouts() {
        let training = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: .connected,
            dataSource: .appleHealth,
            weekWorkouts: [],
            calendar: calendar
        )
        let analytics = JourneyTrainingSummaryBuilder.workoutAnalytics(
            integrationState: .connected,
            dataSource: .appleHealth,
            workouts: [],
            rangeDays: 28,
            calendar: calendar
        )

        XCTAssertEqual(training, .connectedEmpty)
        XCTAssertNil(analytics)
        XCTAssertEqual(
            TrainingStrategyTestSupport.journeyTrainingAnalyticsDisplay(
                training: training,
                workoutSummary: analytics
            ),
            .emptyConnected
        )
    }

    func testAnalyticsMetricsWhenConnectedWithHealthWorkouts() {
        let training = JourneyTrainingSummaryBuilder.weeklyTrainingStatus(
            integrationState: .connected,
            dataSource: .appleHealth,
            weekWorkouts: TrainingInsightsPreviewData.sampleWorkouts,
            asOf: TrainingStrategyTestSupport.referenceNow,
            calendar: calendar
        )
        let analytics = JourneyTrainingSummaryBuilder.workoutAnalytics(
            integrationState: .connected,
            dataSource: .appleHealth,
            workouts: TrainingInsightsPreviewData.sampleWorkouts,
            rangeDays: 28,
            calendar: calendar
        )

        XCTAssertNotNil(analytics)
        XCTAssertTrue(analytics?.isFromAppleHealth == true)
        XCTAssertEqual(
            TrainingStrategyTestSupport.journeyTrainingAnalyticsDisplay(
                training: training,
                workoutSummary: analytics
            ),
            .metrics
        )
    }
}

// MARK: - Test doubles

private struct FixedStrategyDateProvider: DateProviding {
    let now: Date

    func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

private final class StrategyStubClassifierAIService: AIServiceProtocol, @unchecked Sendable {
    var classifyCoachIntentCallCount = 0
    var parseWorkoutCallCount = 0
    let classifyResult: CoachIntentResult

    init(classifyResult: CoachIntentResult) {
        self.classifyResult = classifyResult
    }

    func classifyCoachIntent(
        _ text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        classifyCoachIntentCallCount += 1
        return classifyResult
    }

    func estimateFood(prompt: String, context: AIContext) async throws -> AIFoodEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateMealAdvice(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub advice.", confidence: .medium)
    }

    func parseWorkout(prompt: String, context: AIContext) async throws -> AIWorkoutParseResponse {
        parseWorkoutCallCount += 1
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: AIContext) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub review.", confidence: .medium)
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: AIContext
    ) async throws -> AICoachResponse {
        AICoachResponse(message: "Stub review.", confidence: .medium)
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}
