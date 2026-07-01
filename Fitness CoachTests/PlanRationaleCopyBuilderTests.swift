//
//  PlanRationaleCopyBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Tests for plan rationale copy.
//

import XCTest
@testable import Fitness_Coach

final class PlanRationaleCopyBuilderTests: XCTestCase {

    func testCutHighlightsIncludeMaintenanceDeficitTargetProteinAndWater() throws {
        let profile = PlanPreviewData.profile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        XCTAssertTrue(rationale.usesHighlightLayout)
        let highlights = try XCTUnwrap(rationale.highlights)
        XCTAssertEqual(highlights.map(\.id), ["maintenance", "deficit", "target", "protein", "water"])
        XCTAssertEqual(highlights[0].label, FormaProductCopy.PlanRationale.maintenanceEstimate)
        XCTAssertEqual(highlights[1].label, FormaProductCopy.PlanRationale.healthyDeficit)
        XCTAssertEqual(highlights[2].label, FormaProductCopy.PlanRationale.dailyTarget)
        XCTAssertTrue(highlights[0].value.contains("kcal"))
        XCTAssertTrue(highlights[3].value.contains("g"))
        XCTAssertTrue(highlights[3].value.contains(FormaProductCopy.PlanRationale.proteinRecoverySuffix))
        XCTAssertTrue(highlights[4].value.contains("ml/day"))
        XCTAssertTrue(rationale.usesVisualFlowLayout)
        XCTAssertNotNil(rationale.calculationDetails)
    }

    func testModerateCutHighlightsUseEngineNumbers() throws {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let result = try FormaCalculationEngine.calculate(input)
        let profile = profileMatching(fixtureInput: input, result: result, aggressiveness: .moderate)

        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)
        let highlights = try XCTUnwrap(rationale.highlights)

        let formattedTarget = NumberFormatter.localizedString(
            from: NSNumber(value: result.calorieTargetKcal),
            number: .decimal
        )
        let formattedDeficit = NumberFormatter.localizedString(
            from: NSNumber(value: result.dailyDeficitKcal),
            number: .decimal
        )
        let formattedMaintenance = NumberFormatter.localizedString(
            from: NSNumber(value: result.tdeeKcal),
            number: .decimal
        )

        XCTAssertTrue(highlights.first { $0.id == "maintenance" }?.value.contains(formattedMaintenance) == true)
        XCTAssertTrue(highlights.first { $0.id == "deficit" }?.value.contains(formattedDeficit) == true)
        XCTAssertTrue(highlights.first { $0.id == "target" }?.value.contains(formattedTarget) == true)
        XCTAssertNotNil(rationale.sustainabilityNote)
    }

    func testAdvancedPaceSummaryMentionsCustomPaceInParagraphFallback() throws {
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
        XCTAssertTrue(rationale.usesHighlightLayout)
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

    func testHighlightsUseEngineCalorieTarget() throws {
        let profile = PlanPreviewData.profile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        let formatted = NumberFormatter.localizedString(
            from: NSNumber(value: result.calorieTargetKcal),
            number: .decimal
        )
        let targetValue = rationale.highlights?.first { $0.id == "target" }?.value
        XCTAssertTrue(
            targetValue?.contains(formatted) == true,
            "Expected calorie target \(formatted) in highlights"
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

        XCTAssertFalse(rationale.usesHighlightLayout)
        XCTAssertNil(rationale.highlights)
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
