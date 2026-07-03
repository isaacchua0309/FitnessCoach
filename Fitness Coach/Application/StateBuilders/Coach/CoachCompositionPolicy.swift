//
//  CoachCompositionPolicy.swift
//  Fitness Coach
//
//  Forma — Avoid duplicate workout signals when Coach Health Intelligence context is active.
//

import Foundation

enum CoachCompositionPolicy {

    static func suppressesLegacyWorkoutSignals(
        isCoachContextEnabled: Bool,
        healthIntelligenceAwarenessAvailable: Bool
    ) -> Bool {
        isCoachContextEnabled && healthIntelligenceAwarenessAvailable
    }

    /// Omits legacy workout count from AI today summary when Health Intelligence already carries workout status.
    static func legacyWorkoutsTodayForAISummary(
        activity: CoachAIActivityContext,
        explicitOverride: Int?,
        isCoachContextEnabled: Bool = HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence
    ) -> Int {
        if let explicitOverride {
            return explicitOverride
        }

        if suppressesLegacyWorkoutSignals(
            isCoachContextEnabled: isCoachContextEnabled,
            healthIntelligenceAwarenessAvailable: activity.healthIntelligenceAwarenessAvailable
        ) {
            return 0
        }

        return activity.workoutsToday
    }

    static func suggestedFocus(
        healthIntelligence: CoachHealthIntelligenceContext?,
        proteinProgress: Double,
        waterProgress: Double,
        weightLogged: Bool,
        legacyHasWorkout: Bool,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        healthIntelligenceAwarenessAvailable: Bool = false,
        isCoachContextEnabled: Bool = HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence
    ) -> String {
        if suppressesLegacyWorkoutSignals(
            isCoachContextEnabled: isCoachContextEnabled,
            healthIntelligenceAwarenessAvailable: healthIntelligenceAwarenessAvailable
        ),
           let healthIntelligence {
            if let nextBestActionTitle = healthIntelligence.nextBestActionTitle,
               !nextBestActionTitle.isEmpty {
                return nextBestActionTitle
            }

            if healthIntelligence.workoutCompletedToday,
               let workoutSummary = healthIntelligence.workoutSummaryText,
               !workoutSummary.isEmpty {
                return workoutSummary
            }

            if !healthIntelligence.recoveryExplanation.isEmpty {
                return healthIntelligence.recoveryExplanation
            }
        }

        return TodayFocusBuilder.focus(
            proteinProgress: proteinProgress,
            waterProgress: waterProgress,
            weightLogged: weightLogged,
            hasWorkout: legacyHasWorkout,
            trainingIntegration: trainingIntegration,
            trainingDataSource: trainingDataSource
        )
    }
}
