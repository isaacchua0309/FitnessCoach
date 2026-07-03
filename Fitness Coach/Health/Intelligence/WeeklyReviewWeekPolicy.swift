//
//  WeeklyReviewWeekPolicy.swift
//  Fitness Coach
//
//  Forma — Calendar week boundaries for weekly review generation and caching.
//

import Foundation

enum WeeklyReviewWeekPolicy {

    /// Normalizes any date to the calendar week start used for cache keys.
    static func normalizedWeekStart(_ date: Date, calendar: Calendar) -> Date? {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            .map { calendar.startOfDay(for: $0) }
    }

    /// Last day (inclusive) of the calendar week containing `weekStart`.
    static func weekEndDate(forWeekStarting weekStart: Date, calendar: Calendar) -> Date? {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else {
            return nil
        }
        let endExclusive = interval.end
        return calendar.date(byAdding: .day, value: -1, to: endExclusive)
            .map { calendar.startOfDay(for: $0) }
    }

    /// A week is completed when the reference day is strictly after the week's last day.
    static func isWeekCompleted(
        weekStart: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let weekEnd = weekEndDate(forWeekStarting: weekStart, calendar: calendar) else {
            return false
        }
        return calendar.startOfDay(for: referenceDate) > calendar.startOfDay(for: weekEnd)
    }

    /// Most recent fully completed calendar week start relative to `referenceDate`.
    static func latestCompletedWeekStart(
        referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        let day = calendar.startOfDay(for: referenceDate)
        guard let currentWeekStart = normalizedWeekStart(day, calendar: calendar) else {
            return nil
        }

        if isWeekCompleted(weekStart: currentWeekStart, referenceDate: day, calendar: calendar) {
            return currentWeekStart
        }

        return calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)
            .map { calendar.startOfDay(for: $0) }
    }

    static func weekStartMatches(_ review: WeeklyHealthReview, weekStart: Date, calendar: Calendar) -> Bool {
        guard let normalized = normalizedWeekStart(weekStart, calendar: calendar) else {
            return false
        }
        guard let reviewStart = normalizedWeekStart(review.weekStartDate, calendar: calendar) else {
            return false
        }
        return calendar.isDate(reviewStart, inSameDayAs: normalized)
    }
}
