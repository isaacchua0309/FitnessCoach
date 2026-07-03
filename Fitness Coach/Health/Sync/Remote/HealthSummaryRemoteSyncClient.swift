//
//  HealthSummaryRemoteSyncClient.swift
//  Fitness Coach
//
//  Forma — Remote sync abstraction for normalized Health Summary payloads.
//
//  Privacy boundary: only typed summary payloads cross this boundary. Raw HealthKit
//  samples, secrets, and unsanitized free text must never be passed to upload methods.
//

import Foundation

// MARK: - Protocol

protocol HealthSummaryRemoteSyncing: Sendable {
    func uploadDailySummaries(_ summaries: [HealthDailySummarySyncPayload]) async throws
    func uploadWorkoutSummaries(_ workouts: [HealthWorkoutSummarySyncPayload]) async throws
    func uploadRecoverySummaries(_ recovery: [RecoverySummarySyncPayload]) async throws
    func uploadWeeklyReviews(_ reviews: [WeeklyHealthReviewSyncPayload]) async throws
    func uploadSyncMetadata(_ metadata: HealthSyncMetadataPayload) async throws
    func deleteRemoteHealthSummaries() async throws
}

// MARK: - Document payload marker

protocol HealthSummaryRemoteSyncDocumentPayload: Codable, Sendable {
    var id: String { get }
    var userId: String { get }
    var generatedAt: String { get }
}

extension HealthDailySummarySyncPayload: HealthSummaryRemoteSyncDocumentPayload {}
extension HealthWorkoutSummarySyncPayload: HealthSummaryRemoteSyncDocumentPayload {}
extension RecoverySummarySyncPayload: HealthSummaryRemoteSyncDocumentPayload {}
extension WeeklyHealthReviewSyncPayload: HealthSummaryRemoteSyncDocumentPayload {}
extension HealthSyncMetadataPayload: HealthSummaryRemoteSyncDocumentPayload {}

// MARK: - Collection names

enum HealthSummaryRemoteSyncCollection {
    static let daily = "healthDaily"
    static let workouts = "healthWorkouts"
    static let recovery = "healthRecovery"
    static let weeklyReviews = "healthWeeklyReviews"
    static let metadata = "healthSyncMetadata"
}

// MARK: - Support

enum HealthSummaryRemoteSyncSupport {

    static let defaultBatchOperationLimit = 400

    static func resolveAuthenticatedUserID(from provider: any HealthCacheUserProviding) throws -> String {
        let raw = provider.currentUserID()?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uid = raw, !uid.isEmpty, uid != HealthCachePolicy.anonymousUserID else {
            throw HealthSummarySyncError.notAuthenticated
        }
        return uid
    }

    static func validateDocumentID(_ documentID: String) throws {
        let trimmed = documentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 128 else {
            throw HealthSummarySyncError.invalidDocumentID
        }
    }

    static func validatePayloads<T: HealthSummaryRemoteSyncDocumentPayload>(
        _ payloads: [T],
        authUid: String
    ) throws {
        for payload in payloads {
            try validateDocumentID(payload.id)
            guard payload.userId == authUid else {
                throw HealthSummarySyncError.userIdMismatch
            }
        }
    }

    static func validateMetadata(_ metadata: HealthSyncMetadataPayload, authUid: String) throws {
        try validateDocumentID(metadata.id)
        guard metadata.id == HealthSummarySyncDocumentID.metadataDocumentID else {
            throw HealthSummarySyncError.invalidDocumentID
        }
        guard metadata.userId == authUid else {
            throw HealthSummarySyncError.userIdMismatch
        }
    }

    static func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0, !items.isEmpty else { return items.isEmpty ? [] : [items] }
        var chunks: [[T]] = []
        chunks.reserveCapacity((items.count + size - 1) / size)
        var index = items.startIndex
        while index < items.endIndex {
            let end = items.index(index, offsetBy: size, limitedBy: items.endIndex) ?? items.endIndex
            chunks.append(Array(items[index..<end]))
            index = end
        }
        return chunks
    }
}

// MARK: - Logging

enum HealthSummaryRemoteSyncLogger {

    static func event(_ message: String, fields: [String: String] = [:]) {
        log(level: "info", message: message, fields: fields)
    }

    static func warn(_ message: String, fields: [String: String] = [:]) {
        log(level: "warn", message: message, fields: fields)
    }

    static func uploadStarted(collection: String, count: Int, uid: String) {
        event(
            "Remote health summary upload started",
            fields: [
                "collection": collection,
                "count": String(count),
                "uidSuffix": uidSuffix(uid)
            ]
        )
    }

    static func uploadFinished(collection: String, count: Int, uid: String) {
        event(
            "Remote health summary upload finished",
            fields: [
                "collection": collection,
                "count": String(count),
                "uidSuffix": uidSuffix(uid)
            ]
        )
    }

    static func uploadFailed(collection: String, uid: String, error: HealthSummarySyncError) {
        warn(
            "Remote health summary upload failed",
            fields: [
                "collection": collection,
                "uidSuffix": uidSuffix(uid),
                "error": error.localizedDescription
            ]
        )
    }

    static func deleteStarted(uid: String) {
        event(
            "Remote health summary delete started",
            fields: ["uidSuffix": uidSuffix(uid)]
        )
    }

    static func deleteFinished(uid: String, deletedDocumentCount: Int) {
        event(
            "Remote health summary delete finished",
            fields: [
                "uidSuffix": uidSuffix(uid),
                "deletedDocuments": String(deletedDocumentCount)
            ]
        )
    }

    // MARK: - Private

    private static func uidSuffix(_ uid: String) -> String {
        guard uid.count >= 4 else { return "****" }
        return String(uid.suffix(4))
    }

    private static func log(level: String, message: String, fields: [String: String]) {
        var metadata = fields
        metadata["level"] = level
        metadata["component"] = "HealthSummaryRemoteSync"

        #if DEBUG
        print("[HealthSummaryRemoteSync] \(HealthOSLogFormatting.message(message, fields: metadata))")
        #endif

        HealthSyncLogger.event(message, fields: metadata)
    }
}

// MARK: - No-op client

/// Inert remote sync client for previews, offline mode, and disabled sync flags.
final class NoopHealthSummaryRemoteSyncClient: HealthSummaryRemoteSyncing, @unchecked Sendable {

    func uploadDailySummaries(_ summaries: [HealthDailySummarySyncPayload]) async throws {
        _ = summaries
    }

    func uploadWorkoutSummaries(_ workouts: [HealthWorkoutSummarySyncPayload]) async throws {
        _ = workouts
    }

    func uploadRecoverySummaries(_ recovery: [RecoverySummarySyncPayload]) async throws {
        _ = recovery
    }

    func uploadWeeklyReviews(_ reviews: [WeeklyHealthReviewSyncPayload]) async throws {
        _ = reviews
    }

    func uploadSyncMetadata(_ metadata: HealthSyncMetadataPayload) async throws {
        _ = metadata
    }

    func deleteRemoteHealthSummaries() async throws {}
}
