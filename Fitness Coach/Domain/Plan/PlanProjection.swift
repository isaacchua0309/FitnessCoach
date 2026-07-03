//
//  PlanProjection.swift
//  Fitness Coach
//
//  Forma — Live plan projection for the Edit / Adjust Plan flow.
//

import Foundation
import SwiftUI

/// Unified projection surfaced across Edit Plan screens.
///
/// Numeric fields are `nil` when inputs are incomplete; labels use friendly copy, never raw enum IDs.
struct PlanProjection: Equatable, Sendable {
    let goalLabel: String
    let goalDirection: PlanGoalDirection?

    let currentWeightDisplay: String
    let targetWeightDisplay: String
    let weightToLoseOrGainKg: Double?
    let weightChangeLabel: String?
    let weeklyRateKg: Double?
    let monthlyRateKg: Double?
    let estimatedWeeks: Int?
    let estimatedCompletionDate: Date?
    let estimatedCompletionLabel: String?

    /// Signed energy balance: negative = deficit (cut), positive = surplus (gain), zero = maintenance.
    let dailyDeficitOrSurplusKcal: Int?
    let dailyDeficitOrSurplusLabel: String?

    let maintenanceCalories: Int?
    let targetCalories: Int?
    let proteinTargetG: Double?
    let carbTargetG: Double?
    let fatTargetG: Double?
    let waterTargetMl: Int?

    let difficultyLabel: String
    let difficultyDescription: String
    let adherenceEstimate: String
    let recoveryImpact: String
    let hungerImpact: String

    let isCalculationComplete: Bool
    let validationMessage: String?
}

extension PlanProjection {

    static func incomplete(goalType: PlanGoalType) -> PlanProjection {
        PlanProjectionBuilder.build(
            formState: .defaultDraftValues(),
            goalType: goalType
        )
    }

    var hasPaceMetrics: Bool {
        weeklyRateKg != nil
            || monthlyRateKg != nil
            || dailyDeficitOrSurplusLabel != nil
    }

    var hasEnergyTargets: Bool {
        maintenanceCalories != nil || targetCalories != nil
    }

    var hasMacroTargets: Bool {
        proteinTargetG != nil || carbTargetG != nil || fatTargetG != nil || waterTargetMl != nil
    }
}

// MARK: - Environment

private struct PlanProjectionEnvironmentKey: EnvironmentKey {
    static let defaultValue: PlanProjection? = nil
}

extension EnvironmentValues {
    var planProjection: PlanProjection? {
        get { self[PlanProjectionEnvironmentKey.self] }
        set { self[PlanProjectionEnvironmentKey.self] = newValue }
    }
}
