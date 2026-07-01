//
//  CloudUserProfileDocument.swift
//  Fitness Coach
//
//  FitPilot — Firestore DTO for a single user profile snapshot.
//

import Foundation

struct CloudUserProfileDocument: Codable, Equatable, Sendable {

    var name: String?
    var birthDate: Date?
    var age: Int
    var sex: String
    var heightCm: Double
    var currentWeightKg: Double
    var goalWeightKg: Double
    var estimatedBodyFatPercentage: Double?
    var activityLevel: String
    var trainingFrequencyPerWeek: Int
    var averageSteps: Int
    var dietPreference: String?
    var unitSystem: String
    var targets: CloudUserTargets
    var onboardingCompletedAt: Date
    var updatedAt: Date
}

struct CloudUserTargets: Codable, Equatable, Sendable {
    var calorieTarget: Int
    var proteinTarget: Double
    var carbTarget: Double
    var fatTarget: Double
    var waterTargetMl: Int
    var expectedWeeklyWeightLossKg: Double?
    var aggressiveness: String
}

extension CloudUserProfileDocument {

    static let currentDocumentID = "current"

    init(profile: UserProfile, onboardingCompletedAt: Date, updatedAt: Date) {
        name = profile.name
        birthDate = profile.birthDate
        age = profile.resolvedAge(referenceDate: updatedAt)
        sex = profile.sex.rawValue
        heightCm = profile.heightCm
        currentWeightKg = profile.currentWeightKg
        goalWeightKg = profile.goalWeightKg
        estimatedBodyFatPercentage = profile.estimatedBodyFatPercentage
        activityLevel = profile.activityLevel.rawValue
        trainingFrequencyPerWeek = profile.trainingFrequencyPerWeek
        averageSteps = profile.averageSteps
        dietPreference = profile.dietPreference
        unitSystem = profile.unitSystem.rawValue
        targets = CloudUserTargets(targets: profile.targets)
        self.onboardingCompletedAt = onboardingCompletedAt
        self.updatedAt = updatedAt
    }

    func makeUserProfile(now: Date = Date()) -> UserProfile {
        UserProfile(
            id: UUID(),
            name: name,
            birthDate: birthDate,
            age: age,
            sex: Sex(rawValue: sex) ?? .preferNotToSay,
            heightCm: heightCm,
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            estimatedBodyFatPercentage: estimatedBodyFatPercentage,
            activityLevel: ActivityLevel(rawValue: activityLevel) ?? .moderatelyActive,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek,
            averageSteps: averageSteps,
            dietPreference: dietPreference,
            unitSystem: UnitSystem(rawValue: unitSystem) ?? .metric,
            targets: targets.makeUserTargets(),
            createdAt: onboardingCompletedAt,
            updatedAt: updatedAt
        )
    }
}

extension CloudUserTargets {

    init(targets: UserTargets) {
        calorieTarget = targets.calorieTarget
        proteinTarget = targets.proteinTarget
        carbTarget = targets.carbTarget
        fatTarget = targets.fatTarget
        waterTargetMl = targets.waterTargetMl
        expectedWeeklyWeightLossKg = targets.expectedWeeklyWeightLossKg
        aggressiveness = targets.aggressiveness.rawValue
    }

    func makeUserTargets() -> UserTargets {
        UserTargets(
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            carbTarget: carbTarget,
            fatTarget: fatTarget,
            waterTargetMl: waterTargetMl,
            expectedWeeklyWeightLossKg: expectedWeeklyWeightLossKg,
            aggressiveness: CalorieAggressiveness(rawValue: aggressiveness) ?? .moderate
        )
    }
}
