//
//  TodayFocusBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic single-line focus aligned with Next Actions (no AI).
//

import Foundation

enum TodayFocusBuilder {

    static func focus(
        proteinProgress: Double,
        waterProgress: Double,
        weightLogged: Bool,
        hasWorkout: Bool,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth
    ) -> String {
        let proteinLow = proteinProgress < proteinOnTrackThreshold
        let waterLow = waterProgress < waterOnTrackThreshold

        if proteinLow && (!waterLow || proteinProgress <= waterProgress) {
            return FormaProductCopy.Today.focusProteinLow
        }
        if waterLow {
            return FormaProductCopy.Today.focusWaterLow
        }
        if !weightLogged {
            return FormaProductCopy.Today.focusLogWeight
        }
        if isTrainingActionRelevant(
            hasWorkout: hasWorkout,
            trainingDataSource: trainingDataSource,
            trainingIntegration: trainingIntegration
        ) {
            return FormaProductCopy.Today.focusTraining
        }
        return FormaProductCopy.Today.focusOnTrack
    }

    static func focus(
        from state: TodayDashboardState,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth
    ) -> String {
        focus(
            proteinProgress: state.macroSummary.protein.progress,
            waterProgress: state.waterSummary.progress,
            weightLogged: state.weightSummary.weightKg != nil,
            hasWorkout: state.workoutSummary.hasWorkout,
            trainingIntegration: trainingIntegration,
            trainingDataSource: trainingDataSource
        )
    }

    static let proteinOnTrackThreshold = 0.9
    static let waterOnTrackThreshold = 0.8

    static func isTrainingActionRelevant(
        hasWorkout: Bool,
        trainingDataSource: TrainingDataSource,
        trainingIntegration: TrainingIntegrationState
    ) -> Bool {
        switch trainingDataSource {
        case .appleHealth:
            return trainingIntegration.showsConnectionGate
        case .unavailable:
            return !hasWorkout
        }
    }
}
