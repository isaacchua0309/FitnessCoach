//
//  TodayHealthIntelligenceSectionLoaderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayHealthIntelligenceSectionLoaderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        )
    }

    func testLoaderBuildsSectionFromSnapshotAndAvailability() async throws {
        let snapshot = makeSnapshot(on: referenceDay)
        let request = makeRequest()

        let result = try await TodayHealthIntelligenceSectionLoader.loadSection(
            request: request,
            snapshotProvider: TodayLoaderMockSnapshotService(snapshot: snapshot),
            healthDataRepository: TodayLoaderMockRepository(connected: true)
        )

        XCTAssertNotNil(result.sectionState)
        XCTAssertEqual(result.snapshot?.date, referenceDay)
        XCTAssertEqual(result.availability?.cachedDayCount, 1)
        XCTAssertEqual(result.analyticsContext.cachedDayCount, 1)
    }

    func testLoaderReturnsNilSectionWhenUIDisabled() async throws {
        var request = makeRequest()
        request.uiEnabled = false

        let result = try await TodayHealthIntelligenceSectionLoader.loadSection(
            request: request,
            snapshotProvider: TodayLoaderMockSnapshotService(snapshot: makeSnapshot(on: referenceDay)),
            healthDataRepository: TodayLoaderMockRepository(connected: true)
        )

        XCTAssertNil(result.sectionState)
    }

    func testFallbackSectionPreservesErrorAnalyticsContext() {
        let request = makeRequest()
        let fallback = TodayHealthIntelligenceSectionLoader.fallbackSection(
            request: request,
            errorMessage: "load_failed"
        )

        XCTAssertNotNil(fallback.sectionState)
        XCTAssertEqual(fallback.analyticsContext.explicitErrorMessage, "load_failed")
    }

    // MARK: - Helpers

    private func makeRequest() -> TodayHealthIntelligenceSectionLoader.LoadRequest {
        TodayHealthIntelligenceSectionLoader.LoadRequest(
            referenceDate: referenceDay,
            nutritionProgress: .unavailable,
            isAppleHealthConnected: true,
            trainingIntegrationState: .connected,
            connectionRecord: .empty,
            uiEnabled: true,
            syncPhase: nil,
            lastSuccessfulLocalSyncAt: nil,
            isRemoteSyncCapabilityEnabled: false,
            remoteSyncConsentDecision: .notDetermined,
            calendar: calendar
        )
    }

    private func makeSnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 74,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable after recent training.",
                recommendedTraining: "Train based on how you feel.",
                recommendedNutrition: "Stay on your usual plan.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_450, activeEnergyKcal: 420, exerciseMinutes: 38),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            nextBestAction: .none
        )
    }
}

// MARK: - Mocks

private final class TodayLoaderMockSnapshotService: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    let snapshot: HealthIntelligenceSnapshot?

    init(snapshot: HealthIntelligenceSnapshot?) {
        self.snapshot = snapshot
    }

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        snapshot
    }
}

private final class TodayLoaderMockRepository: HealthDataRepositorying, @unchecked Sendable {
    let connected: Bool

    init(connected: Bool) {
        self.connected = connected
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] { [] }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        .empty(for: date)
    }

    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] {
        []
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { [] }

    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] { [] }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }

    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] {
        []
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }

    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] {
        []
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: connected,
            permissionStatus: connected
                ? .uniform(.available, isHealthDataAvailable: true)
                : .uniform(.denied, isHealthDataAvailable: true),
            cachedDayCount: connected ? 1 : 0
        )
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: 0, refreshedAt: Date())
    }
}
