//
//  PlanCalculationDetailsBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Tests for calculation details sheet content.
//

import XCTest
@testable import Fitness_Coach

final class PlanCalculationDetailsBuilderTests: XCTestCase {

    func testCutDetailsIncludeRequiredFields() throws {
        let profile = ProfilePreviewData.profile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let details = PlanCalculationDetailsBuilder.build(profile: profile, result: result)

        XCTAssertEqual(details.disclaimer, PlanCalculationDetailsState.defaultDisclaimer)

        let labels = details.sections.flatMap(\.rows).map(\.label)
        XCTAssertTrue(labels.contains("Resting burn (BMR)"))
        XCTAssertTrue(labels.contains("Activity level"))
        XCTAssertTrue(labels.contains("Estimated maintenance"))
        XCTAssertTrue(labels.contains("Weight-loss pace"))
        XCTAssertTrue(labels.contains("Daily deficit"))
        XCTAssertTrue(labels.contains("Calorie target"))
        XCTAssertTrue(labels.contains("Protein target"))
        XCTAssertTrue(labels.contains("Water target"))
    }

    func testProteinRowIncludesPerKgFootnote() throws {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let result = try FormaCalculationEngine.calculate(input)
        let profile = profileMatching(fixtureInput: input, result: result)

        let details = PlanCalculationDetailsBuilder.build(profile: profile, result: result)
        let proteinRow = details.sections
            .flatMap(\.rows)
            .first { $0.label == "Protein target" }

        XCTAssertNotNil(proteinRow?.footnote)
        XCTAssertTrue(proteinRow?.footnote?.contains("g per kg") == true)
    }

    func testRationaleIncludesCalculationDetails() throws {
        let profile = ProfilePreviewData.profile
        let rationale = PlanRationaleCopyBuilder.build(for: profile)

        XCTAssertNotNil(rationale.calculationDetails)
        XCTAssertFalse(rationale.calculationDetails?.sections.isEmpty ?? true)
    }

    func testFallbackRationaleOmitsCalculationDetails() {
        let profile = UserProfile(
            id: UUID(),
            name: nil,
            age: 0,
            sex: .male,
            heightCm: 0,
            currentWeightKg: 0,
            goalWeightKg: 0,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 5000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 2000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2500,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            createdAt: Date(),
            updatedAt: Date()
        )

        let rationale = PlanRationaleCopyBuilder.build(for: profile)

        XCTAssertNil(rationale.calculationDetails)
    }

    private func profileMatching(
        fixtureInput input: PlanCalculationInput,
        result: PlanCalculationResult
    ) -> UserProfile {
        UserProfile(
            id: UUID(),
            name: "Test",
            age: input.ageYears,
            sex: input.sex,
            heightCm: input.heightCm,
            currentWeightKg: input.weightKg,
            goalWeightKg: input.goalWeightKg,
            estimatedBodyFatPercentage: input.bodyFatPercent,
            activityLevel: input.activityLevel,
            trainingFrequencyPerWeek: input.trainingFrequencyPerWeek,
            averageSteps: input.averageStepsPerDay,
            dietPreference: input.dietPreference,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: result.calorieTargetKcal,
                proteinTarget: result.proteinTargetG,
                carbTarget: result.carbTargetG,
                fatTarget: result.fatTargetG,
                waterTargetMl: result.waterTargetMl,
                expectedWeeklyWeightLossKg: result.weightLossRateKgPerWeek,
                aggressiveness: .moderate
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
