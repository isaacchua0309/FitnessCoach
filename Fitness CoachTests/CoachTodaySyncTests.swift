//
//  CoachTodaySyncTests.swift
//  Fitness CoachTests
//
//  Verifies Coach meal saves propagate to Today dashboard state via AppRefreshCenter.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachTodaySyncTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var coachHarness: CoachRoutingIntegrationTestSupport.Harness!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness(cloudUID: "test-user-1")
        coachHarness = CoachRoutingIntegrationTestSupport.Harness(
            fitness: harness,
            healthTrainingService: HealthTrainingService(
                userDefaults: UserDefaults(suiteName: UUID().uuidString)!
            ),
            trainingInsightsStore: TrainingInsightsStore(
                integration: HealthTrainingService(
                    userDefaults: UserDefaults(suiteName: UUID().uuidString)!
                )
            )
        )
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: coachHarness)
    }

    override func tearDown() {
        harness = nil
        coachHarness = nil
        super.tearDown()
    }

    func testCoachMealSaveUpdatesTodayDashboard() async throws {
        let todayModel = makeTodayModel()
        await todayModel.loadToday()

        guard case .loaded(let baseline) = todayModel.viewState else {
            return XCTFail("Expected loaded Today state before Coach save")
        }
        XCTAssertTrue(baseline.meals.isEmpty)
        XCTAssertEqual(baseline.mission.calorieSummary.consumed, 0)
        XCTAssertEqual(baseline.nextBestAction.reason, .logBreakfast)

        let refreshTokenBefore = harness.refreshCenter.refreshToken
        let coachModel = coachHarness.makeCoach(
            aiService: CoachTodaySyncFoodEstimateService(
                response: FoodLoggingGoldenFixtures.case4Response
            )
        )

        await coachModel.send(FoodLoggingGoldenFixtures.case4Prompt)
        XCTAssertNotNil(coachModel.pendingConfirmation)

        await coachModel.confirmPendingFromBar()
        XCTAssertNil(coachModel.pendingConfirmation)

        XCTAssertEqual(harness.refreshCenter.refreshToken, refreshTokenBefore + 1)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)

        await todayModel.refresh()

        guard case .loaded(let updated) = todayModel.viewState else {
            return XCTFail("Expected loaded Today state after Coach save refresh")
        }

        let meal = FoodLoggingGoldenFixtures.case4MealDraft
        XCTAssertEqual(updated.meals.entryCount, 1)
        XCTAssertEqual(updated.mission.calorieSummary.consumed, meal.totalCalories)
        XCTAssertEqual(
            updated.mission.calorieSummary.remaining,
            baseline.mission.calorieSummary.target - meal.totalCalories
        )
        XCTAssertEqual(
            updated.macroHydration.macroSummary.protein.remaining,
            baseline.macroHydration.macroSummary.protein.target - meal.totalProtein,
            accuracy: 0.01
        )
        XCTAssertNotEqual(updated.nextBestAction.reason, .logBreakfast)
    }

    func testFailedCoachMealSaveDoesNotBumpRefreshOrTodayTotals() async throws {
        let todayModel = makeTodayModel()
        await todayModel.loadToday()

        guard case .loaded(let baseline) = todayModel.viewState else {
            return XCTFail("Expected loaded Today state")
        }

        let refreshTokenBefore = harness.refreshCenter.refreshToken
        let executor = CoachMutationExecutor(
            actionCenter: harness.actionCenter,
            dailyLogReader: harness.dailyLogService,
            healthActivityQuery: harness.healthActivityQuery,
            mutationHistory: CoachMutationHistory()
        )

        let invalidDraft = FoodLogDraft(
            displayName: "",
            components: [
                FoodComponent(
                    name: "invalid",
                    quantity: 1,
                    unit: "g",
                    calories: -10,
                    protein: 0,
                    carbs: 0,
                    fat: 0
                )
            ],
            confidence: .low,
            source: .aiTextEstimate
        )

        let response = executor.executeLogFood(invalidDraft)
        XCTAssertFalse(response.isEmpty)

        XCTAssertEqual(harness.refreshCenter.refreshToken, refreshTokenBefore)
        XCTAssertTrue(try harness.actionCenter.getFoodEntries(for: harness.today).isEmpty)

        await todayModel.refresh()

        guard case .loaded(let afterFailedSave) = todayModel.viewState else {
            return XCTFail("Expected loaded Today state after failed save refresh")
        }

        XCTAssertEqual(afterFailedSave.mission.calorieSummary, baseline.mission.calorieSummary)
        XCTAssertEqual(afterFailedSave.meals.entryCount, baseline.meals.entryCount)
        XCTAssertEqual(afterFailedSave.nextBestAction.reason, baseline.nextBestAction.reason)
    }

    func testDuplicateConfirmDoesNotCreateSecondMealEntry() async throws {
        let coachModel = coachHarness.makeCoach(
            aiService: CoachTodaySyncFoodEstimateService(
                response: FoodLoggingGoldenFixtures.case4Response
            )
        )

        await coachModel.send(FoodLoggingGoldenFixtures.case4Prompt)
        await coachModel.confirmPendingFromBar()
        await coachModel.confirmPendingFromBar()

        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)
    }

    // MARK: - Helpers

    private func makeTodayModel() -> TodayModel {
        let hydrationContext = TodayHydrationGate.resolve(
            authState: .signedIn(uid: "test-user-1"),
            profile: try? harness.profileService.getCurrentProfile(),
            calendar: Calendar.current,
            now: harness.today
        )

        let reviewService = ReviewService(
            store: harness.store,
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.base.foodLogService,
            waterLogService: harness.base.waterLogService,
            weightLogService: harness.weightLogService,
            healthActivityQuery: harness.healthActivityQuery,
            userProfileService: harness.profileService,
            aiService: AIService(llmClient: MockLLMClient())
        )

        return TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: reviewService,
            userProfileReader: harness.profileService,
            healthActivityQuery: harness.healthActivityQuery,
            hydrationContextProvider: { hydrationContext },
            authStateProvider: { .signedIn(uid: "test-user-1") }
        )
    }
}

// MARK: - Test doubles

@MainActor
private final class CoachTodaySyncFoodEstimateService: AIServiceProtocol, @unchecked Sendable {
    private let response: AIFoodEstimateResponse

    init(response: AIFoodEstimateResponse) {
        self.response = response
    }

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachIntentResult(
            intent: .logFood,
            confidence: 0.9,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false,
            action: nil
        )
    }

    func estimateFood(
        prompt: String,
        context: CoachContextPacketV2,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        response
    }

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateMealAdvice(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateNutritionEstimate(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateNutritionComparison(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionComparisonResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseWorkout(prompt: String, context: CoachContextPacketV2) async throws -> AIWorkoutParseResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseEditOrDelete(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func parseMultiAction(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReview(context: CoachContextPacketV2) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: CoachContextPacketV2
    ) async throws -> AICoachResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}
