//
//  TestInfrastructureTests.swift
//  Fitness CoachTests
//
//  Sanity checks for shared test helpers.
//

import XCTest
@testable import Fitness_Coach

final class TestInfrastructureTests: XCTestCase {

    func testFakeClockNormalizesDateProvidingNowToStartOfDay() {
        var calendar = TestDateFixtures.utcCalendar()
        let raw = TestDateFixtures.day(year: 2026, month: 7, day: 4, hour: 15, calendar: calendar)
        let clock = FakeClock(now: raw, calendar: calendar)

        XCTAssertEqual(clock.now, calendar.startOfDay(for: raw))
        XCTAssertEqual(clock.now(), clock.now)
        XCTAssertEqual(clock.startOfDay(for: raw), calendar.startOfDay(for: raw))
    }

    func testFakeClockAdvanceDaysUpdatesNow() {
        let calendar = TestDateFixtures.utcCalendar()
        let clock = FakeClock(now: TestDateFixtures.referenceEpoch, calendar: calendar)
        let before = clock.now

        clock.advanceDays(3)

        XCTAssertEqual(
            calendar.dateComponents([.day], from: before, to: clock.now).day,
            3
        )
    }

    func testFakeUIDProviderIsMutable() {
        let provider = FakeUIDProvider(uid: "user-a")
        XCTAssertEqual(provider.currentUID, "user-a")

        provider.setUID("user-b")
        XCTAssertEqual(provider.asClosure()(), "user-b")
    }

    func testInMemorySwiftDataTestStoreCreatesContainer() throws {
        let store = try InMemorySwiftDataTestStore.makeStoreOnly()
        XCTAssertNotNil(store.modelContext)
    }

    func testWeeklyProgressFixturesRollingWeekSpan() {
        let calendar = WeeklyProgressFixtures.calendar
        let start = JourneyLogMetrics.rollingWeekStart(
            asOf: WeeklyProgressFixtures.asOf,
            calendar: calendar
        )
        let firstLog = WeeklyProgressFixtures.makeLog(daysAgo: 6, calories: 500)
        let lastLog = WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 500)

        XCTAssertEqual(calendar.startOfDay(for: firstLog.date), start)
        XCTAssertEqual(calendar.startOfDay(for: lastLog.date), calendar.startOfDay(for: WeeklyProgressFixtures.asOf))
    }

    func testCoachFoodFixturesChickenEntryHasMacros() {
        let entry = CoachFoodFixtures.chickenFoodEntry
        XCTAssertGreaterThan(entry.protein, 0)
        XCTAssertGreaterThan(entry.calories, 0)
    }
}
