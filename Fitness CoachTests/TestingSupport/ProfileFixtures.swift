//
//  ProfileFixtures.swift
//  Fitness CoachTests
//
//  Shared profile drafts, models, and cloud documents for bootstrap / routing tests.
//

import Foundation
@testable import Fitness_Coach

enum ProfileFixtures {

    static let referenceDate = TestDateFixtures.referenceEpoch

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

    static var alternateTargets: UserTargets {
        UserTargets(
            calorieTarget: 2_100,
            proteinTarget: 145,
            carbTarget: 185,
            fatTarget: 62,
            waterTargetMl: 2_800,
            expectedWeeklyWeightLossKg: 0.52,
            aggressiveness: .aggressive
        )
    }

    static var nutritionSummaryTargets: UserTargets {
        UserTargets(
            calorieTarget: 2_000,
            proteinTarget: 150,
            carbTarget: 200,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: 0.45,
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
            birthDate: TestDateFixtures.utcCalendar().date(
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
            birthDate: TestDateFixtures.utcCalendar().date(
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

extension UserTargets {
    func withCalories(_ calories: Int) -> UserTargets {
        UserTargets(
            calorieTarget: calories,
            proteinTarget: proteinTarget,
            carbTarget: carbTarget,
            fatTarget: fatTarget,
            waterTargetMl: waterTargetMl,
            expectedWeeklyWeightLossKg: expectedWeeklyWeightLossKg,
            aggressiveness: aggressiveness
        )
    }
}
