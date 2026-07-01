//
//  WeightEntryEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

extension WeightEntryEntity {

    convenience init(model: WeightEntry) {
        self.init(
            id: model.id,
            date: model.date,
            weightKg: model.weightKg,
            note: model.note,
            createdAt: model.createdAt
        )
    }

    func toModel() -> WeightEntry {
        WeightEntry(
            id: id,
            date: date,
            weightKg: weightKg,
            note: note,
            createdAt: createdAt
        )
    }
}
