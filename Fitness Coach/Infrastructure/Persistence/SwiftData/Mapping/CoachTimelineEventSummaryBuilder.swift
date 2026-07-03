//
//  CoachTimelineEventSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Compact summaries for persisted Coach timeline rows.
//

import Foundation

enum CoachTimelineEventSummaryBuilder {

    static func summary(for event: CoachTimelineEvent) -> String {
        switch event.payload {
        case .message(let payload):
            return truncate(payload.textPreview)
        case .foodEstimate(let payload):
            return truncate("Estimate: \(payload.mealName)")
        case .foodLogged(let payload):
            let action = payload.isDelete ? "Deleted" : (payload.isEdit ? "Edited" : "Logged")
            return truncate("\(action) food: \(payload.name)")
        case .waterLogged(let payload):
            return "Logged water: \(payload.amountMl)ml"
        case .weightLogged(let payload):
            return "Logged weight: \(payload.weightKg)kg"
        case .workoutDetected(let payload):
            return "Workout detected (\(payload.workoutCount))"
        case .steps(let payload):
            return "Steps updated: \(payload.steps)"
        case .photo(let payload):
            var parts = ["Meal photo"]
            if let bytes = payload.compressedByteSize {
                parts.append("\(bytes) bytes")
            }
            return parts.joined(separator: " · ")
        case .confirmation(let payload):
            return truncate("Pending \(payload.kind)")
        case .error(let payload):
            return truncate("Error: \(payload.category)")
        case .healthAvailability(let payload):
            return payload.isAvailable ? "Health data available" : "Health data unavailable"
        case .contextGeneration(let payload):
            if let days = payload.lookbackDays {
                return "Context generated (\(days)d lookback)"
            }
            return "Context generated"
        case .undo(let payload):
            return truncate("Undo \(payload.entryType)")
        case .systemRefresh(let payload):
            return truncate(payload.reason ?? "System refresh")
        case .empty:
            if event.type == .unknown {
                return "Unknown timeline event"
            }
            return event.type.rawValue
        }
    }

    static func summaryForUnknownPayload(
        eventTypeRaw: String,
        existingSummary: String
    ) -> String {
        let trimmed = existingSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return truncate(trimmed)
        }
        return "Unknown payload (\(eventTypeRaw))"
    }

    private static func truncate(_ value: String, maxLength: Int = 180) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]) + "…"
    }
}
