//
//  TestDateFixtures.swift
//  Fitness CoachTests
//
//  Canonical fixed dates and UTC calendars for deterministic tests.
//

import Foundation

enum TestDateFixtures {

    /// Stable epoch used across profile, plan, journey, and coach builder tests.
    static let referenceEpoch = Date(timeIntervalSince1970: 1_700_000_000)

    /// SwiftData migration and entity seeding anchor (mid-2026, noon UTC).
    static let migrationAnchor: Date = {
        utcCalendar().date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
    }()

    /// Health Intelligence weekly-review pipeline anchor (completed week context).
    static let weeklyReviewReference: Date = {
        utcCalendar().date(from: DateComponents(year: 2026, month: 7, day: 8, hour: 12))!
    }()

    /// Coach context packet compaction default day.
    static let coachContextAnchor: Date = {
        utcCalendar().date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 12))!
    }()

    static func utcCalendar(
        firstWeekday: Int = 1,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = firstWeekday
        calendar.locale = locale
        return calendar
    }

    static func day(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        calendar: Calendar = utcCalendar()
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static func daysAgo(_ count: Int, from anchor: Date, calendar: Calendar = utcCalendar()) -> Date {
        calendar.date(byAdding: .day, value: -count, to: anchor)!
    }
}
