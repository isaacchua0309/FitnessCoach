//
//  WeightLogRepository.swift
//  Fitness Coach
//
//  Domain protocols for weight entry reads.
//

import Foundation

@MainActor
protocol WeightLogReading: AnyObject {
    func getWeightEntries(from startDate: Date, to endDate: Date) throws -> [WeightEntry]
}

extension WeightLogService: WeightLogReading {}
