//
//  TodayDailyReviewTeaserTests.swift
//  Fitness CoachTests
//
//  Forma — Daily review teaser on Today (outside Coach).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class TodayDailyReviewTeaserTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var refreshEventBus: AccountDataRefreshEventBus!
    private var sessionUID: String!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        refreshEventBus = AccountDataRefreshEventBus()
        sessionUID = harness.cloudUID
        _ = try harness.seedProfile(ownerUID: sessionUID)
    }

    override func tearDown() {
        harness = nil
        refreshEventBus = nil
        sessionUID = nil
        super.tearDown()
    }

    func testDailyReviewTeaserRefreshesAfterDailyReviewEvent() async throws {
        let yesterday = harness.base.day(offset: -1)
        _ = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(
                name: "Dinner",
                calories: 620,
                protein: 42
            ),
            date: yesterday
        )

        let model = try makeModel()
        await model.loadToday()

        guard case .loaded(let initial) = model.viewState else {
            return XCTFail("Expected loaded Today state")
        }
        XCTAssertTrue(initial.yesterdayReview.isVisible)
        XCTAssertEqual(initial.yesterdayReview.cta, .generateReview)
        XCTAssertNil(initial.yesterdayReview.review)

        _ = try await harness.actionCenter.generateDailyReview(for: yesterday)

        try await publishRefresh(domains: [.dailyReview])

        guard case .loaded(let refreshed) = model.viewState else {
            return XCTFail("Expected loaded Today state after daily review refresh")
        }
        XCTAssertTrue(refreshed.yesterdayReview.isVisible)
        XCTAssertEqual(refreshed.yesterdayReview.cta, .viewReview)
        XCTAssertNotNil(refreshed.yesterdayReview.review)
        XCTAssertFalse(refreshed.yesterdayReview.previewLines.isEmpty)
    }

    func testDailyReviewTeaserDoesNotDependOnCoach() async throws {
        let review = DailyReview(
            id: UUID(),
            dailyLogId: UUID(),
            summaryText: "Balanced day.",
            caloriesSummary: "Calories: 1,700 / 1,800 kcal.",
            proteinSummary: "Protein: 165 / 170g.",
            hydrationSummary: "Water: 2,800 / 3,500ml.",
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: "Repeat tomorrow.",
            createdAt: Date()
        )

        let coordinator = TodayActionCoordinator(actionCenter: harness.actionCenter)
        var coachOpened = false
        coordinator.onOpenCoach = { _ in coachOpened = true }

        coordinator.viewYesterdayReview(review)

        XCTAssertEqual(coordinator.presentedDailyReview, review)
        XCTAssertFalse(coachOpened)

        let presentationState = TodayPresentationBuilder.dashboard(
            from: TodayMissionControlInputs(
                date: harness.today,
                calorieSummary: CalorieSummary(
                    consumed: 500,
                    target: 1_800,
                    remaining: 1_300,
                    progress: 0.28,
                    isOverTarget: false
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(consumed: 40, target: 170, remaining: 130, progress: 0.24),
                    carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                    fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
                ),
                waterSummary: WaterSummary(
                    consumedMl: 1_000,
                    targetMl: 3_500,
                    remainingMl: 2_500,
                    progress: 0.29
                ),
                weightSummary: TodayWeightSummary(weightKg: nil, displayText: "Not logged today"),
                weightLoggedToday: false,
                hasRecentWeight: true,
                workoutSummary: TodayWorkoutSummary(workoutCaloriesBurned: 0, workoutCount: 0, hasWorkout: false),
                foodEntries: [],
                hasPriorFoodLogs: true,
                yesterdayReviewInput: TodayYesterdayReviewInput(
                    date: harness.base.day(offset: -1),
                    review: review,
                    foodEntryCount: 2,
                    waterConsumedMl: 1_000,
                    workoutCaloriesBurned: 0,
                    weightLogged: false
                ),
                goalWeightKg: 75,
                profileWeightKg: 80,
                latestWeightKg: nil,
                activityContext: .default,
                stepGoalAssumption: 7_500,
                trainingFrequencyPerWeek: 0
            )
        )

        XCTAssertTrue(presentationState.yesterdayReview.isVisible)
        XCTAssertFalse(presentationState.smartCoach.isVisible)
        XCTAssertNotEqual(presentationState.yesterdayReview.sectionTitle, presentationState.smartCoach.message)
    }

    func testDailyReviewTeaserUsesSafeCopy() {
        let review = DailyReview(
            id: UUID(),
            dailyLogId: UUID(),
            summaryText: "Nice consistency.",
            caloriesSummary: "Calories: 1,650 / 1,800 kcal.",
            proteinSummary: "Protein: 160 / 170g.",
            hydrationSummary: "Water: 2,500 / 3,500ml.",
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: "Keep logging.",
            createdAt: Date()
        )

        let state = TodayPresentationBuilder.dashboard(
            from: TodayMissionControlInputs(
                date: harness.today,
                calorieSummary: CalorieSummary(
                    consumed: 0,
                    target: 1_800,
                    remaining: 1_800,
                    progress: 0,
                    isOverTarget: false
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(consumed: 0, target: 170, remaining: 170, progress: 0),
                    carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                    fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
                ),
                waterSummary: WaterSummary(
                    consumedMl: 0,
                    targetMl: 3_500,
                    remainingMl: 3_500,
                    progress: 0
                ),
                weightSummary: TodayWeightSummary(weightKg: nil, displayText: "Not logged today"),
                weightLoggedToday: false,
                hasRecentWeight: false,
                workoutSummary: TodayWorkoutSummary(workoutCaloriesBurned: 0, workoutCount: 0, hasWorkout: false),
                foodEntries: [],
                hasPriorFoodLogs: true,
                yesterdayReviewInput: TodayYesterdayReviewInput(
                    date: harness.base.day(offset: -1),
                    review: review,
                    foodEntryCount: 2,
                    waterConsumedMl: 500,
                    workoutCaloriesBurned: 0,
                    weightLogged: false
                ),
                goalWeightKg: nil,
                profileWeightKg: nil,
                latestWeightKg: nil,
                activityContext: .default,
                stepGoalAssumption: 7_500,
                trainingFrequencyPerWeek: 0
            )
        )

        let copySamples = [
            FormaProductCopy.Today.YesterdayReview.sectionTitle,
            FormaProductCopy.Today.YesterdayReview.viewAction,
            FormaProductCopy.Today.YesterdayReview.viewHint,
            FormaProductCopy.Today.YesterdayReview.generateAction,
            FormaProductCopy.Today.YesterdayReview.generateHint,
            FormaProductCopy.Today.YesterdayReview.generatedSuccess,
            state.yesterdayReview.accessibilityLabel
        ] + state.yesterdayReview.previewLines

        for sample in copySamples {
            XCTAssertNil(
                PlanCopySafetyPolicy.forbiddenViolation(in: sample),
                "Forbidden teaser copy in: \(sample)"
            )
            let lowered = sample.lowercased()
            XCTAssertFalse(lowered.contains("diagnos"), "Medical claim in teaser copy: \(sample)")
            XCTAssertFalse(lowered.contains("clinical"), "Clinical claim in teaser copy: \(sample)")
        }
    }

    func testDailyReviewTeaserHandlesSyncedRestoredReview() async throws {
        let yesterday = harness.base.day(offset: -1)
        _ = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Lunch", calories: 540, protein: 35),
            date: yesterday
        )

        let dailyLogEntity = try harness.dailyLogService.getOrCreateLogEntity(for: yesterday)
        let restoredSummary = "Synced review from another device."
        let entity = DailyReviewEntity(
            id: UUID(),
            ownerUID: sessionUID,
            dailyLogId: dailyLogEntity.id,
            summaryText: restoredSummary,
            caloriesSummary: "Calories: 1,540 / 1,800 kcal.",
            proteinSummary: "Protein: 150 / 170g.",
            hydrationSummary: "Water: 2,200 / 3,500ml.",
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: "Stay consistent.",
            createdAt: yesterday
        )
        entity.cloudId = "cloud-review-\(dailyLogEntity.id.uuidString)"
        entity.cloudUpdatedAt = yesterday
        entity.lastSyncedAt = yesterday
        entity.syncStatusRawValue = AccountDataSyncStatus.synced.rawValue
        entity.dailyLog = dailyLogEntity
        dailyLogEntity.dailyReview = entity
        dailyLogEntity.dailyReviewId = entity.id
        try harness.store.insert(entity)
        try harness.store.save()

        let model = try makeModel()
        await model.loadToday()

        guard case .loaded(let state) = model.viewState else {
            return XCTFail("Expected loaded Today state")
        }

        XCTAssertTrue(state.yesterdayReview.isVisible)
        XCTAssertEqual(state.yesterdayReview.cta, .viewReview)
        XCTAssertEqual(state.yesterdayReview.review?.summaryText, restoredSummary)
        XCTAssertEqual(state.yesterdayReview.review?.dailyLogId, dailyLogEntity.id)
        XCTAssertEqual(
            state.yesterdayReview.previewLines,
            DailyReviewSummaryBuilder.teaserLines(from: entity.toModel())
        )
    }

    // MARK: - Helpers

    private func makeModel() throws -> TodayModel {
        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: sessionUID),
            profile: try harness.profileService.getCurrentProfile(),
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
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: self.sessionUID) },
            ownerUIDProvider: { self.sessionUID },
            accountDataRefreshEventBus: refreshEventBus
        )
    }

    private func publishRefresh(
        domains: Set<AccountDataRefreshDomain>,
        uid: String? = nil
    ) async throws {
        try await CrossDeviceRefreshTestSupport.publishAndWait(
            bus: refreshEventBus,
            event: AccountDataRefreshEvent(
                uid: uid ?? sessionUID,
                domains: domains,
                reason: .realtimeSnapshot,
                createdAt: harness.today
            )
        )
    }
}
