//
//  HealthKitWorkoutReading.swift
//  Fitness Coach
//
//  Forma — Protocol for reading workout samples from Apple Health.
//

import Foundation

protocol HealthKitWorkoutReading: Sendable {
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord]
}
