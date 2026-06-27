//
//  OnboardingPlanRevealBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Onboarding plan reveal presentation builder tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingPlanRevealBuilderTests: XCTestCase {

    // MARK: - Cut goal

    func testCutGoalShowsWeeklyLossAndEstimatedWeeks() throws {
        var form = cutForm(currentWeightKg: 82.5, goalWeightKg: 75)
        form.selectPaceChoice(.moderate)

        let plan = CalorieTargetResult(
            estimatedBMR: 1800,
            estimatedTDEE: 2500,
            targets: UserTargets(
                calorieTarget: 2000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2800,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            estimatedDailyDeficit: 500,
            isAggressive: false,
            warning: nil
        )

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertEqual(reveal.currentWeightLabel, "82.5 kg")
        XCTAssertEqual(reveal.goalWeightLabel, "75 kg")
        XCTAssertTrue(reveal.weeklyChangeLabel?.contains("0.5") == true)
        XCTAssertTrue(reveal.weeklyChangeLabel?.contains("kg/week") == true)
        XCTAssertEqual(reveal.estimatedWeeksLabel, "About 15 weeks")
        XCTAssertTrue(reveal.journeySummaryLine.contains("starting targets"))
    }

    // MARK: - Maintain / gain

    func testMaintainGoalHidesLossTimeline() throws {
        let form = bodyForm(currentWeightKg: 72, goalWeightKg: 72)
        let plan = try samplePlan(for: form)

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertNil(reveal.weeklyChangeLabel)
        XCTAssertNil(reveal.estimatedWeeksLabel)
        XCTAssertTrue(reveal.journeySummaryLine.contains("maintaining around 72 kg"))
    }

    func testGainGoalHidesLossTimeline() throws {
        let form = bodyForm(currentWeightKg: 72, goalWeightKg: 78)
        let plan = try samplePlan(for: form)

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertNil(reveal.weeklyChangeLabel)
        XCTAssertNil(reveal.estimatedWeeksLabel)
        XCTAssertTrue(reveal.journeySummaryLine.contains("building toward 78 kg"))
    }

    // MARK: - Missing weekly loss

    func testMissingWeeklyLossHandlesSafely() throws {
        var form = cutForm(currentWeightKg: 82.5, goalWeightKg: 75)
        form.selectPaceChoice(.advanced)
        form.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "")

        let plan = CalorieTargetResult(
            estimatedBMR: 1800,
            estimatedTDEE: 2500,
            targets: UserTargets(
                calorieTarget: 2000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2800,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            estimatedDailyDeficit: 500,
            isAggressive: false,
            warning: nil
        )

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertNil(reveal.weeklyChangeLabel)
        XCTAssertNil(reveal.estimatedWeeksLabel)
    }

    // MARK: - Target rows

    func testPrimaryAndSecondaryTargetRowsArePresent() throws {
        let form = cutForm(currentWeightKg: 72, goalWeightKg: 65)
        let plan = try samplePlan(for: form)

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertFalse(reveal.proteinLabel.isEmpty)
        XCTAssertFalse(reveal.waterLabel.isEmpty)
        XCTAssertEqual(reveal.secondaryMacroRows.map(\.label), ["Carbs", "Fat"])
        XCTAssertTrue(reveal.secondaryMacroRows.allSatisfy { !$0.value.isEmpty })
        XCTAssertEqual(reveal.dailyCalorieLabel, OnboardingFormatter.kcal(plan.targets.calorieTarget))
        XCTAssertEqual(
            reveal.calorieExplanationLine,
            FormaProductCopy.Onboarding.V2.PlanReveal.heroCalorieExplanation
        )
    }

    func testAdvancedPacePlanStillUsesHeroExplanation() throws {
        var form = cutForm(currentWeightKg: 82.5, goalWeightKg: 75)
        form.selectPaceChoice(.advanced)
        form.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.45")

        let plan = try samplePlan(for: form)
        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertEqual(
            reveal.calorieExplanationLine,
            FormaProductCopy.Onboarding.V2.PlanReveal.heroCalorieExplanation
        )
        XCTAssertFalse(reveal.proteinLabel.isEmpty)
    }

    // MARK: - Language

    func testLabelsUseExpectedLanguageNotGuaranteed() throws {
        let form = cutForm(currentWeightKg: 82.5, goalWeightKg: 75)
        let plan = try samplePlan(for: form)

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        let combined = [
            reveal.journeySummaryLine,
            reveal.weeklyChangeLabel,
            reveal.estimatedWeeksLabel,
            reveal.dailyCalorieLabel,
            reveal.calorieExplanationLine
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        XCTAssertTrue(combined.contains("expected") || combined.contains("about") || combined.contains("starting"))
        XCTAssertFalse(combined.contains("guaranteed"))
        XCTAssertFalse(combined.contains("will lose"))
    }

    // MARK: - Fixtures

    private func cutForm(currentWeightKg: Double, goalWeightKg: Double) -> OnboardingFormState {
        var form = bodyForm(currentWeightKg: currentWeightKg, goalWeightKg: goalWeightKg)
        form.selectPaceChoice(.moderate)
        return form
    }

    private func bodyForm(currentWeightKg: Double, goalWeightKg: Double) -> OnboardingFormState {
        var form = OnboardingFormState()
        form.ageText = "28"
        form.sex = .female
        form.heightCmText = "168"
        form.currentWeightKgText = formatWeight(currentWeightKg)
        form.goalWeightKgText = formatWeight(goalWeightKg)
        form.activityLevel = .moderatelyActive
        form.trainingFrequencyPerWeekText = "3"
        form.averageStepsText = "5000"
        return form
    }

    private func formatWeight(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(kg))
            : String(format: "%.1f", kg)
    }

    private func samplePlan(for form: OnboardingFormState) throws -> CalorieTargetResult {
        try PlanCalculationBridge.calorieTargetResult(from: form.makeCalorieTargetInput())
    }
}
