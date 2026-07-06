//
//  CoachModelDecompositionCharacterizationTests.swift
//  Fitness CoachTests
//
//  Freezes current CoachModel behavior before decomposition refactors.
//  Run this suite before and after each extraction PR.
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachModelDecompositionCharacterizationTests: XCTestCase {

    private var harness: CoachRoutingIntegrationTestSupport.Harness!
    private var timelineStore: FakeCoachTimelineStore!

    override func setUp() async throws {
        harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        timelineStore = FakeCoachTimelineStore()
    }

    override func tearDown() {
        timelineStore = nil
        harness = nil
        super.tearDown()
    }

    // MARK: - Text send

    func testPlainMessageSend_appendsUserAndAssistantMessages() async {
        let aiService = CoachModelCharacterizationTestSupport.UnreachableAIService()
        let model = harness.makeCoach(aiService: aiService, timelineStore: timelineStore)

        await model.send("hello")

        XCTAssertGreaterThanOrEqual(model.messageCount, 2)
        XCTAssertEqual(model.messages.filter { $0.role == .user }.last?.text, "hello")
        XCTAssertEqual(model.messages.filter { $0.role == .assistant }.last?.text, CoachResponseBuilder.greetingResponse)
        XCTAssertEqual(aiService.classifyCallCount, 0)
        XCTAssertNil(model.pendingConfirmation)
    }

    // MARK: - Local greeting

    func testLocalGreetingPath_doesNotCallClassifier() async {
        let aiService = CoachModelCharacterizationTestSupport.UnreachableAIService()
        let model = harness.makeCoach(aiService: aiService, timelineStore: timelineStore)

        await model.send("hi")

        XCTAssertEqual(aiService.classifyCallCount, 0)
        XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.greetingResponse)
    }

    // MARK: - Local food estimate

    func testLocalFoodEstimatePath_createsPendingWithoutAI() async {
        let aiService = CoachModelCharacterizationTestSupport.UnreachableAIService()
        let model = harness.makeCoach(aiService: aiService, timelineStore: timelineStore)

        await model.send("log 500g chicken breast")

        XCTAssertEqual(aiService.classifyCallCount, 0)
        XCTAssertEqual(aiService.estimateFoodCallCount, 0)
        guard case .food(let draft) = model.pendingConfirmation else {
            return XCTFail("Expected local food pending confirmation")
        }
        XCTAssertTrue(draft.primaryMealDraft.totalCalories > 0)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 0)
    }

    // MARK: - AI food estimate pending

    func testAIFoodEstimatePath_createsPendingConfirmation() async {
        let aiService = CoachModelCharacterizationTestSupport.FoodEstimateAIService()
        let model = harness.makeCoach(aiService: aiService, timelineStore: timelineStore)

        await model.send("log chicken rice bowl")

        XCTAssertEqual(aiService.classifyCallCount, 1)
        XCTAssertEqual(aiService.estimateFoodCallCount, 1)
        guard case .food(let draft) = model.pendingConfirmation else {
            return XCTFail("Expected AI food pending confirmation")
        }
        XCTAssertEqual(draft.primaryMealDraft.displayName, "Chicken rice bowl")
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 0)
    }

    // MARK: - Confirm food

    func testConfirmPendingFromBar_logsFoodAndClearsPending() async {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.FoodEstimateAIService(),
            timelineStore: timelineStore
        )

        await model.send("log chicken rice bowl")
        await model.confirmPendingFromBar()

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)
        let logged = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
            in: timelineStore,
            matching: { $0.type == .foodLogged }
        )
        XCTAssertNotNil(logged.linkedEntryId)
    }

    // MARK: - Cancel pending

    func testRejectPendingFromBar_preservesRejectionCopy() async {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.FoodEstimateAIService(),
            timelineStore: timelineStore
        )

        await model.send("log chicken rice bowl")
        model.rejectPendingFromBar()

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.pendingRejected)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 0)
    }

    func testTypedReject_clearsPendingWithSameCopy() async {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.FoodEstimateAIService(),
            timelineStore: timelineStore
        )

        await model.send("log chicken rice bowl")
        await model.send("no")

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.pendingRejected)
    }

    // MARK: - Edit pending draft

    func testEditPendingFoodDraft_updatesCaloriesBeforeConfirm() async {
        let estimatedDraft = FoodDraft(
            mealType: nil,
            name: "Chicken rice",
            quantity: 1,
            unit: "plate",
            calories: 650,
            protein: 35,
            carbs: 75,
            fat: 20,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )
        let aiService = CoachModelCharacterizationTestSupport.FoodEstimateAIService(
            estimateResponse: AIFoodEstimateResponse(
                foodLogDrafts: [estimatedDraft],
                confidence: .medium,
                requiresConfirmation: true
            )
        )
        let model = harness.makeCoach(aiService: aiService, timelineStore: timelineStore)

        await model.send("log chicken rice")

        var formState = FoodLogEditFormState(foodDraft: estimatedDraft)
        formState.componentStates[0].caloriesText = "700"
        model.saveFoodEdit(formState)

        guard case .food(let draft) = model.pendingConfirmation else {
            return XCTFail("Expected food pending confirmation after edit")
        }
        XCTAssertEqual(draft.primaryMealDraft.totalCalories, 700)

        await model.confirmPendingFromBar()
        let entry = try XCTUnwrap(try harness.actionCenter.getFoodEntries(for: harness.today).first)
        XCTAssertEqual(entry.calories, 700)
    }

    // MARK: - Undo (local)

    func testUndoWater_afterImmediateLog_reducesWaterTotal() async {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.UnreachableAIService(),
            timelineStore: timelineStore
        )

        await model.send("add 500ml water")
        XCTAssertEqual(try harness.dailyLogService.getTodayLog().waterConsumedMl, 500)

        await model.send("undo water")
        XCTAssertEqual(try harness.dailyLogService.getTodayLog().waterConsumedMl, 0)
    }

    // MARK: - Water / weight immediate paths

    func testWaterLogImmediatePath_noPendingConfirmation() async {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.UnreachableAIService(),
            timelineStore: timelineStore
        )

        await model.send("add 500ml water")

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(try harness.dailyLogService.getTodayLog().waterConsumedMl, 500)
        XCTAssertTrue(model.messages.last?.text.contains("500") == true)
    }

    func testWeightLogImmediatePath_noPendingConfirmation() async {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.UnreachableAIService(),
            timelineStore: timelineStore
        )

        await model.send("weight 72.5")

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(try harness.dailyLogService.getTodayLog().weightKg ?? 0, 72.5, accuracy: 0.01)
        XCTAssertTrue(model.messages.last?.text.contains("72.50") == true)
    }

    // MARK: - Photo attachment preview

    func testPhotoAttachmentPreviewState_stagesWithoutSending() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        let model = CoachModelTestFactory.makeModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: CoachModelCharacterizationTestSupport.CharacterizationPhotoAIService(),
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        XCTAssertTrue(
            await CoachImageWorkflowTestSupport.stageTestMealPhoto(
                on: model,
                jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
                source: .library
            )
        )

        XCTAssertNotNil(model.inputState.pendingImage)
        XCTAssertTrue(model.inputState.hasReadyPendingImage)
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertFalse(model.isSending)
    }

    func testTextOnlySendClearsStagedMealPhoto() async throws {
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        let model = CoachModelTestFactory.makeModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: CoachModelCharacterizationTestSupport.UnreachableAIService(),
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        XCTAssertTrue(
            await CoachImageWorkflowTestSupport.stageTestMealPhoto(
                on: model,
                jpeg: CoachImageWorkflowTestSupport.makeTestJPEG(),
                source: .library
            )
        )
        XCTAssertTrue(model.inputState.hasReadyPendingImage)

        await model.send("daily review")

        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNil(model.inputState.imageError)
    }

    // MARK: - Photo send success

    func testPhotoSendSuccess_createsPendingConfirmationAndClearsStagedImage() async throws {
        let aiService = CoachModelCharacterizationTestSupport.CharacterizationPhotoAIService()
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        let model = CoachModelTestFactory.makeModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        _ = try await CoachModelCharacterizationTestSupport.stageAndSendPhoto(on: model, aiService: aiService)

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
        XCTAssertNotNil(model.pendingConfirmation)
        XCTAssertNil(model.inputState.pendingImage)
        XCTAssertNotNil(model.messages.first { $0.role == .user }?.mealPhotoJPEG)
        XCTAssertEqual(model.messages.last?.role, .assistant)
    }

    // MARK: - Photo failure and retry

    func testPhotoAnalysisFailureAndRetry_surfacesErrorThenPending() async throws {
        let aiService = CoachModelCharacterizationTestSupport.CharacterizationPhotoAIService()
        aiService.injectedAnalyzeError = AIServiceError.networkUnavailable
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        let model = CoachModelTestFactory.makeModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        let userMessageID = try await CoachModelCharacterizationTestSupport.stageAndSendPhoto(
            on: model,
            aiService: aiService
        )

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.isFailure == true })

        aiService.injectedAnalyzeError = nil
        await model.retryMealPhotoAnalysis(for: userMessageID)

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
        XCTAssertNotNil(model.pendingConfirmation)
    }

    // MARK: - Photo recommission / correction

    func testPhotoRecommission_afterClarification_usesSameImage() async throws {
        let aiService = CoachModelCharacterizationTestSupport.CharacterizationPhotoAIService()
        aiService.clarifyingQuestion = "Was this rice or barley?"
        let container = try AppContainer(inMemory: true)
        try container.userProfileService.createProfile(ProfileTestFixtures.sampleDraft)
        let model = CoachModelTestFactory.makeModel(
            actionCenter: container.actionCenter,
            dailyLogReader: container.dailyLogService,
            healthActivityQuery: container.healthActivityQueryService,
            aiService: aiService,
            userProfileReader: container.userProfileService,
            aiCommandParsingEnabled: true
        )

        _ = try await CoachModelCharacterizationTestSupport.stageAndSendPhoto(on: model, aiService: aiService)

        XCTAssertTrue(model.awaitingPhotoClarification)
        XCTAssertNotNil(model.pendingConfirmation)

        model.inputText = "It was barley."
        await model.send("It was barley.")

        XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
        XCTAssertFalse(model.awaitingPhotoClarification)
        XCTAssertNotNil(model.pendingConfirmation)
    }

    // MARK: - Transcript persistence

    func testTranscriptPersistence_savesOnEachAppend() async {
        let transcriptStore = CoachModelCharacterizationTestSupport.CapturingCoachChatTranscriptStore()
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.UnreachableAIService(),
            transcriptStore: transcriptStore,
            timelineStore: timelineStore
        )

        await model.send("hello")

        XCTAssertGreaterThanOrEqual(transcriptStore.saveCount, 2)
        XCTAssertEqual(transcriptStore.persistedMessages.count, model.messageCount)
        XCTAssertEqual(transcriptStore.persistedMessages.first?.text, "hello")
    }

    func testTranscriptPersistence_loadsOnInit() throws {
        let transcriptStore = CoachModelCharacterizationTestSupport.CapturingCoachChatTranscriptStore()
        let seeded = ChatMessage(role: .user, text: "persisted hello", createdAt: Date())
        transcriptStore.saveMessages([seeded])

        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.UnreachableAIService(),
            transcriptStore: transcriptStore
        )

        XCTAssertEqual(model.messageCount, 1)
        XCTAssertEqual(model.messages.first?.text, "persisted hello")
    }

    // MARK: - Timeline recording

    func testTimelineRecording_createsUserAssistantAndPendingEvents() async throws {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.FoodEstimateAIService(),
            timelineStore: timelineStore
        )

        await model.send("log chicken rice bowl")

        _ = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
            in: timelineStore,
            matching: { $0.type == .userMessage }
        )
        _ = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
            in: timelineStore,
            matching: { $0.type == .assistantMessage }
        )
        let pending = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
            in: timelineStore,
            matching: { $0.type == .pendingConfirmationCreated }
        )
        XCTAssertEqual(pending.status, .pending)
    }

    // MARK: - Today refresh after mutation

    func testTodayRefreshAfterMutation_reflectsLoggedCalories() async {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.FoodEstimateAIService(
                estimateResponse: AIFoodEstimateResponse(
                    foodLogDrafts: [FoodLoggingGoldenFixtures.case4MealDraft],
                    confidence: .medium,
                    requiresConfirmation: true
                )
            ),
            timelineStore: timelineStore
        )

        model.refreshTodayContext()
        _ = await waitForTodayContext(on: model)
        let baselineCaloriesLine = model.todayContext?.caloriesLine

        await model.send(FoodLoggingGoldenFixtures.case4Prompt)
        await model.confirmPendingFromBar()
        model.refreshTodayContext()

        let updated = await waitForTodayContext(on: model)
        XCTAssertNotNil(updated)
        XCTAssertNotEqual(updated?.caloriesLine, baselineCaloriesLine)
        XCTAssertTrue(updated?.caloriesLine.contains("\(FoodLoggingGoldenFixtures.case4MealDraft.totalCalories)") == true)
    }

    // MARK: - Duplicate confirmation protection

    func testDuplicateConfirmFromBar_doesNotCreateSecondFoodEntry() async {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.FoodEstimateAIService(
                estimateResponse: AIFoodEstimateResponse(
                    foodLogDrafts: [FoodLoggingGoldenFixtures.case4MealDraft],
                    confidence: .medium,
                    requiresConfirmation: true
                )
            )
        )

        await model.send(FoodLoggingGoldenFixtures.case4Prompt)
        await model.confirmPendingFromBar()
        await model.confirmPendingFromBar()

        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)
    }

    func testPendingConfirmationTimeline_dedupesCreatedEvent() async throws {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.FoodEstimateAIService(),
            timelineStore: timelineStore
        )

        await model.send("log chicken rice bowl")

        let pendingEvents = timelineStore.events.filter { $0.type == .pendingConfirmationCreated }
        XCTAssertEqual(pendingEvents.count, 1)
    }

    // MARK: - Error copy preservation

    func testBackendUnavailable_preservesCanonicalErrorCopy() async {
        let model = harness.makeCoach(
            aiService: CoachModelCharacterizationTestSupport.FailingEstimateAIService(),
            timelineStore: timelineStore
        )

        await model.send("log mystery quinoa bowl")

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertEqual(model.messages.last?.text, FormaProductCopy.Error.coachUnavailable)
    }

    // MARK: - Correction memory

    func testCorrectionMemory_writeOnPendingEdit_readInContextPacket() async throws {
        let memoryStore = InMemoryFoodCorrectionMemoryStore()
        let estimatedDraft = FoodDraft(
            mealType: nil,
            name: "Chicken rice",
            quantity: 1,
            unit: "plate",
            calories: 650,
            protein: 35,
            carbs: 75,
            fat: 20,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )
        let aiService = CoachModelCharacterizationTestSupport.FoodEstimateAIService(
            estimateResponse: AIFoodEstimateResponse(
                foodLogDrafts: [estimatedDraft],
                confidence: .medium,
                requiresConfirmation: true
            )
        )
        let model = harness.makeCoach(
            aiService: aiService,
            foodCorrectionMemoryStore: memoryStore,
            timelineStore: timelineStore
        )

        await model.send("log chicken rice")

        var formState = FoodLogEditFormState(foodDraft: estimatedDraft)
        formState.componentStates[0].caloriesText = "700"
        model.saveFoodEdit(formState)

        var resolved: [FoodCorrectionMemoryEntry] = []
        var recorded = false
        for _ in 0..<40 {
            await Task.yield()
            resolved = (try? await memoryStore.recentEntries(limit: 10)) ?? []
            if !resolved.isEmpty {
                recorded = true
                break
            }
        }
        XCTAssertTrue(recorded, "Expected correction memory after pending edit")
        XCTAssertFalse(resolved.isEmpty)

        let packetBuilder = CoachContextPacketV2Builder(foodCorrectionMemoryStore: memoryStore)
        let packet = await packetBuilder.makeContext(recentMessages: [], mode: .preview)
        XCTAssertFalse(packet.foodCorrectionMemory.isEmpty)
    }

    // MARK: - Helpers

    private func waitForTodayContext(
        on model: CoachModel,
        timeout: TimeInterval = 1.0
    ) async -> CoachTodayContextState? {
        let satisfied = await AsyncTestSupport.waitUntilWallClock(timeout: timeout) {
            model.todayContext != nil
        }
        return satisfied ? model.todayContext : nil
    }
}
