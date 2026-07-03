//
//  PlanEditSaveSuccessBuilder.swift
//  Fitness Coach
//
//  Forma — Save confirmation copy for Edit Plan.
//

import Foundation

struct PlanEditSaveSuccessState: Equatable, Sendable {
    let title: String
    let trackLine: String
    let todayLine: String
    let accessibilitySummary: String
}

enum PlanEditSaveSuccessBuilder {

    /// Brief display before the wizard dismisses after a successful save.
    static let displayDurationNanoseconds: UInt64 = 1_200_000_000

    static func build(
        projection: PlanProjection,
        calendar: Calendar = .current
    ) -> PlanEditSaveSuccessState {
        let copy = FormaProductCopy.PlanEditSave.self
        let trackLine = trackLine(for: projection, calendar: calendar, copy: copy)

        return PlanEditSaveSuccessState(
            title: copy.planUpdatedTitle,
            trackLine: trackLine,
            todayLine: copy.todayTargetsRegenerated,
            accessibilitySummary: [
                copy.planUpdatedTitle,
                trackLine,
                copy.todayTargetsRegenerated
            ].joined(separator: " ")
        )
    }

    private static func trackLine(
        for projection: PlanProjection,
        calendar: Calendar,
        copy: FormaProductCopy.PlanEditSave.Type
    ) -> String {
        if projection.goalDirection == .maintain {
            return copy.onTrackMaintaining
        }

        if let completionDate = projection.estimatedCompletionDate {
            let formatted = formattedMonthYear(completionDate, calendar: calendar)
            return copy.onTrackForGoal(projection.goalLabel, by: formatted)
        }

        return copy.onTrackForGoalOnly(projection.goalLabel)
    }

    private static func formattedMonthYear(_ date: Date, calendar: Calendar) -> String {
        var format = Date.FormatStyle(date: .abbreviated, time: .omitted)
            .month(.wide)
            .year()
            .locale(.autoupdatingCurrent)
        format.calendar = calendar
        return date.formatted(format)
    }
}
