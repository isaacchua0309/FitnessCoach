//
//  TestFixtureFactory.swift
//  Fitness CoachTests
//
//  Central entry point for composing deterministic test fixtures and harnesses.
//

import Foundation
@testable import Fitness_Coach

enum TestFixtureFactory {

    static var referenceDate: Date { TestDateFixtures.referenceEpoch }

    // MARK: - Clocks and identity

    static func clock(
        at date: Date = TestDateFixtures.referenceEpoch,
        calendar: Calendar = TestDateFixtures.utcCalendar(),
        normalizeToStartOfDay: Bool = true
    ) -> FakeClock {
        FakeClock(
            now: date,
            calendar: calendar,
            normalizeToStartOfDay: normalizeToStartOfDay
        )
    }

    static func uid(_ value: String = "test-user-a") -> FakeUIDProvider {
        FakeUIDProvider(uid: value)
    }

    // MARK: - SwiftData

    @MainActor
    static func inMemoryStore(
        referenceNow: Date = referenceDate,
        calendar: Calendar = TestDateFixtures.utcCalendar()
    ) throws -> (store: SwiftDataStore, clock: FakeClock) {
        try InMemorySwiftDataTestStore.makeStore(referenceNow: referenceNow, calendar: calendar)
    }

    @MainActor
    static func dailyLogHarness(
        referenceNow: Date = DailyLogFixtures.referenceDate,
        ownerUID: String? = nil
    ) throws -> DailyLogServiceTestSupport.Harness {
        try DailyLogServiceTestSupport.makeHarness(referenceNow: referenceNow, ownerUID: ownerUID)
    }

    // MARK: - Nutrition scenarios

    static func nutritionLog(
        _ scenario: DailyLogFixtures.NutritionScenario = .baseline
    ) -> DailyLog {
        DailyLogFixtures.log(for: scenario)
    }

    static func allNutritionScenarioLogs() -> [DailyLog] {
        DailyLogFixtures.NutritionScenario.allCases.map(DailyLogFixtures.log(for:))
    }

    // MARK: - Journey / weekly progress

    static func rollingWeekLogs(
        daysAgoRange: ClosedRange<Int> = 0...6,
        asOf: Date = WeeklyProgressFixtures.asOf,
        calendar: Calendar = WeeklyProgressFixtures.calendar
    ) -> [DailyLog] {
        daysAgoRange.map {
            DailyLogFixtures.rollingWeekLog(daysAgo: $0, asOf: asOf, calendar: calendar)
        }
    }

    // MARK: - Health Intelligence

    static func healthIntelligenceHarness(
        clockDay: Date = HealthIntelligenceFixtures.pipelineWeekDay,
        calendar: Calendar = HealthIntelligenceFixtures.calendar,
        dependencies: HealthIntelligenceEngineDependencies = .production()
    ) -> HealthIntelligencePipelineTestHarness {
        HealthIntelligencePipelineTestHarness(
            calendar: calendar,
            clockDay: clockDay,
            dependencies: dependencies
        )
    }
}
