//
//  WeightFixtures.swift
//  Fitness CoachTests
//
//  Deterministic weight entries for Journey and weekly progress tests.
//

import Foundation
@testable import Fitness_Coach

enum WeightFixtures {

    static var referenceDate: Date { TestDateFixtures.referenceEpoch }

    static var calendar: Calendar {
        TestDateFixtures.utcCalendar(firstWeekday: 2)
    }

    static func entry(
        daysAgo: Int,
        kg: Double,
        asOf: Date = referenceDate,
        calendar: Calendar = calendar,
        note: String? = nil
    ) -> WeightEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return WeightEntry(
            id: UUID(),
            date: date,
            weightKg: kg,
            note: note,
            createdAt: date
        )
    }

    /// Seven-day downward trend ending at `asOf` (one entry per day).
    static func weekLossTrend(
        startKg: Double = 72.0,
        dailyDeltaKg: Double = 0.2,
        asOf: Date = referenceDate,
        calendar: Calendar = calendar
    ) -> [WeightEntry] {
        (0..<7).map { offset in
            entry(
                daysAgo: 6 - offset,
                kg: startKg - (Double(offset) * dailyDeltaKg),
                asOf: asOf,
                calendar: calendar
            )
        }
    }
}
