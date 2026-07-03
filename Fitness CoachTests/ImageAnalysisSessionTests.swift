//
//  ImageAnalysisSessionTests.swift
//  Fitness CoachTests
//
//  Meal photo analysis session state machine regressions.
//

import XCTest
@testable import Fitness_Coach

final class ImageAnalysisSessionTests: XCTestCase {

    func testLowConfidenceMovesSessionToNeedsClarification() {
        var session = makeSession()
        let result = ImageAnalysisSessionResult(
            mealDraft: sampleMealDraft(),
            confidence: .low,
            summary: "Chicken bowl"
        )

        session = ImageAnalysisSessionReducer.apply(session, event: .analysisSucceeded(result))

        XCTAssertEqual(session.status, .needsClarification)
        XCTAssertNotNil(session.activeClarifyingQuestion)
        XCTAssertEqual(session.clarificationTurns.count, 1)
    }

    func testClarificationAnswerTriggersReanalysisState() {
        var session = makeSession()
        session = ImageAnalysisSessionReducer.apply(
            session,
            event: .analysisSucceeded(
                ImageAnalysisSessionResult(
                    mealDraft: sampleMealDraft(),
                    confidence: .low,
                    summary: "Grain bowl",
                    clarifyingQuestion: "Was this rice or barley?"
                )
            )
        )

        session = ImageAnalysisSessionReducer.apply(
            session,
            event: .clarificationAnswered("It was barley.")
        )

        XCTAssertEqual(session.status, .analyzing)
        XCTAssertEqual(session.clarificationTurns.last?.answer, "It was barley.")
    }

    func testRecommissionPromptIncludesPreviousEstimateAndClarification() {
        var session = makeSession()
        session.userCaption = "Lunch bowl"
        session = ImageAnalysisSessionReducer.apply(
            session,
            event: .analysisSucceeded(
                ImageAnalysisSessionResult(
                    mealDraft: sampleMealDraft(),
                    confidence: .medium,
                    summary: "Chicken and rice"
                )
            )
        )
        session = ImageAnalysisSessionReducer.apply(
            session,
            event: .clarificationAnswered("Brown rice, not white.")
        )

        let prompt = ImageAnalysisPromptBuilder.recommissionMessage(
            session: session,
            clarification: "Brown rice, not white."
        )

        XCTAssertTrue(prompt.contains("Previous summary"))
        XCTAssertTrue(prompt.contains("Brown rice, not white."))
        XCTAssertTrue(prompt.contains("Refine the meal photo estimate"))
    }

    func testDraftEditMovesSucceededSessionToNeedsClarification() {
        var session = makeSession()
        session = ImageAnalysisSessionReducer.apply(
            session,
            event: .analysisSucceeded(
                ImageAnalysisSessionResult(
                    mealDraft: sampleMealDraft(),
                    confidence: .high,
                    summary: "Salmon plate"
                )
            )
        )

        let edited = sampleMealDraft()
        session = ImageAnalysisSessionReducer.apply(session, event: .draftEdited(edited))

        XCTAssertEqual(session.status, .needsClarification)
        XCTAssertEqual(session.latestResult?.mealDraft.displayName, edited.displayName)
    }

    func testAnalysisStartedIncrementsAttempts() {
        var session = makeSession()
        XCTAssertEqual(session.attempts, 0)

        session = ImageAnalysisSessionReducer.apply(session, event: .analysisStarted)
        XCTAssertEqual(session.attempts, 1)
        XCTAssertEqual(session.status, .analyzing)
    }

    func testFailedThenRetryIncrementsAttempts() {
        var session = makeSession()
        session = ImageAnalysisSessionReducer.apply(session, event: .analysisStarted)
        session = ImageAnalysisSessionReducer.apply(session, event: .analysisFailed("Network error"))
        XCTAssertEqual(session.status, .failed)
        XCTAssertEqual(session.attempts, 1)

        session = ImageAnalysisSessionReducer.apply(session, event: .analysisStarted)
        XCTAssertEqual(session.attempts, 2)
        XCTAssertEqual(session.status, .analyzing)
    }

    private func makeSession() -> ImageAnalysisSession {
        let attachment = ChatMessageImageAttachment(
            imageJPEG: Data([0xFF, 0xD8, 0xFF]),
            thumbnailJPEG: Data([0xFF, 0xD8, 0xFF]),
            source: .library
        )
        return ImageAnalysisSession.newSession(
            userMessageID: UUID(),
            attachment: attachment,
            userCaption: ""
        )
    }

    private func sampleMealDraft() -> FoodLogDraft {
        FoodLogDraft(
            displayName: "Chicken bowl",
            components: [
                FoodComponent(
                    name: "Chicken",
                    calories: 250,
                    protein: 40,
                    carbs: 0,
                    fat: 8,
                    confidence: .medium
                )
            ],
            confidence: .medium,
            source: .aiPhotoEstimate
        )
    }
}
