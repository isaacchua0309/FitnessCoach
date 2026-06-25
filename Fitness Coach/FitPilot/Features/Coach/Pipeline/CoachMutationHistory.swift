//
//  CoachMutationHistory.swift
//  Fitness Coach
//
//  FitPilot AI — current-session mutation history for Coach undo routing.
//

import Foundation

enum CoachMutationEntryType: Equatable, Sendable {
    case food
    case water
    case weight
    case workout
}

struct CoachMutationRecord: Identifiable, Equatable, Sendable {
    var id: UUID
    var entryId: UUID
    var entryType: CoachMutationEntryType
    var timestamp: Date
    var summary: String
}

final class CoachMutationHistory {
    private var records: [CoachMutationRecord] = []
    private let limit: Int

    init(limit: Int = 25) {
        self.limit = limit
    }

    func record(entryId: UUID, type: CoachMutationEntryType, summary: String, timestamp: Date = Date()) {
        records.append(
            CoachMutationRecord(
                id: UUID(),
                entryId: entryId,
                entryType: type,
                timestamp: timestamp,
                summary: summary
            )
        )
        if records.count > limit {
            records.removeFirst(records.count - limit)
        }
    }

    func latest(type: CoachMutationEntryType? = nil) -> CoachMutationRecord? {
        records.reversed().first { record in
            guard let type else { return true }
            return record.entryType == type
        }
    }

    func remove(id: UUID) {
        records.removeAll { $0.id == id }
    }
}
