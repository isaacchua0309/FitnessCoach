//
//  HealthIntelligenceSectionLoaderCoreTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceSectionLoaderCoreTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
    }

    func testSnapshotPromptsConnectHealthWhenNextBestActionRequiresConnection() {
        let snapshot = makeSnapshot(
            on: referenceDay,
            nextBestAction: NextBestAction(
                id: "connect-health",
                title: "Connect Apple Health",
                message: "",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )

        XCTAssertTrue(HealthIntelligenceSectionLoaderCore.snapshotPromptsConnectHealth(snapshot))
    }

    func testJourneyHealthConnectionReturnsNotConnectedWhenSnapshotPromptsConnectHealth() {
        let snapshot = makeSnapshot(
            on: referenceDay,
            nextBestAction: NextBestAction(
                id: "connect-health",
                title: "Connect Apple Health",
                message: "",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
        let availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 1
        )

        let connection = HealthIntelligenceSectionLoaderCore.journeyHealthConnection(
            isAppleHealthConnected: true,
            availability: availability,
            todaySnapshot: snapshot
        )

        XCTAssertEqual(connection, .notConnected)
    }

    func testJourneyHealthConnectionReturnsConnectedWhenReadableSignalsExist() {
        let availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 2
        )

        let connection = HealthIntelligenceSectionLoaderCore.journeyHealthConnection(
            isAppleHealthConnected: false,
            availability: availability,
            todaySnapshot: makeSnapshot(on: referenceDay)
        )

        XCTAssertEqual(connection, .connected)
    }

    func testShouldShowConnectOnlySectionForUnavailablePermissionStates() {
        let uiState = HealthIntelligenceUIState(
            kind: .noHealthPermission,
            title: "Connect Apple Health",
            message: "Permission needed",
            primaryActionTitle: "Connect",
            secondaryActionTitle: nil,
            primaryAction: .connectAppleHealth,
            secondaryAction: .none,
            severity: .warning,
            canShowInsight: false,
            confidenceLabel: nil,
            missingSignals: [],
            fallbackReason: .permissionsRequired
        )

        XCTAssertTrue(
            HealthIntelligenceSectionLoaderCore.shouldShowConnectOnlySection(uiState: uiState)
        )
    }

    func testLoadTodaySnapshotAndAvailabilityReturnsParallelResults() async {
        let snapshot = makeSnapshot(on: referenceDay)
        let snapshotProvider = CoreMockSnapshotService(snapshot: snapshot)
        let repository = CoreMockRepository(connected: true)

        let result = await HealthIntelligenceSectionLoaderCore.loadTodaySnapshotAndAvailability(
            referenceDate: referenceDay,
            snapshotProvider: snapshotProvider,
            healthDataRepository: repository,
            calendar: calendar
        )

        XCTAssertEqual(result.snapshot?.date, referenceDay)
        XCTAssertTrue(result.availability.isHealthDataAvailable)
        XCTAssertEqual(result.availability.cachedDayCount, 1)
    }

    func testLoadWeeklyReviewUsesGenerateWhenForceRefreshEnabled() async {
        let weeklyReviewService = CoreMockWeeklyReviewService()
        weeklyReviewService.latestReview = makeWeeklyReview()

        _ = await HealthIntelligenceSectionLoaderCore.loadWeeklyReview(
            referenceDate: referenceDay,
            provider: weeklyReviewService,
            forceRefresh: true,
            calendar: calendar
        )

        XCTAssertEqual(weeklyReviewService.generateCallCount, 1)
        XCTAssertTrue(weeklyReviewService.lastForceRefresh)
    }

    // MARK: - Section loading classification

    func testClassifySectionLoadingReturnsDisabledWhenUIEnabledIsFalse() {
        let result = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
            from: HealthIntelligenceSectionLoadingInput(isUIEnabled: false)
        )

        XCTAssertEqual(result.availability, .disabled)
        XCTAssertFalse(result.shouldShowSection)
        XCTAssertNil(result.staleDataLabel)
        XCTAssertNil(result.partialSignalsLabel)
        XCTAssertNil(result.unavailableReason)
    }

    func testClassifySectionLoadingReturnsLoadingWhenSnapshotLoadInProgress() {
        let result = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
            from: HealthIntelligenceSectionLoadingInput(
                isUIEnabled: true,
                isLoading: true
            )
        )

        XCTAssertEqual(result.availability, .loading)
        XCTAssertTrue(result.shouldShowSection)
    }

    func testClassifySectionLoadingReturnsLoadingWhenSyncPhaseIsSyncing() {
        let result = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
            from: HealthIntelligenceSectionLoadingInput(
                isUIEnabled: true,
                syncPhase: .syncing
            )
        )

        XCTAssertEqual(result.availability, .loading)
        XCTAssertTrue(result.shouldShowSection)
    }

    func testCharacterizationFixtureA_ClassifiesReadyAcrossSurfaces() {
        for surface in [HealthIntelligenceSurface.today, .plan, .journey] {
            let result = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
                from: HealthIntelligencePresentationCharacterizationFixtures.sectionLoadingInput(
                    for: .fullyReady,
                    surface: surface
                )
            )

            XCTAssertEqual(result.availability, .ready, "Expected ready for \(surface.rawValue)")
            XCTAssertTrue(result.shouldShowSection)
            XCTAssertNil(result.staleDataLabel)
            XCTAssertNil(result.partialSignalsLabel)
            XCTAssertNil(result.unavailableReason)
        }
    }

    func testCharacterizationFixtureB_ClassifiesDisconnectedOrHealthUnavailable() {
        for surface in [HealthIntelligenceSurface.today, .plan, .journey] {
            let result = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
                from: HealthIntelligencePresentationCharacterizationFixtures.sectionLoadingInput(
                    for: .healthKitDisconnected,
                    surface: surface
                )
            )

            XCTAssertTrue(
                result.availability == .disconnected || result.availability == .healthUnavailable,
                "Expected disconnected or healthUnavailable for \(surface.rawValue), got \(result.availability)"
            )
            XCTAssertTrue(result.shouldShowSection)
            XCTAssertNotNil(result.unavailableReason)
        }
    }

    func testCharacterizationFixtureC_ClassifiesStaleWithStaleLabel() {
        let now = Date()
        for surface in [HealthIntelligenceSurface.today, .plan, .journey] {
            let result = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
                from: HealthIntelligencePresentationCharacterizationFixtures.sectionLoadingInput(
                    for: .staleData,
                    surface: surface,
                    now: now
                )
            )

            XCTAssertEqual(result.availability, .stale, "Expected stale for \(surface.rawValue)")
            XCTAssertTrue(result.shouldShowSection)
            XCTAssertNotNil(result.staleDataLabel)
            XCTAssertNil(result.unavailableReason)
        }
    }

    func testCharacterizationFixtureD_ClassifiesPartialWithPartialSignalsLabelOnJourney() {
        let now = Date()
        let today = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
            from: HealthIntelligencePresentationCharacterizationFixtures.sectionLoadingInput(
                for: .partialSignals,
                surface: .today,
                now: now
            )
        )
        let journey = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
            from: HealthIntelligencePresentationCharacterizationFixtures.sectionLoadingInput(
                for: .partialSignals,
                surface: .journey,
                now: now
            )
        )

        XCTAssertEqual(today.availability, .partial)
        XCTAssertTrue(today.shouldShowSection)
        XCTAssertNil(today.partialSignalsLabel)

        XCTAssertEqual(journey.availability, .partial)
        XCTAssertTrue(journey.shouldShowSection)
        XCTAssertNotNil(journey.partialSignalsLabel)
    }

    func testCharacterizationFixtureE_ClassifiesReadyWhenWeeklyReviewUnavailable() {
        for surface in [HealthIntelligenceSurface.today, .plan, .journey] {
            let result = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
                from: HealthIntelligencePresentationCharacterizationFixtures.sectionLoadingInput(
                    for: .weeklyReviewUnavailable,
                    surface: surface,
                    weeklyReviewEnabled: false
                )
            )

            XCTAssertEqual(result.availability, .ready, "Expected ready for \(surface.rawValue)")
            XCTAssertTrue(result.shouldShowSection)
            XCTAssertNil(result.unavailableReason)
        }
    }

    func testClassifySectionLoadingReturnsEmptyWhenEnginesUnavailableWithoutCachedData() {
        let result = HealthIntelligenceSectionLoaderCore.classifySectionLoading(
            from: HealthIntelligenceSectionLoadingInput(
                isUIEnabled: true,
                enginesEnabled: false,
                snapshot: nil,
                availability: deniedAvailability(),
                isAppleHealthConnected: false,
                cachedDayCount: 0
            )
        )

        XCTAssertEqual(result.availability, .empty)
        XCTAssertTrue(result.shouldShowSection)
        XCTAssertNotNil(result.unavailableReason)
    }

    func testShouldShowConnectOnlySectionDelegatesToPresentationPolicy() {
        let uiState = HealthIntelligenceUIState(
            kind: .noHealthPermission,
            title: "Connect Apple Health",
            message: "Permission needed",
            primaryActionTitle: "Connect",
            secondaryActionTitle: nil,
            primaryAction: .connectAppleHealth,
            secondaryAction: .none,
            severity: .warning,
            canShowInsight: false,
            confidenceLabel: nil,
            missingSignals: [],
            fallbackReason: .permissionsRequired
        )

        XCTAssertEqual(
            HealthIntelligenceSectionLoaderCore.shouldShowConnectOnlySection(uiState: uiState),
            HealthIntelligencePresentationPolicy.shouldShowConnectOnlySection(uiState: uiState)
        )
    }

    // MARK: - Helpers

    private func deniedAvailability() -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: false,
            permissionStatus: .unavailable(),
            cachedDayCount: 0
        )
    }

    private func makeSnapshot(
        on day: Date,
        nextBestAction: NextBestAction = .none
    ) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 72,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable.",
                recommendedTraining: "Train based on how you feel.",
                recommendedNutrition: "Stay on your usual plan.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 30),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.7, label: "Moderate"),
            nextBestAction: nextBestAction
        )
    }

    private func makeWeeklyReview() -> WeeklyHealthReview {
        let weekEnd = referenceDay
        let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Solid training week",
            summary: "Summary",
            stats: .empty,
            wins: [],
            risks: [],
            nextWeekFocus: [],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: weekEnd
        )
    }
}

// MARK: - Mocks

private final class CoreMockSnapshotService: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    let snapshot: HealthIntelligenceSnapshot?

    init(snapshot: HealthIntelligenceSnapshot?) {
        self.snapshot = snapshot
    }

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        snapshot
    }
}

private final class CoreMockRepository: HealthDataRepositorying, @unchecked Sendable {
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

private final class CoreMockWeeklyReviewService: WeeklyReviewServing, @unchecked Sendable {
    var latestReview: WeeklyHealthReview?
    private(set) var generateCallCount = 0
    var lastForceRefresh = false

    func getLatestCompletedWeeklyReview(calendar: Calendar) async -> WeeklyHealthReview? {
        latestReview
    }

    func getWeeklyReview(for weekStartDate: Date, calendar: Calendar) async -> WeeklyHealthReview? {
        latestReview
    }

    func generateWeeklyReview(
        for weekStartDate: Date,
        forceRefresh: Bool,
        allowPreview: Bool,
        calendar: Calendar
    ) async -> WeeklyHealthReview? {
        generateCallCount += 1
        lastForceRefresh = forceRefresh
        return latestReview
    }
}
