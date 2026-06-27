//
//  PlanRationaleCopyBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Tests for plan rationale copy.
//

import XCTest
@testable import Fitness_Coach

final class PlanRationaleCopyBuilderTests: XCTestCase {

    func testCutSummaryIncludesWeightActivityPaceAndTargets() throws {
        let profile = ProfilePreviewData.profile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        XCTAssertTrue(rationale.summary.contains("90 kg"))
        XCTAssertTrue(rationale.summary.contains("moderately active"))
        XCTAssertTrue(rationale.summary.contains("maintenance"))
        XCTAssertTrue(
            rationale.summary.contains("aggressive")
                || rationale.summary.contains("custom pace")
        )
        XCTAssertTrue(rationale.summary.contains("kcal"))
        XCTAssertTrue(rationale.summary.contains("Protein"))
        XCTAssertTrue(rationale.summary.contains("ml"))
        XCTAssertNotNil(rationale.calculationDetails)
    }

    func testModerateCutSummaryUsesEngineNumbers() throws {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let result = try FormaCalculationEngine.calculate(input)
        let profile = profileMatching(fixtureInput: input, result: result, aggressiveness: .moderate)

        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        XCTAssertTrue(rationale.summary.contains("moderate"))
        XCTAssertTrue(rationale.summary.contains("deficit"))
        XCTAssertTrue(rationale.summary.contains("maintenance"))

        let formattedTarget = NumberFormatter.localizedString(
            from: NSNumber(value: result.calorieTargetKcal),
            number: .decimal
        )
        XCTAssertTrue(rationale.summary.contains(formattedTarget))

        let formattedDeficit = NumberFormatter.localizedString(
            from: NSNumber(value: result.dailyDeficitKcal),
            number: .decimal
        )
        XCTAssertTrue(rationale.summary.contains(formattedDeficit))
        XCTAssertNotNil(rationale.sustainabilityNote)
    }

    func testAdvancedPaceSummaryMentionsCustomPace() throws {
        let input = FormaCalculationTestFixtures.advancedWeeklyCut
        let result = try FormaCalculationEngine.calculate(input)
        let profile = profileMatching(
            fixtureInput: input,
            result: result,
            aggressiveness: .moderate,
            expectedWeeklyLossKg: 0.55
        )

        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        XCTAssertTrue(rationale.summary.contains("custom pace"))
        XCTAssertTrue(rationale.summary.contains("kg/week"))
        XCTAssertEqual(
            rationale.calculationDetails?
                .sections
                .flatMap(\.rows)
                .first { $0.id == "pace" }?
                .value
                .contains("Custom"),
            true
        )
    }

    func testSummaryUsesEngineCalorieTarget() throws {
        let profile = ProfilePreviewData.profile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        let formatted = NumberFormatter.localizedString(
            from: NSNumber(value: result.calorieTargetKcal),
            number: .decimal
        )
        XCTAssertTrue(
            rationale.summary.contains(formatted),
            "Expected calorie target \(formatted) in summary"
        )
    }

    func testSustainablePaceIncludesRecoveryNote() throws {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let result = try FormaCalculationEngine.calculate(input)
        let profile = profileMatching(fixtureInput: input, result: result, aggressiveness: .moderate)

        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        XCTAssertEqual(
            rationale.sustainabilityNote,
            "This pace is designed to be sustainable alongside your training and recovery."
        )
    }

    func testFallbackWhenCalculationFails() {
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

        XCTAssertTrue(rationale.summary.contains("2,000 kcal/day") || rationale.summary.contains("2000 kcal/day"))
        XCTAssertNil(rationale.calculationDetails)
        XCTAssertNotNil(rationale.sustainabilityNote)
    }

    private func profileMatching(
        fixtureInput input: PlanCalculationInput,
        result: PlanCalculationResult,
        aggressiveness: CalorieAggressiveness,
        expectedWeeklyLossKg: Double? = nil
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
                expectedWeeklyWeightLossKg: expectedWeeklyLossKg ?? result.weightLossRateKgPerWeek,
                aggressiveness: aggressiveness
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
