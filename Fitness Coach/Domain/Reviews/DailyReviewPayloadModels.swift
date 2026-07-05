//
//  DailyReviewPayloadModels.swift
//  Fitness Coach
//
//  Forma — Typed daily review payload for Coach structured messages.
//

import Foundation

// MARK: - Progress metric

struct ProgressMetric: Codable, Equatable, Sendable {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let remainingText: String
    let progress: Double

    init(
        label: String,
        current: Double,
        target: Double,
        unit: String,
        remainingText: String,
        progress: Double
    ) {
        self.label = label
        self.current = current
        self.target = target
        self.unit = unit
        self.remainingText = remainingText
        self.progress = Self.clampedProgress(progress)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        current = try container.decode(Double.self, forKey: .current)
        target = try container.decode(Double.self, forKey: .target)
        unit = try container.decode(String.self, forKey: .unit)
        remainingText = try container.decode(String.self, forKey: .remainingText)
        progress = Self.clampedProgress(try container.decode(Double.self, forKey: .progress))
    }

    static func clampedProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    static func progressRatio(current: Double, target: Double) -> Double {
        guard target > 0, current > 0 else { return 0 }
        return clampedProgress(current / target)
    }
}

// MARK: - Snapshot

struct DailyReviewSnapshot: Codable, Equatable, Sendable {
    let calories: ProgressMetric
    let protein: ProgressMetric
    let water: ProgressMetric
}

// MARK: - Payload

struct DailyReviewPayload: Codable, Equatable, Sendable {
    let title: String
    let timezoneLabel: String?
    let generatedAt: Date?
    let snapshot: DailyReviewSnapshot
    let statusSummary: String
    let bestNextMove: String
    let tomorrowFocus: String?
    let missingSignals: [String]
    let detailNote: String?
}
