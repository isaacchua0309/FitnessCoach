//
//  JourneyRestoreAwarenessTests.swift
//  Fitness CoachTests
//
//  Forma — Journey tab restore-aware loading tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class JourneyRestoreAwarenessTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testJourneyDoesNotShowNoProgressDuringBlockingRestore() async throws {
        _ = try harness.seedProfile(ownerUID: RestoreAwareTestSupport.ownerUID)
        let session = AccountRestoreSessionState()
        session.beginBlockingRestore()

        let model = RestoreAwareTestSupport.makeJourneyModel(
            harness: harness,
            session: session,
            isEffectivelyEmpty: true
        )

        await model.loadProgress()

        XCTAssertEqual(model.viewState, .loading)
    }

    func testJourneyRebuildsAfterRestoreCompleted() async throws {
        _ = try harness.seedProfile(ownerUID: RestoreAwareTestSupport.ownerUID)
        _ = try harness.base.dailyLogService.getOrCreateLogEntity(for: harness.today)

        let session = AccountRestoreSessionState()
        session.beginBlockingRestore()
        let loadingModel = RestoreAwareTestSupport.makeJourneyModel(
            harness: harness,
            session: session,
            isEffectivelyEmpty: false
        )
        await loadingModel.loadProgress()
        XCTAssertEqual(loadingModel.viewState, .loading)

        session.recordRestoreCompletion(
            RestoreAwareTestSupport.makeRestoreSummary(status: .completed)
        )

        let rebuiltModel = RestoreAwareTestSupport.makeJourneyModel(
            harness: harness,
            session: session,
            isEffectivelyEmpty: false
        )
        await rebuiltModel.loadProgress()

        guard case .loaded = rebuiltModel.viewState else {
            return XCTFail("Expected loaded journey state after restore, got \(rebuiltModel.viewState)")
        }
    }

    func testJourneyShowsRestorePendingWhenOfflineAndEmpty() async throws {
        _ = try harness.seedProfile(ownerUID: RestoreAwareTestSupport.ownerUID)
        let session = AccountRestoreSessionState()
        session.recordRestoreCompletion(
            RestoreAwareTestSupport.makeRestoreSummary(status: .offline)
        )

        let model = RestoreAwareTestSupport.makeJourneyModel(
            harness: harness,
            session: session,
            isEffectivelyEmpty: true
        )

        await model.loadProgress()

        guard case .pendingAccountRestore(let message) = model.viewState else {
            return XCTFail("Expected pending restore state, got \(model.viewState)")
        }
        XCTAssertEqual(message, FormaProductCopy.AccountRestore.Pending.offlineBody)
    }
}
