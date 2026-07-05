//
//  JourneyProgressSectionBuilder.swift
//  Fitness Coach
//
//  Forma — Compact progress rows for the Journey dashboard.
//

import Foundation

enum JourneyProgressSectionBuilder {

    struct Input: Equatable {
        var screenPresentation: JourneyScreenPresentationState
        var unifiedWeeklyReview: UnifiedWeeklyReviewState
        var goalProjection: JourneyGoalProjectionState
        var connectHealthCTA: JourneyHealthConnectCTAState?
    }

    static func build(_ input: Input) -> JourneyProgressSectionState {
        let copy = FormaProductCopy.Journey.Dashboard.Progress.self
        let stats = input.screenPresentation.weekly.stats
        let unlocks = input.screenPresentation.unlocks

        var rows: [JourneyProgressRowState] = []

        rows.append(nutritionRow(stats: stats, unlocks: unlocks, copy: copy))
        rows.append(weightTrendRow(stats: stats, unlocks: unlocks, unified: input.unifiedWeeklyReview, copy: copy))
        rows.append(trainingRow(stats: stats, copy: copy))
        rows.append(recoveryRow(stats: stats, unlocks: unlocks, copy: copy))

        if let stepsRow = stepsRow(stats: stats, copy: copy) {
            rows.append(stepsRow)
        }

        if let projectionRow = goalProjectionRow(goalProjection: input.goalProjection, copy: copy) {
            rows.append(projectionRow)
        }

        let accessibilitySummary = [
            copy.sectionTitle,
            rows.map(\.accessibilityLabel).joined(separator: ". ")
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ". ")

        return JourneyProgressSectionState(
            sectionTitle: copy.sectionTitle,
            rows: rows,
            connectHealthCTA: input.connectHealthCTA,
            accessibilitySummary: accessibilitySummary
        )
    }

    // MARK: - Rows

    private static func nutritionRow(
        stats: JourneyWeeklyStatsState,
        unlocks: JourneyUnlockPresentationState,
        copy: FormaProductCopy.Journey.Dashboard.Progress.Type
    ) -> JourneyProgressRowState {
        let value: String
        let status: JourneyProgressRowStatus

        if stats.mealsLogged == 0 {
            value = copy.notStarted
            status = .notStarted
        } else if unlocks.nutritionInsight {
            value = copy.ready
            status = .ready
        } else {
            value = copy.building
            status = .building
        }

        return JourneyProgressRowState(
            id: "nutrition",
            title: copy.nutritionTitle,
            value: value,
            status: status,
            accessibilityLabel: copy.rowAccessibility(title: copy.nutritionTitle, value: value)
        )
    }

    private static func weightTrendRow(
        stats: JourneyWeeklyStatsState,
        unlocks: JourneyUnlockPresentationState,
        unified: UnifiedWeeklyReviewState,
        copy: FormaProductCopy.Journey.Dashboard.Progress.Type
    ) -> JourneyProgressRowState {
        let value: String
        let status: JourneyProgressRowStatus

        if unlocks.weightTrend {
            if let change = unified.weightTrendBlock?.changeLabel
                ?? unified.weightTrendBlock?.weeklyChangeLabel {
                value = change
                status = .ready
            } else {
                value = copy.ready
                status = .ready
            }
        } else if stats.weighIns > 0 {
            value = copy.building
            status = .building
        } else {
            value = copy.building
            status = .building
        }

        return JourneyProgressRowState(
            id: "weight-trend",
            title: copy.weightTrendTitle,
            value: value,
            status: status,
            accessibilityLabel: copy.rowAccessibility(title: copy.weightTrendTitle, value: value)
        )
    }

    private static func trainingRow(
        stats: JourneyWeeklyStatsState,
        copy: FormaProductCopy.Journey.Dashboard.Progress.Type
    ) -> JourneyProgressRowState {
        let value: String
        let status: JourneyProgressRowStatus

        if stats.workouts == 0 {
            value = copy.notStarted
            status = .notStarted
        } else {
            value = copy.sessions(stats.workouts)
            status = .ready
        }

        return JourneyProgressRowState(
            id: "training",
            title: copy.trainingTitle,
            value: value,
            status: status,
            accessibilityLabel: copy.rowAccessibility(title: copy.trainingTitle, value: value)
        )
    }

    private static func recoveryRow(
        stats: JourneyWeeklyStatsState,
        unlocks: JourneyUnlockPresentationState,
        copy: FormaProductCopy.Journey.Dashboard.Progress.Type
    ) -> JourneyProgressRowState {
        let value: String
        let status: JourneyProgressRowStatus

        switch stats.recoveryAvailability {
        case .unavailable:
            value = copy.limitedData
            status = .limited
        case .partial(let days, let required):
            value = copy.buildingProgress(current: days, total: required)
            status = .building
        case .available:
            value = unlocks.recoveryBaseline ? copy.ready : copy.building
            status = unlocks.recoveryBaseline ? .ready : .building
        }

        return JourneyProgressRowState(
            id: "recovery",
            title: copy.recoveryTitle,
            value: value,
            status: status,
            accessibilityLabel: copy.rowAccessibility(title: copy.recoveryTitle, value: value)
        )
    }

    private static func stepsRow(
        stats: JourneyWeeklyStatsState,
        copy: FormaProductCopy.Journey.Dashboard.Progress.Type
    ) -> JourneyProgressRowState? {
        guard let averageSteps = stats.averageSteps, averageSteps > 0 else { return nil }

        let value = copy.averageSteps(averageSteps)
        return JourneyProgressRowState(
            id: "steps",
            title: copy.stepsTitle,
            value: value,
            status: .ready,
            accessibilityLabel: copy.rowAccessibility(title: copy.stepsTitle, value: value)
        )
    }

    private static func goalProjectionRow(
        goalProjection: JourneyGoalProjectionState,
        copy: FormaProductCopy.Journey.Dashboard.Progress.Type
    ) -> JourneyProgressRowState? {
        switch goalProjection.status {
        case .hidden, .insufficientData:
            return nil
        case .towardGoal(let title, _), .goalReached(let title, _):
            return JourneyProgressRowState(
                id: "goal-projection",
                title: copy.goalProjectionTitle,
                value: title,
                status: .ready,
                accessibilityLabel: copy.rowAccessibility(title: copy.goalProjectionTitle, value: title)
            )
        case .flatTrend(let title, _), .awayFromGoal(let title, _):
            return JourneyProgressRowState(
                id: "goal-projection",
                title: copy.goalProjectionTitle,
                value: title,
                status: .building,
                accessibilityLabel: copy.rowAccessibility(title: copy.goalProjectionTitle, value: title)
            )
        }
    }
}
