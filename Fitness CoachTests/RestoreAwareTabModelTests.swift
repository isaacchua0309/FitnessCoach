//
//  RestoreAwareTabModelTests.swift
//  Fitness CoachTests
//
//  Forma — Today and Journey restore-aware loading (Phase 4).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class RestoreAwareTabModelTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testTodayModelStaysLoadingWhileBlockingRestoreActive() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let session = AccountRestoreSessionState()
        session.beginBlockingRestore()

        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: "test-user-1"),
            profile: try harness.profileService.getCurrentProfile(),
            calendar: Calendar.current,
            now: harness.today
        )

        let model = TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: makeReviewService(),
            userProfileReader: harness.profileService,
            healthActivityQuery: harness.healthActivityQuery,
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: "test-user-1") },
            restoreSessionState: session,
            localDataInspector: StubAccountLocalDataInspector(isEffectivelyEmpty: true),
            ownerUIDProvider: { "test-user-1" }
        )

        await model.loadToday()

        XCTAssertEqual(model.viewState, .loading)
    }

    func testTodayModelShowsPendingRestoreAfterOfflineRestoreWithEmptyLocalData() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let session = AccountRestoreSessionState()
        session.recordRestoreCompletion(makeOfflineSummary(uid: "test-user-1"))

        let context = TodayHydrationGate.resolve(
            authState: .signedIn(uid: "test-user-1"),
            profile: try harness.profileService.getCurrentProfile(),
            calendar: Calendar.current,
            now: harness.today
        )

        let model = TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: makeReviewService(),
            userProfileReader: harness.profileService,
            healthActivityQuery: harness.healthActivityQuery,
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: "test-user-1") },
            restoreSessionState: session,
            localDataInspector: StubAccountLocalDataInspector(isEffectivelyEmpty: true),
            ownerUIDProvider: { "test-user-1" }
        )

        await model.loadToday()

        guard case .pendingAccountRestore(let message) = model.viewState else {
            return XCTFail("Expected pending restore state, got \(model.viewState)")
        }
        XCTAssertEqual(message, FormaProductCopy.AccountRestore.Pending.offlineBody)
    }

    func testJourneyModelStaysLoadingWhileBlockingRestoreActive() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let session = AccountRestoreSessionState()
        session.beginBlockingRestore()

        let model = makeJourneyModel(session: session)

        await model.loadProgress()

        XCTAssertEqual(model.viewState, .loading)
    }

    func testJourneyModelShowsPendingRestoreAfterOfflineRestoreWithEmptyLocalData() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let session = AccountRestoreSessionState()
        session.recordRestoreCompletion(makeOfflineSummary(uid: "test-user-1"))

        let model = makeJourneyModel(session: session)

        await model.loadProgress()

        guard case .pendingAccountRestore(let message) = model.viewState else {
            return XCTFail("Expected pending restore state, got \(model.viewState)")
        }
        XCTAssertEqual(message, FormaProductCopy.AccountRestore.Pending.offlineBody)
    }

    private func makeJourneyModel(session: AccountRestoreSessionState) -> JourneyModel {
        let trainingStore = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: .notConnected)
        )
        return JourneyModel(
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            userProfileReader: harness.profileService,
            trainingInsightsStore: trainingStore,
            restoreSessionState: session,
            localDataInspector: StubAccountLocalDataInspector(isEffectivelyEmpty: true),
            ownerUIDProvider: { "test-user-1" }
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
            aiService: AIService(llmClient: MockLLMClient()),
            mutationTracker: harness.base.accountLocalMutationTracker
        )
    }

    private func makeOfflineSummary(uid: String) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: .offline,
            startedAt: Date(),
            endedAt: Date(),
            profileRestored: true,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: true,
            userFacingMessage: nil
        )
    }
}
