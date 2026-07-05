//
//  TodayLoggingFlowTests.swift
//  Fitness CoachTests
//
//  Canonical coverage for the simplified Today logging flow (Coach meals + inline water).
//
//  UI assertions use dashboard/coordinator composition tests because the project has no
//  XCUITest target. See `TodayLoggingFlowCompositionTests`.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

// MARK: - Unit / state

@MainActor
final class TodayLoggingFlowTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var coordinator: TodayActionCoordinator!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness(cloudUID: "test-user-1")
        coordinator = TodayActionCoordinator(
            actionCenter: harness.actionCenter,
            logDate: { [harness] in harness.today }
        )
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        _ = try harness.actionCenter.ensureTodayLog()
    }

    override func tearDown() {
        harness = nil
        coordinator = nil
        super.tearDown()
    }

    // 1. Today Log Meal action creates CoachLaunchIntent.logMeal.
    func testLogMealQuickActionCreatesCoachLaunchIntent() {
        var launchedIntent: CoachLaunchIntent?
        coordinator.onOpenCoach = { launchedIntent = $0 }

        coordinator.performQuickAction(.logMeal)

        XCTAssertEqual(launchedIntent, .logMeal(mealType: nil))
    }

    func testLogMealFromMealsPreviewCreatesCoachLaunchIntentWithMealType() {
        var launchedIntent: CoachLaunchIntent?
        coordinator.onOpenCoach = { launchedIntent = $0 }

        coordinator.logMeal(for: .breakfast)

        XCTAssertEqual(launchedIntent, .logMeal(mealType: .breakfast))
    }

    // 2. Manual Entry action is not present in Today quick actions.
    func testManualEntryIsNotPresentInTodayQuickActions() {
        let quickActionTitles = [
            FormaProductCopy.Today.QuickActions.title(for: .logMeal),
            FormaProductCopy.Today.QuickActions.title(for: .scanFood)
        ]

        for title in quickActionTitles {
            XCTAssertFalse(title.localizedCaseInsensitiveContains("manual"))
        }

        XCTAssertFalse(
            FormaProductCopy.Today.QuickActions.sectionTitle
                .localizedCaseInsensitiveContains("manual")
        )
        XCTAssertFalse(TodayQuickActionPolicy.isVisible(.scanFood, isScanFoodAvailable: false))
        XCTAssertTrue(TodayQuickActionPolicy.isVisible(.logMeal))
    }

    // 3. Water +250 updates water total.
    func testAddWater250UpdatesWaterTotal() throws {
        XCTAssertTrue(coordinator.addWater(amountMl: 250))

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.waterConsumedMl, 250)
    }

    // 4. Water +500 updates water total.
    func testAddWater500UpdatesWaterTotal() throws {
        XCTAssertTrue(coordinator.addWater(amountMl: 500))

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.waterConsumedMl, 500)
    }

    func testSequentialWaterAddsAccumulateTotal() throws {
        XCTAssertTrue(coordinator.addWater(amountMl: 250))
        XCTAssertTrue(coordinator.addWater(amountMl: 500))

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.waterConsumedMl, 750)
    }

    // 5. Water failure shows recoverable error.
    func testWaterFailureShowsRecoverableError() throws {
        let tokenBefore = harness.refreshCenter.refreshToken
        let logBefore = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(logBefore.waterConsumedMl, 0)

        XCTAssertFalse(coordinator.addWater(amountMl: 0))

        XCTAssertEqual(
            coordinator.snackbarMessage,
            TodayTransientFeedback(
                message: FormaProductCopy.Today.Water.logFailedMessage,
                style: .error
            )
        )
        XCTAssertEqual(harness.refreshCenter.refreshToken, tokenBefore)

        let logAfter = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(logAfter.waterConsumedMl, 0)
    }

    // 6. Coach meal save refreshes Today totals.
    func testCoachMealSaveRefreshesTodayTotals() async throws {
        let todayModel = makeTodayModel()
        await todayModel.loadToday()

        guard case .loaded(let baseline) = todayModel.viewState else {
            return XCTFail("Expected loaded Today state")
        }
        XCTAssertEqual(baseline.mission.calorieSummary.consumed, 0)

        let refreshTokenBefore = harness.refreshCenter.refreshToken
        let coachHarness = CoachRoutingIntegrationTestSupport.Harness(
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
        let coachModel = coachHarness.makeCoach(
            aiService: TodayLoggingFlowFoodEstimateService(
                response: FoodLoggingGoldenFixtures.case4Response
            )
        )

        await coachModel.send(FoodLoggingGoldenFixtures.case4Prompt)
        await coachModel.confirmPendingFromBar()

        XCTAssertEqual(harness.refreshCenter.refreshToken, refreshTokenBefore + 1)

        await todayModel.refresh()

        guard case .loaded(let updated) = todayModel.viewState else {
            return XCTFail("Expected loaded Today state after Coach save")
        }

        let meal = FoodLoggingGoldenFixtures.case4MealDraft
        XCTAssertEqual(updated.mission.calorieSummary.consumed, meal.totalCalories)
        XCTAssertEqual(updated.meals.entryCount, 1)
    }

    // 7. Manual form remains available for fallback/editing routes.
    func testManualFormRemainsAvailableForFallbackAndEditingRoutes() throws {
        var formState = FoodEntryFormState()
        formState.mealType = .lunch
        formState.name = "Fallback meal"
        formState.caloriesText = "410"
        formState.proteinText = "32"
        formState.carbsText = "28"
        formState.fatText = "12"

        coordinator.saveMeal(from: formState)

        let entry = try XCTUnwrap(try harness.actionCenter.getFoodEntries(for: harness.today).first)
        XCTAssertEqual(entry.name, "Fallback meal")

        coordinator.openEditFood(entry)
        XCTAssertEqual(coordinator.editFoodPresentation?.entry.id, entry.id)

        XCTAssertEqual(FormaProductCopy.FoodForm.createCustomFoodTitle, "Create custom food")
        XCTAssertEqual(FormaProductCopy.FoodForm.editNutritionTitle, "Edit nutrition")
        XCTAssertTrue(FoodEntryFormMode.createCustomFood.showsAdvancedNutrients)
        XCTAssertFalse(FoodEntryFormMode.editNutrition.showsAdvancedNutrients)
        XCTAssertTrue(FoodEntryFormMode.coachEdit(estimateContext: nil, confidence: .high).showsEstimateBanner)
    }

    func testWaterTapDebounceDurationIsConfigured() {
        XCTAssertEqual(FormaProductCopy.Today.Water.tapDebounceSeconds, 0.35, accuracy: 0.001)
    }

    func testCoachSaveThenTodayRefreshMatchesForegroundReturnScenario() async throws {
        let todayModel = makeTodayModel()
        await todayModel.loadToday()

        let refreshTokenBefore = harness.refreshCenter.refreshToken
        let coachHarness = CoachRoutingIntegrationTestSupport.Harness(
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
        let coachModel = coachHarness.makeCoach(
            aiService: TodayLoggingFlowFoodEstimateService(
                response: FoodLoggingGoldenFixtures.case4Response
            )
        )

        await coachModel.send(FoodLoggingGoldenFixtures.case4Prompt)
        await coachModel.confirmPendingFromBar()
        XCTAssertEqual(harness.refreshCenter.refreshToken, refreshTokenBefore + 1)

        await todayModel.refresh()

        guard case .loaded(let afterForegroundRefresh) = todayModel.viewState else {
            return XCTFail("Expected loaded state after foreground-style refresh")
        }

        XCTAssertEqual(
            afterForegroundRefresh.mission.calorieSummary.consumed,
            FoodLoggingGoldenFixtures.case4MealDraft.totalCalories
        )
        XCTAssertEqual(afterForegroundRefresh.meals.entryCount, 1)
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

// MARK: - UI composition (no XCUITest target)

@MainActor
final class TodayLoggingFlowCompositionTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var coordinator: TodayActionCoordinator!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness(cloudUID: "test-user-1")
        coordinator = TodayActionCoordinator(
            actionCenter: harness.actionCenter,
            logDate: { [harness] in harness.today }
        )
        try harness.seedProfile(ownerUID: "test-user-1")
        _ = try harness.actionCenter.ensureTodayLog()
    }

    override func tearDown() {
        harness = nil
        coordinator = nil
        super.tearDown()
    }

    // 1. Today screen shows Log Meal and Water.
    func testTodayDashboardShowsLogMealAndWaterSections() {
        let state = TodayDashboardFixtures.emptyDay()

        XCTAssertTrue(state.mission.showsLogMealCTA)
        XCTAssertEqual(
            FormaProductCopy.Today.Mission.logMealCTA,
            "Log meal with Coach"
        )
        XCTAssertGreaterThan(state.macroHydration.waterSummary.targetMl, 0)
        XCTAssertEqual(
            FormaProductCopy.Today.Water.sectionTitle,
            "Water"
        )
        XCTAssertEqual(
            TodayActionCoordinator.defaultWaterPresetAmountsMl,
            [250, 500, 750, 1_000]
        )
    }

    // 2. Today screen does not show Manual Entry.
    func testTodayDashboardDoesNotExposeManualEntryQuickAction() {
        XCTAssertEqual(
            FormaProductCopy.Today.QuickActions.title(for: .logMeal),
            "Log meal with Coach"
        )
        XCTAssertFalse(
            FormaProductCopy.Today.QuickActions.logMealMicrocopy
                .localizedCaseInsensitiveContains("manual entry")
        )
        XCTAssertFalse(
            FormaProductCopy.Today.QuickActions.logMealMicrocopy
                .localizedCaseInsensitiveContains("manual form")
        )
    }

    // 3. Tapping Log Meal opens Coach.
    func testLogMealRoutesToCoach() {
        var openedCoach = false
        coordinator.onOpenCoach = { intent in
            openedCoach = true
            XCTAssertEqual(intent, .logMeal(mealType: nil))
        }

        coordinator.performQuickAction(.logMeal)

        XCTAssertTrue(openedCoach)
    }

    // 4. Coach displays meal logging starter state.
    func testCoachDisplaysMealLoggingStarterState() throws {
        let model = try AppContainer(inMemory: true).makeCoachModel()

        model.launch(with: .logMeal(mealType: nil))

        XCTAssertEqual(model.messages.count, 0)
        XCTAssertNotNil(model.activeLaunchPresentation)
        XCTAssertEqual(
            model.activeLaunchPresentation?.headline,
            FormaProductCopy.Coach.Launch.logMealHeadline(mealType: nil)
        )
        XCTAssertEqual(
            model.activeLaunchPresentation?.chips,
            [.takePhoto, .describeMeal, .useVoice]
        )
        XCTAssertTrue(model.requestsComposerFocus)
    }

    // 5. Tapping water amount updates water card.
    func testInlineWaterLoggingUpdatesDashboardWaterSummary() async throws {
        let todayModel = makeTodayModel()
        await todayModel.loadToday()

        guard case .loaded(let baseline) = todayModel.viewState else {
            return XCTFail("Expected loaded Today state")
        }
        XCTAssertEqual(baseline.macroHydration.waterSummary.consumedMl, 0)

        XCTAssertTrue(coordinator.addWater(amountMl: 250))
        await todayModel.refresh()

        guard case .loaded(let updated) = todayModel.viewState else {
            return XCTFail("Expected loaded Today state after water add")
        }

        XCTAssertEqual(updated.macroHydration.waterSummary.consumedMl, 250)
        XCTAssertEqual(
            coordinator.snackbarMessage?.message,
            FormaProductCopy.Today.Water.addedMessage(amountMl: 250)
        )
    }

    // 6. No Add Water modal appears for common amounts.
    func testTodayCoordinatorHasNoAddWaterModalPresentationState() {
        let publishedLabels = Mirror(reflecting: coordinator)
            .children
            .compactMap(\.label)

        XCTAssertTrue(publishedLabels.contains("isPresentingLogWeightSheet"))
        XCTAssertTrue(publishedLabels.contains("editFoodPresentation"))
        XCTAssertFalse(publishedLabels.contains("isPresentingAddWaterSheet"))
        XCTAssertFalse(publishedLabels.contains("isPresentingLogMealSheet"))

        XCTAssertTrue(coordinator.addWater(amountMl: 500))
        XCTAssertFalse(coordinator.isPresentingLogWeightSheet)
        XCTAssertNil(coordinator.editFoodPresentation)
    }

    func testTodayReadOnlyViewUsesTighterSpacingOnCompactHeight() {
        XCTAssertEqual(FormaTokens.Spacing.lg < TodayLayout.sectionSpacing, true)
    }

    func testMainTabViewKeepsStableTodayActionCoordinator() throws {
        let root = ThemeTestSupport.repositoryRoot()
        let mainTabSource = try String(
            contentsOf: root.appendingPathComponent("Fitness Coach/App/MainTabView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            mainTabSource.contains("@StateObject private var todayActionCoordinator: TodayActionCoordinator"),
            "MainTabView must hold a single TodayActionCoordinator across body re-evaluations."
        )
        XCTAssertFalse(
            mainTabSource.contains("actionCoordinator: container.makeTodayActionCoordinator()"),
            "MainTabView must not construct a new TodayActionCoordinator inline in TodayView."
        )
        XCTAssertTrue(
            mainTabSource.contains("await todayModel.refresh()"),
            "MainTabView must refresh Today when the app returns to the foreground."
        )
    }

    func testTodayLoggingSurfacesResolveAcrossLightAndDarkAppearances() async {
        await MainActor.run {
            for palette in AppThemePalette.allCases {
                for appearance in [ColorScheme.dark, ColorScheme.light] {
                    FormaThemeAccess.update(
                        resolved: ThemeTestSupport.makeResolved(
                            palette: palette,
                            systemColorScheme: appearance
                        )
                    )

                    ThemeTestSupport.assertSameColor(
                        FormaTokens.Theme.primary,
                        ThemePaletteCatalog.palette(for: palette, colorScheme: appearance).primary
                    )
                    ThemeTestSupport.assertSameColor(
                        FormaTokens.Color.progress,
                        FormaPaletteCatalog.palette(for: palette, colorScheme: appearance).progress
                    )
                    XCTAssertGreaterThan(
                        ThemeTestSupport.colorDistance(
                            FormaTokens.Color.textPrimary,
                            FormaTokens.Color.canvas
                        ),
                        0.05
                    )
                }
            }
        }
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
private final class TodayLoggingFlowFoodEstimateService: AIServiceProtocol, @unchecked Sendable {
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
    ) async throws -> DailyReviewAIResponse {
        throw AIServiceError.backendUnavailable
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        throw AIServiceError.backendUnavailable
    }
}
