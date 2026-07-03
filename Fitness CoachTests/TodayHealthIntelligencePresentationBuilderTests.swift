//
//  TodayHealthIntelligencePresentationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayHealthIntelligencePresentationBuilderTests: XCTestCase {

    private var referenceDay: Date {
        HealthIntelligencePipelineFixtures.day(2026, 7, 3)
    }

    // MARK: - Feature flag

    func testBuildSectionReturnsNilWhenUIEnabledIsFalse() {
        let snapshot = makeReadyDaySnapshot()

        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            isUIEnabled: false
        )

        XCTAssertNil(section)
    }

    func testBuildSectionReturnsStateWhenUIEnabledIsTrue() {
        let snapshot = makeReadyDaySnapshot()

        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            isUIEnabled: true
        )

        XCTAssertNotNil(section)
    }

    // MARK: - Loading

    func testLoadingSectionUsesLoadingPlaceholders() {
        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: nil,
            isLoading: true,
            isUIEnabled: true
        )

        XCTAssertNotNil(section)
        XCTAssertTrue(section?.isLoading == true)
        XCTAssertEqual(section?.recoveryCard.title, FormaProductCopy.Today.HealthIntelligence.loadingTitle)
        XCTAssertNil(section?.workoutCard)
        XCTAssertNil(section?.fallbackMessage)
    }

    // MARK: - Ready recovery day

    func testReadyRecoveryDayMapsRecoveryCard() {
        let snapshot = makeReadyDaySnapshot()

        let section = build(snapshot: snapshot)
        let recovery = section.recoveryCard

        XCTAssertEqual(recovery.phase, .ready)
        XCTAssertEqual(recovery.title, "Ready to train")
        XCTAssertNil(recovery.confidenceNote)
        XCTAssertFalse(recovery.accessibilityLabel.isEmpty)
        XCTAssertFalse(recovery.accessibilityLabel.contains("84"))
    }

    func testReadyRecoveryDayDailyMissionIncludesNutritionRemaining() {
        let snapshot = makeReadyDaySnapshot()
        let nutrition = TodayHealthIntelligenceNutritionProgress(
            calorieRemaining: 620,
            proteinRemainingGrams: 42,
            waterRemainingMl: 800,
            hasCalorieTarget: true,
            hasProteinTarget: true,
            hasWaterTarget: true
        )

        let section = build(snapshot: snapshot, nutritionProgress: nutrition)

        XCTAssertEqual(section.dailyMission.headline, FormaProductCopy.Today.HealthIntelligence.DailyMission.readyHeadline)
        XCTAssertTrue(section.dailyMission.detailLines.contains(where: { $0.contains("620") && $0.contains("kcal") }))
        XCTAssertTrue(section.dailyMission.detailLines.contains(where: { $0.contains("42") && $0.contains("protein") }))
        XCTAssertTrue(section.dailyMission.detailLines.contains(where: { $0.contains("800") && $0.contains("water") }))
    }

    // MARK: - Low recovery day

    func testLowRecoveryDayMapsRecoveryCardAndMission() {
        let snapshot = makeLowRecoveryDaySnapshot()

        let section = build(snapshot: snapshot)

        XCTAssertEqual(section.recoveryCard.phase, .low)
        XCTAssertEqual(section.recoveryCard.title, "Recovery is low")
        XCTAssertEqual(section.dailyMission.headline, FormaProductCopy.Today.HealthIntelligence.DailyMission.lowHeadline)
        XCTAssertEqual(section.nextBestAction.title, "Prioritize recovery")
        XCTAssertEqual(section.nextBestAction.destination, .viewRecovery)
    }

    // MARK: - Workout day

    func testWorkoutDayPrefersWorkoutCompleteLanguage() {
        let snapshot = makeWorkoutDaySnapshot()

        let section = build(snapshot: snapshot)

        XCTAssertNotNil(section.workoutCard)
        XCTAssertEqual(section.workoutCard?.title, FormaProductCopy.Today.HealthIntelligence.workoutComplete)
        XCTAssertEqual(section.workoutCard?.subtitle, "Strength training")
        XCTAssertTrue(section.dailyMission.detailLines.contains(
            FormaProductCopy.Today.HealthIntelligence.DailyMission.workoutCompleteDetail
        ))
    }

    func testWorkoutDayShowsAdaptiveNutritionCard() {
        let snapshot = makeWorkoutDaySnapshot()

        let section = build(snapshot: snapshot)

        XCTAssertNotNil(section.adaptiveNutritionCard)
        XCTAssertTrue(section.adaptiveNutritionCard?.isVisible == true)
        XCTAssertEqual(
            section.adaptiveNutritionCard?.title,
            FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.postWorkoutTitle
        )
    }

    // MARK: - No health data

    func testNoHealthDataShowsConnectHealthFallback() {
        let snapshot = makeNoHealthDataSnapshot()

        let section = build(snapshot: snapshot)

        XCTAssertEqual(section.recoveryCard.phase, .unknown)
        XCTAssertEqual(
            section.fallbackMessage,
            FormaProductCopy.Today.HealthIntelligence.connectHealthFallback
        )
        XCTAssertTrue(section.nextBestAction.isVisible)
        XCTAssertEqual(section.nextBestAction.destination, .connectHealth)
        XCTAssertNil(section.workoutCard)
    }

    // MARK: - Missing sleep / HRV

    func testMissingSleepAndHRVMissingDataNote() {
        let recovery = RecoverySummary(
            score: nil,
            status: .unknown,
            title: "Recovery unclear",
            explanation: "Sleep and HRV are missing.",
            recommendedTraining: "Use how you feel today.",
            recommendedNutrition: "Stay on your usual plan.",
            confidence: .low,
            contributingFactors: [],
            missingSignals: [.sleep, .hrv]
        )
        let card = TodayHealthIntelligencePresentationBuilder.recoveryCard(from: recovery)

        XCTAssertEqual(card.confidenceNote, FormaProductCopy.Today.HealthIntelligence.limitedEstimate)
        XCTAssertEqual(card.missingDataNote, "Missing: sleep, HRV.")
        XCTAssertEqual(
            card.subtitle,
            FormaProductCopy.Today.HealthIntelligence.limitedRecoveryMissingSignals
        )
        XCTAssertFalse(card.accessibilityLabel.contains("ms"))
        XCTAssertFalse(card.accessibilityLabel.contains("bpm"))
    }

    func testWorkoutDayDailyMissionOmitsNutritionOverlapWhenAdaptiveCardVisible() {
        let snapshot = makeWorkoutDaySnapshot()
        let nutrition = TodayHealthIntelligenceNutritionProgress(
            calorieRemaining: 620,
            proteinRemainingGrams: 28,
            waterRemainingMl: 900,
            hasCalorieTarget: true,
            hasProteinTarget: true,
            hasWaterTarget: true
        )

        let section = build(snapshot: snapshot, nutritionProgress: nutrition)

        XCTAssertNotNil(section.adaptiveNutritionCard)
        XCTAssertTrue(section.dailyMission.detailLines.contains(where: { $0.contains("620") && $0.contains("kcal") }))
        XCTAssertFalse(section.dailyMission.detailLines.contains(where: { $0.contains("protein") }))
        XCTAssertFalse(section.dailyMission.detailLines.contains(where: { $0.contains("water") }))
        XCTAssertEqual(
            section.dailyMission.focusSummary,
            "Aim for 30–40g protein in your next meal."
        )
    }

    func testRecoveryExplanationSanitizesRawMetricLanguage() {
        let recovery = RecoverySummary(
            score: 55,
            status: .low,
            title: "Recovery is low",
            explanation: "HRV was below your recent baseline and sleep was short.",
            recommendedTraining: "Keep today lighter.",
            recommendedNutrition: "Fuel steadily.",
            confidence: .moderate,
            contributingFactors: [],
            missingSignals: []
        )

        let card = TodayHealthIntelligencePresentationBuilder.recoveryCard(from: recovery)

        XCTAssertEqual(card.subtitle, FormaProductCopy.Today.HealthIntelligence.Recovery.lowExplanation)
        XCTAssertFalse(card.subtitle?.lowercased().contains("hrv") ?? true)
    }

    func testMissingSignalsFallbackMessageWhenConfidenceLow() {
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: nil,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Limited signals.",
                recommendedTraining: "Train with care.",
                recommendedNutrition: "Stay steady.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 4_000, activeEnergyKcal: 220, exerciseMinutes: 20),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )

        let section = build(snapshot: snapshot)

        XCTAssertEqual(
            section.fallbackMessage,
            FormaProductCopy.Today.HealthIntelligence.continueLoggingFallback
        )
    }

    // MARK: - Next best action

    func testNextBestActionAvailableMapsCTA() {
        let action = NextBestAction(
            id: "log-protein",
            title: "Log protein",
            message: "Protein is your biggest gap after training.",
            ctaTitle: "Log meal",
            destination: .logMeal,
            priority: 2,
            reason: .postWorkoutRecovery,
            createdAt: referenceDay,
            expiresAt: nil
        )

        let mapped = TodayHealthIntelligencePresentationBuilder.nextBestAction(from: action)

        XCTAssertTrue(mapped.isVisible)
        XCTAssertEqual(mapped.title, "Log protein")
        XCTAssertEqual(mapped.ctaTitle, "Log meal")
        XCTAssertEqual(mapped.destination, .logMeal)
        XCTAssertTrue(mapped.accessibilityLabel.contains("Log protein"))
    }

    func testNextBestActionNoneIsHiddenUnlessFallbackProvided() {
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 84,
                status: .ready,
                title: "Ready to train",
                explanation: "Sleep and recovery signals look supportive for your usual plan today.",
                recommendedTraining: "Your usual training plan looks reasonable today.",
                recommendedNutrition: "Stick with your normal protein and hydration rhythm.",
                confidence: .high,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_450, activeEnergyKcal: 420, exerciseMinutes: 38),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.82, label: "High"),
            nextBestAction: .none
        )

        let section = build(snapshot: snapshot)

        XCTAssertFalse(section.nextBestAction.isVisible)
        XCTAssertEqual(section.nextBestAction, .hidden)
    }

    // MARK: - No workout

    func testNoWorkoutOmitsWorkoutCard() {
        let snapshot = makeReadyDaySnapshot()

        let section = build(snapshot: snapshot)

        XCTAssertNil(section.workoutCard)
        XCTAssertTrue(section.dailyMission.detailLines.contains(
            FormaProductCopy.Today.HealthIntelligence.noWorkoutYet
        ))
    }

    // MARK: - Limited estimate

    func testLowConfidenceShowsLimitedEstimateWithoutScore() {
        let recovery = RecoverySummary(
            score: 72,
            status: .ready,
            title: "Ready to train",
            explanation: "Signals are partial.",
            recommendedTraining: "Train as planned.",
            recommendedNutrition: "Stay on plan.",
            confidence: .low,
            contributingFactors: [],
            missingSignals: [.hrv]
        )

        let card = TodayHealthIntelligencePresentationBuilder.recoveryCard(from: recovery)

        XCTAssertEqual(card.phase, .limitedEstimate)
        XCTAssertEqual(card.confidenceNote, FormaProductCopy.Today.HealthIntelligence.limitedEstimate)
        XCTAssertEqual(card.title, "Ready to train")
        XCTAssertFalse(card.accessibilityLabel.contains("72"))
    }

    func testNilRecoveryScoreNeverAppearsInPresentation() {
        let recovery = RecoverySummary(
            score: nil,
            status: .moderate,
            title: "Moderate recovery",
            explanation: "Recovery is acceptable.",
            recommendedTraining: "You can train.",
            recommendedNutrition: "Prioritize protein.",
            confidence: .moderate,
            contributingFactors: [],
            missingSignals: []
        )

        let card = TodayHealthIntelligencePresentationBuilder.recoveryCard(from: recovery)

        XCTAssertEqual(card.title, "Moderate recovery")
        XCTAssertFalse(card.accessibilityLabel.contains("%"))
    }

    func testFallbackConnectHealthActionWhenNoExplicitNextBestAction() {
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: .unknown,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )

        let section = build(snapshot: snapshot)

        XCTAssertTrue(section.nextBestAction.isVisible)
        XCTAssertEqual(section.nextBestAction.destination, .connectHealth)
        XCTAssertEqual(section.nextBestAction.title, FormaProductCopy.Today.actionConnectAppleHealth)
    }

    func testModerateConfidenceDoesNotShowLimitedEstimate() {
        let recovery = RecoverySummary(
            score: 74,
            status: .moderate,
            title: "Moderate recovery",
            explanation: "Recovery is acceptable.",
            recommendedTraining: "You can train.",
            recommendedNutrition: "Prioritize protein.",
            confidence: .moderate,
            contributingFactors: [],
            missingSignals: []
        )

        let card = TodayHealthIntelligencePresentationBuilder.recoveryCard(from: recovery)

        XCTAssertEqual(card.phase, .moderate)
        XCTAssertNil(card.confidenceNote)
    }

    // MARK: - Adaptive nutrition hidden

    func testAdaptiveNutritionHiddenWhenNoMeaningfulAdjustment() {
        let card = TodayHealthIntelligencePresentationBuilder.adaptiveNutritionCard(
            from: .none,
            nutritionProgress: .unavailable
        )

        XCTAssertNil(card)
    }

    // MARK: - Helpers

    private func build(
        snapshot: HealthIntelligenceSnapshot,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress = .unavailable
    ) -> TodayHealthIntelligenceSectionState {
        guard let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            isUIEnabled: true
        ) else {
            XCTFail("Expected section state")
            return TodayHealthIntelligenceSectionState(
                recoveryCard: .loading,
                dailyMission: .loading,
                nextBestAction: .loading,
                workoutCard: nil,
                adaptiveNutritionCard: nil,
                isLoading: false,
                fallbackMessage: nil
            )
        }
        return section
    }

    private func makeReadyDaySnapshot() -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 84,
                status: .ready,
                title: "Ready to train",
                explanation: "Sleep and recovery signals look supportive for your usual plan today.",
                recommendedTraining: "Your usual training plan looks reasonable today.",
                recommendedNutrition: "Stick with your normal protein and hydration rhythm.",
                confidence: .high,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_450, activeEnergyKcal: 420, exerciseMinutes: 38),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.82, label: "High"),
            nextBestAction: NextBestAction(
                id: "stay-on-plan",
                title: "Stay on plan",
                message: "Recovery looks good. Keep following your usual plan today.",
                ctaTitle: "",
                destination: .none,
                priority: 7,
                reason: .stayOnPlan,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }

    private func makeLowRecoveryDaySnapshot() -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 48,
                status: .low,
                title: "Recovery is low",
                explanation: "Sleep was short and recent training load is elevated.",
                recommendedTraining: "Keep today lighter and avoid stacking hard sessions.",
                recommendedNutrition: "Prioritize protein, hydration, and steady fueling today.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 5_600, activeEnergyKcal: 290, exerciseMinutes: 22),
            nutritionAdjustment: AdaptiveNutritionSummary(
                proteinRecommendationGrams: nil,
                suggestedProteinRemaining: nil,
                waterIncreaseMl: 250,
                suggestedWaterRemainingMl: 1_100,
                calorieAdvice: "Keep fueling steady while recovery catches up.",
                shouldChangeTarget: false,
                suggestedCalorieAdjustment: 0,
                adjustmentReason: "",
                priority: 3,
                confidence: .moderate,
                missingSignals: []
            ),
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.62, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "recover",
                title: "Prioritize recovery",
                message: "Recovery is low today. Keep movement light and fuel steadily.",
                ctaTitle: "View recovery",
                destination: .viewRecovery,
                priority: 2,
                reason: .lowRecovery,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }

    private func makeWorkoutDaySnapshot() -> HealthIntelligenceSnapshot {
        let workout = WorkoutSummary(
            hasWorkout: true,
            primaryWorkoutType: .strength,
            title: "Strength training",
            workoutCount: 1,
            totalDurationMinutes: 50,
            totalActiveCalories: 320,
            intensity: .moderate,
            demand: .high,
            latestWorkoutStart: referenceDay,
            latestWorkoutEnd: referenceDay,
            nutritionAdvice: "Aim for 30–40g protein in your next meal.",
            hydrationAdviceMl: 700,
            explanation: "Strength training added meaningful load today.",
            confidence: .high,
            sourceSummary: "Synced workout."
        )

        return HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 74,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable after recent training.",
                recommendedTraining: "You can train, but avoid stacking intensity tonight.",
                recommendedNutrition: "Prioritize protein and hydration after your workout.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: workout,
            activity: ActivitySummary(steps: 9_120, activeEnergyKcal: 560, exerciseMinutes: 52),
            nutritionAdjustment: AdaptiveNutritionSummary(
                proteinRecommendationGrams: 35,
                suggestedProteinRemaining: 28,
                waterIncreaseMl: 350,
                suggestedWaterRemainingMl: 900,
                calorieAdvice: "Keep calories steady and prioritize protein after training.",
                shouldChangeTarget: false,
                suggestedCalorieAdjustment: 0,
                adjustmentReason: "",
                priority: 6,
                confidence: .high,
                missingSignals: []
            ),
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "log-protein",
                title: "Log protein",
                message: "You still have meaningful protein left after today's workout.",
                ctaTitle: "Log meal",
                destination: .logMeal,
                priority: 2,
                reason: .postWorkoutRecovery,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }

    private func makeNoHealthDataSnapshot() -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: .unknown,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: NextBestAction(
                id: "connect-health",
                title: "Connect Apple Health",
                message: "Enable Apple Health to unlock recovery and activity insights.",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }
}
