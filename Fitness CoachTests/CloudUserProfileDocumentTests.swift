//
//  CloudUserProfileDocumentTests.swift
//  Fitness CoachTests
//
//  FitPilot — Round-trip tests for cloud profile DTO mapping.
//

import XCTest
@testable import Fitness_Coach

final class CloudUserProfileDocumentTests: XCTestCase {

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testRoundTripPreservesProfileFields() {
        let profile = sampleProfile
        let document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )
        let restored = document.makeUserProfile()

        XCTAssertEqual(restored.name, profile.name)
        XCTAssertEqual(restored.birthDate, profile.birthDate)
        XCTAssertEqual(restored.age, profile.age)
        XCTAssertEqual(restored.sex, profile.sex)
        XCTAssertEqual(restored.heightCm, profile.heightCm)
        XCTAssertEqual(restored.currentWeightKg, profile.currentWeightKg)
        XCTAssertEqual(restored.goalWeightKg, profile.goalWeightKg)
        XCTAssertEqual(restored.estimatedBodyFatPercentage, profile.estimatedBodyFatPercentage)
        XCTAssertEqual(restored.activityLevel, profile.activityLevel)
        XCTAssertEqual(restored.trainingFrequencyPerWeek, profile.trainingFrequencyPerWeek)
        XCTAssertEqual(restored.averageSteps, profile.averageSteps)
        XCTAssertEqual(restored.dietPreference, profile.dietPreference)
        XCTAssertEqual(restored.unitSystem, profile.unitSystem)
        XCTAssertEqual(restored.targets, profile.targets)
        XCTAssertEqual(restored.createdAt, referenceDate)
        XCTAssertEqual(restored.updatedAt, referenceDate)
    }

    func testAdvancedPaceFieldsSurviveRoundTrip() {
        var profile = sampleProfile
        profile.targets.expectedWeeklyWeightLossKg = 0.42
        profile.targets.aggressiveness = .moderate

        let document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: referenceDate,
            updatedAt: referenceDate
        )
        let restored = document.makeUserProfile()

        XCTAssertEqual(restored.targets.expectedWeeklyWeightLossKg, 0.42)
        XCTAssertEqual(restored.targets.aggressiveness, .moderate)
    }

    private var sampleProfile: UserProfile {
        UserProfile(
            id: UUID(),
            name: "Alex",
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: 24,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7000,
            dietPreference: "High protein",
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 1800,
                proteinTarget: 130,
                carbTarget: 170,
                fatTarget: 55,
                waterTargetMl: 2400,
                expectedWeeklyWeightLossKg: 0.34,
                aggressiveness: .moderate
            ),
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }
}
