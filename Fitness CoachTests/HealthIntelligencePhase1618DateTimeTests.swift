//
//  HealthIntelligencePhase1618DateTimeTests.swift
//  Fitness CoachTests
//
//  Phase 16–18 — Local day boundaries, timezone shifts, and cross-midnight workouts.
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligencePhase1618DateTimeTests: XCTestCase {

    // MARK: - Local day boundary

    func testLocalDateStringUsesStartOfDayWithinSameCalendarDay() {
        let calendar = HealthIntelligencePhase1618TestSupport.makeCalendar()
        let day = HealthIntelligencePhase1618TestSupport.referenceDay(calendar: calendar)
        let lateEvening = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)!
        let earlyMorning = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))!

        XCTAssertEqual(
            HealthSummarySyncFormatting.localDateString(from: lateEvening, calendar: calendar),
            "2026-07-03"
        )
        XCTAssertEqual(
            HealthSummarySyncFormatting.localDateString(from: earlyMorning, calendar: calendar),
            "2026-07-04"
        )
    }

    func testDailyDocumentIDMatchesLocalDateStringAtDayBoundary() {
        let calendar = HealthIntelligencePhase1618TestSupport.makeCalendar()
        let day = HealthIntelligencePhase1618TestSupport.referenceDay(calendar: calendar)
        let lateEvening = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)!

        let localDate = HealthSummarySyncFormatting.localDateString(from: lateEvening, calendar: calendar)
        let documentID = HealthSummarySyncDocumentID.daily(localDate: lateEvening, calendar: calendar)

        XCTAssertEqual(documentID, localDate)
        XCTAssertEqual(documentID, "2026-07-03")
    }

    // MARK: - Timezone shift

    func testLocalDateStringChangesWhenTimezoneCrossesMidnight() {
        let utcCalendar = HealthIntelligencePhase1618TestSupport.makeCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
        var pacificCalendar = Calendar(identifier: .gregorian)
        pacificCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let instant = utcCalendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 3,
            hour: 2,
            minute: 0
        ))!

        let utcDate = HealthSummarySyncFormatting.localDateString(from: instant, calendar: utcCalendar)
        let pacificDate = HealthSummarySyncFormatting.localDateString(from: instant, calendar: pacificCalendar)

        XCTAssertEqual(utcDate, "2026-07-03")
        XCTAssertEqual(pacificDate, "2026-07-02")
        XCTAssertNotEqual(utcDate, pacificDate)
    }

    func testWorkoutPayloadLocalDateUsesMappingCalendarTimezone() {
        let utcCalendar = HealthIntelligencePhase1618TestSupport.makeCalendar(timeZone: TimeZone(secondsFromGMT: 0)!)
        var easternCalendar = Calendar(identifier: .gregorian)
        easternCalendar.timeZone = TimeZone(identifier: "America/New_York")!

        let day = utcCalendar.startOfDay(for: HealthIntelligencePhase1618TestSupport.referenceDay(calendar: utcCalendar))
        let start = utcCalendar.date(bySettingHour: 3, minute: 0, second: 0, of: day)!
        let end = utcCalendar.date(byAdding: .minute, value: 45, to: start)!
        let workout = NormalizedWorkout(
            id: UUID(),
            category: .running,
            activityLabel: "Early run",
            startDate: start,
            endDate: end,
            durationMinutes: 45,
            activeEnergyKcal: 300,
            sourceName: "Apple Watch"
        )

        let utcContext = HealthSummaryRemoteSyncTestSupport.makeMappingContext(calendar: utcCalendar)
        let easternContext = HealthSummaryRemoteSyncTestSupport.makeMappingContext(calendar: easternCalendar)

        let utcPayload = HealthWorkoutSummarySyncPayload.make(from: workout, context: utcContext)
        let easternPayload = HealthWorkoutSummarySyncPayload.make(from: workout, context: easternContext)

        XCTAssertEqual(utcPayload.localDate, "2026-07-03")
        XCTAssertEqual(easternPayload.localDate, "2026-07-02")
        XCTAssertNotEqual(utcPayload.localDate, easternPayload.localDate)
    }

    // MARK: - Workout crossing midnight

    func testCrossMidnightWorkoutGroupsOnStartLocalDayForDailyPayload() {
        let calendar = HealthIntelligencePhase1618TestSupport.makeCalendar()
        let day = HealthIntelligencePhase1618TestSupport.referenceDay(calendar: calendar)
        let workout = HealthIntelligencePhase1618TestSupport.crossMidnightWorkout(startingOn: day, calendar: calendar)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!

        let startDayMatches = HealthSummarySyncFormatting.workouts(onLocalDay: day, from: [workout], calendar: calendar)
        let endDayMatches = HealthSummarySyncFormatting.workouts(onLocalDay: nextDay, from: [workout], calendar: calendar)

        XCTAssertEqual(startDayMatches.count, 1)
        XCTAssertTrue(endDayMatches.isEmpty)
    }

    func testCrossMidnightWorkoutGroupsOnStartDayInJourneyHistory() {
        let calendar = HealthIntelligencePhase1618TestSupport.makeCalendar()
        let day = HealthIntelligencePhase1618TestSupport.referenceDay(calendar: calendar)
        let workout = HealthIntelligencePhase1618TestSupport.crossMidnightWorkout(startingOn: day, calendar: calendar)

        let history = JourneyHealthIntelligencePresentationBuilder.workoutHistory(
            from: [
                JourneyHealthIntelligenceWorkoutRecordInput(
                    id: workout.id.uuidString,
                    date: workout.startDate,
                    title: "Late run",
                    durationMinutes: workout.durationMinutes,
                    activeCalories: Int(workout.activeEnergyKcal),
                    demand: .moderate,
                    intensity: .moderate
                )
            ],
            healthConnection: .connected,
            calendar: calendar
        )

        XCTAssertEqual(history.phase, .loaded)
        XCTAssertEqual(history.groups.count, 1)
        XCTAssertEqual(history.groups.first?.items.count, 1)
        XCTAssertEqual(
            HealthSummarySyncFormatting.localDateString(from: history.groups.first!.date, calendar: calendar),
            "2026-07-03"
        )
    }

    func testCrossMidnightWorkoutDailySummaryIncludesWorkoutOnlyOnStartDay() {
        let calendar = HealthIntelligencePhase1618TestSupport.makeCalendar()
        let day = HealthIntelligencePhase1618TestSupport.referenceDay(calendar: calendar)
        let workout = HealthIntelligencePhase1618TestSupport.crossMidnightWorkout(startingOn: day, calendar: calendar)
        let context = HealthIntelligencePhase1618TestSupport.makeMappingContext(calendar: calendar)

        let startDayMetrics = DailyHealthMetrics(date: day, steps: 6_000, activeEnergyKcal: 300, exerciseMinutes: 25)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let nextDayMetrics = DailyHealthMetrics(date: nextDay, steps: 7_000, activeEnergyKcal: 320, exerciseMinutes: 30)

        let startPayload = HealthDailySummarySyncPayload.make(
            from: startDayMetrics,
            workouts: [workout],
            context: context
        )
        let nextPayload = HealthDailySummarySyncPayload.make(
            from: nextDayMetrics,
            workouts: [workout],
            context: context
        )

        XCTAssertEqual(startPayload.workoutCount, 1)
        XCTAssertEqual(nextPayload.workoutCount, 0)
    }
}
