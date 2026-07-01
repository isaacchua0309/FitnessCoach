//
//  PlanWeekPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Display formatting for the Plan "This Week" section.
//

import Foundation

enum PlanWeekPresentationBuilder {

    static func applyPresentation(
        to week: PlanWeekState,
        training: JourneyWeeklyTrainingStatus,
        goalDirection: JourneyGoalDirection
    ) -> PlanWeekState {
        var updated = week
        let copy = FormaProductCopy.PlanMissionControl.self

        updated.caloriesLine = copy.weekDayAdherence(
            "Calories",
            achieved: week.calorieAdherence.achieved,
            total: week.calorieAdherence.eligible
        )
        updated.proteinLine = copy.weekDayAdherence(
            "Protein",
            achieved: week.proteinAdherence.achieved,
            total: week.proteinAdherence.eligible
        )
        updated.waterLine = copy.weekDayAdherence(
            "Water",
            achieved: week.waterAdherence.achieved,
            total: week.waterAdherence.eligible
        )
        updated.trainingLine = trainingLine(
            achieved: week.trainingDays,
            expected: week.expectedTrainingDays,
            training: training
        )
        updated.weightLine = weightLine(
            delta: week.weightChangeKg,
            goalDirection: goalDirection
        )
        updated.accessibilitySummary = accessibilitySummary(for: updated)
        return updated
    }

    static func trainingLine(
        achieved: Int,
        expected: Int,
        training: JourneyWeeklyTrainingStatus
    ) -> String {
        switch training {
        case .locked:
            return FormaProductCopy.PlanMissionControl.weekTrainingConnectHealth
        case .hidden, .connectedEmpty, .connected:
            guard expected > 0 else {
                return FormaProductCopy.PlanMissionControl.weekTrainingUnavailable
            }
            return FormaProductCopy.PlanMissionControl.weekTrainingSessions(
                achieved: achieved,
                expected: expected
            )
        }
    }

    static func weightLine(
        delta: Double?,
        goalDirection: JourneyGoalDirection
    ) -> String {
        guard let formatted = formattedWeightValue(delta, goalDirection: goalDirection) else {
            return FormaProductCopy.PlanMissionControl.weekWeightUnavailable
        }
        return "Weight: \(formatted)"
    }

    static func formatWeightDelta(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta)) kg"
    }

    static func formattedWeightValue(
        _ delta: Double?,
        goalDirection: JourneyGoalDirection
    ) -> String? {
        guard let delta else { return nil }

        let journeyFormatted = JourneyWeeklyReviewBuilder.formattedWeightDelta(
            delta,
            goalDirection: goalDirection,
            unavailableCopy: ""
        )
        guard !journeyFormatted.isEmpty else { return nil }

        if journeyFormatted.contains("kg") {
            return journeyFormatted.replacingOccurrences(of: "kg", with: " kg")
        }
        return journeyFormatted
    }

    static func accessibilitySummary(for week: PlanWeekState) -> String {
        if week.showsEmptyState, let emptyStateCopy = week.emptyStateCopy {
            return [week.sectionTitle, emptyStateCopy].joined(separator: ". ")
        }

        return [
            week.sectionTitle,
            week.caloriesLine,
            week.proteinLine,
            week.waterLine,
            week.trainingLine,
            week.weightLine,
            week.overallHeadline,
            week.overallStatusCopy
        ].joined(separator: ". ")
    }
}
