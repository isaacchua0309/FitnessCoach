//
//  CoachCorrectionMemoryBuilder.swift
//  Fitness Coach
//
//  Forma — Surfaces recent user food corrections for Coach context assumptions.
//

import Foundation

enum CoachCorrectionMemoryBuilder {

    static let maxCorrections = 5
    static let lookbackDays = 14

    static func makeAssumptions(
        from events: [CoachTimelineEvent],
        now: Date,
        calendar: Calendar = .current
    ) -> [CoachAssumptionContext] {
        guard !events.isEmpty else { return [] }

        let cutoff = calendar.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
        let corrections = events
            .filter { $0.utcTimestamp >= cutoff }
            .sorted { $0.utcTimestamp > $1.utcTimestamp }
            .compactMap { assumption(from: $0) }
            .prefix(maxCorrections)

        return Array(corrections)
    }

    private static func assumption(from event: CoachTimelineEvent) -> CoachAssumptionContext? {
        switch event.type {
        case .foodEdited:
            guard case .foodLogged(let payload) = event.payload else { return nil }
            return CoachAssumptionContext(
                key: "correction.\(payload.entryId.uuidString)",
                detail: correctionDetail(
                    prefix: "User corrected a logged meal",
                    payload: payload
                ),
                confidence: event.confidence.map(CoachContextConfidence.from)
            )
        case .foodLogged:
            guard case .foodLogged(let payload) = event.payload else { return nil }
            guard payload.userEditedBeforeConfirm == true else { return nil }
            return CoachAssumptionContext(
                key: "correction.pending.\(payload.entryId.uuidString)",
                detail: correctionDetail(
                    prefix: "User edited an AI estimate before logging",
                    payload: payload
                ),
                confidence: event.confidence.map(CoachContextConfidence.from)
            )
        default:
            return nil
        }
    }

    private static func correctionDetail(prefix: String, payload: FoodLoggedPayload) -> String {
        var parts = [prefix, payload.name]
        if payload.calories > 0 {
            parts.append("\(payload.calories) kcal")
        }
        if let quantity = payload.quantity, let unit = payload.unit, !unit.isEmpty {
            parts.append("\(quantity) \(unit)")
        }
        return parts.joined(separator: " · ")
    }
}
