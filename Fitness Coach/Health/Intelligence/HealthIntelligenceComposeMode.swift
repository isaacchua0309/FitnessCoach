//
//  HealthIntelligenceComposeMode.swift
//  Fitness Coach
//
//  Forma — Snapshot composition modes for Health Intelligence.
//

import Foundation

enum HealthIntelligenceComposeMode: Equatable, Sendable {
    /// Standard Today snapshot. Weekly review is included on calendar week-end days when data allows.
    case today
    /// Caller explicitly requests weekly review synthesis.
    case weeklyReview
    /// Lightweight preview snapshot with reduced weekly synthesis work.
    case preview
}

enum HealthIntelligenceComposeModePolicy {

    static func shouldIncludeWeeklyReview(
        mode: HealthIntelligenceComposeMode,
        targetDate: Date,
        hasEnoughWeeklyActivity: Bool,
        calendar: Calendar
    ) -> Bool {
        switch mode {
        case .weeklyReview:
            return hasEnoughWeeklyActivity
        case .preview:
            return false
        case .today:
            guard hasEnoughWeeklyActivity else { return false }
            return isCalendarWeekEndingDay(targetDate, calendar: calendar)
        }
    }

    static func isCalendarWeekEndingDay(_ date: Date, calendar: Calendar) -> Bool {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return false
        }
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? date
        return calendar.isDate(date, inSameDayAs: lastDay)
    }
}
