//
//  RecoverySummarySyncPayload.swift
//  Fitness Coach
//
//  Forma — Sanitized daily recovery summary for remote Health Summary Sync.
//
//  Privacy boundary: qualitative status, optional score/bucket, and contributing
//  factor signal names only. No raw HRV/RHR values, engine detail strings, or
//  recommendation prose.
//
//  Firestore: `/users/{uid}/healthRecovery/{yyyy-MM-dd}`
//

import Foundation

enum RecoverySummaryScoreBucket: String, Equatable, Sendable, Codable, CaseIterable {
    case ready
    case moderate
    case low
    case unknown

    init(status: RecoveryStatus) {
        switch status {
        case .ready: self = .ready
        case .moderate: self = .moderate
        case .low: self = .low
        case .unknown: self = .unknown
        }
    }
}

struct RecoverySummarySyncContributingFactor: Equatable, Sendable, Codable {
    let signal: String
    let impact: String
}

struct RecoverySummarySyncPayload: Equatable, Sendable, Codable {
    let id: String
    let userId: String
    let localDate: String
    let timezone: String
    let generatedAt: String
    let source: HealthSummarySyncSource
    let confidence: HealthSyncConfidence
    let missingSignals: [String]
    let schemaVersion: Int

    let date: String
    let score: Int?
    let scoreBucket: String?
    let status: String
    let contributingFactors: [RecoverySummarySyncContributingFactor]

    var firestorePath: String {
        HealthSummarySyncFirestorePath.recovery(userId: userId, documentID: id)
    }
}

extension RecoverySummarySyncPayload {

    /// Maps a domain recovery summary into a sanitized remote sync payload.
    ///
    /// Numeric scores are included only when confidence is moderate/high and the
    /// score would be shown in UI; otherwise a qualitative bucket is sent.
    static func make(
        from recovery: RecoverySummary,
        date: Date,
        context: HealthSummarySyncMappingContext,
        source: HealthSummarySyncSource? = nil
    ) -> RecoverySummarySyncPayload {
        let calendar = context.calendar
        let day = calendar.startOfDay(for: date)
        let localDate = HealthSummarySyncFormatting.localDateString(from: day, calendar: calendar)
        let documentID = HealthSummarySyncDocumentID.recovery(localDate: day, calendar: calendar)
        let syncConfidence = HealthSyncConfidence(recoveryConfidence: recovery.confidence)
        let score = syncSafeScore(from: recovery)
        let scoreBucket: RecoverySummaryScoreBucket? = score == nil
            ? RecoverySummaryScoreBucket(status: recovery.status)
            : nil

        return RecoverySummarySyncPayload(
            id: documentID,
            userId: context.userId,
            localDate: localDate,
            timezone: context.timezoneIdentifier,
            generatedAt: HealthSummarySyncFormatting.iso8601UTCString(from: context.generatedAt),
            source: source ?? context.source,
            confidence: syncConfidence,
            missingSignals: recovery.missingSignals.map(\.rawValue).sorted(),
            schemaVersion: HealthSummarySyncSchemaVersion.current,
            date: localDate,
            score: score,
            scoreBucket: scoreBucket?.rawValue,
            status: recovery.status.rawValue,
            contributingFactors: recovery.contributingFactors.map {
                RecoverySummarySyncContributingFactor(
                    signal: $0.signal.rawValue,
                    impact: $0.impact.rawValue
                )
            }
        )
    }

    // MARK: - Private

    private static func syncSafeScore(from recovery: RecoverySummary) -> Int? {
        guard let score = recovery.score else { return nil }
        guard recovery.confidence == .moderate || recovery.confidence == .high else { return nil }
        guard !shouldPreferScoreBucket(for: recovery) else { return nil }
        return min(max(score, 0), 100)
    }

    private static func shouldPreferScoreBucket(for recovery: RecoverySummary) -> Bool {
        recovery.confidence == .low
            || recovery.confidence == .unknown
            || recovery.missingSignals.count >= 3
    }
}
