//
//  CoachModelCharacterizationTestSupport.swift
//  Fitness CoachTests
//
//  Shared harness, fakes, and AIService stubs for CoachModel characterization tests.
//  Freezes end-to-end CoachModel behavior before decomposition (TD-COACH-001).
//

import UIKit
import XCTest
@testable import Fitness_Coach

@MainActor
enum CoachModelCharacterizationTestSupport {

  @MainActor
  struct Harness {
    let routing: CoachRoutingIntegrationTestSupport.Harness
    let timelineStore: FakeCoachTimelineStore
    let transcriptStore: CapturingCoachTranscriptStore
    let correctionMemoryStore: InMemoryFoodCorrectionMemoryStore
    let analyticsLogger: CapturingCoachAnalyticsLogger

    var actionCenter: FitnessActionCenter { routing.actionCenter }
    var dailyLogService: DailyLogService { routing.dailyLogService }
    var today: Date { routing.today }

    func makeCoach(
      aiService: AIServiceProtocol,
      transcriptStore overrideTranscript: CoachChatTranscriptStore? = nil
    ) -> CoachModel {
      CoachModel(
        services: routing.makeCoachServices(),
        dependencies: routing.makeCoachDependencies(
          aiService: aiService,
          timelineStore: timelineStore,
          transcriptStore: overrideTranscript ?? transcriptStore,
          foodCorrectionMemoryStore: correctionMemoryStore,
          coachAnalyticsLogger: analyticsLogger
        )
      )
    }
  }

  static func makeHarness() throws -> Harness {
    let routing = try CoachRoutingIntegrationTestSupport.makeHarness()
    try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: routing)
    return Harness(
      routing: routing,
      timelineStore: FakeCoachTimelineStore(),
      transcriptStore: CapturingCoachTranscriptStore(),
      correctionMemoryStore: InMemoryFoodCorrectionMemoryStore(),
      analyticsLogger: FakeAnalyticsLogger.coach()
    )
  }

  static func foodEstimateIntent() -> CoachIntentResult {
    CoachIntentResult(
      intent: .logFood,
      confidence: 0.92,
      domain: .nutrition,
      requiresAppMutation: true,
      requiresUserContext: true,
      canAnswerWithCheapModel: true,
      requiresEscalation: false,
      action: nil
    )
  }

  static func deleteLogIntent() -> CoachIntentResult {
    CoachIntentResult(
      intent: .deleteLog,
      confidence: 0.92,
      domain: .nutrition,
      requiresAppMutation: true,
      requiresUserContext: true,
      canAnswerWithCheapModel: true,
      requiresEscalation: false,
      action: nil
    )
  }

  static func characterizationFoodEstimateResponse(
    name: String = "Chicken rice bowl",
    calories: Int = 620
  ) -> AIFoodEstimateResponse {
    AIFoodEstimateResponse(
      foodLogDrafts: [
        FoodLogDraft(
          displayName: name,
          components: [
            FoodComponent(
              name: name,
              calories: calories,
              protein: 42,
              carbs: 55,
              fat: 18,
              confidence: .medium,
              sourceText: name
            )
          ],
          confidence: .medium,
          source: .aiTextEstimate
        )
      ],
      confidence: .medium,
      requiresConfirmation: true,
      assistantMessage: "Confirm before logging."
    )
  }

  static func testJPEG(color: UIColor = .orange) -> Data {
    CoachImageWorkflowTestSupport.makeTestJPEG(color: color)
  }

  static func waitForTimelineEvent(
    in store: FakeCoachTimelineStore,
    matching predicate: @escaping (CoachTimelineEvent) -> Bool,
    timeout: TimeInterval = 1.0
  ) async throws -> CoachTimelineEvent {
    let satisfied = await AsyncTestSupport.waitUntilWallClock(timeout: timeout, interval: 0.02) {
      store.events.contains(where: predicate)
    }
    if !satisfied {
      throw NSError(domain: "CoachModelCharacterizationTestSupport", code: 1)
    }
    return try XCTUnwrap(store.events.first(where: predicate))
  }
}

// MARK: - Capturing transcript store

@MainActor
final class CapturingCoachTranscriptStore: CoachChatTranscriptStore {
  private(set) var messages: [ChatMessage] = []
  private(set) var saveCallCount = 0

  func loadMessages() -> [ChatMessage] {
    messages
  }

  func saveMessages(_ messages: [ChatMessage]) {
    saveCallCount += 1
    self.messages = messages
  }
}

// MARK: - Configurable AIService stub

@MainActor
final class CharacterizationAIService: AIServiceProtocol, @unchecked Sendable {
  var classifyResult: CoachIntentResult?
  var classifyError: Error?
  var estimateFoodResponse: AIFoodEstimateResponse?
  var estimateFoodError: Error?
  var mealAdviceError: Error?
  var mealAdviceResponse: AICoachResponse?
  var parseEditOrDeleteHandler: ((String, CoachContextPacketV2) async throws -> AIParsedCommand)?
  var analyzeMealImageHandler: ((AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse)?
  var analyzeMealImageError: Error?

  private(set) var classifyCoachIntentCallCount = 0
  private(set) var estimateFoodCallCount = 0
  private(set) var analyzeMealImageCallCount = 0
  private(set) var parseEditOrDeleteCallCount = 0
  private(set) var lastImageJPEGData: Data?
  private(set) var lastClarification: String?

  func classifyCoachIntent(
    _ text: String,
    context: CoachContextPacketV2,
    config: CoachModelConfig
  ) async throws -> CoachIntentResult {
    classifyCoachIntentCallCount += 1
    if let classifyError { throw classifyError }
    if let classifyResult { return classifyResult }
    throw AIServiceError.backendUnavailable
  }

  func estimateFood(
    prompt: String,
    context: CoachContextPacketV2,
    imageJPEGData: Data?
  ) async throws -> AIFoodEstimateResponse {
    estimateFoodCallCount += 1
    if let estimateFoodError { throw estimateFoodError }
    if let estimateFoodResponse { return estimateFoodResponse }
    throw AIServiceError.backendUnavailable
  }

  func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
    analyzeMealImageCallCount += 1
    if let data = Data(base64Encoded: request.image.base64) {
      lastImageJPEGData = data
    }
    lastClarification = request.clarification
    if let analyzeMealImageError { throw analyzeMealImageError }
    if let analyzeMealImageHandler {
      return try await analyzeMealImageHandler(request)
    }
    return CoachImageWorkflowTestSupport.validMealImageAnalysisResponse()
  }

  func generateMealAdvice(
    prompt: String,
    context: CoachContextPacketV2,
    intentResult: CoachIntentResult?,
    tier: CoachModelTier
  ) async throws -> AICoachResponse {
    if let mealAdviceError { throw mealAdviceError }
    return mealAdviceResponse ?? AICoachResponse(message: "Stub advice.", confidence: .medium)
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
    parseEditOrDeleteCallCount += 1
    if let parseEditOrDeleteHandler {
      return try await parseEditOrDeleteHandler(prompt, context)
    }
    throw AIServiceError.backendUnavailable
  }

  func parseMultiAction(prompt: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
    throw AIServiceError.backendUnavailable
  }

  func generateDailyReview(context: CoachContextPacketV2) async throws -> AICoachResponse {
    DailyReviewAIResponse(statusSummary: "Within target.", bestNextMove: "Keep logging.")
  }

  func generateDailyReviewText(
    input: DailyReviewAIInput,
    context: CoachContextPacketV2
  ) async throws -> DailyReviewAIResponse {
    DailyReviewAIResponse(statusSummary: "Within target.", bestNextMove: "Keep logging.")
  }

  func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
    throw AIServiceError.backendUnavailable
  }
}

// MARK: - Clarifying photo AI service

@MainActor
final class CharacterizationClarifyingPhotoAIService: AIServiceProtocol, @unchecked Sendable {
  private(set) var analyzeMealImageCallCount = 0
  private(set) var lastClarification: String?

  func classifyCoachIntent(
    _ text: String,
    context: CoachContextPacketV2,
    config: CoachModelConfig
  ) async throws -> CoachIntentResult {
    CoachMealPhotoPipeline.photoAnalysisIntentResult
  }

  func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
    analyzeMealImageCallCount += 1
    lastClarification = request.clarification
    let confidence: AIConfidence = request.clarification == nil ? .low : .medium
    return AIMealImageAnalysisResponse(
      summary: request.clarification == nil ? "Grain bowl" : "Barley bowl",
      items: [
        AIMealImageAnalysisItem(
          name: request.clarification == nil ? "Grain bowl" : "Barley bowl",
          quantity: "1 bowl",
          calories: 420,
          protein: 18,
          carbs: 55,
          fat: 12,
          confidence: confidence,
          assumptions: []
        )
      ],
      total: AIMealImageAnalysisTotals(calories: 420, protein: 18, carbs: 55, fat: 12),
      needsUserReview: true,
      clarifyingQuestion: request.clarification == nil ? "Was this rice or barley?" : nil
    )
  }

  func estimateFood(
    prompt: String,
    context: CoachContextPacketV2,
    imageJPEGData: Data?
  ) async throws -> AIFoodEstimateResponse {
    throw AIServiceError.backendUnavailable
  }

  func generateMealAdvice(
    prompt: String,
    context: CoachContextPacketV2,
    intentResult: CoachIntentResult?,
    tier: CoachModelTier
  ) async throws -> AICoachResponse {
    DailyReviewAIResponse(statusSummary: "Within target.", bestNextMove: "Keep logging.")
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
    DailyReviewAIResponse(statusSummary: "Within target.", bestNextMove: "Keep logging.")
  }

  func generateDailyReviewText(
    input: DailyReviewAIInput,
    context: CoachContextPacketV2
  ) async throws -> DailyReviewAIResponse {
    DailyReviewAIResponse(statusSummary: "Within target.", bestNextMove: "Keep logging.")
  }

  func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
    throw AIServiceError.backendUnavailable
  }
}
