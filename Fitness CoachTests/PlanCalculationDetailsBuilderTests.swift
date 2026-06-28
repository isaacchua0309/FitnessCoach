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
        XCTAssertTrue(labels.contains(where: { $0.contains("Estimated maintenance") }))
        XCTAssertTrue(labels.contains("Weight-loss pace"))
        XCTAssertTrue(labels.contains("Daily deficit"))
        XCTAssertTrue(labels.contains("Calorie target"))
        XCTAssertTrue(labels.contains("Protein target"))
        XCTAssertTrue(labels.contains("Water target"))
    }

    func testPersonalDetailsSectionUsesBirthdayDerivedAge() throws {
        let calendar = Calendar.current
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )

        let details = PlanCalculationDetailsBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )
        let personalSection = try XCTUnwrap(
            details.sections.first { $0.id == "personal" }
        )
        let ageRow = try XCTUnwrap(personalSection.rows.first { $0.id == "age" })

        XCTAssertEqual(ageRow.value, "28 years")
        XCTAssertEqual(ageRow.footnote, FormaProductCopy.PlanCalculation.personalDetailsAgeFromBirthday)
        XCTAssertFalse(personalSection.rows.contains { $0.label == FormaProductCopy.ProfileForm.bodyFat })
    }

    func testPersonalDetailsLegacyAgeUsesFallbackFootnote() throws {
        let profile = PlanMissionControlFixtures.legacyAgeOnlyProfile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let details = PlanCalculationDetailsBuilder.build(profile: profile, result: result)
        let ageRow = details.sections
            .flatMap(\.rows)
            .first { $0.id == "age" }

        XCTAssertNotNil(ageRow)
        XCTAssertEqual(ageRow?.footnote, FormaProductCopy.PlanCalculation.personalDetailsAgeLegacy)
    }

    func testModerateCutDetailsUseEngineExplanationFootnotes() throws {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let result = try FormaCalculationEngine.calculate(input)
        let profile = profileMatching(fixtureInput: input, result: result)

        let details = PlanCalculationDetailsBuilder.build(profile: profile, result: result)
        let rowsByID = Dictionary(
            uniqueKeysWithValues: details.sections.flatMap(\.rows).map { ($0.id, $0) }
        )

        XCTAssertEqual(rowsByID["bmr"]?.footnote, result.explanation.bmrLine)
        XCTAssertEqual(rowsByID["maintenance"]?.footnote, result.explanation.tdeeLine)
        XCTAssertEqual(rowsByID["pace"]?.footnote, result.explanation.lossRateLine)
        XCTAssertEqual(rowsByID["deficit"]?.footnote, result.explanation.dailyDeficitLine)
        XCTAssertEqual(rowsByID["calories"]?.footnote, result.explanation.calorieTargetLine)
        XCTAssertEqual(rowsByID["protein"]?.footnote, result.explanation.proteinLine)
        XCTAssertEqual(rowsByID["water"]?.footnote, result.explanation.waterLine)
    }

    func testAdvancedPaceDetailsUseCustomPaceLabel() throws {
        let input = FormaCalculationTestFixtures.advancedWeeklyCut
        let result = try FormaCalculationEngine.calculate(input)
        let profile = profileMatching(
            fixtureInput: input,
            result: result,
            aggressiveness: .moderate,
            expectedWeeklyLossKg: 0.55
        )

        let details = PlanCalculationDetailsBuilder.build(profile: profile, result: result)
        let paceRow = details.sections
            .flatMap(\.rows)
            .first { $0.id == "pace" }

        XCTAssertNotNil(paceRow)
        XCTAssertTrue(paceRow?.value.contains("Custom") == true)
        XCTAssertEqual(paceRow?.footnote, result.explanation.lossRateLine)
    }

    func testWaterAndProteinRowsArePresentWithFootnotes() throws {
        let profile = ProfilePreviewData.profile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let details = PlanCalculationDetailsBuilder.build(profile: profile, result: result)

        let proteinRow = details.sections.flatMap(\.rows).first { $0.id == "protein" }
        let waterRow = details.sections.flatMap(\.rows).first { $0.id == "water" }

        XCTAssertNotNil(proteinRow)
        XCTAssertNotNil(waterRow)
        XCTAssertFalse(proteinRow?.value.isEmpty ?? true)
        XCTAssertFalse(waterRow?.value.isEmpty ?? true)
        XCTAssertEqual(proteinRow?.footnote, result.explanation.proteinLine)
        XCTAssertEqual(waterRow?.footnote, result.explanation.waterLine)
    }

    func testRationaleIncludesCalculationDetails() throws {
        let profile = ProfilePreviewData.profile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        XCTAssertNotNil(rationale.calculationDetails)
        XCTAssertFalse(rationale.calculationDetails?.sections.isEmpty ?? true)
    }

    func testFallbackRationaleOmitsCalculationDetails() {
        let profile = invalidProfileForFallback()

        let rationale = PlanRationaleCopyBuilder.build(for: profile)

        XCTAssertNil(rationale.calculationDetails)
    }

    private func invalidProfileForFallback() -> UserProfile {
        UserProfile(
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
    }

    private func profileMatching(
        fixtureInput input: PlanCalculationInput,
        result: PlanCalculationResult,
        aggressiveness: CalorieAggressiveness = .moderate,
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
