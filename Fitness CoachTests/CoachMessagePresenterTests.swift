//
//  CoachMessagePresenterTests.swift
//  Fitness CoachTests
//
//  Forma — Presentation mapping for Coach chat transcript messages.
//

import UIKit
import XCTest
@testable import Fitness_Coach

final class CoachMessagePresenterTests: XCTestCase {

    func testUserMealPhotoWithoutCaptionRendersImageOnlyPresentation() throws {
        let attachment = try makeAttachment()
        let message = ChatMessage.userMealPhoto(caption: nil, attachment: attachment)

        let presentation = CoachMessagePresenter.presentation(for: message)

        guard case .userMealPhoto(let renderedAttachment, let caption) = presentation else {
            return XCTFail("Expected user meal photo presentation")
        }
        XCTAssertEqual(renderedAttachment.imageJPEG, attachment.imageJPEG)
        XCTAssertNil(caption)
        XCTAssertTrue(message.text.isEmpty)
        XCTAssertNotEqual(message.text, CoachMealPhotoPipeline.userMessageLabel)
    }

    func testUserMealPhotoWithCaptionPreservesCaption() throws {
        let attachment = try makeAttachment()
        let message = ChatMessage.userMealPhoto(caption: "Lunch bowl", attachment: attachment)

        guard case .userMealPhoto(_, let caption) = CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected user meal photo presentation")
        }

        XCTAssertEqual(caption, "Lunch bowl")
    }

    func testAssistantPhotoAnalysisFailurePresentation() throws {
        let userID = UUID()
        let sessionID = UUID()
        let message = ChatMessage.assistantPhotoAnalysisFailure(
            text: "I couldn't analyze that photo right now.",
            sessionID: sessionID,
            relatedUserMessageID: userID
        )

        guard case .assistantPhotoAnalysis(let text, let relatedID, let kind) =
            CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected assistant photo analysis presentation")
        }

        XCTAssertTrue(text.contains("couldn't analyze"))
        XCTAssertEqual(relatedID, userID)
        XCTAssertEqual(kind, .failure)
        XCTAssertNotNil(message.mealPhotoAnalysisFailure)
    }

    func testAssistantPhotoAnalysisSuccessPresentation() throws {
        let userID = UUID()
        let sessionID = UUID()
        let message = ChatMessage.assistantPhotoAnalysisResult(
            text: "From your meal photo, I estimated chicken bowl:",
            sessionID: sessionID,
            relatedUserMessageID: userID
        )

        guard case .assistantPhotoAnalysis(let text, let relatedID, let kind) =
            CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected assistant photo analysis presentation")
        }

        XCTAssertTrue(text.contains("meal photo"))
        XCTAssertEqual(relatedID, userID)
        XCTAssertEqual(kind, .result)
    }

    func testPlainTextUserMessageStaysTextPresentation() {
        let message = ChatMessage(role: .user, text: "log water")
        guard case .user(let text) = CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected text presentation")
        }
        XCTAssertEqual(text, "log water")
    }

    func testNutritionEstimateStructuredMessageRendersCardPresentation() {
        let card = NutritionEstimateCardState(
            id: UUID(),
            foodName: "Big Mac",
            displayEmoji: "🍔",
            servingDescription: "1 burger",
            caloriesDisplay: "550 kcal",
            proteinDisplay: "Protein 25g",
            carbsDisplay: "Carbs 45g",
            fatDisplay: "Fat 30g",
            confidenceTitle: "High confidence",
            confidenceSubtitle: nil,
            coachSummary: nil,
            coachTip: "Skip fries.",
            caveats: [],
            todayContext: nil,
            suggestedActions: [],
            sourceType: .branded,
            confidenceLevel: .high,
            hasMacros: true,
            hasTodayContext: false,
            logMealPayload: nil
        )
        let message = ChatMessage(
            role: .assistant,
            text: "Big Mac estimate",
            structuredContent: .nutritionEstimate(card)
        )

        guard case .nutritionEstimate(let state) = CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected nutrition estimate presentation")
        }
        XCTAssertEqual(state.foodName, "Big Mac")
    }

    func testDailyReviewStructuredMessageRendersCardPresentation() {
        let payload = DailyReviewPayload(
            title: "Daily Review",
            timezoneLabel: "Jul 5, 2026 · GMT",
            generatedAt: Date(),
            snapshot: DailyReviewSnapshot(
                calories: ProgressMetric(
                    label: "Calories",
                    current: 1_500,
                    target: 2_000,
                    unit: "kcal",
                    remainingText: "500 kcal remaining",
                    progress: 0.75
                ),
                protein: ProgressMetric(
                    label: "Protein",
                    current: 90,
                    target: 140,
                    unit: "g",
                    remainingText: "50g to go",
                    progress: 0.64
                ),
                water: ProgressMetric(
                    label: "Water",
                    current: 1_000,
                    target: 2_500,
                    unit: "ml",
                    remainingText: "1,500 ml remaining",
                    progress: 0.4
                )
            ),
            statusSummary: "You logged 1,500 kcal with 500 kcal remaining.",
            bestNextMove: "Prioritize lean protein earlier tomorrow.",
            tomorrowFocus: nil,
            missingSignals: [],
            detailNote: "Nice consistency."
        )
        let message = ChatMessage(
            role: .assistant,
            text: "Daily review accessibility text",
            structuredContent: .dailyReview(payload)
        )

        guard case .dailyReview(let rendered) = CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected daily review presentation")
        }
        XCTAssertEqual(rendered.title, "Daily Review")
    }

    func testLegacyPlainTextAssistantMessageStillRendersTextPresentation() {
        let message = ChatMessage(
            role: .assistant,
            text: "Daily Review\n\nCalories: 1,500 / 2,000 kcal."
        )

        guard case .assistant(let text) = CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected plain assistant text presentation")
        }
        XCTAssertTrue(text.contains("Daily Review"))
    }

    func testUserMessageWithoutRenderableImageBytesFallsBackToTextPresentation() {
        let message = ChatMessage(
            role: .user,
            text: "daily review",
            imageAttachment: ChatMessageImageAttachment(
                kind: .mealPhoto,
                imageJPEG: Data(),
                thumbnailJPEG: Data()
            )
        )

        guard case .user(let text) = CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected plain user text presentation")
        }
        XCTAssertEqual(text, "daily review")
    }

    func testUserMessageWithRenderableImageBytesUsesPhotoPresentation() throws {
        let attachment = try makeAttachment()
        let message = ChatMessage.userMealPhoto(caption: nil, attachment: attachment)

        guard case .userMealPhoto(let renderedAttachment, _) =
            CoachMessagePresenter.presentation(for: message) else {
            return XCTFail("Expected user meal photo presentation")
        }
        XCTAssertFalse(renderedAttachment.thumbnailJPEG.isEmpty)
    }

    private func makeAttachment() throws -> ChatMessageImageAttachment {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.85))
        return try XCTUnwrap(ChatMessageImageAttachment.fromJPEG(data, source: .camera))
    }
}
