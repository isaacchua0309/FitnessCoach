//
//  MockHealthKitStepReader.swift
//  Fitness Coach
//
//  Forma — Test double for Apple Health step reads.
//

import Foundation

final class MockHealthKitStepReader: HealthKitStepReading, @unchecked Sendable {

    var stepCount: Int
    var error: Error?

    private(set) var fetchCallCount = 0
    private(set) var lastFetchRange: (start: Date, end: Date)?

    init(stepCount: Int = 0, error: Error? = nil) {
        self.stepCount = stepCount
        self.error = error
    }

    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        fetchCallCount += 1
        lastFetchRange = (startDate, endDate)
        if let error { throw error }
        return stepCount
    }
}
