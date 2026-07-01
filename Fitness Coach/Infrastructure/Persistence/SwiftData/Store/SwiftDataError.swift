//
//  SwiftDataError.swift
//  Fitness Coach
//
//  FitPilot AI — Persistence-level error type.
//

import Foundation

enum SwiftDataError: Error, Equatable {
    case saveFailed
    case fetchFailed
    case deleteFailed
    case mappingFailed
    case modelNotFound
}
