//
//  CoachCompositionPolicyTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachCompositionPolicyTests: XCTestCase {

    func testCoachContextDisabledPreservesLegacyWorkoutSignals() {
        let activity = CoachAIActivityContext(
            workoutsToday: 1,
            hasWorkoutToday: true,
            healthIntelligence: workoutHealthContext,
            healthIntelligenceAwarenessAvailable: true
        )

        XCTAssertFalse(
            CoachCompositionPolicy.suppressesLegacyWorkoutSignals(
                isCoachContextEnabled: false,
                healthIntelligenceAwarenessAvailable: true
            )
        )
        XCTAssertEqual(
            CoachCompositionPolicy.legacyWorkoutsTodayForAISummary(
                activity: activity,
                explicitOverride: nil,
                isCoachContextEnabled: false
            ),
            1
        )
    }

    func testCoachContextEnabledSuppressesDuplicateWorkoutCountInAISummary() {
        let activity = CoachAIActivityContext(
            workoutsToday: 1,
            hasWorkoutToday: true,
            healthIntelligence: workoutHealthContext,
            healthIntelligenceAwarenessAvailable: true
        )

        XCTAssertTrue(
            CoachCompositionPolicy.suppressesLegacyWorkoutSignals(
                isCoachContextEnabled: true,
                healthIntelligenceAwarenessAvailable: true
            )
        )
        XCTAssertEqual(
            CoachCompositionPolicy.legacyWorkoutsTodayForAISummary(
                activity: activity,
                explicitOverride: nil,
                isCoachContextEnabled: true
            ),
            0
        )
    }

    func testExplicitWorkoutsTodayOverrideIsPreservedWhenCoachContextEnabled() {
        let activity = CoachAIActivityContext(
            workoutsToday: 1,
            hasWorkoutToday: true,
            healthIntelligence: workoutHealthContext,
            healthIntelligenceAwarenessAvailable: true
        )

        XCTAssertEqual(
            CoachCompositionPolicy.legacyWorkoutsTodayForAISummary(
                activity: activity,
                explicitOverride: 2,
                isCoachContextEnabled: true
            ),
            2
        )
    }

    func testSuggestedFocusUsesHealthIntelligenceWhenCoachContextEnabled() {
        let focus = CoachCompositionPolicy.suggestedFocus(
            healthIntelligence: workoutHealthContext,
            proteinProgress: 0.95,
            waterProgress: 0.95,
            weightLogged: true,
            legacyHasWorkout: false,
            healthIntelligenceAwarenessAvailable: true,
            isCoachContextEnabled: true
        )

        XCTAssertEqual(focus, "Log protein")
    }

    func testSuggestedFocusFallsBackToTodayFocusBuilderWhenCoachContextDisabled() {
        let focus = CoachCompositionPolicy.suggestedFocus(
            healthIntelligence: workoutHealthContext,
            proteinProgress: 0.2,
            waterProgress: 0.95,
            weightLogged: true,
            legacyHasWorkout: false,
            healthIntelligenceAwarenessAvailable: true,
            isCoachContextEnabled: false
        )

        XCTAssertEqual(focus, FormaProductCopy.Today.focusProteinLow)
    }

    // MARK: - Fixtures

    private var workoutHealthContext: CoachHealthIntelligenceContext {
        CoachHealthIntelligenceContextBuilder.build(
            from: HealthIntelligenceSnapshot(
                date: Date(),
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
                workout: WorkoutSummary(
                    hasWorkout: true,
                    primaryWorkoutType: .strength,
                    title: "Strength training",
                    workoutCount: 1,
                    totalDurationMinutes: 50,
                    totalActiveCalories: 320,
                    intensity: .moderate,
                    demand: .high,
                    latestWorkoutStart: Date(),
                    latestWorkoutEnd: Date(),
                    nutritionAdvice: "Aim for 30–40g protein in your next meal.",
                    hydrationAdviceMl: 700,
                    explanation: "Strength training added meaningful load today.",
                    confidence: .high,
                    sourceSummary: "Synced workout."
                ),
                activity: ActivitySummary(steps: 9_120, activeEnergyKcal: 560, exerciseMinutes: 52),
                nutritionAdjustment: .none,
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
                    createdAt: Date(),
                    expiresAt: nil
                )
            )
        )
    }
}
