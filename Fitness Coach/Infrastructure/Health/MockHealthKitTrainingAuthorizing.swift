//
//  MockHealthKitTrainingAuthorizing.swift
//  Fitness Coach
//
//  Forma — Test double for HealthKit training authorization.
//

import Foundation

final class MockHealthKitTrainingAuthorizing: HealthKitTrainingAuthorizing, @unchecked Sendable {

    var isHealthDataAvailable: Bool
    var status: HealthTrainingAuthorizationStatus
    var requestResult: HealthTrainingAuthorizationStatus?

    private(set) var requestCallCount = 0

    init(
        isHealthDataAvailable: Bool = true,
        status: HealthTrainingAuthorizationStatus = .notDetermined,
        requestResult: HealthTrainingAuthorizationStatus? = nil
    ) {
        self.isHealthDataAvailable = isHealthDataAvailable
        self.status = status
        self.requestResult = requestResult
    }

    func workoutReadAuthorizationStatus() -> HealthTrainingAuthorizationStatus {
        guard isHealthDataAvailable else { return .unavailable }
        return status
    }

    func resolveWorkoutReadAccess() async -> HealthTrainingAuthorizationStatus {
        workoutReadAuthorizationStatus()
    }

    func requestReadAuthorization() async -> HealthTrainingAuthorizationStatus {
        requestCallCount += 1
        guard isHealthDataAvailable else { return .unavailable }
        if let requestResult {
            status = requestResult
            return requestResult
        }
        return status
    }
}
