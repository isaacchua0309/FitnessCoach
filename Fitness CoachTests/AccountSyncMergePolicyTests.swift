//
//  AccountSyncMergePolicyTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync merge policy tests (Phase 3).
//

import XCTest
@testable import Fitness_Coach

final class AccountSyncMergePolicyTests: XCTestCase {

    private let uid = "userA"
    private let referenceDate = ProfileTestFixtures.referenceDate

    func testInsertsWhenLocalMissingAndRemoteActive() {
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: referenceDate,
                remoteDeletedAt: nil,
                localExists: false,
                localOwnerUID: nil,
                localSyncStatus: nil,
                localEffectiveUpdatedAt: nil
            )
        )

        XCTAssertEqual(decision, .insert)
    }

    func testSkipsRemoteDeletedWhenLocalMissing() {
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: referenceDate,
                remoteDeletedAt: referenceDate,
                localExists: false,
                localOwnerUID: nil,
                localSyncStatus: nil,
                localEffectiveUpdatedAt: nil
            )
        )

        XCTAssertEqual(decision, .skipRemoteDeletedNoLocal)
    }

    func testUpdatesSyncedLocalWhenRemoteIsNewer() {
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: referenceDate.addingTimeInterval(60),
                remoteDeletedAt: nil,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .synced,
                localEffectiveUpdatedAt: referenceDate
            )
        )

        XCTAssertEqual(decision, .update)
    }

    func testSkipsStaleRemoteForSyncedLocal() {
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: referenceDate,
                remoteDeletedAt: nil,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .synced,
                localEffectiveUpdatedAt: referenceDate.addingTimeInterval(60)
            )
        )

        XCTAssertEqual(decision, .skipStaleRemote)
    }

    func testMarksConflictWhenPendingUploadAndRemoteNewer() {
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: referenceDate.addingTimeInterval(120),
                remoteDeletedAt: nil,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .pendingUpload,
                localEffectiveUpdatedAt: referenceDate
            )
        )

        XCTAssertEqual(decision, .conflict)
    }

    func testSkipsLocalNewerPendingUploadWhenRemoteOlder() {
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: referenceDate,
                remoteDeletedAt: nil,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .pendingUpload,
                localEffectiveUpdatedAt: referenceDate.addingTimeInterval(120)
            )
        )

        XCTAssertEqual(decision, .skipLocalNewer)
    }

    func testDoesNotResurrectPendingDelete() {
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: referenceDate.addingTimeInterval(120),
                remoteDeletedAt: nil,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .pendingDelete,
                localEffectiveUpdatedAt: referenceDate
            )
        )

        XCTAssertEqual(decision, .skipLocalNewer)
    }

    func testAppliesRemoteTombstoneWhenSyncedAndRemoteDeleteNewer() {
        let deletedAt = referenceDate.addingTimeInterval(30)
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: deletedAt,
                remoteDeletedAt: deletedAt,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .synced,
                localEffectiveUpdatedAt: referenceDate
            )
        )

        XCTAssertEqual(decision, .applyRemoteTombstone)
    }

    func testFailsOwnerMismatch() {
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: referenceDate,
                remoteDeletedAt: nil,
                localExists: true,
                localOwnerUID: "other-user",
                localSyncStatus: .synced,
                localEffectiveUpdatedAt: referenceDate
            )
        )

        XCTAssertEqual(decision, .failedOwnerMismatch)
    }
}
