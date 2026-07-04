//
//  HealthSummarySyncEnvelope.swift
//  Fitness Coach
//
//  Forma — Shared envelope fields, document identifiers, and formatting helpers
//  for normalized Health Summary Sync payloads.
//
//  Privacy boundary: envelope types never carry raw HealthKit samples, time-series
//  biometrics, or unsanitized free text. Only summary metadata crosses this layer.
//

import Foundation

// MARK: - Source

/// Provenance of a synced summary document.
enum HealthSummarySyncSource: String, Equatable, Sendable, Codable, CaseIterable {
    /// Derived from normalized Apple Health / HealthKit reads.
    case appleHealth = "apple_health"
    /// Derived from Forma engine output without a fresh HealthKit read.
    case formaDerived = "forma_engine"
    /// Combined Apple Health and Forma app data (weekly review only).
    case mixed
}

// MARK: - Confidence

/// Cross-domain confidence bucket for remote sync payloads.
enum HealthSyncConfidence: String, Equatable, Sendable, Codable, CaseIterable {
    case low
    case moderate
    case high
    case unknown

    init(recoveryConfidence: RecoveryConfidence) {
        switch recoveryConfidence {
        case .high: self = .high
        case .moderate: self = .moderate
        case .low: self = .low
        case .unknown: self = .unknown
        }
    }

    init(workoutConfidence: WorkoutSummaryConfidence) {
        switch workoutConfidence {
        case .high: self = .high
        case .moderate: self = .moderate
        case .low: self = .low
        }
    }

    init(weeklyConfidence: WeeklyReviewConfidence) {
        switch weeklyConfidence {
        case .high: self = .high
        case .moderate: self = .moderate
        case .low: self = .low
        }
    }
}

// MARK: - Missing signal tokens

enum HealthDailySummaryMissingSignal: String, Equatable, Sendable, Codable, CaseIterable {
    case steps
    case activeEnergy
    case exerciseMinutes
    case workout
    case workoutCalories
}

// MARK: - Envelope

/// Shared metadata included on every Health Summary Sync document.
struct HealthSummarySyncEnvelope: Equatable, Sendable, Codable {
    let id: String
    let userId: String
    let localDate: String
    let timezone: String
    let generatedAt: String
    let source: HealthSummarySyncSource
    let confidence: HealthSyncConfidence
    let missingSignals: [String]
    let schemaVersion: Int

    init(
        id: String,
        userId: String,
        localDate: String,
        timezone: String,
        generatedAt: Date,
        source: HealthSummarySyncSource,
        confidence: HealthSyncConfidence,
        missingSignals: [String],
        schemaVersion: Int = HealthSummarySyncSchemaVersion.current
    ) {
        self.id = id
        self.userId = userId
        self.localDate = localDate
        self.timezone = timezone
        self.generatedAt = HealthSummarySyncFormatting.iso8601UTCString(from: generatedAt)
        self.source = source
        self.confidence = confidence
        self.missingSignals = missingSignals
        self.schemaVersion = schemaVersion
    }
}

// MARK: - Mapping context

/// Inputs shared by payload mappers (no HealthKit types).
struct HealthSummarySyncMappingContext: Equatable, Sendable {
    let userId: String
    let calendar: Calendar
    let generatedAt: Date
    let source: HealthSummarySyncSource

    init(
        userId: String,
        calendar: Calendar = .current,
        generatedAt: Date = Date(),
        source: HealthSummarySyncSource = .appleHealth
    ) {
        self.userId = userId
        self.calendar = calendar
        self.generatedAt = generatedAt
        self.source = source
    }

    var timezoneIdentifier: String {
        calendar.timeZone.identifier
    }
}

// MARK: - Document identifiers

/// Deterministic Firestore document identifiers for Health Summary Sync collections.
enum HealthSummarySyncDocumentID {

    static let metadataDocumentID = "current"

    static func daily(localDate: Date, calendar: Calendar) -> String {
        HealthSummarySyncFormatting.localDateString(from: localDate, calendar: calendar)
    }

    static func recovery(localDate: Date, calendar: Calendar) -> String {
        daily(localDate: localDate, calendar: calendar)
    }

    static func workout(workoutID: UUID) -> String {
        workoutID.uuidString.lowercased()
    }

    static func workout(from workout: NormalizedWorkout) -> String {
        HealthSummarySyncDocumentID.workout(workoutID: workout.id)
    }

    static func weeklyReview(weekStart: Date, calendar: Calendar) -> String {
        HealthSummarySyncFormatting.localDateString(from: weekStart, calendar: calendar)
    }
}

// MARK: - Firestore paths

enum HealthSummarySyncFirestorePath {

    static func daily(userId: String, documentID: String) -> String {
        "users/\(userId)/healthDaily/\(documentID)"
    }

    static func workout(userId: String, documentID: String) -> String {
        "users/\(userId)/healthWorkouts/\(documentID)"
    }

    static func recovery(userId: String, documentID: String) -> String {
        "users/\(userId)/healthRecovery/\(documentID)"
    }

    static func weeklyReview(userId: String, documentID: String) -> String {
        "users/\(userId)/healthWeeklyReviews/\(documentID)"
    }

    static func metadata(userId: String) -> String {
        "users/\(userId)/healthSyncMetadata/\(HealthSummarySyncDocumentID.metadataDocumentID)"
    }
}

// MARK: - Formatting

enum HealthSummarySyncFormatting {

    static func localDateString(from date: Date, calendar: Calendar) -> String {
        let day = calendar.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: day)
    }

    static func iso8601UTCString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    static func workouts(onLocalDay day: Date, from workouts: [NormalizedWorkout], calendar: Calendar) -> [NormalizedWorkout] {
        workouts.filter { workout in
            calendar.isDate(workout.startDate, inSameDayAs: day)
        }
    }
}

// MARK: - Source app name sanitization

enum HealthSummarySyncSourceAppNameSanitizer {

    private static let maxLength = 64
    private static let forbiddenSubstrings = [
        "@",
        "com.apple",
        "com.",
        "healthkit",
        "bundle",
        "udid",
        "uuid"
    ]

    /// Returns a safe display name for remote sync, or `nil` when the value must be omitted.
    static func sanitize(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        let lower = trimmed.lowercased()
        guard !forbiddenSubstrings.contains(where: { lower.contains($0) }) else {
            return nil
        }

        guard trimmed.count <= maxLength else {
            return String(trimmed.prefix(maxLength))
        }

        return trimmed
    }
}

// MARK: - Text sanitization

enum HealthSummarySyncTextSanitizer {

    static func sanitizeList(_ items: [String], maxItems: Int, maxLength: Int) -> [String] {
        items
            .compactMap { HealthIntelligencePresentationTextSanitizer.sanitize($0) }
            .prefix(maxItems)
            .map { String($0.prefix(maxLength)) }
    }
}
