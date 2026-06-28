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
        XCTAssertEqual(reveal.goalProgressLabel, "82.5 kg → 75 kg")
        XCTAssertTrue(reveal.weeklyChangeLabel?.contains("0.5") == true)
        XCTAssertTrue(reveal.weeklyChangeLabel?.contains("kg/week") == true)
        XCTAssertTrue(reveal.paceLabel?.contains("0.5") == true)
        XCTAssertTrue(reveal.paceLabel?.contains("kg/week") == true)
        XCTAssertEqual(reveal.estimatedWeeksLabel, "About 15 weeks")
        XCTAssertTrue(reveal.journeySummaryLine.contains("starting targets"))
        XCTAssertEqual(reveal.strategyLabel, FormaProductCopy.Onboarding.V2.PlanReveal.Strategy.moderateCut)
    }

    // MARK: - Maintain / gain

    func testMaintainGoalHidesLossTimeline() throws {
        let form = bodyForm(currentWeightKg: 72, goalWeightKg: 72)
        let plan = try samplePlan(for: form)

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertNil(reveal.weeklyChangeLabel)
        XCTAssertNil(reveal.paceLabel)
        XCTAssertNil(reveal.estimatedWeeksLabel)
        XCTAssertTrue(reveal.journeySummaryLine.contains("maintaining around 72 kg"))
        XCTAssertEqual(reveal.strategyLabel, FormaProductCopy.Onboarding.V2.PlanReveal.Strategy.maintenance)
        XCTAssertEqual(reveal.planStatus.title, FormaProductCopy.Onboarding.V2.PlanReveal.Status.maintenanceTitle)
    }

    func testGainGoalHidesLossTimeline() throws {
        let form = bodyForm(currentWeightKg: 72, goalWeightKg: 78)
        let plan = try samplePlan(for: form)

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertNil(reveal.weeklyChangeLabel)
        XCTAssertNil(reveal.paceLabel)
        XCTAssertNil(reveal.estimatedWeeksLabel)
        XCTAssertTrue(reveal.journeySummaryLine.contains("building toward 78 kg"))
        XCTAssertEqual(reveal.strategyLabel, FormaProductCopy.Onboarding.V2.PlanReveal.Strategy.leanGain)
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
        XCTAssertNil(reveal.paceLabel)
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
            FormaProductCopy.Onboarding.V2.PlanReveal.cutCalorieExplanation
        )
    }

    func testAdvancedPacePlanUsesCutExplanation() throws {
        var form = cutForm(currentWeightKg: 82.5, goalWeightKg: 75)
        form.selectPaceChoice(.advanced)
        form.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.45")

        let plan = try samplePlan(for: form)
        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertEqual(
            reveal.calorieExplanationLine,
            FormaProductCopy.Onboarding.V2.PlanReveal.cutCalorieExplanation
        )
        XCTAssertEqual(reveal.strategyLabel, FormaProductCopy.Onboarding.V2.PlanReveal.Strategy.customCut)
        XCTAssertFalse(reveal.proteinLabel.isEmpty)
    }

    // MARK: - Status mapping

    func testAggressiveDeficitKeyMapsToUserFacingStatus() throws {
        let form = cutForm(currentWeightKg: 90, goalWeightKg: 79.5)
        let plan = CalorieTargetResult(
            estimatedBMR: 1800,
            estimatedTDEE: 2600,
            targets: UserTargets(
                calorieTarget: 2080,
                proteinTarget: 180,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2950,
                expectedWeeklyWeightLossKg: 0.26,
                aggressiveness: .moderate
            ),
            estimatedDailyDeficit: 520,
            isAggressive: true,
            warning: "aggressiveDeficit"
        )

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertEqual(
            reveal.planStatus.title,
            FormaProductCopy.Onboarding.V2.PlanReveal.Status.aggressiveDeficitTitle
        )
        XCTAssertEqual(
            reveal.planStatus.body,
            FormaProductCopy.Onboarding.V2.PlanReveal.Status.aggressiveDeficitBody
        )
        XCTAssertEqual(reveal.planStatus.style, .caution)
        XCTAssertFalse(reveal.planStatus.title.contains("aggressiveDeficit"))
    }

    func testSustainablePlanShowsPositiveStatus() throws {
        let form = cutForm(currentWeightKg: 72, goalWeightKg: 65)
        let plan = try samplePlan(for: form)
        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertEqual(
            reveal.planStatus.title,
            FormaProductCopy.Onboarding.V2.PlanReveal.Status.sustainableTitle
        )
        XCTAssertEqual(reveal.planStatus.style, .positive)
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
            reveal.calorieExplanationLine,
            reveal.planStatus.title,
            reveal.planStatus.body
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        XCTAssertTrue(combined.contains("expected") || combined.contains("about") || combined.contains("starting"))
        XCTAssertFalse(combined.contains("guaranteed"))
        XCTAssertFalse(combined.contains("will lose"))
        XCTAssertFalse(combined.contains("aggressivedeficit"))
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
