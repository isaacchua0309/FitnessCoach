//
//  TodayGoalsBuilder.swift
//  Fitness Coach
//
//  Forma — State-aware next actions from dashboard data (no AI).
//

import Foundation

struct TodayGoalItem: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case weight
        case protein
        case water
        case workout
    }

    enum TapAction: Equatable {
        case coach(prefill: String)
        case openTrainingInsights
    }

    var id: String { kind.rawValue }
    let kind: Kind
    var label: String
    /// Row reflects a met goal or calm status — not an open action.
    var isComplete: Bool
    /// Neutral status (e.g. rest day) — circle icon, no chevron.
    var isInformational: Bool
    var tapAction: TapAction?

    /// Chevron only when the row opens a screen or flow (Training Insights, Settings, etc.).
    var showsChevron: Bool {
        guard let tapAction, !isInformational else { return false }
        if case .openTrainingInsights = tapAction { return true }
        return false
    }

    /// Bordered chip for immediate Coach logging — not a navigation row.
    var showsQuickActionButton: Bool {
        guard !isComplete, !isInformational else { return false }
        if case .coach = tapAction { return true }
        return false
    }

    var isActionable: Bool { showsChevron || showsQuickActionButton }
}

enum TodayGoalsBuilder {

    static func goals(
        from state: TodayDashboardState,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        appleHealthWorkoutCount: Int? = nil
    ) -> [TodayGoalItem] {
        let protein = state.macroSummary.protein
        let water = state.waterSummary
        let proteinComplete = protein.progress >= TodayFocusBuilder.proteinOnTrackThreshold
        let waterComplete = water.progress >= TodayFocusBuilder.waterOnTrackThreshold
        let weightLogged = state.weightSummary.weightKg != nil

        var items: [TodayGoalItem] = [
            weightGoal(weightLogged: weightLogged),
            proteinGoal(proteinComplete: proteinComplete),
            waterGoal(waterComplete: waterComplete)
        ]

        if let workout = workoutGoal(
            trainingDataSource: trainingDataSource,
            trainingIntegration: trainingIntegration,
            appleHealthWorkoutCount: appleHealthWorkoutCount
        ) {
            items.append(workout)
        }

        return items
    }

    private static func weightGoal(weightLogged: Bool) -> TodayGoalItem {
        if weightLogged {
            return TodayGoalItem(
                kind: .weight,
                label: FormaProductCopy.Today.statusWeightLogged,
                isComplete: true,
                isInformational: false,
                tapAction: nil
            )
        }
        return TodayGoalItem(
            kind: .weight,
            label: FormaProductCopy.Today.actionLogWeight,
            isComplete: false,
            isInformational: false,
            tapAction: .coach(prefill: TodayCoachPrompt.logWeight)
        )
    }

    private static func proteinGoal(proteinComplete: Bool) -> TodayGoalItem {
        if proteinComplete {
            return TodayGoalItem(
                kind: .protein,
                label: FormaProductCopy.Today.statusProteinOnTrack,
                isComplete: true,
                isInformational: false,
                tapAction: nil
            )
        }
        return TodayGoalItem(
            kind: .protein,
            label: FormaProductCopy.Today.actionPlanProteinMeal,
            isComplete: false,
            isInformational: false,
            tapAction: .coach(prefill: TodayCoachPrompt.logProtein)
        )
    }

    private static func waterGoal(waterComplete: Bool) -> TodayGoalItem {
        if waterComplete {
            return TodayGoalItem(
                kind: .water,
                label: FormaProductCopy.Today.statusHydrationOnTrack,
                isComplete: true,
                isInformational: false,
                tapAction: nil
            )
        }
        return TodayGoalItem(
            kind: .water,
            label: FormaProductCopy.Today.actionDrinkWater,
            isComplete: false,
            isInformational: false,
            tapAction: .coach(prefill: TodayCoachPrompt.logWater)
        )
    }

    private static func workoutGoal(
        trainingDataSource: TrainingDataSource,
        trainingIntegration: TrainingIntegrationState,
        appleHealthWorkoutCount: Int?
    ) -> TodayGoalItem? {
        switch trainingDataSource {
        case .appleHealth:
            return appleHealthWorkoutGoal(
                workoutCount: appleHealthWorkoutCount ?? 0,
                trainingIntegration: trainingIntegration
            )
        case .unavailable:
            return nil
        }
    }

    private static func appleHealthWorkoutGoal(
        workoutCount: Int,
        trainingIntegration: TrainingIntegrationState
    ) -> TodayGoalItem {
        if trainingIntegration.showsConnectionGate {
            return TodayGoalItem(
                kind: .workout,
                label: lockedTrainingLabel(for: trainingIntegration),
                isComplete: false,
                isInformational: false,
                tapAction: .openTrainingInsights
            )
        }

        if workoutCount > 0 {
            return TodayGoalItem(
                kind: .workout,
                label: connectedWorkoutLabel(count: workoutCount),
                isComplete: true,
                isInformational: false,
                tapAction: .openTrainingInsights
            )
        }

        return TodayGoalItem(
            kind: .workout,
            label: FormaProductCopy.Today.statusNoAppleHealthWorkoutToday,
            isComplete: true,
            isInformational: true,
            tapAction: nil
        )
    }

    private static func lockedTrainingLabel(for integration: TrainingIntegrationState) -> String {
        switch integration {
        case .denied, .failed:
            return FormaProductCopy.Today.actionManageHealthAccess
        case .notConnected:
            return FormaProductCopy.Training.Integration.connectAppleHealth
        case .unavailable, .requestingPermission, .connected:
            return FormaProductCopy.Training.Integration.connectAppleHealth
        }
    }

    private static func connectedWorkoutLabel(count: Int) -> String {
        switch count {
        case 1:
            return FormaProductCopy.Today.workoutsToday(1)
        default:
            return FormaProductCopy.Today.workoutsToday(count)
        }
    }
}
