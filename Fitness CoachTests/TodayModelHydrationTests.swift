//
//  TodayModelHydrationTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class TodayModelHydrationTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testLoadTodayWithoutHydrationContextStaysLoading() async {
        let model = makeModel(hydrationContext: nil)

        await model.loadToday()

        XCTAssertEqual(model.viewState, .loading)
    }

    func testLoadTodayWithHydrationContextCreatesEmptyDashboard() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = makeModel(
            hydrationContext: TodayHydrationGate.resolve(
                authState: .signedIn(uid: "test-user-1"),
                profile: try harness.profileService.getCurrentProfile(),
                calendar: Calendar.current,
                now: harness.today
            )
        )

        await model.loadToday()

        guard case .loaded(let state) = model.viewState else {
            return XCTFail("Expected loaded state, got \(model.viewState)")
        }
        XCTAssertTrue(state.meals.isEmpty)
        XCTAssertEqual(state.mission.calorieSummary.target, ProfileTestFixtures.sampleTargets.calorieTarget)
    }

    func testRefreshWhileNotLoadedDoesNotSurfaceRefreshError() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: "test-user-1"),
            profile: try harness.profileService.getCurrentProfile(),
            calendar: Calendar.current,
            now: harness.today
        )
        let failingHealthQuery = HealthActivityQueryService(
            workoutReader: ThrowingHealthKitWorkoutReader(),
            stepReader: MockHealthKitStepReader(stepCount: 0)
        )
        let model = TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: makeReviewService(),
            userProfileReader: harness.profileService,
            healthActivityQuery: failingHealthQuery,
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: "test-user-1") }
        )

        await model.refresh()

        if case .error(let message) = model.viewState {
            XCTAssertNotEqual(
                message,
                FormaProductCopy.Today.EmptyState.refreshErrorLocalBody,
                "Refresh before initial load should not show refresh error copy"
            )
        } else {
            XCTAssertFalse(model.viewState.isLoaded)
        }
    }

    func testResetForUserContextChangeClearsErrorState() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: "test-user-1"),
            profile: try harness.profileService.getCurrentProfile(),
            calendar: Calendar.current,
            now: harness.today
        )
        let failingHealthQuery = HealthActivityQueryService(
            workoutReader: ThrowingHealthKitWorkoutReader(),
            stepReader: MockHealthKitStepReader(stepCount: 0)
        )
        let model = TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: makeReviewService(),
            userProfileReader: harness.profileService,
            healthActivityQuery: failingHealthQuery,
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: "test-user-1") }
        )

        await model.loadToday()
        if case .error = model.viewState {
            model.resetForUserContextChange()
            XCTAssertEqual(model.viewState, .loading)
        } else {
            XCTFail("Expected load error for failing health query")
        }
    }

    func testSessionUIDChangeResetsToLoadingBeforeReload() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        var activeUID = "test-user-1"
        let model = makeModel(
            hydrationContext: TodayHydrationGate.resolve(
                authState: .signedIn(uid: activeUID),
                profile: try harness.profileService.getCurrentProfile(),
                calendar: Calendar.current,
                now: harness.today
            ),
            hydrationContextProvider: {
                TodayHydrationGate.resolve(
                    authState: .signedIn(uid: activeUID),
                    profile: try? harness.profileService.getCurrentProfile(),
                    calendar: Calendar.current,
                    now: harness.today
                )
            }
        )

        await model.loadToday()
        XCTAssertTrue(model.viewState.isLoaded)

        activeUID = "test-user-2"
        await model.loadToday()

        XCTAssertEqual(model.viewState, .loading)
    }

    // MARK: - Helpers

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

    private func makeModel(
        hydrationContext: TodayHydrationContext?,
        hydrationContextProvider: (() -> TodayHydrationContext?)? = nil
    ) -> TodayModel {
        let reviewService = makeReviewService()

        return TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: reviewService,
            userProfileReader: harness.profileService,
            healthActivityQuery: harness.healthActivityQuery,
            hydrationContextProvider: hydrationContextProvider ?? { hydrationContext },
            authStateProvider: { .signedIn(uid: "test-user-1") }
        )
    }
}

private struct ThrowingHealthKitWorkoutReader: HealthKitWorkoutReading {
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        throw ServiceError.persistenceFailed("HealthKit unavailable in test")
    }
}
