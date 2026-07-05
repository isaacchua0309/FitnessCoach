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
            formattedFinishDate(date, calendar: calendar)
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

    private static func formattedFinishDate(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        guard let day = components.day,
              let month = components.month,
              let year = components.year,
              (1...12).contains(month) else {
            return formattedMonthYearFallback(date, calendar: calendar)
        }

        let monthName = calendar.monthSymbols[month - 1]
        return "\(day) \(monthName) \(year)"
    }

    private static func formattedMonthYearFallback(_ date: Date, calendar: Calendar) -> String {
        var format = Date.FormatStyle(date: .abbreviated, time: .omitted)
            .day()
            .month(.wide)
            .year()
            .locale(.autoupdatingCurrent)
        format.calendar = calendar
        return date.formatted(format)
    }
}
