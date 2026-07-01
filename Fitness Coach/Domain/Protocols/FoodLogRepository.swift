//
//  FoodLogRepository.swift
//  Fitness Coach
//
//  Domain protocols for food entry reads.
//

import Foundation

@MainActor
protocol FoodLogReading: AnyObject {
    func getFoodEntries(for date: Date) throws -> [FoodEntry]
}

extension FoodLogService: FoodLogReading {}
