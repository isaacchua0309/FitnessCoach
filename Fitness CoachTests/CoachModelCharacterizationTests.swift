//
//  CoachModelCharacterizationTests.swift
//  Fitness CoachTests
//
//  End-to-end characterization coverage for CoachModel before decomposition (TD-COACH-001).
//  These tests freeze visible behavior — do not "improve" assertions when refactoring.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachModelCharacterizationTests: XCTestCase {

  private var harness: CoachModelCharacterizationTestSupport.Harness!

  override func setUp() async throws {
    harness = try CoachModelCharacterizationTestSupport.makeHarness()
  }

  override func tearDown() {
    harness = nil
    super.tearDown()
  }

  // MARK: - Text send paths

  func testPlainMessageSendAppendsUserMessageAndPersistsTranscript() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("status")

    XCTAssertEqual(model.messages.filter { $0.role == .user }.last?.text, "status")
    XCTAssertGreaterThanOrEqual(model.messageCount, 2)
    XCTAssertGreaterThanOrEqual(harness.transcriptStore.saveCallCount, 2)
    XCTAssertEqual(aiService.classifyCoachIntentCallCount, 0)
    XCTAssertFalse(model.isSending)
  }

  func testLocalGreetingPathReturnsGreetingWithoutClassifier() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("hello")

    XCTAssertEqual(model.messages.filter { $0.role == .user }.last?.text, "hello")
    XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.greetingResponse)
    XCTAssertEqual(aiService.classifyCoachIntentCallCount, 0)
    XCTAssertNil(model.pendingConfirmation)
  }

  func testLocalFoodEstimateCreatesPendingWithoutClassifier() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log 500g chicken breast")

    XCTAssertEqual(aiService.classifyCoachIntentCallCount, 0)
    XCTAssertEqual(aiService.estimateFoodCallCount, 0)
    guard case .food(let draft) = model.pendingConfirmation else {
      return XCTFail("Expected local food pending confirmation")
    }
    XCTAssertGreaterThan(draft.primaryMealDraft.totalCalories, 0)
  }

  func testAIFoodEstimateCreatesPendingConfirmation() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = CoachModelCharacterizationTestSupport.characterizationFoodEstimateResponse()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log chicken rice bowl")

    XCTAssertEqual(aiService.classifyCoachIntentCallCount, 1)
    XCTAssertEqual(aiService.estimateFoodCallCount, 1)
    guard case .food(let draft) = model.pendingConfirmation else {
      return XCTFail("Expected AI food pending confirmation")
    }
    XCTAssertEqual(draft.primaryMealDraft.displayName, "Chicken rice bowl")
    XCTAssertEqual(draft.primaryMealDraft.totalCalories, 620)
  }

  // MARK: - Pending confirmation

  func testConfirmingFoodLogPersistsEntryAndClearsPending() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = CoachModelCharacterizationTestSupport.characterizationFoodEstimateResponse()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log chicken rice bowl")
    await model.confirmPendingFromBar()

    XCTAssertNil(model.pendingConfirmation)
    XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)
    let entry = try XCTUnwrap(try harness.actionCenter.getFoodEntries(for: harness.today).first)
    XCTAssertEqual(entry.calories, 620)
  }

  func testCancellingPendingConfirmationClearsPendingAndShowsRejectedCopy() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = CoachModelCharacterizationTestSupport.characterizationFoodEstimateResponse()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log chicken rice bowl")
    await model.send("no")

    XCTAssertNil(model.pendingConfirmation)
    XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.pendingRejected)
    XCTAssertTrue(try harness.actionCenter.getFoodEntries(for: harness.today).isEmpty)
  }

  func testRejectPendingFromBarShowsRejectedCopy() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = CoachModelCharacterizationTestSupport.characterizationFoodEstimateResponse()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log chicken rice bowl")
    model.rejectPendingFromBar()

    XCTAssertNil(model.pendingConfirmation)
    XCTAssertEqual(model.messages.last?.text, CoachResponseBuilder.pendingRejected)
  }

  func testEditPendingFoodDraftUpdatesCaloriesBeforeConfirm() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = CoachModelCharacterizationTestSupport.characterizationFoodEstimateResponse(
      calories: 650
    )
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log chicken rice")
    guard case .food(let pending) = model.pendingConfirmation else {
      return XCTFail("Expected food pending confirmation")
    }

    var form = FoodLogEditFormState(mealDraft: pending.primaryMealDraft)
    form.componentStates[0].caloriesText = "700"
    model.saveFoodEdit(form)

    guard case .food(let updated) = model.pendingConfirmation else {
      return XCTFail("Expected food pending confirmation after edit")
    }
    XCTAssertEqual(updated.primaryMealDraft.totalCalories, 700)

    await model.confirmPendingFromBar()
    let entry = try XCTUnwrap(try harness.actionCenter.getFoodEntries(for: harness.today).first)
    XCTAssertEqual(entry.calories, 700)
  }

  func testDuplicateConfirmDoesNotCreateSecondMealEntry() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = CoachModelCharacterizationTestSupport.characterizationFoodEstimateResponse()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log chicken rice bowl")
    await model.confirmPendingFromBar()
    await model.confirmPendingFromBar()

    XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)
  }

  // MARK: - Immediate local mutations

  func testWaterLogImmediatePath() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("add 500ml water")

    XCTAssertNil(model.pendingConfirmation)
    XCTAssertEqual(try harness.dailyLogService.getTodayLog().waterConsumedMl, 500)
    XCTAssertEqual(aiService.classifyCoachIntentCallCount, 0)
  }

  func testWeightLogImmediatePath() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("weight 89.2kg")

    XCTAssertNil(model.pendingConfirmation)
    XCTAssertEqual(try harness.dailyLogService.getTodayLog().weightKg, 89.2, accuracy: 0.01)
    XCTAssertEqual(aiService.classifyCoachIntentCallCount, 0)
  }

  func testUndoWaterRemovesLoggedWaterImmediately() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("add 500ml water")
    XCTAssertEqual(try harness.dailyLogService.getTodayLog().waterConsumedMl, 500)

    await model.send("undo water")

    XCTAssertNil(model.pendingConfirmation)
    XCTAssertEqual(try harness.dailyLogService.getTodayLog().waterConsumedMl, 0)
  }

  // MARK: - Delete flow (AI-assisted)

  func testDeleteFlowCreatesPendingDeleteConfirmation() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log 500g chicken breast")
    await model.confirmPendingFromBar()
    let loggedEntry = try XCTUnwrap(try harness.actionCenter.getFoodEntries(for: harness.today).first)

    aiService.classifyResult = CoachModelCharacterizationTestSupport.deleteLogIntent()
    aiService.parseEditOrDeleteHandler = { _, _ in
      AIParsedCommand(
        originalText: "delete lunch",
        intent: .deleteEntry,
        actions: [
          AICommandAction(
            type: .deleteEntry,
            targetEntrySelector: loggedEntry.id.uuidString,
            linkedEntryId: loggedEntry.id
          )
        ],
        confidence: .high,
        requiresConfirmation: true,
        assistantMessage: "Delete this meal?"
      )
    }

    await model.send("delete lunch")

    XCTAssertEqual(aiService.parseEditOrDeleteCallCount, 1)
    guard case .delete = model.pendingConfirmation else {
      return XCTFail("Expected delete pending confirmation")
    }

    await model.confirmPendingFromBar()
    XCTAssertNil(model.pendingConfirmation)
    XCTAssertTrue(try harness.actionCenter.getFoodEntries(for: harness.today).isEmpty)
  }

  // MARK: - Photo attachment and analysis

  func testPhotoAttachmentPreviewStateStagedWithoutSending() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    XCTAssertTrue(
      await CoachImageWorkflowTestSupport.stageTestMealPhoto(
        on: model,
        jpeg: CoachModelCharacterizationTestSupport.testJPEG(),
        source: .library
      )
    )

    XCTAssertNotNil(model.inputState.pendingImage)
    XCTAssertTrue(model.inputState.hasReadyPendingImage)
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertFalse(model.isSending)
    XCTAssertEqual(aiService.analyzeMealImageCallCount, 0)
  }

  func testPhotoSendSuccessCreatesPendingConfirmation() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    XCTAssertTrue(
      await CoachImageWorkflowTestSupport.stageTestMealPhoto(
        on: model,
        jpeg: CoachModelCharacterizationTestSupport.testJPEG(),
        source: .library
      )
    )
    await model.sendCurrentMessage()

    XCTAssertEqual(aiService.analyzeMealImageCallCount, 1)
    XCTAssertNotNil(model.pendingConfirmation)
    XCTAssertNil(model.inputState.pendingImage)
    XCTAssertNotNil(model.messages.first { $0.role == .user }?.mealPhotoJPEG)
    XCTAssertEqual(model.messages.last?.role, .assistant)
    XCTAssertFalse(model.messages.last?.photoAnalysisLink?.isFailure ?? true)
  }

  func testPhotoAnalysisFailureSurfacesErrorAndRetrySucceeds() async throws {
    let aiService = CharacterizationAIService()
    aiService.analyzeMealImageError = AIServiceError.networkUnavailable
    let model = harness.makeCoach(aiService: aiService)

    XCTAssertTrue(
      await CoachImageWorkflowTestSupport.stageTestMealPhoto(
        on: model,
        jpeg: CoachModelCharacterizationTestSupport.testJPEG(),
        source: .library
      )
    )
    await model.sendCurrentMessage()

    XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.isFailure == true })
    XCTAssertEqual(model.messages.last?.text, AIServiceError.networkUnavailable.userMessage)
    XCTAssertNil(model.pendingConfirmation)

    aiService.analyzeMealImageError = nil
    let userMessageID = try XCTUnwrap(model.messages.first { $0.role == .user }?.id)
    await model.retryMealPhotoAnalysis(for: userMessageID)

    XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
    XCTAssertNotNil(model.pendingConfirmation)
    XCTAssertTrue(model.messages.contains { $0.photoAnalysisLink?.isFailure == false })
  }

  func testPhotoRecommissionAfterClarification() async throws {
    let aiService = CharacterizationClarifyingPhotoAIService()
    let model = harness.makeCoach(aiService: aiService)

    XCTAssertTrue(
      await CoachImageWorkflowTestSupport.stageTestMealPhoto(
        on: model,
        jpeg: CoachModelCharacterizationTestSupport.testJPEG(),
        source: .library
      )
    )
    await model.sendCurrentMessage()

    XCTAssertTrue(model.awaitingPhotoClarification)
    XCTAssertNotNil(model.pendingConfirmation)

    model.inputText = "It was barley, not rice."
    await model.sendCurrentMessage()

    XCTAssertEqual(aiService.analyzeMealImageCallCount, 2)
    XCTAssertEqual(aiService.lastClarification, "It was barley, not rice.")
    XCTAssertNotNil(model.pendingConfirmation)
    XCTAssertFalse(model.awaitingPhotoClarification)
  }

  // MARK: - Transcript persistence

  func testTranscriptPersistenceOnSend() async throws {
    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("hello")

    XCTAssertGreaterThanOrEqual(harness.transcriptStore.saveCallCount, 2)
    XCTAssertEqual(harness.transcriptStore.messages.count, model.messages.count)
    XCTAssertEqual(harness.transcriptStore.messages.last?.text, model.messages.last?.text)
  }

  func testTranscriptReloadsOnInit() throws {
    let store = CapturingCoachTranscriptStore()
    let message = ChatMessage(role: .user, text: "hello again", createdAt: harness.today)
    store.saveMessages([message])

    let aiService = CharacterizationAIService()
    let model = harness.makeCoach(aiService: aiService, transcriptStore: store)

    XCTAssertEqual(model.messageCount, 1)
    XCTAssertEqual(model.messages.first?.text, "hello again")
  }

  // MARK: - Timeline recording

  func testTimelineRecordsUserAssistantAndPendingEvents() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = CoachModelCharacterizationTestSupport.characterizationFoodEstimateResponse()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log chicken rice bowl")

    _ = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
      in: harness.timelineStore,
      matching: { $0.type == .userMessage }
    )
    _ = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
      in: harness.timelineStore,
      matching: { $0.type == .assistantMessage }
    )
    _ = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
      in: harness.timelineStore,
      matching: { $0.type == .pendingConfirmationCreated }
    )
  }

  func testConfirmingFoodRecordsFoodLoggedTimelineEvent() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = CoachModelCharacterizationTestSupport.characterizationFoodEstimateResponse()
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log chicken rice bowl")
    await model.confirmPendingFromBar()

    _ = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
      in: harness.timelineStore,
      matching: { $0.type == .foodLogged }
    )
    XCTAssertTrue(
      harness.timelineStore.events.contains { $0.type == .pendingConfirmationConfirmed }
    )
  }

  // MARK: - Today context refresh

  func testTodayContextRefreshReflectsConfirmedFoodLog() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = FoodLoggingGoldenFixtures.case4Response
    let model = harness.makeCoach(aiService: aiService)

    model.refreshTodayContext()
    await AsyncTestSupport.drainMainActorTasks()
    let baseline = model.todayContext

    await model.send(FoodLoggingGoldenFixtures.case4Prompt)
    await model.confirmPendingFromBar()

    model.refreshTodayContext()
    await AsyncTestSupport.drainMainActorTasks()

    let meal = FoodLoggingGoldenFixtures.case4MealDraft
    XCTAssertNotNil(model.todayContext)
    XCTAssertNotEqual(model.todayContext?.caloriesLine, baseline?.caloriesLine)
    XCTAssertTrue(model.todayContext?.caloriesLine.contains("\(meal.totalCalories)") == true)
  }

  // MARK: - Error copy preservation

  func testBackendErrorPreservesUserFacingCopy() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachIntentResult(
      intent: .mealDecision,
      confidence: 0.9,
      domain: .nutrition,
      requiresAppMutation: false,
      requiresUserContext: true,
      canAnswerWithCheapModel: true,
      requiresEscalation: false,
      action: nil
    )
    aiService.mealAdviceError = AIServiceError.backendUnavailable
    let model = harness.makeCoach(aiService: aiService)

    await model.send("should I eat pasta tonight?")

    XCTAssertEqual(model.messages.last?.text, FormaProductCopy.Error.coachUnavailable)
    XCTAssertFalse(model.showsAuthRetry)
    _ = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
      in: harness.timelineStore,
      matching: { $0.type == .backendError }
    )
  }

  func testAuthenticationFailurePreservesInlineErrorState() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachIntentResult(
      intent: .mealDecision,
      confidence: 0.9,
      domain: .nutrition,
      requiresAppMutation: false,
      requiresUserContext: true,
      canAnswerWithCheapModel: true,
      requiresEscalation: false,
      action: nil
    )
    aiService.mealAdviceError = AIServiceError.authenticationFailed
    let model = harness.makeCoach(aiService: aiService)

    await model.send("should I eat pasta tonight?")

    XCTAssertTrue(model.showsAuthRetry)
    XCTAssertEqual(model.errorMessage, AIServiceError.coachSessionFailureMessage)
    XCTAssertEqual(model.messages.last?.text, "")
    _ = try await CoachModelCharacterizationTestSupport.waitForTimelineEvent(
      in: harness.timelineStore,
      matching: { $0.type == .authError }
    )
  }

  // MARK: - Correction memory

  func testCorrectionMemoryWrittenOnPendingFoodEdit() async throws {
    let aiService = CharacterizationAIService()
    aiService.classifyResult = CoachModelCharacterizationTestSupport.foodEstimateIntent()
    aiService.estimateFoodResponse = CoachModelCharacterizationTestSupport.characterizationFoodEstimateResponse(
      name: "Chicken rice",
      calories: 620
    )
    let model = harness.makeCoach(aiService: aiService)

    await model.send("log chicken rice")
    guard case .food(let pending) = model.pendingConfirmation else {
      return XCTFail("Expected food pending confirmation")
    }

    var form = FoodLogEditFormState(mealDraft: pending.primaryMealDraft)
    form.componentStates[0].caloriesText = "700"
    model.saveFoodEdit(form)

    var entries: [FoodCorrectionMemoryEntry] = []
    for _ in 0..<60 {
      await Task.yield()
      entries = (try? await harness.correctionMemoryStore.recentEntries(limit: 10)) ?? []
      if !entries.isEmpty { break }
    }
    XCTAssertFalse(entries.isEmpty, "Expected correction memory after pending food edit")
    XCTAssertEqual(entries.first?.source, .pendingEditSheet)
  }
}
