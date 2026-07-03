//
//  PlanEditTimelineCopy.swift
//  Fitness Coach
//
//  Forma — Goal timeline formatting for Edit Plan.
//

import Foundation

enum PlanEditTimelineCopy {

    static func estimatedFinishLabel(for date: Date, calendar: Calendar = .current) -> String {
        FormaProductCopy.PlanEditHero.estimatedFinish(
            formattedMonthYear(date, calendar: calendar)
        )
    }

    static func monthYearDisplay(fromCompletionLabel label: String?) -> String? {
        guard let label else { return nil }

        var trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Estimated finish: ",
            "On track for "
        ]
        for prefix in prefixes where trimmed.hasPrefix(prefix) {
            trimmed = String(trimmed.dropFirst(prefix.count))
            break
        }
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "."))
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
