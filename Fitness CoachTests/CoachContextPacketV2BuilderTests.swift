//
//  CoachContextPacketV2BuilderTests.swift
//  Fitness CoachTests
//
//  Forma — CoachContextPacketV2Builder assembly tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachContextPacketV2BuilderTests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!
    private var weightLogService: WeightLogService!
    private var timelineStore: FakeCoachTimelineStore!
    private var healthQuery: FakeCoachTimelineHealthActivityQuery!
    private var snapshotProvider: MockCoachContextSnapshotProvider!
    private var timelineRecorder: CapturingCoachTimelineRecorder!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        weightLogService = harness.weightLogService
        timelineStore = FakeCoachTimelineStore()
        healthQuery = FakeCoachTimelineHealthActivityQuery()
        snapshotProvider = MockCoachContextSnapshotProvider()
        timelineRecorder = CapturingCoachTimelineRecorder()
    }

    override func tearDown() {
        timelineRecorder = nil
        snapshotProvider = nil
        healthQuery = nil
        timelineStore = nil
        weightLogService = nil
        harness = nil
        super.tearDown()
    }

    func testBuildsPacketFromAuthoritativeLogs() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Salad", calories: 420, protein: 28),
            date: harness.today
        )
        _ = try? harness.waterLogService.addWater(amountMl: 500, date: harness.today)
        _ = try? weightLogService.logWeight(68.0, date: harness.today)
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 7_500

        let packet = await makeBuilder().makeContext(
            recentMessages: [
                ChatMessage(role: .user, text: "How am I doing?", createdAt: harness.today)
            ],
            mode: .live
        )

        XCTAssertEqual(packet.meta.schemaVersion, CoachContextPacketV2.schemaVersion)
        XCTAssertNotNil(packet.profile)
        XCTAssertNotNil(packet.today)
        XCTAssertEqual(packet.today?.nutrition?.caloriesConsumed, 420)
        XCTAssertEqual(packet.today?.hydration?.waterConsumedMl, 500)
        XCTAssertEqual(packet.today?.weight?.weightKg, 68.0)
        XCTAssertEqual(packet.today?.steps?.value, 7_500)
        XCTAssertEqual(packet.recentMealsStructured.count, 1)
        XCTAssertEqual(packet.recentMealsStructured.first?.name, "Salad")
        XCTAssertEqual(packet.recentChatMessages.count, 1)
        XCTAssertNotNil(packet.recentChatMessages.first?.timestamp)
        XCTAssertEqual(packet.recentChatMessages.first?.text, "How am I doing?")
        XCTAssertFalse(packet.missingData.noRecentMeals)
    }

    func testBackfillsTimelineBeforeBuildingContext() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Toast", calories: 180),
            date: harness.today
        )

        let packet = await makeBuilder(includeBackfill: true).makeContext(
            recentMessages: [],
            mode: .live
        )

        XCTAssertFalse(packet.timeline.recentEvents.isEmpty)
        XCTAssertTrue(packet.timeline.recentEvents.contains { $0.type == CoachTimelineEventType.foodLogged.rawValue })
        XCTAssertFalse(packet.missingData.noTimelineHistory)
    }

    func testPopulatesCommonFoodsFromHistory() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Oatmeal", calories: 300, protein: 10),
            date: harness.day(offset: -1)
        )
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Oatmeal", calories: 320, protein: 12),
            date: harness.today
        )

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.commonFoods.first?.name, "oatmeal")
        XCTAssertEqual(packet.commonFoods.first?.displayName, "Oatmeal")
        XCTAssertGreaterThanOrEqual(packet.commonFoods.first?.frequency ?? 0, 2)
        XCTAssertEqual(packet.commonFoods.first?.typicalCalories, 310)
        XCTAssertEqual(packet.commonFoods.first?.typicalProteinGrams, 11)
    }

    func testStructuredRecentMealsIncludeMacrosAndLocalDate() async throws {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(
                name: "Greek yogurt",
                calories: 180,
                protein: 17,
                carbs: 8,
                fat: 4
            ),
            date: harness.today
        )

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)
        let meal = try XCTUnwrap(packet.recentMealsStructured.first)

        XCTAssertEqual(meal.name, "Greek yogurt")
        XCTAssertEqual(meal.proteinGrams, 17)
        XCTAssertEqual(meal.carbsGrams, 8)
        XCTAssertEqual(meal.fatGrams, 4)
        XCTAssertNotNil(meal.localDate)
        XCTAssertNotNil(meal.loggedAt)
        XCTAssertEqual(meal.source, FoodEntrySource.manual.rawValue)
    }

    func testCommonFoodsExcludeUncertainOneOffFood() async {
        _ = try? harness.foodLogService.addFoodEntry(
            FoodDraft(
                mealType: .snack,
                name: "Maybe almonds",
                quantity: 1,
                unit: "serving",
                calories: 120,
                protein: 4,
                carbs: 4,
                fat: 10,
                fiber: nil,
                sodium: nil,
                source: .aiPhotoEstimate,
                confidence: .low,
                imageUrl: nil,
                notes: nil
            ),
            date: harness.today
        )
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Eggs", calories: 140, protein: 12),
            date: harness.day(offset: -2)
        )
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Eggs", calories: 150, protein: 13),
            date: harness.today
        )

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertFalse(packet.commonFoods.contains { $0.name == "maybe almonds" })
        XCTAssertEqual(packet.commonFoods.first?.name, "eggs")
    }

    func testTodayMealsPrioritizedInRecentMeals() async {
        for index in 0..<7 {
            _ = try? harness.foodLogService.addFoodEntry(
                DailyLogServiceTestSupport.foodDraft(name: "Today \(index)", calories: 200 + index),
                date: harness.today
            )
        }
        for index in 0..<5 {
            _ = try? harness.foodLogService.addFoodEntry(
                DailyLogServiceTestSupport.foodDraft(name: "Prior \(index)", calories: 100 + index),
                date: harness.day(offset: -1)
            )
        }

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.recentMealsStructured.count, 10)
        XCTAssertEqual(
            packet.recentMealsStructured.filter { $0.name.hasPrefix("Today") }.count,
            7
        )
        XCTAssertEqual(
            packet.recentMealsStructured.filter { $0.name.hasPrefix("Prior") }.count,
            3
        )
    }

    func testFoodMemoryKeepsContextWithinByteLimit() async {
        for index in 0..<12 {
            _ = try? harness.foodLogService.addFoodEntry(
                DailyLogServiceTestSupport.foodDraft(
                    name: "Meal \(index)",
                    calories: 400 + index,
                    protein: 25,
                    carbs: 35,
                    fat: 12
                ),
                date: harness.day(offset: -(index % 20))
            )
        }

        let packet = await makeBuilder().makeContext(
            recentMessages: (0..<8).map {
                ChatMessage(role: .assistant, text: String(repeating: "Detail ", count: 20) + "\($0)")
            },
            mode: .live
        )

        XCTAssertTrue(packet.fitsWithinByteLimit())
        XCTAssertLessThanOrEqual(packet.recentMealsStructured.count, CoachContextPacketV2Limits.maxRecentMeals)
        XCTAssertLessThanOrEqual(packet.commonFoods.count, CoachContextPacketV2Limits.maxCommonFoods)
    }

    func testMissingDataWhenStepsUnavailable() async {
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .degraded)

        XCTAssertTrue(packet.missingData.stepsMissing)
        XCTAssertTrue(packet.missingData.workoutPermissionDeniedOrUnavailable)
        XCTAssertTrue(packet.missingData.healthKitDenied)
        XCTAssertTrue(packet.missingData.stepsUnavailable)
        XCTAssertEqual(packet.generationMode, .degraded)
    }

    func testWorkoutsIncludedInTrainingContext() async {
        healthQuery.workouts = [
            HealthWorkoutRecord(
                id: UUID(),
                activityName: "Run",
                startDate: harness.today,
                endDate: harness.today.addingTimeInterval(1_800),
                durationMinutes: 30,
                activeCalories: 260
            )
        ]
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 5_000

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.training?.workoutsToday, 1)
        XCTAssertEqual(packet.training?.workouts.count, 1)
        XCTAssertEqual(packet.training?.workouts.first?.title, "Run")
        XCTAssertEqual(packet.training?.workouts.first?.durationMinutes, 30)
        XCTAssertEqual(packet.training?.workouts.first?.activeEnergyKcal, 260)
        XCTAssertEqual(packet.training?.workouts.first?.source, "healthKit")
    }

    func testStepsIncludedWithSourceAndAsOf() async {
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 8_200

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.today?.steps?.value, 8_200)
        XCTAssertEqual(packet.today?.steps?.source, "healthKit")
        XCTAssertNotNil(packet.today?.steps?.asOf)
        XCTAssertFalse(packet.missingData.stepsMissing)
    }

    func testPermissionDeniedPopulatesGranularMissingDataFlags() async {
        healthQuery.workoutsError = HealthKitManagerError.authorizationDenied
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .degraded)

        XCTAssertTrue(packet.missingData.healthKitDenied)
        XCTAssertTrue(packet.missingData.stepsUnavailable)
        XCTAssertTrue(packet.missingData.workoutPermissionDeniedOrUnavailable)
        XCTAssertNil(packet.training?.workoutsToday)
    }

    func testNoWorkoutDistinctFromUnknownWhenPossible() async {
        healthQuery.workouts = []
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 3_000

        let confirmedEmpty = await makeBuilder().makeContext(recentMessages: [], mode: .live)
        XCTAssertEqual(confirmedEmpty.training?.workoutsToday, 0)
        XCTAssertTrue(confirmedEmpty.training?.workouts.isEmpty == true)

        healthQuery.workoutsError = HealthKitManagerError.authorizationDenied
        let unknown = await makeBuilder().makeContext(recentMessages: [], mode: .degraded)
        XCTAssertNil(unknown.training?.workoutsToday)
    }

    func testRecoveryMissingSignalsIncludedInHealthIntelligence() async {
        snapshotProvider.snapshot = HealthIntelligenceSnapshot(
            date: harness.today,
            recovery: RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery unclear",
                explanation: "Sleep and HRV are missing.",
                recommendedTraining: "Use how you feel today.",
                recommendedNutrition: "Stay on your usual plan.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 4_000, activeEnergyKcal: 200, exerciseMinutes: 20),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )

        let packet = await makeBuilder(loadHealthIntelligence: true).makeContext(
            recentMessages: [],
            mode: .live
        )

        XCTAssertNotNil(packet.healthIntelligence)
        XCTAssertTrue(packet.healthIntelligence?.missingSignals.contains("sleep") == true)
        XCTAssertTrue(packet.healthIntelligence?.missingSignals.contains("HRV") == true)
        XCTAssertTrue(packet.missingData.sleepMissing)
        XCTAssertTrue(packet.missingData.hrvMissing)
    }

    func testRecordsWorkoutDetectedAndStepsUpdatedTimelineEvents() async {
        healthQuery.workouts = [
            HealthWorkoutRecord(
                id: UUID(),
                activityName: "Strength",
                startDate: harness.today,
                endDate: harness.today.addingTimeInterval(2_400),
                durationMinutes: 40,
                activeCalories: 180
            )
        ]
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 6_500

        _ = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(timelineRecorder.stepsUpdatedPayloads.count, 1)
        XCTAssertEqual(timelineRecorder.stepsUpdatedPayloads.first?.steps, 6_500)
        XCTAssertEqual(timelineRecorder.workoutDetectedPayloads.count, 1)
        XCTAssertEqual(timelineRecorder.workoutDetectedPayloads.first?.workoutCount, 1)
        XCTAssertEqual(timelineRecorder.workoutDetectedPayloads.first?.primaryWorkoutTitle, "Strength")
    }

    func testRecordsHealthDataUnavailableWhenPermissionDenied() async {
        healthQuery.workoutsError = HealthKitManagerError.authorizationDenied
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied

        _ = await makeBuilder().makeContext(recentMessages: [], mode: .degraded)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(timelineRecorder.healthDataUnavailablePayloads.count, 1)
        XCTAssertEqual(timelineRecorder.healthDataUnavailablePayloads.first?.reason, "access_denied")
    }

    func testUsesHealthWorkoutCaloriesNotLegacyDailyLogCalories() async throws {
        try harness.seedWorkoutCaloriesBurned(calories: 500)
        healthQuery.workouts = [
            HealthWorkoutRecord(
                id: UUID(),
                activityName: "Run",
                startDate: harness.today,
                endDate: harness.today.addingTimeInterval(1_800),
                durationMinutes: 30,
                activeCalories: 260
            )
        ]
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 4_000

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.today?.workoutCaloriesBurned?.value, 260)
        XCTAssertNotEqual(packet.today?.workoutCaloriesBurned?.value, 500)
    }

    func testIncludesHealthIntelligenceWhenSnapshotAvailable() async {
        snapshotProvider.snapshot = makeReadySnapshot(on: harness.today)

        let packet = await makeBuilder(loadHealthIntelligence: true).makeContext(
            recentMessages: [],
            mode: .live
        )

        XCTAssertNotNil(packet.healthIntelligence)
        XCTAssertTrue(packet.sourceAttribution?.healthIntelligenceIncluded == true)
    }

    func testNilDependenciesDoNotCrash() async {
        let packet = await CoachContextPacketV2Builder().makeContext(
            recentMessages: [],
            mode: .preview
        )

        XCTAssertEqual(packet.generationMode, .preview)
        XCTAssertNil(packet.profile)
        XCTAssertTrue(packet.missingData.noRecentMeals)
        XCTAssertTrue(packet.missingData.noTimelineHistory)
    }

    func testPacketFitsWithinDefaultByteLimit() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Lunch", calories: 650, protein: 40),
            date: harness.today
        )
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 9_000

        let packet = await makeBuilder().makeContext(
            recentMessages: (0..<8).map {
                ChatMessage(role: .assistant, text: String(repeating: "Detail ", count: 20) + "\($0)")
            },
            mode: .live
        )

        XCTAssertTrue(packet.fitsWithinByteLimit())
        XCTAssertLessThanOrEqual(packet.recentChatMessages.count, CoachContextPacketV2Builder.recentChatMessageLimit)
        XCTAssertLessThanOrEqual(packet.timeline.recentEvents.count, CoachContextPacketV2Builder.defaultTimelineEventLimit)
    }

    func testRecordsContextGeneratedWithoutAffectingReturnedTimeline() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Eggs", calories: 140),
            date: harness.today
        )

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(timelineRecorder.contextGeneratedPayloads.count, 1)
        XCTAssertEqual(timelineRecorder.contextGeneratedPayloads.first?.timelineEventCount, packet.timeline.recentEvents.count)
        XCTAssertFalse(packet.timeline.recentEvents.contains { $0.type == CoachTimelineEventType.contextGenerated.rawValue })
    }

    func testChatOnlyProvidesToneWithoutLoggedFacts() async {
        let packet = await makeBuilder(includeBackfill: false).makeContext(
            recentMessages: [
                ChatMessage(role: .user, text: "How was my day?", createdAt: harness.today),
                ChatMessage(role: .assistant, text: "You're doing fine.", createdAt: harness.today)
            ],
            mode: .live
        )

        XCTAssertEqual(packet.recentChatMessages.count, 2)
        XCTAssertNil(packet.currentUserMessage)
        XCTAssertTrue(packet.recentMealsStructured.isEmpty)
        XCTAssertEqual(packet.today?.nutrition?.caloriesConsumed ?? 0, 0)
        XCTAssertFalse(
            packet.timeline.recentEvents.contains {
                $0.type == CoachTimelineEventType.foodLogged.rawValue
                    && $0.status == CoachTimelineEventStatus.confirmed.rawValue
            }
        )
        XCTAssertTrue(packet.missingData.noRecentMeals)
    }

    func testLogsWithoutChatStillProvideFactualState() async {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Chicken rice", calories: 520, protein: 35),
            date: harness.today
        )

        let packet = await makeBuilder().makeContext(recentMessages: [], mode: .live)

        XCTAssertTrue(packet.recentChatMessages.isEmpty)
        XCTAssertNil(packet.currentUserMessage)
        XCTAssertEqual(packet.recentMealsStructured.first?.name, "Chicken rice")
        XCTAssertEqual(packet.today?.nutrition?.caloriesConsumed, 520)
        XCTAssertTrue(
            packet.timeline.recentEvents.contains {
                $0.type == CoachTimelineEventType.foodLogged.rawValue
                    && $0.status == CoachTimelineEventStatus.confirmed.rawValue
            }
        )
    }

    func testRejectedEstimateInChatNotTreatedAsLogged() async {
        let rejected = CoachTimelineEvent.make(
            type: .foodRejected,
            source: .aiBackend,
            sourceAttribution: .estimateFood,
            status: .rejected,
            payload: .foodEstimate(
                FoodEstimatePayload(mealName: "Chicken", calories: 500, requiresConfirmation: true)
            ),
            occurredAt: harness.today,
            calendar: harness.dateProvider.calendar
        )
        try? await timelineStore.append(rejected)

        let packet = await makeBuilder(includeBackfill: false).makeContext(
            recentMessages: [
                ChatMessage(role: .assistant, text: "Logged 500 cal chicken for you.", createdAt: harness.today)
            ],
            mode: .live
        )

        XCTAssertTrue(packet.recentMealsStructured.isEmpty)
        XCTAssertEqual(packet.today?.nutrition?.caloriesConsumed ?? 0, 0)
        XCTAssertFalse(
            packet.timeline.recentEvents.contains {
                $0.type == CoachTimelineEventType.foodLogged.rawValue
                    && $0.status == CoachTimelineEventStatus.confirmed.rawValue
            }
        )
        XCTAssertFalse(
            packet.timeline.recentEvents.contains {
                $0.type == CoachTimelineEventType.foodRejected.rawValue
            },
            "Rejected estimates must not be exported as consumed timeline facts"
        )
    }

    func testAssistantClaimInChatNotTreatedAsFoodTruth() async {
        let packet = await makeBuilder(includeBackfill: false).makeContext(
            recentMessages: [
                ChatMessage(role: .assistant, text: "I logged your oatmeal at 300 kcal.", createdAt: harness.today)
            ],
            mode: .live
        )

        XCTAssertTrue(packet.recentMealsStructured.isEmpty)
        XCTAssertEqual(packet.today?.nutrition?.caloriesConsumed ?? 0, 0)
        XCTAssertFalse(
            packet.timeline.recentEvents.contains {
                $0.type == CoachTimelineEventType.foodLogged.rawValue
                    && $0.status == CoachTimelineEventStatus.confirmed.rawValue
            }
        )
    }

    func testCurrentUserMessageNotDoubleCounted() async {
        let prior = [
            ChatMessage(role: .user, text: "Good morning", createdAt: harness.today),
            ChatMessage(role: .assistant, text: "Morning!", createdAt: harness.today)
        ]

        let packet = await makeBuilder(includeBackfill: false).makeContext(
            recentMessages: prior,
            currentUserMessage: "Log lunch",
            mode: .live
        )

        XCTAssertEqual(packet.currentUserMessage, "Log lunch")
        XCTAssertEqual(packet.recentChatMessages.count, 2)
        XCTAssertFalse(packet.recentChatMessages.contains { $0.text == "Log lunch" })
    }

    func testCurrentUserMessageOmittedWhenAlreadyLinkedInTimeline() async {
        let messageID = UUID()
        let prior = [
            ChatMessage(id: messageID, role: .user, text: "Log lunch", createdAt: harness.today)
        ]
        let linked = CoachTimelineEvent.make(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .localParser,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "Log lunch", role: "user")),
            occurredAt: harness.today,
            calendar: harness.dateProvider.calendar,
            link: CoachTimelineEventLink(linkedMessageId: messageID)
        )
        try? await timelineStore.append(linked)

        let packet = await makeBuilder(includeBackfill: false).makeContext(
            recentMessages: prior,
            currentUserMessage: "Log lunch",
            mode: .live
        )

        XCTAssertNil(packet.currentUserMessage)
        XCTAssertEqual(packet.recentChatMessages.count, 1)
        XCTAssertEqual(packet.recentChatMessages.first?.text, "Log lunch")
        XCTAssertTrue(
            packet.timeline.recentEvents.contains { $0.linkedMessageId == messageID }
        )
    }

    func testTimelineSelectorPrefersTodayConfirmedMutations() {
        let today = "2026-07-03"
        let food = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Salad",
                    calories: 400,
                    proteinGrams: 20,
                    carbsGrams: 30,
                    fatGrams: 12
                )
            ),
            occurredAt: harness.today,
            calendar: harness.dateProvider.calendar
        )
        let system = CoachTimelineEvent.make(
            type: .systemRefresh,
            source: .system,
            sourceAttribution: .system,
            status: .confirmed,
            payload: .systemRefresh(SystemRefreshPayload(reason: "refresh")),
            occurredAt: harness.today.addingTimeInterval(-10),
            calendar: harness.dateProvider.calendar
        )

        let selected = CoachContextPacketV2TimelineSelector.selectEvents(
            from: [system, food],
            todayLocalDate: today,
            limit: 1
        )

        XCTAssertEqual(selected.map(\.id), [food.id])
    }

    // MARK: Helpers

    private func makeBuilder(
        includeBackfill: Bool = true,
        loadHealthIntelligence: Bool = false
    ) -> CoachContextPacketV2Builder {
        CoachContextPacketV2Builder(
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: weightLogService,
            userProfileService: harness.profileService,
            healthActivityQuery: HealthActivityQueryService(
                workoutReader: StubHealthKitWorkoutReader(
                    workouts: healthQuery.workouts,
                    error: healthQuery.workoutsError
                ),
                stepReader: StubHealthKitStepReader(
                    stepsByDay: healthQuery.stepsByDay,
                    error: healthQuery.stepsError
                ),
                repositoryReadRoutingEnabled: false
            ),
            healthIntelligenceSnapshotProvider: snapshotProvider,
            timelineStore: timelineStore,
            timelineBackfillService: includeBackfill
                ? CoachTimelineBackfillService(
                    timelineStore: timelineStore,
                    foodLogService: harness.foodLogService,
                    waterLogService: harness.waterLogService,
                    weightLogService: weightLogService,
                    healthActivityQuery: healthQuery,
                    dateProvider: harness.dateProvider,
                    calendar: harness.dateProvider.calendar
                )
                : nil,
            timelineRecorder: timelineRecorder,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar,
            loadHealthIntelligence: { loadHealthIntelligence }
        )
    }

    private func makeReadySnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 72,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Sleep was decent.",
                recommendedTraining: "Moderate training is appropriate.",
                recommendedNutrition: "Stay on plan.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 420, exerciseMinutes: 35),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.7, label: "Moderate"),
            nextBestAction: .none
        )
    }
}

// MARK: - Test doubles

@MainActor
private final class CapturingCoachTimelineRecorder: CoachTimelineRecording, @unchecked Sendable {
    private(set) var contextGeneratedPayloads: [ContextGenerationPayload] = []
    private(set) var workoutDetectedPayloads: [WorkoutDetectedPayload] = []
    private(set) var stepsUpdatedPayloads: [StepsUpdatedPayload] = []
    private(set) var healthDataUnavailablePayloads: [HealthDataUnavailablePayload] = []

    struct WorkoutDetectedPayload {
        var workoutCount: Int
        var totalDurationMinutes: Int
        var totalActiveCalories: Int?
        var primaryWorkoutTitle: String?
        var demand: String?
    }

    struct StepsUpdatedPayload {
        var steps: Int
        var previousSteps: Int?
    }

    struct HealthDataUnavailablePayload {
        var missingSignals: [String]
        var reason: String?
    }

    func recordUserMessage(text: String, messageId: UUID?, hasPhotoAttachment: Bool, occurredAt: Date?) {}
    func recordAssistantMessage(text: String, messageId: UUID?, sourceAttribution: CoachTimelineEventSourceAttribution, occurredAt: Date?) {}
    func recordFoodEstimateCreated(payload: FoodEstimatePayload, source: CoachTimelineEventSource, sourceAttribution: CoachTimelineEventSourceAttribution, confidence: CoachTimelineEventConfidence?, status: CoachTimelineEventStatus, messageId: UUID?, photoSessionId: UUID?, relatedEventIds: [UUID], occurredAt: Date?) {}
    func recordFoodLogged(entry: FoodEntry, sourceAttribution: CoachTimelineEventSourceAttribution, userEditedBeforeConfirm: Bool, linkedPhotoSessionId: UUID?, occurredAt: Date?) {}
    func recordFoodRejected(payload: FoodEstimatePayload, messageId: UUID?, photoSessionId: UUID?, relatedEventIds: [UUID], occurredAt: Date?) {}
    func recordFoodEdited(entry: FoodEntry, supersedesEventId: UUID?, occurredAt: Date?) {}
    func recordFoodDeleted(entry: FoodEntry, supersedesEventId: UUID?, occurredAt: Date?) {}
    func recordWaterLogged(entry: WaterEntry, occurredAt: Date?) {}
    func recordWeightLogged(entry: WeightEntry, occurredAt: Date?) {}
    func recordWorkoutDetected(workoutCount: Int, totalDurationMinutes: Int, totalActiveCalories: Int?, primaryWorkoutTitle: String?, demand: String?, occurredAt: Date?) {
        workoutDetectedPayloads.append(
            WorkoutDetectedPayload(
                workoutCount: workoutCount,
                totalDurationMinutes: totalDurationMinutes,
                totalActiveCalories: totalActiveCalories,
                primaryWorkoutTitle: primaryWorkoutTitle,
                demand: demand
            )
        )
    }
    func recordStepsUpdated(steps: Int, previousSteps: Int?, occurredAt: Date?) {
        stepsUpdatedPayloads.append(StepsUpdatedPayload(steps: steps, previousSteps: previousSteps))
    }
    func recordPhotoAttached(payload: PhotoPayload, messageId: UUID?, occurredAt: Date?) {}
    func recordPhotoAnalysisStarted(sessionId: UUID, messageId: UUID?, occurredAt: Date?) {}
    func recordPhotoAnalysisCompleted(sessionId: UUID, messageId: UUID?, mealName: String?, estimateId: UUID?, confidence: CoachTimelineEventConfidence?, occurredAt: Date?) {}
    func recordPhotoAnalysisFailed(sessionId: UUID, messageId: UUID?, errorCategory: String, userMessage: String?, isRetryable: Bool, occurredAt: Date?) {}
    func recordClarificationAsked(question: String, messageId: UUID?, sessionId: UUID, occurredAt: Date?) {}
    func recordClarificationAnswered(answer: String, messageId: UUID?, sessionId: UUID, occurredAt: Date?) {}
    func recordPendingConfirmationCreated(
        payload: ConfirmationPayload,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        occurredAt: Date?
    ) {}
    func recordPendingConfirmationConfirmed(payload: ConfirmationPayload, entryId: UUID?, occurredAt: Date?) {}
    func recordPendingConfirmationRejected(payload: ConfirmationPayload, occurredAt: Date?) {}
    func recordUndoPerformed(entryType: String, undoneEntryId: UUID?, summary: String?, occurredAt: Date?) {}
    func recordBackendError(category: String, userMessage: String?, isRetryable: Bool, httpStatus: Int?, occurredAt: Date?) {}
    func recordAuthError(userMessage: String?, occurredAt: Date?) {}
    func recordHealthDataUnavailable(missingSignals: [String], reason: String?, healthIntelligenceAwarenessAvailable: Bool?, occurredAt: Date?) {
        healthDataUnavailablePayloads.append(
            HealthDataUnavailablePayload(missingSignals: missingSignals, reason: reason)
        )
    }
    func recordContextGenerated(payload: ContextGenerationPayload, occurredAt: Date?) {
        contextGeneratedPayloads.append(payload)
    }
}

private final class MockCoachContextSnapshotProvider: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        snapshot
    }
}

private struct StubHealthKitWorkoutReader: HealthKitWorkoutReading {
    let workouts: [HealthWorkoutRecord]
    let error: Error?

    init(workouts: [HealthWorkoutRecord], error: Error? = nil) {
        self.workouts = workouts
        self.error = error
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        if let error { throw error }
        return workouts.filter { $0.startDate >= startDate && $0.startDate < endDate }
    }
}

private struct StubHealthKitStepReader: HealthKitStepReading {
    let stepsByDay: [Date: Int]
    let error: Error?

    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        if let error { throw error }
        guard let steps = stepsByDay[startDate] else {
            throw HealthKitManagerError.authorizationDenied
        }
        return steps
    }
}
