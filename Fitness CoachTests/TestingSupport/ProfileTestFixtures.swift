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

    static var onboardingSampleDraft: UserProfileDraft {
        UserProfileDraft(
            name: "Alex",
            birthDate: Calendar(identifier: .gregorian).date(
                from: DateComponents(year: 1990, month: 6, day: 15)
            ),
            age: 35,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 7500,
            dietPreference: nil,
            unitSystem: .metric,
            targets: sampleTargets
        )
    }

    static var onboardingSampleProfile: UserProfile {
        UserProfile(
            id: UUID(),
            name: "Alex",
            birthDate: Calendar(identifier: .gregorian).date(
                from: DateComponents(year: 1990, month: 6, day: 15)
            ),
            age: 35,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 7500,
            dietPreference: nil,
            unitSystem: .metric,
            targets: sampleTargets,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    static func legacyAgeOnlyCloudDocument(
        referenceDate: Date = referenceDate
    ) -> CloudUserProfileDocument {
        var profile = sampleProfile
        profile.birthDate = nil
        profile.age = 45
        return cloudDocument(for: profile, referenceDate: referenceDate)
    }

    static func legacyCloudDocumentMissingActivityRhythm(
        activityLevel: ActivityLevel = .moderatelyActive,
        referenceDate: Date = referenceDate
    ) -> CloudUserProfileDocument {
        var profile = sampleProfile
        profile.birthDate = nil
        profile.age = 52
        profile.activityLevel = activityLevel
        profile.trainingFrequencyPerWeek = 0
        profile.averageSteps = 0
        return cloudDocument(for: profile, referenceDate: referenceDate)
    }

    static func legacyCloudDocumentWithAdvancedTargets(
        referenceDate: Date = referenceDate
    ) -> CloudUserProfileDocument {
        var profile = sampleProfile
        profile.birthDate = nil
        profile.age = 38
        profile.targets = UserTargets(
            calorieTarget: 1650,
            proteinTarget: 125,
            carbTarget: 155,
            fatTarget: 52,
            waterTargetMl: 2200,
            expectedWeeklyWeightLossKg: 0.55,
            aggressiveness: .aggressive
        )
        return cloudDocument(for: profile, referenceDate: referenceDate)
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
