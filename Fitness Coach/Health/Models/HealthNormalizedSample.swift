//
//  HealthNormalizedSample.swift
//  Fitness Coach
//
//  Forma — App-facing normalized Health samples (HealthKit-agnostic).
//

import Foundation

enum HealthSampleKind: String, Equatable, Sendable, Codable {
    case stepCount
    case activeEnergy
    case exerciseTime
    case workout
    case heartRate
    case restingHeartRate
    case sleep
    case unknown
}

struct HealthNormalizedSample: Equatable, Sendable, Identifiable {
    let id: UUID
    let kind: HealthSampleKind
    let startDate: Date
    let endDate: Date
    let value: Double
    let unitSymbol: String
    let sourceBundleIdentifier: String?

    init(
        id: UUID = UUID(),
        kind: HealthSampleKind,
        startDate: Date,
        endDate: Date,
        value: Double,
        unitSymbol: String,
        sourceBundleIdentifier: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.unitSymbol = unitSymbol
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }
}
