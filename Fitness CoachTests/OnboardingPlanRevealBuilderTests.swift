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

        XCTAssertEqual(reveal.goalDirection, .cut)
        XCTAssertEqual(reveal.currentWeightLabel, "82.5 kg")
        XCTAssertEqual(reveal.goalWeightLabel, "75 kg")
        XCTAssertEqual(reveal.goalProgressLabel, "82.5 kg → 75 kg")
        XCTAssertEqual(reveal.goalHeroHeadline, "Reach 75 kg")
        XCTAssertEqual(reveal.goalHeroProgressLine, "From 82.5 kg to 75 kg")
        XCTAssertEqual(
            reveal.goalHeroSupport,
            FormaProductCopy.Onboarding.V2.PlanReveal.GoalHero.lossSupport
        )
        XCTAssertTrue(reveal.weeklyChangeLabel?.contains("0.5") == true)
        XCTAssertTrue(reveal.weeklyChangeLabel?.contains("kg/week") == true)
        XCTAssertTrue(reveal.paceLabel?.contains("0.5") == true)
        XCTAssertTrue(reveal.paceLabel?.contains("kg/week") == true)
        XCTAssertEqual(reveal.estimatedWeeksLabel, "About 15 weeks")
        XCTAssertEqual(reveal.strategyLabel, FormaProductCopy.Onboarding.V2.PlanReveal.Strategy.moderateCut)
    }

    // MARK: - Maintain / gain

    func testMaintainGoalHidesLossTimelineAndUsesMaintainHero() throws {
        let form = bodyForm(currentWeightKg: 72, goalWeightKg: 72)
        let plan = try samplePlan(for: form)

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertEqual(reveal.goalDirection, .maintain)
        XCTAssertNil(reveal.weeklyChangeLabel)
        XCTAssertNil(reveal.paceLabel)
        XCTAssertNil(reveal.estimatedWeeksLabel)
        XCTAssertNil(reveal.goalHeroProgressLine)
        XCTAssertEqual(reveal.goalHeroHeadline, "Maintain around 72 kg")
        XCTAssertEqual(
            reveal.goalHeroSupport,
            FormaProductCopy.Onboarding.V2.PlanReveal.GoalHero.maintainSupport
        )
        XCTAssertEqual(
            reveal.focusTitle,
            FormaProductCopy.Onboarding.V2.PlanReveal.Focus.maintainTitle
        )
        XCTAssertEqual(reveal.strategyLabel, FormaProductCopy.Onboarding.V2.PlanReveal.Strategy.maintenance)
        XCTAssertEqual(reveal.planStatus.title, FormaProductCopy.Onboarding.V2.PlanReveal.Status.maintenanceTitle)
    }

    func testGainGoalHidesLossTimelineAndUsesGainHero() throws {
        let form = bodyForm(currentWeightKg: 72, goalWeightKg: 78)
        let plan = try samplePlan(for: form)

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertEqual(reveal.goalDirection, .gain)
        XCTAssertNil(reveal.weeklyChangeLabel)
        XCTAssertNil(reveal.paceLabel)
        XCTAssertNil(reveal.estimatedWeeksLabel)
        XCTAssertEqual(reveal.goalHeroHeadline, "Build toward 78 kg")
        XCTAssertEqual(reveal.goalHeroProgressLine, "From 72 kg to 78 kg")
        XCTAssertEqual(
            reveal.focusTitle,
            FormaProductCopy.Onboarding.V2.PlanReveal.Focus.gainTitle
        )
        XCTAssertEqual(reveal.strategyLabel, FormaProductCopy.Onboarding.V2.PlanReveal.Strategy.leanGain)
    }

    func testImperialGoalHeroUsesImperialLabels() throws {
        var form = bodyForm(currentWeightKg: 72, goalWeightKg: 65)
        form.unitSystem = .imperial
        let plan = try samplePlan(for: form)

        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertTrue(reveal.goalHeroHeadline.contains("lb"))
        XCTAssertTrue(reveal.goalHeroProgressLine?.contains("lb") == true)
        XCTAssertTrue(reveal.accessibilitySummary.contains("Goal:"))
        XCTAssertTrue(reveal.accessibilitySummary.contains("lb"))
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
        XCTAssertEqual(reveal.dailyMissionCalorieLine, "\(OnboardingFormatter.kcal(plan.targets.calorieTarget)) / day")
        XCTAssertEqual(
            reveal.dailyMissionSectionTitle,
            FormaProductCopy.Onboarding.V2.PlanReveal.dailyMissionSectionTitle
        )
        XCTAssertEqual(
            reveal.nextStepLine,
            FormaProductCopy.Onboarding.V2.PlanReveal.nextStepLine
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
            reveal.goalHeroSupport,
            reveal.focusBody,
            reveal.nextStepLine,
            reveal.accessibilitySummary,
            reveal.planStatus.title,
            reveal.planStatus.body
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        XCTAssertTrue(combined.contains("expected") || combined.contains("about") || combined.contains("toward"))
        XCTAssertFalse(combined.contains("guaranteed"))
        XCTAssertFalse(combined.contains("will lose"))
        XCTAssertFalse(combined.contains("aggressivedeficit"))
    }

    func testRevealCopyAvoidsAdaptiveTrendLanguage() throws {
        let form = bodyForm(currentWeightKg: 72, goalWeightKg: 72)
        let plan = try samplePlan(for: form)
        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        let combined = [
            reveal.goalHeroSupport,
            reveal.calorieExplanationLine,
            reveal.journeySummaryLine,
            reveal.focusBody,
            reveal.nextStepLine,
            reveal.planStatus.body,
            reveal.accessibilitySummary
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        XCTAssertFalse(combined.contains("learns your trend"))
        XCTAssertFalse(combined.contains("dynamic calor"))
        XCTAssertFalse(combined.contains("adjust as real"))
        XCTAssertFalse(combined.contains("automatic"))
    }

    func testAccessibilitySummaryFollowsEmotionalHierarchy() throws {
        let form = bodyForm(currentWeightKg: 70, goalWeightKg: 70)
        let plan = try samplePlan(for: form)
        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        let summary = reveal.accessibilitySummary
        let labels = FormaProductCopy.Onboarding.V2.PlanReveal.Accessibility.self

        XCTAssertTrue(summary.contains(FormaProductCopy.Onboarding.Flow.PlanReveal.title))
        XCTAssertTrue(summary.contains(FormaProductCopy.Onboarding.Flow.PlanReveal.subtitle))
        XCTAssertTrue(summary.contains("\(labels.goal): Maintain around 70 kg."))
        XCTAssertTrue(summary.contains("\(labels.journey):"))
        XCTAssertTrue(summary.contains("\(labels.firstWeek):"))
        XCTAssertTrue(summary.contains("\(labels.dailyFuel):"))
        XCTAssertTrue(summary.contains(reveal.coachMessage))
        XCTAssertFalse(summary.contains("daily mission"))

        let goalRange = try XCTUnwrap(summary.range(of: "\(labels.goal):"))
        let fuelRange = try XCTUnwrap(summary.range(of: "\(labels.dailyFuel):"))
        let coachRange = try XCTUnwrap(summary.range(of: reveal.coachMessage))
        XCTAssertTrue(goalRange.lowerBound < fuelRange.lowerBound)
        XCTAssertTrue(fuelRange.lowerBound < coachRange.lowerBound)
    }

    func testCutDirectionCopyMatchesProductSpec() throws {
        let form = cutForm(currentWeightKg: 82.5, goalWeightKg: 75)
        let plan = try samplePlan(for: form)
        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.self

        XCTAssertEqual(reveal.goalHeroHeadline, copy.GoalHero.lossHeadline(targetWeight: "75 kg"))
        XCTAssertEqual(reveal.firstWeekMissions.map(\.title), [
            copy.FirstWeek.logMealsCut,
            copy.FirstWeek.proteinCut,
            copy.FirstWeek.weighCut
        ])
        XCTAssertEqual(reveal.coachMessage, copy.Coach.cut(goalWeight: "75 kg"))
        XCTAssertFalse(reveal.calorieExplanationLine.isEmpty)
        XCTAssertFalse(reveal.strategyLabel.isEmpty)
        XCTAssertNotNil(reveal.paceLabel)
        XCTAssertNotNil(reveal.estimatedWeeksLabel)
    }

    func testMaintainDirectionCopyMatchesProductSpec() throws {
        let form = bodyForm(currentWeightKg: 72, goalWeightKg: 72)
        let plan = try samplePlan(for: form)
        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.self

        XCTAssertEqual(reveal.goalHeroHeadline, copy.GoalHero.maintainHeadline(targetWeight: "72 kg"))
        XCTAssertEqual(reveal.firstWeekMissions.map(\.title), [
            copy.FirstWeek.logDaysMaintain,
            copy.FirstWeek.caloriesMaintain,
            copy.FirstWeek.waterMaintain
        ])
        XCTAssertEqual(reveal.coachMessage, copy.Coach.maintain)
    }

    func testGainDirectionCopyMatchesProductSpec() throws {
        let form = bodyForm(currentWeightKg: 72, goalWeightKg: 78)
        let plan = try samplePlan(for: form)
        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.self

        XCTAssertEqual(reveal.goalHeroHeadline, copy.GoalHero.gainHeadline(targetWeight: "78 kg"))
        XCTAssertEqual(reveal.firstWeekMissions.map(\.title), [
            copy.FirstWeek.mealsGain,
            copy.FirstWeek.proteinGain,
            copy.FirstWeek.weighGain
        ])
        XCTAssertEqual(reveal.coachMessage, copy.Coach.gain(goalWeight: "78 kg"))
    }

    func testFirstWeekMissionsAndCoachMessageArePopulated() throws {
        let form = cutForm(currentWeightKg: 82.5, goalWeightKg: 75)
        let plan = try samplePlan(for: form)
        let reveal = try XCTUnwrap(OnboardingPlanRevealBuilder.build(formState: form, plan: plan))

        XCTAssertEqual(reveal.firstWeekMissions.count, 3)
        XCTAssertFalse(reveal.coachMessage.isEmpty)
        XCTAssertFalse(reveal.journeyBeliefLine.isEmpty)
        XCTAssertTrue(reveal.journeyBeliefLine.contains("Moderate cut"))
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
