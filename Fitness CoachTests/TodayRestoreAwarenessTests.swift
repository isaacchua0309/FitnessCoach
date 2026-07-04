//
//  TodayRestoreAwarenessTests.swift
//  Fitness CoachTests
//
//  Forma — Today tab restore-aware loading tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class TodayRestoreAwarenessTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testTodayDoesNotShowEmptyStateDuringBlockingRestore() async throws {
        _ = try harness.seedProfile(ownerUID: RestoreAwareTestSupport.ownerUID)
        let session = AccountRestoreSessionState()
        session.beginBlockingRestore()

        let model = try RestoreAwareTestSupport.makeTodayModel(
            harness: harness,
            session: session,
            isEffectivelyEmpty: true
        )

        await model.loadToday()

        XCTAssertEqual(model.viewState, .loading)
    }

    func testTodayReloadsAfterRestoreCompleted() async throws {
        _ = try harness.seedProfile(ownerUID: RestoreAwareTestSupport.ownerUID)
        _ = try harness.base.dailyLogService.getOrCreateLogEntity(for: harness.today)
        _ = try harness.base.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Restored Meal", calories: 420, protein: 30),
            date: harness.today
        )

        let session = AccountRestoreSessionState()
        session.beginBlockingRestore()
        let loadingModel = try RestoreAwareTestSupport.makeTodayModel(
            harness: harness,
            session: session,
            isEffectivelyEmpty: false
        )
        await loadingModel.loadToday()
        XCTAssertEqual(loadingModel.viewState, .loading)

        session.recordRestoreCompletion(
            RestoreAwareTestSupport.makeRestoreSummary(status: .completed)
        )

        let reloadedModel = try RestoreAwareTestSupport.makeTodayModel(
            harness: harness,
            session: session,
            isEffectivelyEmpty: false
        )
        await reloadedModel.loadToday()

        guard case .loaded = reloadedModel.viewState else {
            return XCTFail("Expected loaded state after restore, got \(reloadedModel.viewState)")
        }
    }

    func testTodayShowsPendingRestoreMessageWhenOfflineAndEmpty() async throws {
        _ = try harness.seedProfile(ownerUID: RestoreAwareTestSupport.ownerUID)
        let session = AccountRestoreSessionState()
        session.recordRestoreCompletion(
            RestoreAwareTestSupport.makeRestoreSummary(status: .offline)
        )

        let model = try RestoreAwareTestSupport.makeTodayModel(
            harness: harness,
            session: session,
            isEffectivelyEmpty: true
        )

        await model.loadToday()

        guard case .pendingAccountRestore(let message) = model.viewState else {
            return XCTFail("Expected pending restore state, got \(model.viewState)")
        }
        XCTAssertEqual(message, FormaProductCopy.AccountRestore.Pending.offlineBody)
    }
}
