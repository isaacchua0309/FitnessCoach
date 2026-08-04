//
//  CoachMealPhotoContextV2Tests.swift
//  Fitness CoachTests
//
//  Verifies meal photo analysis sends CoachContextPacketV2 and records timeline events.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachMealPhotoContextV2Tests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!
    private var weightLogService: WeightLogService!
    private var healthQuery: FakeCoachTimelineHealthActivityQuery!
    private var timelineStore: FakeCoachTimelineStore!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        weightLogService = harness.weightLogService
        healthQuery = FakeCoachTimelineHealthActivityQuery()
        timelineStore = FakeCoachTimelineStore()
    }

    override func tearDown() {
        timelineStore = nil
        healthQuery = nil
        weightLogService = nil
        harness = nil
        super.tearDown()
    }

    func testPhotoRequestIncludesContextV2() async throws {
        _ = try? harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Salad", calories: 420),
            date: harness.today
        )
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 6_000

        let context = await makeContextBuilder().makeContext(
            recentMessages: [],
            currentUserMessage: "Lunch photo"
        )
        let attachment = try makeUploadAttachment()

        let request = try XCTUnwrap(
            CoachMealImageAIRequestBuilder.buildAnalysisRequest(
                attachment: attachment,
                context: context,
                message: "Lunch photo"
            ).successValue
        )

        XCTAssertEqual(request.context.meta.schemaVersion, CoachContextPacketV2.schemaVersion)
        XCTAssertEqual(request.context.today?.nutrition?.caloriesConsumed, 420)
        XCTAssertEqual(request.context.today?.steps?.value, 6_000)
        XCTAssertEqual(request.context.recentMealsStructured.first?.name, "Salad")
        let contextJSON = try request.context.encodedJSONData()
        let contextString = String(data: contextJSON, encoding: .utf8) ?? ""
        XCTAssertFalse(contextString.contains(String(request.image.base64.prefix(16))))
        XCTAssertFalse(request.image.base64.isEmpty)
    }

    func testWorkoutTodayIncludedAfterWorkout() async throws {
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

        let context = await makeContextBuilder().makeContext(recentMessages: [], mode: .live)
        let attachment = try makeUploadAttachment()
        let request = try XCTUnwrap(
            CoachMealImageAIRequestBuilder.buildAnalysisRequest(
                attachment: attachment,
                context: context,
                message: nil
            ).successValue
        )

        XCTAssertEqual(request.context.training?.workoutsToday, 1)
        XCTAssertEqual(request.context.training?.workouts.first?.title, "Run")
    }

    func testStepsIncludedOrMissingDataPopulated() async throws {
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 9_500
        let withSteps = await makeContextBuilder().makeContext(recentMessages: [], mode: .live)
        XCTAssertEqual(withSteps.today?.steps?.value, 9_500)
        XCTAssertFalse(withSteps.missingData.stepsMissing)

        healthQuery.stepsError = HealthKitManagerError.authorizationDenied
        let withoutSteps = await makeContextBuilder().makeContext(recentMessages: [], mode: .degraded)
        XCTAssertNil(withoutSteps.today?.steps)
        XCTAssertTrue(withoutSteps.missingData.stepsMissing)
    }

    func testClarificationPreservesPreviousAnalysis() throws {
        let attachment = try makeUploadAttachment()
        let previous = AIMealImageAnalysisPreviousAnalysis(
            summary: "Grain bowl",
            items: [
                AIMealImageAnalysisPreviousItem(
                    name: "Grain bowl",
                    quantity: "1 bowl",
                    calories: 400,
                    protein: 16,
                    carbs: 52,
                    fat: 10,
                    confidence: .low,
                    assumptions: ["Looked like quinoa"]
                )
            ],
            total: AIMealImageAnalysisTotals(
                calories: 400,
                protein: 16,
                carbs: 52,
                fat: 10
            )
        )

        let request = try XCTUnwrap(
            CoachMealImageAIRequestBuilder.buildAnalysisRequest(
                attachment: attachment,
                context: .test,
                message: "Lunch",
                clarification: "It was barley, not quinoa.",
                previousAnalysis: previous
            ).successValue
        )

        XCTAssertEqual(request.clarification, "It was barley, not quinoa.")
        XCTAssertEqual(request.previousAnalysis?.summary, "Grain bowl")
        XCTAssertEqual(request.previousAnalysis?.items.count, 1)
        XCTAssertEqual(request.previousAnalysis?.total.calories, 400)
    }

    func testPhotoFailureRecordsTimelineEvent() async throws {
        let fitness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: harness.today)
        try fitness.seedProfile()
        let aiService = FailingMealPhotoAIService()
        let recorder = DefaultCoachTimelineRecorder(store: timelineStore)
        let model = makePhotoCoachModel(
            fitness: fitness,
            aiService: aiService,
            timelineRecorder: recorder
        )

        let photoStaged1 = await CoachImageWorkflowTestSupport.stageTestMealPhoto(


            on: model,


            jpeg: makeTestJPEGData(),


            source: .library


        )


        XCTAssertTrue(photoStaged1)
        await model.sendCurrentMessage()

        let failedEvent = try await waitForEvent { $0.type == .photoAnalysisFailed }
        XCTAssertEqual(failedEvent.linkedPhotoSessionId, failedEvent.link.linkedPhotoSessionId)
        XCTAssertTrue(timelineStore.events.contains { $0.type == .photoAttached })
        XCTAssertTrue(timelineStore.events.contains { $0.type == .photoAnalysisStarted })
    }

    func testConfirmedPhotoFoodCreatesLinkedFoodLoggedEvent() async throws {
        let fitness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: harness.today)
        try fitness.seedProfile()
        let aiService = PhotoContextCapturingAIService()
        let recorder = DefaultCoachTimelineRecorder(store: timelineStore)
        let model = makePhotoCoachModel(
            fitness: fitness,
            aiService: aiService,
            timelineRecorder: recorder
        )

        let photoStaged2 = await CoachImageWorkflowTestSupport.stageTestMealPhoto(


            on: model,


            jpeg: makeTestJPEGData(),


            source: .library


        )


        XCTAssertTrue(photoStaged2)
        await model.sendCurrentMessage()
        XCTAssertNotNil(model.pendingConfirmation)

        _ = try await waitForEvent { $0.type == .photoAnalysisCompleted }
        let sessionId = try XCTUnwrap(model.pendingConfirmation?.foodDraft?.imageAnalysisSessionID)
        XCTAssertEqual(aiService.lastRequest?.context.meta.schemaVersion, CoachContextPacketV2.schemaVersion)
        XCTAssertGreaterThanOrEqual(aiService.lastRequest?.context.training?.workoutsToday ?? 0, 0)

        await model.confirmPendingFromBar()

        let foodLogged = try await waitForEvent { $0.type == .foodLogged }
        XCTAssertEqual(foodLogged.linkedPhotoSessionId, sessionId)
        XCTAssertNotNil(foodLogged.linkedEntryId)
    }

    func testPhotoClarificationRecordsTimelineEvents() async throws {
        let fitness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: harness.today)
        try fitness.seedProfile()
        let aiService = ClarifyingPhotoContextAIService()
        let recorder = DefaultCoachTimelineRecorder(store: timelineStore)
        let model = makePhotoCoachModel(
            fitness: fitness,
            aiService: aiService,
            timelineRecorder: recorder
        )

        let photoStaged3 = await CoachImageWorkflowTestSupport.stageTestMealPhoto(


            on: model,


            jpeg: makeTestJPEGData(),


            source: .library


        )


        XCTAssertTrue(photoStaged3)
        await model.sendCurrentMessage()

        let asked = try await waitForEvent { $0.type == .clarificationAsked }
        XCTAssertNotNil(asked.linkedPhotoSessionId)

        await model.send("It was barley, not quinoa.")

        let answered = try await waitForEvent { $0.type == .clarificationAnswered }
        XCTAssertEqual(answered.linkedPhotoSessionId, asked.linkedPhotoSessionId)
        XCTAssertEqual(aiService.receivedClarifications.last, "It was barley, not quinoa.")

        let photoLifecycleEvents = timelineStore.events.filter {
            [
                CoachTimelineEventType.photoAttached,
                CoachTimelineEventType.photoAnalysisStarted,
                CoachTimelineEventType.photoAnalysisCompleted,
                CoachTimelineEventType.clarificationAsked,
                CoachTimelineEventType.clarificationAnswered
            ].contains($0.type)
        }
        let sessionIds = Set(photoLifecycleEvents.compactMap(\.linkedPhotoSessionId))
        XCTAssertEqual(sessionIds.count, 1)
    }

    func testCommonFoodsIncludedWhenAvailable() async throws {
        for _ in 0..<2 {
            _ = try harness.foodLogService.addFoodEntry(
                DailyLogServiceTestSupport.foodDraft(name: "Oatmeal", calories: 310, protein: 11),
                date: harness.today
            )
        }

        let context = await makeContextBuilder().makeContext(recentMessages: [], mode: .live)
        let attachment = try makeUploadAttachment()
        let request = try XCTUnwrap(
            CoachMealImageAIRequestBuilder.buildAnalysisRequest(
                attachment: attachment,
                context: context,
                message: nil
            ).successValue
        )

        XCTAssertFalse(request.context.commonFoods.isEmpty)
        XCTAssertEqual(request.context.commonFoods.first?.name, "oatmeal")
    }

    func testHealthIntelligenceIncludedWhenEnabled() async throws {
        let snapshotProvider = MealPhotoHealthIntelligenceSnapshotProvider()
        snapshotProvider.snapshot = HealthIntelligenceSnapshot(
            date: harness.today,
            recovery: RecoverySummary(
                score: 72,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable.",
                recommendedTraining: "Train as planned.",
                recommendedNutrition: "Prioritize protein.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .strength,
                title: "Strength training",
                workoutCount: 1,
                totalDurationMinutes: 45,
                totalActiveCalories: 280,
                intensity: .moderate,
                demand: .high,
                latestWorkoutStart: harness.today,
                latestWorkoutEnd: harness.today.addingTimeInterval(2_700),
                nutritionAdvice: "Refuel with protein.",
                hydrationAdviceMl: 500,
                explanation: "Workout logged.",
                confidence: .high,
                sourceSummary: "Synced workout."
            ),
            activity: ActivitySummary(steps: 7_500, activeEnergyKcal: 350, exerciseMinutes: 45),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.8, label: "High"),
            nextBestAction: .none
        )

        let context = await makeContextBuilder(
            snapshotProvider: snapshotProvider,
            loadHealthIntelligence: true
        ).makeContext(recentMessages: [], mode: .live)
        let attachment = try makeUploadAttachment()
        let request = try XCTUnwrap(
            CoachMealImageAIRequestBuilder.buildAnalysisRequest(
                attachment: attachment,
                context: context,
                message: nil
            ).successValue
        )

        XCTAssertNotNil(request.context.healthIntelligence)
        XCTAssertTrue(request.context.sourceAttribution?.healthIntelligenceIncluded == true)
    }

    func testRejectedPhotoEstimateExcludedFromConsumedTotals() async throws {
        let fitness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: harness.today)
        try fitness.seedProfile()
        let aiService = PhotoContextCapturingAIService()
        let model = makePhotoCoachModel(
            fitness: fitness,
            aiService: aiService,
            timelineRecorder: DefaultCoachTimelineRecorder(store: timelineStore)
        )

        let photoStaged4 = await CoachImageWorkflowTestSupport.stageTestMealPhoto(


            on: model,


            jpeg: makeTestJPEGData(),


            source: .library


        )


        XCTAssertTrue(photoStaged4)
        await model.sendCurrentMessage()
        XCTAssertNotNil(model.pendingConfirmation)

        await model.send("cancel")
        XCTAssertNil(model.pendingConfirmation)

        let log = try fitness.dailyLogService.getTodayLog()
        XCTAssertEqual(log.totals.calories, 0)

        let context = await makeContextBuilder().makeContext(recentMessages: [], mode: .live)
        XCTAssertEqual(context.today?.nutrition?.caloriesConsumed, 0)
    }

    func testTimelinePhotoEventsDoNotStoreRawImageBytes() async throws {
        let fitness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: harness.today)
        try fitness.seedProfile()
        let aiService = PhotoContextCapturingAIService()
        let recorder = DefaultCoachTimelineRecorder(store: timelineStore)
        let model = makePhotoCoachModel(
            fitness: fitness,
            aiService: aiService,
            timelineRecorder: recorder
        )

        let photoStaged5 = await CoachImageWorkflowTestSupport.stageTestMealPhoto(


            on: model,


            jpeg: makeTestJPEGData(),


            source: .library


        )


        XCTAssertTrue(photoStaged5)
        await model.sendCurrentMessage()
        _ = try await waitForEvent { $0.type == .photoAnalysisCompleted }

        let encoded = try JSONEncoder().encode(timelineStore.events)
        let json = String(data: encoded, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("base64"))
        XCTAssertFalse(json.contains("imageJPEG"))

        let attached = try await waitForEvent { $0.type == .photoAttached }
        if case .photo(let payload) = attached.payload {
            XCTAssertNotNil(payload.sessionId)
            XCTAssertNotNil(payload.compressedByteSize)
        }
    }

    func testAmbiguousPhotoAnalysisMapperSurfacesClarification() {
        let response = AIMealImageAnalysisResponse(
            summary: "Grain bowl",
            items: [
                AIMealImageAnalysisItem(
                    name: "Grain bowl",
                    quantity: "1 bowl",
                    calories: 400,
                    protein: 16,
                    carbs: 52,
                    fat: 10,
                    confidence: .low,
                    assumptions: ["Grain type unclear"]
                )
            ],
            total: AIMealImageAnalysisTotals(calories: 400, protein: 16, carbs: 52, fat: 10),
            needsUserReview: true,
            clarifyingQuestion: "Was this rice or barley?"
        )

        let sessionResult = MealImageAnalysisMapper.sessionResult(from: response)
        XCTAssertEqual(sessionResult.clarifyingQuestion, "Was this rice or barley?")
        XCTAssertTrue(sessionResult.mealDraft.warnings.contains("Was this rice or barley?"))
        XCTAssertTrue(sessionResult.mealDraft.warnings.contains("Grain type unclear"))
    }

    // MARK: Helpers

    private func makeContextBuilder(
        snapshotProvider: (any HealthIntelligenceSnapshotServing)? = nil,
        loadHealthIntelligence: Bool = false
    ) -> CoachContextPacketV2Builder {
        CoachContextPacketV2Builder(
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: weightLogService,
            userProfileService: harness.profileService,
            healthActivityQuery: HealthActivityQueryService(
                workoutReader: StubHealthKitWorkoutReader(workouts: healthQuery.workouts),
                stepReader: StubHealthKitStepReader(
                    stepsByDay: healthQuery.stepsByDay,
                    error: healthQuery.stepsError
                ),
                repositoryReadRoutingEnabled: false
            ),
            healthIntelligenceSnapshotProvider: snapshotProvider,
            timelineStore: timelineStore,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar,
            loadHealthIntelligence: { loadHealthIntelligence }
        )
    }

    private func makePhotoCoachModel(
        fitness: FitnessActionCenterTestSupport.Harness,
        aiService: AIServiceProtocol,
        timelineRecorder: any CoachTimelineRecording
    ) -> CoachModel {
        let packetBuilder = CoachContextPacketV2Builder(
            dailyLogService: fitness.dailyLogService,
            foodLogService: fitness.base.foodLogService,
            waterLogService: fitness.base.waterLogService,
            weightLogService: fitness.weightLogService,
            userProfileService: fitness.profileService,
            healthActivityQuery: fitness.healthActivityQuery,
            timelineStore: timelineStore,
            timelineRecorder: timelineRecorder,
            dateProvider: fitness.base.dateProvider,
            calendar: fitness.base.dateProvider.calendar
        )
        return CoachModelTestFactory.makeModel(
            actionCenter: fitness.actionCenter,
            dailyLogReader: fitness.dailyLogService,
            healthActivityQuery: fitness.healthActivityQuery,
            aiService: aiService,
            contextPacketBuilder: packetBuilder,
            userProfileReader: fitness.profileService,
            aiCommandParsingEnabled: true,
            timelineRecorder: timelineRecorder,
            timelineStore: timelineStore
        )
    }

    private func makeUploadAttachment() throws -> CoachMealImageUploadAttachment {
        let image = makeTestImage()
        guard case .success(let processed) = CoachImagePipeline.process(image: image) else {
            throw NSError(domain: "CoachMealPhotoContextV2Tests", code: 1)
        }
        return CoachMealImageUploadAttachment.from(processed: processed)
    }

    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        return renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
    }

    private func makeTestJPEGData() -> Data {
        makeTestImage().jpegData(compressionQuality: 0.85)!
    }

    private func waitForEvent(
        _ predicate: @escaping (CoachTimelineEvent) -> Bool,
        timeout: TimeInterval = 2.0
    ) async throws -> CoachTimelineEvent {
        let satisfied = await AsyncTestSupport.waitUntil(maxYields: Int(timeout * 100)) {
            self.timelineStore.events.contains(where: predicate)
        }
        XCTAssertTrue(satisfied, "Timed out waiting for timeline event")
        return try XCTUnwrap(timelineStore.events.first(where: predicate))
    }
}

// MARK: - Test doubles

private final class MealPhotoHealthIntelligenceSnapshotProvider: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        snapshot
    }
}

@MainActor
private final class ClarifyingPhotoContextAIService: AIServiceProtocol, @unchecked Sendable {
    private(set) var receivedClarifications: [String?] = []

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func estimateFood(
        prompt: String,
        context: CoachContextPacketV2,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        receivedClarifications.append(request.clarification)
        let isClarification = request.clarification?.isEmpty == false
        return AIMealImageAnalysisResponse(
            summary: isClarification ? "Barley bowl" : "Grain bowl",
            items: [
                AIMealImageAnalysisItem(
                    name: isClarification ? "Barley bowl" : "Grain bowl",
                    quantity: "1 bowl",
                    calories: 420,
                    protein: 28,
                    carbs: 35,
                    fat: 14,
                    confidence: isClarification ? .medium : .low,
                    assumptions: []
                )
            ],
            total: AIMealImageAnalysisTotals(calories: 420, protein: 28, carbs: 35, fat: 14),
            needsUserReview: true,
            clarifyingQuestion: isClarification ? nil : "Was this rice or barley?"
        )
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

@MainActor
private final class PhotoContextCapturingAIService: AIServiceProtocol, @unchecked Sendable {
    private(set) var lastRequest: AIMealImageAnalysisRequest?

    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func estimateFood(
        prompt: String,
        context: CoachContextPacketV2,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        throw AIServiceError.backendUnavailable
    }

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        lastRequest = request
        return AIMealImageAnalysisResponse(
            summary: "Photo meal",
            items: [
                AIMealImageAnalysisItem(
                    name: "Photo meal",
                    quantity: "1 serving",
                    calories: 420,
                    protein: 28,
                    carbs: 35,
                    fat: 14,
                    confidence: .medium,
                    assumptions: []
                )
            ],
            total: AIMealImageAnalysisTotals(calories: 420, protein: 28, carbs: 35, fat: 14),
            needsUserReview: true,
            clarifyingQuestion: nil
        )
    }

    func generateMealAdvice(
        prompt: String,
        context: CoachContextPacketV2,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> AICoachResponse {
        AICoachResponse(message: "Within target.", confidence: .medium)
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

@MainActor
private final class FailingMealPhotoAIService: AIServiceProtocol, @unchecked Sendable {
    func classifyCoachIntent(
        _ text: String,
        context: CoachContextPacketV2,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        CoachMealPhotoPipeline.photoAnalysisIntentResult
    }

    func estimateFood(
        prompt: String,
        context: CoachContextPacketV2,
        imageJPEGData: Data?
    ) async throws -> AIFoodEstimateResponse {
        throw AIServiceError.backendUnavailable
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

private extension Result {
    var successValue: Success? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
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
        return workouts
    }
}

private struct StubHealthKitStepReader: HealthKitStepReading {
    let stepsByDay: [Date: Int]
    let error: Error?

    init(stepsByDay: [Date: Int], error: Error? = nil) {
        self.stepsByDay = stepsByDay
        self.error = error
    }

    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        if let error { throw error }
        guard let steps = stepsByDay[startDate] else {
            throw HealthKitManagerError.authorizationDenied
        }
        return steps
    }
}
