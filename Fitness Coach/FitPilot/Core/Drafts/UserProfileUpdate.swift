//
//  UserProfileUpdate.swift
//  Fitness Coach
//
//  FitPilot AI — Optional edits applied to an existing user profile.
//
//  MVP semantics: a nil field means "do not change".
//

import Foundation

struct UserProfileUpdate: Codable, Equatable, Sendable {
    var name: String?
    var age: Int?
    var sex: Sex?
    var heightCm: Double?
    var currentWeightKg: Double?
    var goalWeightKg: Double?
    var estimatedBodyFatPercentage: Double?
    var activityLevel: ActivityLevel?
    var trainingFrequencyPerWeek: Int?
    var averageSteps: Int?
    var dietPreference: String?
    var unitSystem: UnitSystem?
    var targets: UserTargets?
}
