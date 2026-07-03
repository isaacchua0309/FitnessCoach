//
//  HealthSummarySyncPayloadMapperTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for remote Health Summary Sync payload mappers.
//

import Foundation
import XCTest
@testable import Fitness_Coach

final class HealthSummarySyncPayloadMapperTests: XCTestCase {

    private var calendar: Calendar!
    private var context: HealthSummarySyncMappingContext!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        self.calendar = calendar
        context = HealthSummarySyncMappingContext(
            userId: "test-user-id",
            calendar: calendar,
            generatedAt: ISO8601DateFormatter().date(from: "2026-07-03T15:30:00Z")!,
            source: .appleHealth
        )
    }

    func testDailySummaryPayloadUsesDeterministicDocumentID() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let metrics = DailyHealthMetrics(
            date: day,
            steps: 8450,
            activeEnergyKcal: 420,
            exerciseMinutes: 38
        )
        let workout = makeWorkout(on: day)

        let payload = HealthDailySummarySyncPayload.make(
            from: metrics,
            dayWorkouts: [workout],
            context: context
        )

        XCTAssertEqual(payload.id, "2026-07-03")
        XCTAssertEqual(payload.localDate, "2026-07-03")
        XCTAssertEqual(payload.timezone, "America/Los_Angeles")
        XCTAssertEqual(payload.workoutCount, 1)
        XCTAssertEqual(payload.totalWorkoutMinutes, 50)
        XCTAssertEqual(payload.totalWorkoutActiveEnergyKcal, 320)
        XCTAssertEqual(payload.source, .appleHealth)
        XCTAssertEqual(payload.schemaVersion, HealthSummarySyncSchemaVersion.current)
        XCTAssertTrue(payload.firestorePath.contains("healthDaily/2026-07-03"))
    }

    func testDailySummaryPayloadNullsMissingSignals() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let metrics = DailyHealthMetrics(date: day, steps: 0, activeEnergyKcal: 0, exerciseMinutes: 0)

        let payload = HealthDailySummarySyncPayload.make(
            from: metrics,
            dayWorkouts: [],
            context: context,
            missingSignals: [.steps, .activeEnergy, .exerciseMinutes]
        )

        XCTAssertNil(payload.steps)
        XCTAssertNil(payload.activeEnergyKcal)
        XCTAssertNil(payload.exerciseMinutes)
    }

    func testWorkoutSummaryPayloadUsesStableWorkoutID() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let workout = makeWorkout(on: day)

        let payload = HealthWorkoutSummarySyncPayload.make(from: workout, context: context)

        XCTAssertEqual(payload.id, payload.workoutId)
        XCTAssertEqual(payload.id, workout.id.uuidString.lowercased())
        XCTAssertEqual(payload.type, "running")
        XCTAssertEqual(payload.category, "running")
        XCTAssertEqual(payload.sourceAppName, "Apple Watch")
        XCTAssertTrue(payload.firestorePath.contains("healthWorkouts/"))
    }

    func testWorkoutSummaryPayloadOmitsUnsafeSourceAppName() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        var workout = makeWorkout(on: day)
        workout = NormalizedWorkout(
            id: workout.id,
            category: workout.category,
            activityLabel: workout.activityLabel,
            startDate: workout.startDate,
            endDate: workout.endDate,
            durationMinutes: workout.durationMinutes,
            activeEnergyKcal: workout.activeEnergyKcal,
            sourceName: "com.apple.health.UDID-12345"
        )

        let payload = HealthWorkoutSummarySyncPayload.make(from: workout, context: context)

        XCTAssertNil(payload.sourceAppName)
    }

    func testRecoverySummaryPayloadSanitizesContributingFactors() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let recovery = RecoverySummary(
            score: 78,
            status: .ready,
            title: "Ready",
            explanation: "HRV is 42 ms below baseline",
            recommendedTraining: "Go easy",
            recommendedNutrition: "Protein",
            confidence: .high,
            contributingFactors: [
                RecoveryContributingFactor(
                    signal: .sleep,
                    impact: .positive,
                    detail: "8h sleep with 42 ms HRV"
                )
            ],
            missingSignals: []
        )

        let payload = RecoverySummarySyncPayload.make(
            from: recovery,
            date: day,
            context: context
        )

        XCTAssertEqual(payload.score, 78)
        XCTAssertNil(payload.scoreBucket)
        XCTAssertEqual(payload.contributingFactors.count, 1)
        XCTAssertEqual(payload.contributingFactors[0].signal, "sleep")
        XCTAssertEqual(payload.contributingFactors[0].impact, "positive")
        XCTAssertFalse(payload.contributingFactors[0].signal.contains("detail"))
    }

    func testRecoverySummaryPayloadUsesScoreBucketWhenScoreWithheld() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let recovery = RecoverySummary(
            score: 55,
            status: .moderate,
            title: "Moderate",
            explanation: "Limited data",
            recommendedTraining: "Moderate",
            recommendedNutrition: "Stay steady",
            confidence: .low,
            contributingFactors: [],
            missingSignals: [.sleep, .hrv, .restingHeartRate]
        )

        let payload = RecoverySummarySyncPayload.make(
            from: recovery,
            date: day,
            context: context
        )

        XCTAssertNil(payload.score)
        XCTAssertEqual(payload.scoreBucket, "moderate")
    }

    func testWeeklyReviewPayloadSanitizesTextFields() {
        let referenceDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        guard let weekStart = WeeklyReviewWeekPolicy.normalizedWeekStart(referenceDay, calendar: calendar),
              let weekEnd = WeeklyReviewWeekPolicy.weekEndDate(forWeekStarting: weekStart, calendar: calendar) else {
            XCTFail("Expected valid week boundaries")
            return
        }
        let review = WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Week",
            summary: "Summary",
            stats: WeeklyStats(
                totalWorkouts: 4,
                totalWorkoutMinutes: 180,
                totalActiveCalories: 900,
                averageSteps: 8000,
                totalSteps: 56000,
                proteinHitDays: 5,
                calorieTargetHitDays: 4,
                waterHitDays: 6,
                averageRecoveryScore: 72,
                lowRecoveryDays: 1,
                weightChangeKg: -0.4,
                loggingConsistencyDays: 7
            ),
            wins: ["Strong workout consistency", "HRV improved 12 ms"],
            risks: ["Sleep dipped below baseline"],
            nextWeekFocus: ["Prioritize recovery"],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: context.generatedAt
        )

        let payload = WeeklyHealthReviewSyncPayload.make(from: review, context: context)

        XCTAssertNotNil(payload)
        XCTAssertEqual(
            payload?.id,
            HealthSummarySyncDocumentID.weeklyReview(weekStart: weekStart, calendar: calendar)
        )
        XCTAssertEqual(payload?.aggregateStats.totalWorkouts, 4)
        XCTAssertEqual(payload?.wins.count, 1)
        XCTAssertEqual(payload?.wins.first, "Strong workout consistency")
        XCTAssertTrue(payload?.risks.isEmpty == true)
    }

    func testMetadataPayloadMapsSyncStateAndPermissions() {
        let permission = HealthPermissionStatus.uniform(
            .available,
            isHealthDataAvailable: true,
            signals: HealthSignalKind.required,
            resolvedAt: context.generatedAt
        )
        let syncState = HealthSyncState(
            phase: .succeeded,
            trigger: .manual,
            progress: .zero,
            signalResults: [],
            lastSuccessfulSyncAt: context.generatedAt,
            lastError: nil,
            updatedAt: context.generatedAt
        )

        let payload = HealthSyncMetadataPayload.make(
            from: syncState,
            permissionStatus: permission,
            cachedDayCount: 42,
            context: context,
            syncWindowDays: 90,
            appVersion: "1.4.0 (42)"
        )

        XCTAssertEqual(payload.id, "current")
        XCTAssertEqual(payload.clientSchemaVersion, HealthSummarySyncSchemaVersion.clientMapperVersion)
        XCTAssertEqual(payload.syncWindowDays, 90)
        XCTAssertEqual(payload.appVersion, "1.4.0 (42)")
        XCTAssertEqual(payload.healthPermissionSummary.connectionLevel, "connected")
        XCTAssertEqual(payload.healthPermissionSummary.cachedDayCount, 42)
        XCTAssertEqual(payload.lastSyncPhase, "succeeded")
    }

    func testPayloadsRoundTripThroughJSON() throws {
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        let metrics = DailyHealthMetrics(date: day, steps: 1000, activeEnergyKcal: 100, exerciseMinutes: 10)
        let daily = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: context)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        let data = try encoder.encode(daily)
        let decoded = try decoder.decode(HealthDailySummarySyncPayload.self, from: data)

        XCTAssertEqual(decoded, daily)
        XCTAssertEqual(decoded.source.rawValue, "apple_health")
    }

    // MARK: - Helpers

    private func makeWorkout(on day: Date) -> NormalizedWorkout {
        let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
        let end = calendar.date(byAdding: .minute, value: 50, to: start)!
        return NormalizedWorkout(
            id: HealthStableIdentifier.workoutID(
                sourceName: "Apple Watch",
                startDate: start,
                endDate: end,
                durationMinutes: 50,
                category: .running
            ),
            category: .running,
            activityLabel: "Running",
            startDate: start,
            endDate: end,
            durationMinutes: 50,
            activeEnergyKcal: 320,
            sourceName: "Apple Watch"
        )
    }
}
