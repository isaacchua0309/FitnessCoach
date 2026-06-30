//
//  WaterEntryEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

extension WaterEntryEntity {

    convenience init(model: WaterEntry) {
        self.init(
            id: model.id,
            dailyLogId: model.dailyLogId,
            amountMl: model.amountMl,
            createdAt: model.createdAt
        )
    }

    func toModel() -> WaterEntry {
        WaterEntry(
            id: id,
            dailyLogId: dailyLogId,
            amountMl: amountMl,
            createdAt: createdAt
        )
    }
}
