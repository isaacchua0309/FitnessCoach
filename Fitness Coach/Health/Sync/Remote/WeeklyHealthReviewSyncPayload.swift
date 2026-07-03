//
//  WeeklyHealthReviewSyncPayload.swift
//  Fitness Coach
//
//  Forma — Sanitized weekly health review for remote Health Summary Sync.
//
//  Privacy boundary: aggregate stats and sanitized wins/risks/focus strings only.
//  No per-day time series, raw sleep/HRV data, or unsanitized engine prose.
//
//  Firestore: `/users/{uid}/healthWeeklyReviews/{weekId}`
//

import Foundation

struct WeeklyHealthReviewAggregateStats: Equatable, Sendable, Codable {
    let totalWorkouts: Int
    let totalWorkoutMinutes: Int
    let totalActiveCalories: Int?
    let averageSteps: Int?
    let totalSteps: Int?
    let proteinHitDays: Int
    let calorieTargetHitDays: Int
    let waterHitDays: Int
    let averageRecoveryScore: Double?
    let lowRecoveryDays: Int
    let weightChangeKg: Double?
    let loggingConsistencyDays: Int
}

struct WeeklyHealthReviewSyncPayload: Equatable, Sendable, Codable {
    let id: String
    let userId: String
    let localDate: String
    let timezone: String
    let generatedAt: String
    let source: HealthSummarySyncSource
    let confidence: HealthSyncConfidence
    let missingSignals: [String]
    let schemaVersion: Int

    let weekStart: String
    let weekEnd: String
    let aggregateStats: WeeklyHealthReviewAggregateStats
    let wins: [String]
    let risks: [String]
    let nextFocus: [String]

    var firestorePath: String {
        HealthSummarySyncFirestorePath.weeklyReview(userId: userId, documentID: id)
    }
}

extension WeeklyHealthReviewSyncPayload {

    /// Maps a domain weekly review into a sanitized remote sync payload.
    static func make(
        from review: WeeklyHealthReview,
        context: HealthSummarySyncMappingContext,
        source: HealthSummarySyncSource? = nil
    ) -> WeeklyHealthReviewSyncPayload? {
        let calendar = context.calendar
        guard let weekStart = WeeklyReviewWeekPolicy.normalizedWeekStart(review.weekStartDate, calendar: calendar),
              let weekEnd = WeeklyReviewWeekPolicy.weekEndDate(forWeekStarting: weekStart, calendar: calendar) else {
            return nil
        }

        let weekStartString = HealthSummarySyncFormatting.localDateString(from: weekStart, calendar: calendar)
        let weekEndString = HealthSummarySyncFormatting.localDateString(from: weekEnd, calendar: calendar)
        let documentID = HealthSummarySyncDocumentID.weeklyReview(weekStart: weekStart, calendar: calendar)
        let resolvedSource = source ?? context.source

        return WeeklyHealthReviewSyncPayload(
            id: documentID,
            userId: context.userId,
            localDate: weekStartString,
            timezone: context.timezoneIdentifier,
            generatedAt: HealthSummarySyncFormatting.iso8601UTCString(from: context.generatedAt),
            source: resolvedSource,
            confidence: HealthSyncConfidence(weeklyConfidence: review.confidence),
            missingSignals: review.missingSignals.map(\.rawValue).sorted(),
            schemaVersion: HealthSummarySyncSchemaVersion.current,
            weekStart: weekStartString,
            weekEnd: weekEndString,
            aggregateStats: WeeklyHealthReviewAggregateStats(from: review.stats),
            wins: HealthSummarySyncTextSanitizer.sanitizeList(review.wins, maxItems: 5, maxLength: 200),
            risks: HealthSummarySyncTextSanitizer.sanitizeList(review.risks, maxItems: 5, maxLength: 200),
            nextFocus: HealthSummarySyncTextSanitizer.sanitizeList(
                review.nextWeekFocus,
                maxItems: 3,
                maxLength: 200
            )
        )
    }
}

extension WeeklyHealthReviewAggregateStats {

    init(from stats: WeeklyStats) {
        totalWorkouts = stats.totalWorkouts
        totalWorkoutMinutes = stats.totalWorkoutMinutes
        totalActiveCalories = stats.totalActiveCalories
        averageSteps = stats.averageSteps
        totalSteps = stats.totalSteps
        proteinHitDays = stats.proteinHitDays
        calorieTargetHitDays = stats.calorieTargetHitDays
        waterHitDays = stats.waterHitDays
        averageRecoveryScore = stats.averageRecoveryScore
        lowRecoveryDays = stats.lowRecoveryDays
        weightChangeKg = stats.weightChangeKg
        loggingConsistencyDays = stats.loggingConsistencyDays
    }
}
