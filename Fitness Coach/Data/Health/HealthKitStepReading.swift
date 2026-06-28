//
//  HealthKitStepReading.swift
//  Fitness Coach
//
//  Forma — Read-only Apple Health step count access.
//

import Foundation

protocol HealthKitStepReading: Sendable {
    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int
}
