//
//  TodayModelHealthIntelligenceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class TodayModelHealthIntelligenceTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: MockHealthIntelligenceSnapshotService!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = MockHealthIntelligenceSnapshotService()
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        super.tearDown()
    }

    func testHealthIntelligenceDisabledLeavesSectionStateNil() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = makeModel(
            loadEnabled: false,
            uiEnabled: false
        )

        await model.loadToday()

        XCTAssertNil(model.healthIntelligenceSectionState)
        XCTAssertEqual(snapshotProvider.loadCallCount, 0)
    }

    func testUIEnabledLoadsAndMapsHealthIntelligenceSection() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = makeReadySnapshot(on: harness.today)
        let model = makeModel(
            loadEnabled: true,
            uiEnabled: true
        )

        await model.loadToday()

        XCTAssertEqual(snapshotProvider.loadCallCount, 1)
        XCTAssertNotNil(model.healthIntelligenceSectionState)
        XCTAssertEqual(
            model.healthIntelligenceSectionState?.recoveryCard.title,
            "Ready to train"
        )
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testDebugFetchWithoutUIStillAvoidsPublishedSectionWhenUIEnabledFalse() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = makeReadySnapshot(on: harness.today)
        let model = makeModel(
            loadEnabled: true,
            uiEnabled: false
        )

        await model.loadToday()

        XCTAssertEqual(snapshotProvider.loadCallCount, 1)
        XCTAssertNil(model.healthIntelligenceSectionState)
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testSnapshotUnavailableUsesSafeFallbackWhenUIEnabled() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = nil
        let model = makeModel(
            loadEnabled: true,
            uiEnabled: true
        )

        await model.loadToday()

        XCTAssertNotNil(model.healthIntelligenceSectionState)
        XCTAssertEqual(
            model.healthIntelligenceSectionState?.fallbackMessage,
            FormaProductCopy.Today.HealthIntelligence.connectHealthFallback
        )
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testHealthIntelligenceFailureDoesNotFailTodayRefresh() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.shouldFailLoad = true
        let model = makeModel(
            loadEnabled: true,
            uiEnabled: true
        )

        await model.refresh()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Today dashboard despite Health Intelligence fallback")
        }
        XCTAssertNotNil(model.healthIntelligenceSectionState)
    }

    func testResetForUserContextChangeClearsHealthIntelligenceSection() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = makeReadySnapshot(on: harness.today)
        let model = makeModel(
            loadEnabled: true,
            uiEnabled: true
        )

        await model.loadToday()
        XCTAssertNotNil(model.healthIntelligenceSectionState)

        model.resetForUserContextChange()

        XCTAssertNil(model.healthIntelligenceSectionState)
        XCTAssertEqual(model.viewState, .loading)
    }

    // MARK: - Helpers

    private func makeModel(
        loadEnabled: Bool,
        uiEnabled: Bool
    ) -> TodayModel {
        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: "test-user-1"),
            profile: try? harness.profileService.getCurrentProfile(),
            calendar: Calendar.current,
            now: harness.today
        )

        return TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: makeReviewService(),
            userProfileReader: harness.profileService,
            healthActivityQuery: harness.healthActivityQuery,
            healthIntelligenceSnapshotProvider: snapshotProvider,
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: "test-user-1") },
            healthIntelligenceLoadEnabled: { loadEnabled },
            healthIntelligenceUIEnabled: { uiEnabled }
        )
    }

    private func makeReviewService() -> ReviewService {
        ReviewService(
            store: harness.store,
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.base.foodLogService,
            waterLogService: harness.base.waterLogService,
            weightLogService: harness.weightLogService,
            healthActivityQuery: harness.healthActivityQuery,
            userProfileService: harness.profileService,
            aiService: AIService(llmClient: MockLLMClient())
        )
    }

    private func makeReadySnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 84,
                status: .ready,
                title: "Ready to train",
                explanation: "Sleep and recovery signals look supportive for your usual plan today.",
                recommendedTraining: "Your usual training plan looks reasonable today.",
                recommendedNutrition: "Stick with your normal protein and hydration rhythm.",
                confidence: .high,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_450, activeEnergyKcal: 420, exerciseMinutes: 38),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.82, label: "High"),
            nextBestAction: .none
        )
    }
}

// MARK: - Mock

private final class MockHealthIntelligenceSnapshotService: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?
    var shouldFailLoad = false
    private(set) var loadCallCount = 0

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        loadCallCount += 1
        if shouldFailLoad {
            return nil
        }
        return snapshot
    }
}
