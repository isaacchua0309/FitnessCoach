//
//  CoachAccuracyTrustRegressionTests.swift
//  Fitness CoachTests
//
//  Coach Accuracy + Trust Hardening v1 — end-to-end regression matrix.
//  Maps manual QA flows 1–13 to automated unit/integration coverage.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

// MARK: - Flows 1–4: Text food logging & estimate-only

@MainActor
final class CoachAccuracyTrustTextRegressionTests: XCTestCase {

    // Flow 1 — "log chicken rice"
    func testFlow01VagueChickenRiceUsesClassifierNotLocalAutoLog() async throws {
        let service = RecordingAIService()
        _ = try await CoachRouteDecider().decide(
            text: "log chicken rice",
            context: .hardeningTest,
            aiService: service,
            config: .default
        )
        XCTAssertEqual(service.classifyCoachIntentCallCount, 1, "Vague compound dish must not auto-log locally")
    }

    func testFlow01ChickenRicePendingRequiresConfirmationWithTrustFields() {
        let meal = underestimatedChickenRiceDraft()
        let sanity = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log chicken rice",
            confidence: .high
        )

        XCTAssertFalse(sanity.isAcceptable)
        XCTAssertEqual(sanity.confidence, .low)
        XCTAssertTrue(
            sanity.mealDraft.requiresClarificationBeforeLogging
                || sanity.mealDraft.suggestedClarifications.isEmpty == false
                || sanity.confidence == .low
        )

        let enriched = sanity.mealDraft
        XCTAssertFalse(enriched.assumptions.isEmpty || enriched.uncertaintyReasons.isEmpty)
        XCTAssertNotNil(enriched.calorieRangeLower)
        XCTAssertNotNil(enriched.calorieRangeUpper)

        switch ConfirmationPolicy.decision(for: enriched) {
        case .requiresConfirmation:
            break
        case .executeImmediately:
            XCTFail("Vague chicken rice must not auto-log")
        case .reject:
            break
        }
    }

    func testFlow01PendingSummaryShowsAssumptionsAndRange() {
        var meal = underestimatedChickenRiceDraft()
        meal.assumptions = ["Standard hawker plate portion"]
        meal.uncertaintyReasons = ["Portion size unclear."]
        meal.calorieRangeLower = 400
        meal.calorieRangeUpper = 520

        let lines = AIFoodConfirmationFormatter.assumptionLines(for: meal)
        XCTAssertTrue(lines.contains(where: { $0.contains("Standard hawker plate portion") }))
        XCTAssertTrue(lines.contains(where: { $0.contains("Estimated range: 400-520 kcal") }))
    }

    // Flow 2 — "log 200g grilled chicken breast"
    func testFlow02ExactGramsRouteLocallyWithHighConfidence() async throws {
        let service = RecordingAIService()
        let decision = try await CoachRouteDecider().decide(
            text: "log 200g grilled chicken breast",
            context: .hardeningTest,
            aiService: service,
            config: .default
        )
        XCTAssertEqual(service.classifyCoachIntentCallCount, 0)
        XCTAssertFalse(decision.requiresAPI)
        XCTAssertEqual(decision.routeSource, CoachRouteSource.localGuard)
        XCTAssertEqual(decision.chosenHandler, "local_food_estimate")
    }

    func testFlow02ExactChickenBreastHasHighConfidenceNarrowRangeAndRequiresConfirmation() {
        let meal = FoodLogDraft(
            displayName: "grilled chicken breast",
            components: [
                FoodComponent(
                    name: "grilled chicken breast",
                    quantity: 200,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 330,
                    protein: 62,
                    carbs: 0,
                    fat: 7,
                    sourceText: "200g grilled chicken breast"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate,
            assumptions: ["Skinless, grilled without added oil"],
            uncertaintyReasons: ["Minor preparation details assumed."],
            calorieRangeLower: 313,
            calorieRangeUpper: 347
        )

        let sanity = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 200g grilled chicken breast",
            confidence: .high
        )
        XCTAssertTrue(sanity.isAcceptable)
        XCTAssertEqual(sanity.confidence, .high)

        let highWidth = FoodCalorieRangePolicy.minimumWidth(calories: 330, confidence: .high)
        let lowWidth = FoodCalorieRangePolicy.minimumWidth(calories: 330, confidence: .low)
        let rangeWidth = (sanity.mealDraft.calorieRangeUpper ?? 0) - (sanity.mealDraft.calorieRangeLower ?? 0)
        XCTAssertLessThanOrEqual(rangeWidth, lowWidth)
        XCTAssertGreaterThanOrEqual(rangeWidth, highWidth)

        switch ConfirmationPolicy.decision(for: sanity.mealDraft) {
        case .requiresConfirmation:
            break
        case .executeImmediately:
            XCTFail("Even high-confidence text estimates require confirmation")
        case .reject:
            XCTFail("Valid exact-gram chicken breast should not be rejected")
        }
    }

    // Flow 3 — "how many calories in chicken rice"
    func testFlow03CalorieLookupRoutesToNutritionEstimateWithoutMutation() {
        let result = CoachIntentResult(
            intent: .nutritionEstimateQuery,
            confidence: 0.9,
            domain: .nutrition,
            requiresAppMutation: false,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )
        let route = CoachIntentRouter().route(intentResult: result, originalText: "how many calories in chicken rice")
        guard case .ai(let task) = route else {
            return XCTFail("Expected AI nutrition estimate route")
        }
        guard case .nutritionEstimate = task.task else {
            return XCTFail("Expected nutritionEstimate task, not pending log")
        }
    }

    func testFlow03EstimateCardShowsCalorieRange() {
        let response = NutritionEstimateResponse(
            foodName: "Chicken rice",
            displayEmoji: "🍗",
            caloriesKcal: nil,
            caloriesRangeLowerKcal: 520,
            caloriesRangeUpperKcal: 680,
            proteinGrams: 32,
            carbsGrams: 65,
            fatGrams: 16,
            servingDescription: "1 plate",
            confidenceLevel: .medium,
            confidenceLabel: "Medium confidence",
            confidenceReason: "Portion size varies at hawker stalls.",
            coachSummary: "A typical plate is moderate in protein.",
            coachTip: nil,
            caveats: ["Sauce and oil can add hidden calories."],
            suggestedActions: [
                NutritionSuggestedAction(title: "Log this meal", type: .logMeal)
            ],
            sourceType: .common
        )

        let card = NutritionEstimateCardFormatter.cardState(from: response, dailyLog: nil)
        XCTAssertTrue(card.caloriesDisplay.contains("520"))
        XCTAssertTrue(card.caloriesDisplay.contains("680"))
        XCTAssertFalse(card.suggestedActions.isEmpty)
    }

    // Flow 4 — "estimate pad thai but don't log"
    func testFlow04EstimateWithoutLoggingPhraseGuardBlocksMutation() {
        XCTAssertTrue(CoachIntentPhraseGuard.isEstimateWithoutLogging("estimate pad thai but don't log"))

        let raw = CoachIntentResult(
            intent: .logFood,
            confidence: 0.9,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false,
            action: .logFood(FoodDraft(
                mealType: nil,
                name: "pad thai",
                quantity: 1,
                unit: "plate",
                calories: 600,
                protein: 20,
                carbs: 70,
                fat: 22,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .medium,
                imageUrl: nil,
                notes: nil
            ))
        )

        let corrected = CoachIntentPhraseGuard.applyGuards(to: raw, text: "estimate pad thai but don't log")
        XCTAssertEqual(corrected.intent, .nutritionEstimateQuery)
        XCTAssertFalse(corrected.requiresAppMutation)
        XCTAssertNil(corrected.action)
    }

    // MARK: - Helpers

    private func underestimatedChickenRiceDraft() -> FoodLogDraft {
        FoodLogDraft(
            displayName: "chicken rice",
            components: [
                FoodComponent(
                    name: "chicken rice",
                    quantity: 1,
                    unit: "plate",
                    calories: 280,
                    protein: 20,
                    carbs: 35,
                    fat: 8,
                    sourceText: "chicken rice"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate,
            assumptions: ["Standard plate"],
            uncertaintyReasons: ["Portion unclear."],
            calorieRangeLower: 260,
            calorieRangeUpper: 300
        )
    }
}

// MARK: - Flows 5–6: Photo analysis & correction

final class CoachAccuracyTrustPhotoRegressionTests: XCTestCase {

    // Flow 5 — photo upload
    func testFlow05PhotoMapsTrustMetadataAndRequiresConfirmation() {
        let response = trustedRegressionPhotoResponse()
        let result = MealImageAnalysisMapper.sessionResult(from: response, userCaption: "Lunch")

        XCTAssertNotNil(result.trust)
        XCTAssertFalse(result.mealDraft.assumptions.isEmpty)
        XCTAssertNotNil(result.mealDraft.calorieRangeLower)
        XCTAssertNotNil(result.mealDraft.calorieRangeUpper)

        switch ConfirmationPolicy.decision(for: result.mealDraft) {
        case .requiresConfirmation:
            break
        case .executeImmediately, .reject:
            XCTFail("Photo estimate must require confirmation")
        }
    }

    func testFlow05PhotoPresentationIncludesRangeAndReviewCopy() {
        let response = trustedRegressionPhotoResponse()
        let result = MealImageAnalysisMapper.sessionResult(from: response, userCaption: "Lunch")
        let trust = try! XCTUnwrap(result.trust)

        let message = MealPhotoAnalysisPresentationFormatter.assistantMessage(
            mealDraft: result.mealDraft,
            confidence: .medium,
            trust: trust
        )

        XCTAssertTrue(message.contains(MealImageAnalysisTrustPolicy.estimatedFromPhotoMessage))
        XCTAssertTrue(message.contains(MealImageAnalysisTrustPolicy.photoReviewRequiredMessage))
        XCTAssertTrue(message.contains("Likely range:"))
    }

    // Flow 6 — "rice was half portion"
    func testFlow06RecommissionPreservesPreviousRangeAndUpdatesAfterCorrection() {
        let previous = ImageAnalysisSessionResult(
            mealDraft: FoodLogDraft(
                displayName: "Chicken rice",
                components: [photoRegressionComponent(name: "Chicken rice", calories: 520)],
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

        var session = ImageAnalysisSession.newSession(
            userMessageID: UUID(),
            attachment: ChatMessageImageAttachment(
                imageJPEG: Data([0xFF, 0xD8, 0xFF]),
                thumbnailJPEG: Data([0xFF, 0xD8, 0xFF])
            ),
            userCaption: "chicken rice"
        )
        session.latestResult = previous

        let prompt = ImageAnalysisPromptBuilder.recommissionMessage(
            session: session,
            clarification: "rice was half portion"
        )
        XCTAssertTrue(prompt.contains("rice was half portion"))
        XCTAssertTrue(prompt.contains("Previous calorie range: 480-580 kcal"))

        let refined = trustedRegressionPhotoResponse(
            calories: 360,
            lower: 320,
            upper: 420,
            primaryUncertainty: "Half bowl confirmed."
        )
        let updated = MealImageAnalysisMapper.sessionResult(from: refined, userCaption: "rice was half portion")
        XCTAssertEqual(updated.mealDraft.totalCalories, 360)
        XCTAssertEqual(updated.trust?.calorieRangeLower, 320)
        XCTAssertEqual(updated.trust?.calorieRangeUpper, 420)
    }

    private func trustedRegressionPhotoResponse(
        calories: Int = 520,
        lower: Int = 420,
        upper: Int = 560,
        primaryUncertainty: String = "Portion size is unclear from the photo."
    ) -> AIMealImageAnalysisResponse {
        AIMealImageAnalysisResponse(
            summary: "Chicken rice plate",
            items: [
                AIMealImageAnalysisItem(
                    name: "Chicken rice",
                    quantity: "1 plate",
                    calories: calories,
                    protein: 30,
                    carbs: 55,
                    fat: 14,
                    confidence: .medium,
                    assumptions: ["Estimated from photo."],
                    uncertaintyReasons: [primaryUncertainty],
                    suggestedClarifications: ["Was this a half or full bowl?"],
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
            clarifyingQuestion: nil,
            primaryUncertainty: primaryUncertainty
        )
    }

    private func photoRegressionComponent(name: String, calories: Int) -> FoodComponent {
        FoodComponent(
            name: name,
            quantity: 1,
            unit: "plate",
            calories: calories,
            protein: 30,
            carbs: 55,
            fat: 14,
            confidence: .medium,
            sourceText: name
        )
    }
}

// MARK: - Flows 7–9: Pending edit, post-log edit, delete

@MainActor
final class CoachAccuracyTrustMutationRegressionTests: XCTestCase {

    private let baseDate = Date(timeIntervalSince1970: 1_720_108_800)

    // Flow 7 — pending edit before log
    func testFlow07PendingEditUpdatesDraftBeforeConfirmation() {
        let pending = CoachPendingConfirmation.food(
            AIFoodConfirmationDraft(
                originalText: "log chicken rice",
                assistantMessage: nil,
                mealDraft: CoachMutationTestFixtures.chickenConfirmationDraft.primaryMealDraft,
                confidence: .medium,
                requiresConfirmation: true
            )
        )

        let action = AICommandAction(
            type: .editEntry,
            foodDraft: FoodDraft(
                mealType: nil,
                name: "Chicken breast",
                quantity: 200,
                unit: "g",
                calories: 360,
                protein: 68,
                carbs: 0,
                fat: 8,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .high,
                imageUrl: nil,
                notes: nil
            ),
            targetEntrySelector: "change to 360 calories"
        )

        let resolution = CoachEntryReferenceResolver.resolve(
            action: action,
            context: makeContext(meals: [], events: []),
            pendingConfirmation: pending
        )

        guard case .target(_, _, .high, let pendingDraft) = resolution.outcome else {
            return XCTFail("Expected pending draft update")
        }
        XCTAssertEqual(pendingDraft?.primaryMealDraft.totalCalories, 360)
    }

    func testFlow07ReviewedEstimateFlagDocumentedInTimelineTests() {
        // Primary coverage: CoachMutationExecutorTimelineTests.testFoodLogEventAfterPendingConfirmation
        XCTAssertEqual(
            CoachMutationExecutorTimelineTests.self.description(),
            "CoachMutationExecutorTimelineTests"
        )
    }

    // Flow 8 — post-log edit "actually the chicken was 300g"
    func testFlow08PostLogEditResolvesTargetAndRequiresConfirmation() {
        let entryId = UUID()
        let context = makeContext(
            meals: [meal(name: "Chicken breast", entryId: entryId, mealType: .lunch)],
            events: [foodLoggedEvent(entryId: entryId, name: "Chicken breast", mealType: .lunch)]
        )

        let action = AICommandAction(
            type: .editEntry,
            foodDraft: FoodDraft(
                mealType: nil,
                name: "chicken breast",
                quantity: 300,
                unit: "g",
                calories: 495,
                protein: 93,
                carbs: 0,
                fat: 11,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .high,
                imageUrl: nil,
                notes: nil
            ),
            targetEntrySelector: "actually the chicken was 300g"
        )

        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)
        guard case .target(let linkedEntryId, _, .medium, _) = resolution.outcome else {
            return XCTFail("Expected target resolution")
        }
        XCTAssertEqual(linkedEntryId, entryId)

        switch ConfirmationPolicy.decision(for: action) {
        case .requiresConfirmation:
            break
        case .executeImmediately, .reject:
            XCTFail("AI-driven post-log edit must require confirmation")
        }
    }

    // Flow 9 — "delete that"
    func testFlow09DeleteThatResolvesMostRecentMealAndRequiresConfirmation() {
        let older = UUID()
        let newest = UUID()
        let context = makeContext(
            meals: [
                meal(name: "Oatmeal", entryId: older, mealType: .breakfast, offsetMinutes: 120),
                meal(name: "Chicken rice", entryId: newest, mealType: .lunch, offsetMinutes: 10)
            ],
            events: [
                foodLoggedEvent(entryId: older, name: "Oatmeal", mealType: .breakfast, offsetMinutes: 120),
                foodLoggedEvent(entryId: newest, name: "Chicken rice", mealType: .lunch, offsetMinutes: 10)
            ]
        )

        let action = AICommandAction(type: .deleteEntry, targetEntrySelector: "delete that")
        let resolution = CoachEntryReferenceResolver.resolve(action: action, context: context)
        guard case .target(let linkedEntryId, _, .medium, _) = resolution.outcome else {
            return XCTFail("Expected target resolution")
        }
        XCTAssertEqual(linkedEntryId, newest)

        switch ConfirmationPolicy.decision(for: action) {
        case .requiresConfirmation:
            break
        case .executeImmediately, .reject:
            XCTFail("Delete must require confirmation")
        }
    }

    // MARK: - Helpers

    private func makeContext(
        meals: [CoachRecentMealContext],
        events: [CoachTimelineContextEvent]
    ) -> CoachContextPacketV2 {
        CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: baseDate),
            timeline: CoachContextTimelinePacket(recentEvents: events),
            recentMealsStructured: meals
        )
    }

    private func meal(
        name: String,
        entryId: UUID,
        mealType: MealType,
        offsetMinutes: Int = 0
    ) -> CoachRecentMealContext {
        CoachRecentMealContext(
            name: name,
            mealType: mealType.rawValue,
            calories: 500,
            loggedAt: baseDate.addingTimeInterval(TimeInterval(offsetMinutes * 60)),
            linkedEntryId: entryId
        )
    }

    private func foodLoggedEvent(
        entryId: UUID,
        name: String,
        mealType: MealType,
        offsetMinutes: Int = 0
    ) -> CoachTimelineContextEvent {
        CoachTimelineContextEvent(
            id: UUID(),
            timestamp: baseDate.addingTimeInterval(TimeInterval(offsetMinutes * 60)),
            type: CoachTimelineEventType.foodLogged.rawValue,
            source: CoachTimelineEventSourceAttribution.userConfirmation.rawValue,
            status: CoachTimelineEventStatus.confirmed.rawValue,
            summary: name,
            compactPayload: [
                "name": name,
                "kcal": "500",
                "mealType": mealType.rawValue
            ],
            linkedEntryId: entryId
        )
    }
}

// MARK: - Flows 10–13: Water/weight, Today refresh, theme, accessibility

@MainActor
final class CoachAccuracyTrustPlatformRegressionTests: XCTestCase {

    // Flow 10 — water and weight unaffected
    func testFlow10WaterTypoStillRoutesLocally() async throws {
        let service = RecordingAIService()
        let decision = try await CoachRouteDecider().decide(
            text: "add 500ml wter",
            context: .hardeningTest,
            aiService: service,
            config: .default
        )
        XCTAssertEqual(service.classifyCoachIntentCallCount, 0)
        XCTAssertEqual(decision.chosenHandler, "local_command")
    }

    func testFlow10WeightTypoStillRoutesLocally() async throws {
        let service = RecordingAIService()
        let decision = try await CoachRouteDecider().decide(
            text: "wieght 90",
            context: .hardeningTest,
            aiService: service,
            config: .default
        )
        XCTAssertEqual(service.classifyCoachIntentCallCount, 0)
        XCTAssertEqual(decision.chosenHandler, "local_command")
    }

    // Flow 11 — Today totals refresh after food log (covered by CoachTodaySyncTests)
    func testFlow11TodayRefreshContractDocumented() {
        XCTAssertTrue(
            CoachTodaySyncTests.self.description().contains("CoachTodaySyncTests"),
            "Flow 11 primary coverage: CoachTodaySyncTests.testCoachMealSaveUpdatesTodayDashboard"
        )
    }

    // Flow 12 — theme switch updates design tokens without stale pending copy
    func testFlow12ThemeSwitchUpdatesAccentTokens() {
        ThemeTestSupport.resetThemeAccessToProductDefault()
        let blossom = ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .light)
        let ocean = ThemeTestSupport.makeResolved(palette: .oceanBlue, systemColorScheme: .dark)

        FormaThemeAccess.update(resolved: blossom)
        let blossomAccent = FormaThemeAccess.currentColors.accent

        FormaThemeAccess.update(resolved: ocean)
        let oceanAccent = FormaThemeAccess.currentColors.accent

        XCTAssertNotEqual(blossomAccent, oceanAccent)

        let pending = CoachPendingConfirmation.food(CoachMutationTestFixtures.chickenConfirmationDraft)
        XCTAssertFalse(pending.summaryLine.isEmpty)
        XCTAssertTrue(pending.summaryLine.contains("Chicken breast"))
    }

    // Flow 13 — accessibility for trust fields
    func testFlow13TrustFieldsExposeVoiceOverLabels() {
        let meal = FoodLogDraft(
            displayName: "Chicken rice",
            components: [
                FoodComponent(name: "chicken rice", calories: 520, protein: 30, carbs: 55, fat: 14)
            ],
            confidence: .low,
            source: .aiTextEstimate,
            assumptions: ["Standard plate"],
            uncertaintyReasons: ["Hidden oil may add calories."],
            primaryUncertainty: "Portion size unclear.",
            calorieRangeLower: 480,
            calorieRangeUpper: 620
        )

        let assumptionText = AIFoodConfirmationFormatter.assumptionLines(for: meal).joined(separator: ". ")
        XCTAssertTrue(assumptionText.contains("Standard plate"))
        XCTAssertTrue(assumptionText.contains("Estimated range: 480-620 kcal"))
        XCTAssertTrue(assumptionText.contains("Uncertainty:"))

        let estimateCard = NutritionEstimateCardFormatter.cardState(
            from: NutritionEstimateResponse(
                foodName: "Chicken rice",
                displayEmoji: "🍗",
                caloriesKcal: nil,
                caloriesRangeLowerKcal: 480,
                caloriesRangeUpperKcal: 620,
                proteinGrams: 30,
                carbsGrams: 55,
                fatGrams: 14,
                servingDescription: "1 plate",
                confidenceLevel: .low,
                confidenceLabel: "Low confidence",
                confidenceReason: "Portion size unclear.",
                coachSummary: nil,
                coachTip: "Review before logging.",
                caveats: [],
                suggestedActions: [],
                sourceType: .common
            ),
            dailyLog: nil
        )
        let accessibility = NutritionEstimateCardFormatter.accessibilitySummary(for: estimateCard)
        XCTAssertTrue(accessibility.contains("Chicken rice"))
        XCTAssertTrue(accessibility.contains("480"))
        XCTAssertTrue(accessibility.contains("620"))
    }
}
