//
//  UserProfile.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct UserProfile: Codable, Identifiable, Equatable, Sendable {

    // MARK: Identity

    let id: UUID
    /// Firebase UID that owns this on-device profile, when known. `nil` for pre-auth, legacy, or uncertain ownership.
    var ownerUID: String? = nil

    // MARK: Baseline

    var name: String?
    /// Source of truth for age when set. Legacy profiles may have `nil` until edited.
    var birthDate: Date? = nil
    var age: Int
    var sex: Sex
    var heightCm: Double
    var currentWeightKg: Double
    var goalWeightKg: Double
    var estimatedBodyFatPercentage: Double?

    // MARK: Activity

    var activityLevel: ActivityLevel
    var trainingFrequencyPerWeek: Int
    var averageSteps: Int

    // MARK: Preferences

    var dietPreference: String?
    var unitSystem: UnitSystem

    // MARK: Targets

    var targets: UserTargets

    // MARK: Metadata

    var createdAt: Date
    var updatedAt: Date
    /// Why the plan was last recalculated, when known.
    var lastPlanUpdateReason: PlanLastUpdateReason? = nil
}
