//
//  ProfileTestFixtures.swift
//  Fitness CoachTests
//
//  Shared profile drafts and models for bootstrap / routing tests.
//

import Foundation
@testable import Fitness_Coach

enum ProfileTestFixtures {

    static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    static var sampleTargets: UserTargets {
        UserTargets(
            calorieTarget: 1800,
            proteinTarget: 130,
            carbTarget: 170,
            fatTarget: 55,
            waterTargetMl: 2400,
            expectedWeeklyWeightLossKg: 0.34,
            aggressiveness: .moderate
        )
    }

    static var sampleDraft: UserProfileDraft {
        UserProfileDraft(
            name: "Alex",
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: sampleTargets
        )
    }

    static var sampleProfile: UserProfile {
        UserProfile(
            id: UUID(),
            name: "Alex",
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: sampleTargets,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    static func cloudDocument(
        for profile: UserProfile = sampleProfile,
        referenceDate: Date = referenceDate
    ) -> CloudUserProfileDocument {
        CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )
    }
}
