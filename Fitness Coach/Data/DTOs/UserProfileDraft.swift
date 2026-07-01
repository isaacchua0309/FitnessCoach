//
//  UserProfileDraft.swift
//  Fitness Coach
//
//  FitPilot AI — App-facing input for creating a user profile.
//

import Foundation

struct UserProfileDraft: Codable, Equatable, Sendable {
    var name: String?
    var birthDate: Date? = nil
    var age: Int
    var sex: Sex
    var heightCm: Double
    var currentWeightKg: Double
    var goalWeightKg: Double
    var estimatedBodyFatPercentage: Double?
    var activityLevel: ActivityLevel
    var trainingFrequencyPerWeek: Int
    var averageSteps: Int
    var dietPreference: String?
    var unitSystem: UnitSystem
    var targets: UserTargets
}
