//
//  MockHealthKitWorkoutReader.swift
//  Fitness Coach
//
//  Forma — Test double for Apple Health workout reads.
//

import Foundation

final class MockHealthKitWorkoutReader: HealthKitWorkoutReading, @unchecked Sendable {

    var workouts: [HealthWorkoutRecord]
    var error: Error?

    private(set) var fetchCallCount = 0
    private(set) var lastFetchRange: (start: Date, end: Date)?

    init(workouts: [HealthWorkoutRecord] = [], error: Error? = nil) {
        self.workouts = workouts
        self.error = error
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        fetchCallCount += 1
        lastFetchRange = (startDate, endDate)
        if let error { throw error }
        return workouts.filter { $0.startDate >= startDate && $0.startDate <= endDate }
    }
}
