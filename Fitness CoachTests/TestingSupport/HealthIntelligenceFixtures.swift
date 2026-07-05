//
//  HealthIntelligenceFixtures.swift
//  Fitness CoachTests
//
//  Deterministic dates, calendars, and plan snapshots for HI tests.
//

import Foundation
@testable import Fitness_Coach

enum HealthIntelligenceFixtures {

    static var calendar: Calendar { TestDateFixtures.utcCalendar() }

    static var pipelineWeekDay: Date {
        TestDateFixtures.day(year: 2026, month: 7, day: 8, hour: 14, calendar: calendar)
    }

    static var weeklyReviewReference: Date { TestDateFixtures.weeklyReviewReference }

    static func day(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        calendar: Calendar = calendar
    ) -> Date {
        TestDateFixtures.day(year: year, month: month, day: day, hour: hour, calendar: calendar)
    }

    static func defaultPlan() -> HealthIntelligenceUserPlanSnapshot {
        HealthIntelligenceUserPlanSnapshot(
            goal: .maintain,
            calorieTarget: 2_200,
            proteinTargetGrams: 150,
            waterTargetMl: 2_500
        )
    }
}
