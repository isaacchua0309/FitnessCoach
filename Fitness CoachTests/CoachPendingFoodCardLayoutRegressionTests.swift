//
//  CoachPendingFoodCardLayoutRegressionTests.swift
//  Fitness CoachTests
//
//  Regression coverage for Coach pending food card + keyboard layout behavior.
//

import XCTest
@testable import Fitness_Coach

final class CoachPendingFoodCardPresentationTests: XCTestCase {

    func testPresentationModesFromPendingAndFocusState() {
        let pending = CoachLayoutPreviewFixtures.pendingConfirmation

        XCTAssertEqual(
            CoachPendingFoodCardPresentationResolver.presentation(
                pendingConfirmation: nil,
                isInputFocused: false
            ),
            .hidden
        )
        XCTAssertEqual(
            CoachPendingFoodCardPresentationResolver.presentation(
                pendingConfirmation: pending,
                isInputFocused: false
            ),
            .expanded
        )
        XCTAssertEqual(
            CoachPendingFoodCardPresentationResolver.presentation(
                pendingConfirmation: pending,
                isInputFocused: true
            ),
            .compact
        )
    }

    func testPresentationAccessibilityIdentifiers() {
        XCTAssertEqual(
            CoachPendingFoodCardPresentationResolver.cardAccessibilityIdentifier(for: .hidden),
            nil
        )
        XCTAssertEqual(
            CoachPendingFoodCardPresentationResolver.cardAccessibilityIdentifier(for: .expanded),
            CoachAccessibilityIdentifier.pendingFoodCardExpanded
        )
        XCTAssertEqual(
            CoachPendingFoodCardPresentationResolver.cardAccessibilityIdentifier(for: .compact),
            CoachAccessibilityIdentifier.pendingFoodCardCompact
        )
    }
}

@MainActor
final class CoachPendingFoodCardLayoutRegressionTests: XCTestCase {

    func testDiscardClearsPendingFoodDraft() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let model = harness.makeCoach(aiService: makeFoodEstimateService(
            response: FoodLoggingGoldenFixtures.case1Response
        ))

        await model.send(FoodLoggingGoldenFixtures.case1Prompt)
        XCTAssertNotNil(model.pendingConfirmation)

        model.rejectPendingFromBar()

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertFalse(model.isShowingFoodEditSheet)
    }

    func testLogClearsPendingFoodDraftAfterSuccess() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let model = harness.makeCoach(aiService: makeFoodEstimateService(
            response: FoodLoggingGoldenFixtures.case1Response
        ))

        await model.send(FoodLoggingGoldenFixtures.case1Prompt)
        guard case .food(let draft) = model.pendingConfirmation else {
            return XCTFail("Expected food pending confirmation")
        }

        await model.confirmPendingFromBar()

        XCTAssertNil(model.pendingConfirmation)
        XCTAssertFalse(model.isConfirmingPending)
        XCTAssertFalse(try harness.actionCenter.getFoodEntries(for: harness.today).isEmpty)
        XCTAssertEqual(
            try harness.actionCenter.getFoodEntries(for: harness.today).first?.name,
            draft.primaryMealDraft.displayName
        )
    }

    func testEditUpdatesDraftWithoutDuplicatingOriginalText() async throws {
        let harness = try CoachRoutingIntegrationTestSupport.makeHarness()
        try CoachRoutingIntegrationTestSupport.seedCoachProfile(in: harness)
        let model = harness.makeCoach(aiService: makeFoodEstimateService(
            response: FoodLoggingGoldenFixtures.case1Response
        ))

        await model.send(FoodLoggingGoldenFixtures.case1Prompt)
        guard case .food(let originalDraft) = model.pendingConfirmation else {
            return XCTFail("Expected food pending confirmation")
        }

        let originalText = originalDraft.originalText
        var form = FoodLogEditFormState(mealDraft: originalDraft.primaryMealDraft)
        form.displayName = "Updated bowl name"
        form.totalCaloriesText = "\(originalDraft.primaryMealDraft.totalCalories)"

        model.saveFoodEdit(form)

        guard case .food(let updatedDraft) = model.pendingConfirmation else {
            return XCTFail("Expected pending confirmation to remain after edit")
        }

        XCTAssertEqual(updatedDraft.originalText, originalText)
        XCTAssertEqual(updatedDraft.primaryMealDraft.displayName, "Updated bowl name")
        XCTAssertEqual(updatedDraft.primaryMealDraft.components.count, originalDraft.primaryMealDraft.components.count)
        XCTAssertFalse(model.isShowingFoodEditSheet)
    }

    func testLayoutPreviewFixtureIncludesExpectedTranscriptAndPendingCard() {
        XCTAssertFalse(CoachLayoutPreviewFixtures.messages.isEmpty)
        XCTAssertTrue(
            CoachLayoutPreviewFixtures.messages.contains {
                $0.imageAttachment?.kind == .mealPhoto
            }
        )
        XCTAssertTrue(
            CoachLayoutPreviewFixtures.messages.contains {
                if case .nutritionEstimate = $0.structuredContent { return true }
                return false
            }
        )
        guard case .food(let draft) = CoachLayoutPreviewFixtures.pendingConfirmation else {
            return XCTFail("Expected food pending confirmation fixture")
        }
        XCTAssertEqual(draft.primaryMealDraft.totalCalories, 510)
        XCTAssertEqual(draft.relatedPhotoUserMessageID, CoachLayoutPreviewFixtures.mealPhotoUserMessageID)
    }

    private func makeFoodEstimateService(response: AIFoodEstimateResponse) -> AIServiceProtocol {
        LayoutRegressionFoodEstimateAIService(response: response)
    }
}

@MainActor
private final class LayoutRegressionFoodEstimateAIService: AIServiceProtocol, @unchecked Sendable {
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
