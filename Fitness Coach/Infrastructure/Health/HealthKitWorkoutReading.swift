//
//  HealthKitWorkoutReading.swift
//  Fitness Coach
//
//  Forma — Protocol for reading workout samples from Apple Health.
//

import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

protocol HealthKitWorkoutReading: Sendable {
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord]
}

// MARK: - Optional access policy

/// Apple Health workout reads are optional; Today and other surfaces must not fail when access is missing.
enum HealthKitOptionalAccessPolicy {

    nonisolated static func isOptionalAccessFailure(_ error: Error) -> Bool {
        #if canImport(HealthKit)
        if let hkError = error as? HKError {
            switch hkError.code {
            case .errorAuthorizationNotDetermined, .errorAuthorizationDenied:
                return true
            default:
                return false
            }
        }
        let nsError = error as NSError
        if nsError.domain == HKError.errorDomain,
           let code = HKError.Code(rawValue: nsError.code) {
            switch code {
            case .errorAuthorizationNotDetermined, .errorAuthorizationDenied:
                return true
            default:
                return false
            }
        }
        #else
        let nsError = error as NSError
        if nsError.domain == "com.apple.healthkit", nsError.code == 5 {
            return true
        }
        #endif
        return false
    }
}
