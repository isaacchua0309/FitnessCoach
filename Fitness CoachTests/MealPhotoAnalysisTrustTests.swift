//
//  MealPhotoAnalysisTrustTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class MealPhotoAnalysisTrustTests: XCTestCase {

    func testMockedPhotoResponseMapsTrustMetadata() {
        let response = trustedPhotoResponse()

        let result = MealImageAnalysisMapper.sessionResult(from: response, userCaption: "Lunch bowl")

        XCTAssertTrue(result.mealDraft.requiresClarificationBeforeLogging || result.confidence == .low)
        XCTAssertNotNil(result.trust)
        XCTAssertFalse(result.mealDraft.assumptions.isEmpty)
        XCTAssertFalse(result.mealDraft.uncertaintyReasons.isEmpty)
        XCTAssertNotNil(result.mealDraft.primaryUncertainty)
        XCTAssertNotNil(result.mealDraft.calorieRangeLower)
        XCTAssertNotNil(result.mealDraft.calorieRangeUpper)
        XCTAssertGreaterThan(
            (result.mealDraft.calorieRangeUpper ?? 0) - (result.mealDraft.calorieRangeLower ?? 0),
            0
        )
    }

    func testMultiplePlatesAskClarificationUnlessCaptionLogsAll() {
        let response = AIMealImageAnalysisResponse(
            summary: "Two plates visible with rice and chicken",
            items: [
                photoItem(name: "Plate 1 rice", calories: 220),
                photoItem(name: "Plate 2 chicken", calories: 240),
            ],
            total: AIMealImageAnalysisTotals(calories: 460, protein: 35, carbs: 45, fat: 12),
            needsUserReview: true,
            clarifyingQuestion: nil,
            primaryUncertainty: "Multiple plates are visible."
        )

        let withoutAll = MealImageAnalysisTrustPolicy.normalize(response: response, userCaption: "log this")
        XCTAssertTrue(withoutAll.metadata.detectedScenarios.contains(.multiplePlates))
        XCTAssertNotNil(withoutAll.metadata.clarifyingQuestion)

        let validation = MealImageAnalysisResponseValidator.validate(response: response, userCaption: "log this")
        XCTAssertFalse(validation.isValid)

        let withAll = MealImageAnalysisTrustPolicy.normalize(
            response: response,
            userCaption: "log all plates on the table"
        )
        XCTAssertNil(withAll.metadata.clarifyingQuestion)
    }

    func testCroppedImageGetsLowConfidenceAndWarning() {
        let response = AIMealImageAnalysisResponse(
            summary: "Cropped plate with partial rice visible",
            items: [photoItem(name: "Partial rice", calories: 180, confidence: .medium)],
            total: AIMealImageAnalysisTotals(calories: 180, protein: 4, carbs: 38, fat: 1),
            needsUserReview: true,
            primaryUncertainty: "Plate appears cropped."
        )

        let normalized = MealImageAnalysisTrustPolicy.normalize(response: response)
        XCTAssertTrue(normalized.metadata.detectedScenarios.contains(.croppedPlate))
        XCTAssertEqual(normalized.metadata.confidence, .low)
        XCTAssertTrue(
            normalized.metadata.presentationWarnings.contains(
                MealImageAnalysisTrustPolicy.croppedPlateWarning
            )
        )
    }

    func testHiddenSauceAddsUncertainty() {
        let response = AIMealImageAnalysisResponse(
            summary: "Chicken rice without visible sauce",
            items: [photoItem(name: "Chicken rice", calories: 520)],
            total: AIMealImageAnalysisTotals(calories: 520, protein: 30, carbs: 55, fat: 14),
            needsUserReview: true,
            primaryUncertainty: "Hidden oil or sauce may not be visible."
        )

        let normalized = MealImageAnalysisTrustPolicy.normalize(response: response)
        XCTAssertTrue(normalized.metadata.detectedScenarios.contains(.hiddenSauces))
        XCTAssertTrue(
            normalized.metadata.uncertaintyReasons.contains(where: { $0.lowercased().contains("hidden oil") })
        )
    }

    func testRecommissionPromptPreservesPreviousRangeAndUncertainty() {
        let previous = ImageAnalysisSessionResult(
            mealDraft: FoodLogDraft(
                displayName: "Chicken rice",
                components: [photoComponent(name: "Chicken rice", calories: 520)],
                confidence: .medium,
                source: .aiPhotoEstimate,
                uncertaintyReasons: ["Portion size unclear."],
                primaryUncertainty: "Portion size unclear.",
                calorieRangeLower: 480,
                calorieRangeUpper: 580
            ),
            confidence: .medium,
            summary: "Chicken rice",
            trust: MealImageAnalysisTrustMetadata(
                confidence: .medium,
                assumptions: ["Standard plate"],
                uncertaintyReasons: ["Portion size unclear."],
                suggestedClarifications: [],
                primaryUncertainty: "Portion size unclear.",
                calorieRangeLower: 480,
                calorieRangeUpper: 580,
                needsUserReview: true,
                clarifyingQuestion: nil,
                detectedScenarios: [],
                presentationWarnings: []
            )
        )

        let session = ImageAnalysisSession.newSession(
            userMessageID: UUID(),
            attachment: ChatMessageImageAttachment(
                imageJPEG: Data([0xFF, 0xD8, 0xFF]),
                thumbnailJPEG: Data([0xFF, 0xD8, 0xFF])
            ),
            userCaption: "chicken rice"
        )
        var updated = session
        updated.latestResult = previous

        let prompt = ImageAnalysisPromptBuilder.recommissionMessage(
            session: updated,
            clarification: "rice was half"
        )

        XCTAssertTrue(prompt.contains("rice was half"))
        XCTAssertTrue(prompt.contains("Previous calorie range: 480-580 kcal"))
        XCTAssertTrue(prompt.contains("Previous main uncertainty: Portion size unclear."))
    }

    func testPhotoPresentationMessageIncludesTrustCopy() {
        let trust = MealImageAnalysisTrustMetadata(
            confidence: .low,
            assumptions: ["Assumed half bowl of rice."],
            uncertaintyReasons: ["Portion size is unclear from the photo."],
            suggestedClarifications: ["Was this a half or full bowl?"],
            primaryUncertainty: "Portion size is unclear from the photo.",
            calorieRangeLower: 420,
            calorieRangeUpper: 560,
            needsUserReview: true,
            clarifyingQuestion: "Was this a half or full bowl?",
            detectedScenarios: [.unclearPortionSize],
            presentationWarnings: []
        )
        let meal = FoodLogDraft(
            displayName: "Chicken rice",
            components: [photoComponent(name: "Chicken rice", calories: 500)],
            confidence: .low,
            source: .aiPhotoEstimate
        )

        let message = MealPhotoAnalysisPresentationFormatter.assistantMessage(
            mealDraft: meal,
            confidence: .low,
            trust: trust
        )

        XCTAssertTrue(message.contains(MealImageAnalysisTrustPolicy.estimatedFromPhotoMessage))
        XCTAssertTrue(message.contains(MealImageAnalysisTrustPolicy.photoReviewRequiredMessage))
        XCTAssertTrue(message.contains("Likely range: 420-560 kcal"))
        XCTAssertTrue(message.contains("Main uncertainty: Portion size is unclear from the photo."))
    }

    func testPhotoPendingCardStillRequiresConfirmation() {
        let meal = MealImageAnalysisMapper.foodLogDraft(from: trustedPhotoResponse())

        switch ConfirmationPolicy.decision(for: meal) {
        case .requiresConfirmation:
            XCTAssertTrue(meal.requiresClarificationBeforeLogging || meal.confidence != .high)
        case .executeImmediately, .reject:
            XCTFail("Photo estimates must require confirmation")
        }
    }

    func testPhotoEstimateNeverAutoLogsViaAIValidator() {
        let meal = MealImageAnalysisMapper.foodLogDraft(from: trustedPhotoResponse())

        switch AIResponseValidator.validateFood(meal, confidence: .medium) {
        case .requiresConfirmation:
            break
        case .valid, .invalid:
            XCTFail("Photo estimate should not auto-log")
        }
    }

    func testRecommissionUpdatesRangeInMapper() {
        let refined = trustedPhotoResponse(
            calories: 360,
            summary: "Half bowl chicken rice after clarification",
            lower: 320,
            upper: 420,
            primaryUncertainty: "Half bowl confirmed."
        )

        let result = MealImageAnalysisMapper.sessionResult(
            from: refined,
            userCaption: "rice was half"
        )

        XCTAssertEqual(result.mealDraft.totalCalories, 360)
        XCTAssertEqual(result.trust?.calorieRangeLower, 320)
        XCTAssertEqual(result.trust?.calorieRangeUpper, 420)
        XCTAssertEqual(result.trust?.primaryUncertainty, "Half bowl confirmed.")
    }

    // MARK: - Fixtures

    private func trustedPhotoResponse(
        calories: Int = 500,
        summary: String = "Chicken rice bowl",
        lower: Int = 450,
        upper: Int = 560,
        primaryUncertainty: String = "Sauce and portion are partly unclear."
    ) -> AIMealImageAnalysisResponse {
        AIMealImageAnalysisResponse(
            summary: summary,
            items: [
                AIMealImageAnalysisItem(
                    name: "Chicken rice",
                    quantity: "1 plate",
                    calories: calories,
                    protein: 30,
                    carbs: 55,
                    fat: 14,
                    confidence: .medium,
                    assumptions: ["Visible plate with rice and chicken."],
                    uncertaintyReasons: [primaryUncertainty],
                    suggestedClarifications: ["Can you confirm sauce amount?"],
                    primaryUncertainty: primaryUncertainty,
                    calorieRangeLower: lower,
                    calorieRangeUpper: upper
                )
            ],
            total: AIMealImageAnalysisTotals(
                calories: calories,
                protein: 30,
                carbs: 55,
                fat: 14,
                calorieRangeLower: lower,
                calorieRangeUpper: upper
            ),
            needsUserReview: true,
            primaryUncertainty: primaryUncertainty
        )
    }

    private func photoItem(
        name: String,
        calories: Int,
        confidence: AIConfidence = .medium
    ) -> AIMealImageAnalysisItem {
        AIMealImageAnalysisItem(
            name: name,
            calories: calories,
            protein: 10,
            carbs: 20,
            fat: 5,
            confidence: confidence,
            assumptions: ["Estimated from photo."],
            uncertaintyReasons: ["Portion estimated from photo."],
            primaryUncertainty: "Portion estimated from photo."
        )
    }

    private func photoComponent(name: String, calories: Int) -> FoodComponent {
        FoodComponent(
            name: name,
            calories: calories,
            protein: 30,
            carbs: 55,
            fat: 14,
            confidence: .medium,
            sourceText: "Estimated from photo."
        )
    }
}
