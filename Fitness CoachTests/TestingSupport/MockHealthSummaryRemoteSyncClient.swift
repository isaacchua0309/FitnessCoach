//
//  MockHealthSummaryRemoteSyncClient.swift
//  Fitness CoachTests
//
//  In-memory remote health summary sync client for unit tests (no Firebase).
//

import Foundation
@testable import Fitness_Coach

final class MockHealthSummaryRemoteSyncClient: HealthSummaryRemoteSyncing, @unchecked Sendable {

    private let lock = NSLock()

    var uploadDailyError: HealthSummarySyncError?
    var uploadWorkoutError: HealthSummarySyncError?
    var uploadRecoveryError: HealthSummarySyncError?
    var uploadWeeklyReviewError: HealthSummarySyncError?
    var uploadMetadataError: HealthSummarySyncError?
    var deleteError: HealthSummarySyncError?

    private(set) var uploadedDailySummaries: [HealthDailySummarySyncPayload] = []
    private(set) var uploadedWorkoutSummaries: [HealthWorkoutSummarySyncPayload] = []
    private(set) var uploadedRecoverySummaries: [RecoverySummarySyncPayload] = []
    private(set) var uploadedWeeklyReviews: [WeeklyHealthReviewSyncPayload] = []
    private(set) var uploadedMetadata: [HealthSyncMetadataPayload] = []
    private(set) var deleteCallCount = 0

    func uploadDailySummaries(_ summaries: [HealthDailySummarySyncPayload]) async throws {
        try await performUpload(error: uploadDailyError) {
            uploadedDailySummaries.append(contentsOf: summaries)
        }
    }

    func uploadWorkoutSummaries(_ workouts: [HealthWorkoutSummarySyncPayload]) async throws {
        try await performUpload(error: uploadWorkoutError) {
            uploadedWorkoutSummaries.append(contentsOf: workouts)
        }
    }

    func uploadRecoverySummaries(_ recovery: [RecoverySummarySyncPayload]) async throws {
        try await performUpload(error: uploadRecoveryError) {
            uploadedRecoverySummaries.append(contentsOf: recovery)
        }
    }

    func uploadWeeklyReviews(_ reviews: [WeeklyHealthReviewSyncPayload]) async throws {
        try await performUpload(error: uploadWeeklyReviewError) {
            uploadedWeeklyReviews.append(contentsOf: reviews)
        }
    }

    func uploadSyncMetadata(_ metadata: HealthSyncMetadataPayload) async throws {
        try await performUpload(error: uploadMetadataError) {
            uploadedMetadata.append(metadata)
        }
    }

    func deleteRemoteHealthSummaries() async throws {
        lock.lock()
        let error = deleteError
        lock.unlock()

        if let error {
            throw error
        }

        lock.lock()
        deleteCallCount += 1
        uploadedDailySummaries.removeAll()
        uploadedWorkoutSummaries.removeAll()
        uploadedRecoverySummaries.removeAll()
        uploadedWeeklyReviews.removeAll()
        uploadedMetadata.removeAll()
        lock.unlock()
    }

    func reset() {
        lock.lock()
        uploadDailyError = nil
        uploadWorkoutError = nil
        uploadRecoveryError = nil
        uploadWeeklyReviewError = nil
        uploadMetadataError = nil
        deleteError = nil
        uploadedDailySummaries.removeAll()
        uploadedWorkoutSummaries.removeAll()
        uploadedRecoverySummaries.removeAll()
        uploadedWeeklyReviews.removeAll()
        uploadedMetadata.removeAll()
        deleteCallCount = 0
        lock.unlock()
    }

    // MARK: - Private

    private func performUpload(error: HealthSummarySyncError?, update: () -> Void) async throws {
        lock.lock()
        let resolvedError = error
        lock.unlock()

        if let resolvedError {
            throw resolvedError
        }

        lock.lock()
        update()
        lock.unlock()
    }
}
