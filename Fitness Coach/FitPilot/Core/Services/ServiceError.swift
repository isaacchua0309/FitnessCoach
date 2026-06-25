//
//  ServiceError.swift
//  Fitness Coach
//
//  FitPilot AI — App-facing service error type.
//

import Foundation

enum ServiceError: Error, Equatable {
    case missingUserProfile
    case dailyLogNotFound
    case foodEntryNotFound
    case waterEntryNotFound
    case weightEntryNotFound
    case workoutEntryNotFound
    case invalidInput(String)
    case persistenceFailed(String)
    case calculationFailed(String)
}
