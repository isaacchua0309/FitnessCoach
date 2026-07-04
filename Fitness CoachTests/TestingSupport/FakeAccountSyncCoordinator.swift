//
//  FakeAccountSyncCoordinator.swift
//  Fitness CoachTests
//
//  In-memory account sync fakes and coordinator factory for upload/pull tests.
//

import Foundation
@testable import Fitness_Coach

@MainActor
enum FakeAccountSyncCoordinator {

    struct Harness {
        let coordinator: AccountSyncCoordinator
        let uploader: MockAccountSyncUploader
        let puller: MockAccountSyncPuller
        let networkChecker: MockAccountSyncNetworkChecker
        let uidProvider: FakeUIDProvider
    }

    static func makeHarness(
        uid: String = "test-user-a",
        referenceDate: Date = TestDateFixtures.referenceEpoch,
        debounceInterval: Duration = .milliseconds(50),
        uploader: MockAccountSyncUploader? = nil,
        puller: MockAccountSyncPuller? = nil,
        networkChecker: MockAccountSyncNetworkChecker? = nil
    ) -> Harness {
        let resolvedUploader = uploader ?? MockAccountSyncUploader()
        let resolvedPuller = puller ?? MockAccountSyncPuller()
        let resolvedNetwork = networkChecker ?? MockAccountSyncNetworkChecker()
        let uidProvider = FakeUIDProvider(uid: uid)

        let coordinator = AccountSyncCoordinator(
            uploader: resolvedUploader,
            puller: resolvedPuller,
            networkChecker: resolvedNetwork,
            currentUIDProvider: uidProvider.asClosure(),
            nowProvider: { referenceDate },
            debounceInterval: debounceInterval
        )

        return Harness(
            coordinator: coordinator,
            uploader: resolvedUploader,
            puller: resolvedPuller,
            networkChecker: resolvedNetwork,
            uidProvider: uidProvider
        )
    }
}

@MainActor
final class MockAccountSyncUploader: AccountSyncUploading {

    var uploadCallCount = 0
    var delayNanoseconds: UInt64 = 0
    var succeededCount = 0

    func uploadDueMutations(for uid: String, limit: Int) async -> AccountSyncUploadSummary {
        uploadCallCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return AccountSyncUploadSummary(
            uid: uid,
            attempted: succeededCount > 0 ? succeededCount : 0,
            succeeded: succeededCount,
            failed: 0,
            cancelled: 0
        )
    }

    func cancelPendingWork() {}
}

@MainActor
final class DelayedMockAccountSyncUploader: AccountSyncUploading {

    var uploadCallCount = 0
    var delayNanoseconds: UInt64 = 0

    func uploadDueMutations(for uid: String, limit: Int) async -> AccountSyncUploadSummary {
        uploadCallCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return AccountSyncUploadSummary(
            uid: uid,
            attempted: 1,
            succeeded: 1,
            failed: 0,
            cancelled: 0
        )
    }

    func cancelPendingWork() {}
}

@MainActor
final class MockAccountSyncPuller: AccountSyncPulling {

    var pullCallCount = 0

    func pullRecentAccountData(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary {
        pullCallCount += 1
        return AccountSyncPullSummary(
            uid: uid,
            dailyLogsFetched: 0,
            foodEntriesFetched: 0,
            waterEntriesFetched: 0,
            weightEntriesFetched: 0,
            dailyReviewsFetched: 0,
            inserted: 0,
            updated: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0
        )
    }

    func mergeFetchedDocuments(
        for uid: String,
        dailyLogs: [CloudDailyLogDocument],
        foodEntries: [CloudFoodEntryDocument],
        waterEntries: [CloudWaterEntryDocument],
        weightEntries: [CloudWeightEntryDocument],
        dailyReviews: [CloudDailyReviewDocument]
    ) throws -> AccountSyncMergeBatchResult {
        AccountSyncMergeBatchResult(
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0
        )
    }

    func cancelPendingWork() {}
}

@MainActor
final class DelayedMockAccountSyncPuller: AccountSyncPulling {

    var pullCallCount = 0

    func pullRecentAccountData(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary {
        pullCallCount += 1
        return AccountSyncPullSummary(
            uid: uid,
            dailyLogsFetched: 0,
            foodEntriesFetched: 0,
            waterEntriesFetched: 0,
            weightEntriesFetched: 0,
            dailyReviewsFetched: 0,
            inserted: 0,
            updated: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0
        )
    }

    func mergeFetchedDocuments(
        for uid: String,
        dailyLogs: [CloudDailyLogDocument],
        foodEntries: [CloudFoodEntryDocument],
        waterEntries: [CloudWaterEntryDocument],
        weightEntries: [CloudWeightEntryDocument],
        dailyReviews: [CloudDailyReviewDocument]
    ) throws -> AccountSyncMergeBatchResult {
        AccountSyncMergeBatchResult(
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0
        )
    }

    func cancelPendingWork() {}
}

final class MockAccountSyncNetworkChecker: AccountSyncNetworkChecking, @unchecked Sendable {
    var isNetworkAvailable = true
}
