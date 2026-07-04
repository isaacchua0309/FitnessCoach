//
//  AccountSyncMergePolicyTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync merge policy tests (Phase 3/5).
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

        XCTAssertEqual(decision, .conflict(.pendingUploadVsRemoteNewer))
    }

    func testMarksConflictWhenFailedAndRemoteNewer() {
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: referenceDate.addingTimeInterval(120),
                remoteDeletedAt: nil,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .failed,
                localEffectiveUpdatedAt: referenceDate
            )
        )

        XCTAssertEqual(decision, .conflict(.failedVsRemoteNewer))
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

    func testMarksConflictWhenPendingDeleteAndRemoteRevivesNewer() {
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

        XCTAssertEqual(decision, .conflict(.pendingDeleteVsRemoteRevive))
    }

    func testMarksConflictWhenPendingUploadAndRemoteDelete() {
        let deletedAt = referenceDate.addingTimeInterval(120)
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: deletedAt,
                remoteDeletedAt: deletedAt,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .pendingUpload,
                localEffectiveUpdatedAt: referenceDate.addingTimeInterval(300)
            )
        )

        XCTAssertEqual(decision, .conflict(.pendingUploadVsRemoteDelete))
    }

    func testMarksConflictWhenPendingUploadAndRemoteDeleteEvenIfRemoteIsNewer() {
        let deletedAt = referenceDate.addingTimeInterval(300)
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: deletedAt,
                remoteDeletedAt: deletedAt,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .pendingUpload,
                localEffectiveUpdatedAt: referenceDate
            )
        )

        XCTAssertEqual(decision, .conflict(.pendingUploadVsRemoteDelete))
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

    func testAppliesRemoteTombstoneWhenPendingDeleteAndRemoteDelete() {
        let deletedAt = referenceDate.addingTimeInterval(30)
        let decision = AccountSyncMergePolicy.decide(
            AccountSyncMergeContext(
                uid: uid,
                remoteUpdatedAt: deletedAt,
                remoteDeletedAt: deletedAt,
                localExists: true,
                localOwnerUID: uid,
                localSyncStatus: .pendingDelete,
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

    func testMarkConflictPreservesRetryableMetadata() {
        let entity = FoodEntryEntity(
            id: UUID(),
            ownerUID: uid,
            dailyLogId: UUID(),
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Local",
            quantity: 1,
            unit: "bowl",
            calories: 100,
            protein: 10,
            carbs: 10,
            fat: 5,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        entity.syncStatus = .pendingUpload
        entity.localUpdatedAt = referenceDate
        entity.lastMutationId = "mutation-1"

        AccountSyncRemoteMergeApplicator.markConflict(
            on: entity,
            remoteUpdatedAt: referenceDate.addingTimeInterval(60),
            reason: .pendingUploadVsRemoteNewer
        )

        XCTAssertEqual(entity.syncStatus, .conflict)
        XCTAssertEqual(entity.name, "Local")
        XCTAssertEqual(entity.localUpdatedAt, referenceDate)
        XCTAssertEqual(entity.lastMutationId, "mutation-1")
        XCTAssertEqual(entity.lastSyncError, AccountSyncMergeConflictReason.pendingUploadVsRemoteNewer.logCode)
        XCTAssertTrue(entity.syncStatus.needsSyncWork)
    }
}
