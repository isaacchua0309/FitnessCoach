//
//  HealthTrainingAuthorizationStatus.swift
//  Fitness Coach
//
//  Forma — HealthKit authorization status for training read access.
//

import Foundation

enum HealthTrainingAuthorizationStatus: Equatable, Sendable {
    case unavailable
    case notDetermined
    case sharingDenied
    case sharingAuthorized
}

extension HealthTrainingAuthorizationStatus {

    var integrationState: TrainingIntegrationState {
        switch self {
        case .unavailable:
            return .unavailable
        case .notDetermined:
            return .notConnected
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .connected
        }
    }
}
