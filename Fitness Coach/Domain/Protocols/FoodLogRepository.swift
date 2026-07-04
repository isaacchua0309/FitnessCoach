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
    func getFoodEntries(from startDate: Date, to endDate: Date, calendar: Calendar) throws -> [FoodEntry]
}

extension FoodLogService: FoodLogReading {}
