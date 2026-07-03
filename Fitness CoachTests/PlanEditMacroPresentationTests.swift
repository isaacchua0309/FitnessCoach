//
//  PlanEditMacroPresentationTests.swift
//  Fitness CoachTests
//
//  Forma — Macro target wrapping for Edit Plan review and previews.
//

import XCTest
@testable import Fitness_Coach

final class PlanEditMacroPresentationTests: XCTestCase {

    func testFinalSummaryIncludesAllMacroRowsWhenPreviewAvailable() {
        let baseline = PlanMissionControlFixtures.loseProfile
        var formState = PlanFormState(profile: baseline)
        formState.goalWeightKgText = "70"

        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
        let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)
        let preview = PlanPreviewData.generatedPreview

        let summary = PlanEditFinalPlanSummaryBuilder.build(
            baseline: baseline,
            formState: formState,
            goalType: .loseFat,
            projection: projection,
            review: review,
            targetPreview: preview
        )

        XCTAssertNotNil(summary.calories)
        XCTAssertNotNil(summary.protein)
        XCTAssertNotNil(summary.carbs)
        XCTAssertNotNil(summary.fat)
        XCTAssertNotNil(summary.water)
        XCTAssertEqual(summary.calories, PlanFormatter.kcal(preview.targets.calorieTarget))
        XCTAssertEqual(summary.protein, PlanFormatter.grams(preview.targets.proteinTarget))
        XCTAssertEqual(summary.carbs, PlanFormatter.grams(preview.targets.carbTarget))
        XCTAssertEqual(summary.fat, PlanFormatter.grams(preview.targets.fatTarget))
        XCTAssertEqual(summary.water, PlanFormatter.ml(preview.targets.waterTargetMl))
    }

    func testTargetPreviewOverridesProjectionMacros() {
        let baseline = PlanMissionControlFixtures.loseProfile
        let formState = PlanFormState(profile: baseline)
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)
        let review = PlanEditReviewBuilder.build(baseline: baseline, formState: formState)

        var previewTargets = baseline.targets
        previewTargets.calorieTarget = 1_850
        previewTargets.proteinTarget = 155
        previewTargets.carbTarget = 150
        previewTargets.fatTarget = 50
        previewTargets.waterTargetMl = 2_800

        let preview = CalorieTargetResult(
            estimatedBMR: 1_480,
            estimatedTDEE: 2_290,
            targets: previewTargets,
            estimatedDailyDeficit: 440,
            isAggressive: false,
            warning: nil
        )

        let summary = PlanEditFinalPlanSummaryBuilder.build(
            baseline: baseline,
            formState: formState,
            goalType: .loseFat,
            projection: projection,
            review: review,
            targetPreview: preview
        )

        XCTAssertEqual(summary.calories, PlanFormatter.kcal(1_850))
        XCTAssertEqual(summary.protein, PlanFormatter.grams(155))
        XCTAssertEqual(summary.carbs, PlanFormatter.grams(150))
        XCTAssertEqual(summary.fat, PlanFormatter.grams(50))
        XCTAssertEqual(summary.water, PlanFormatter.ml(2_800))
    }

    func testActivityTargetPreviewBuilderWrapsProjectionMacros() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let projection = PlanProjectionBuilder.build(formState: formState, goalType: .loseFat)

        let preview = PlanActivityTargetPreviewBuilder.build(
            projection: projection,
            formState: formState
        )

        XCTAssertNotNil(preview.maintenanceCalories)
        XCTAssertNotNil(preview.targetCalories)
        XCTAssertNotNil(preview.proteinTarget)
        XCTAssertFalse(preview.trainingAssumption.isEmpty)
    }

    func testMacroSummaryDisplayModelSupportsCompactAndStandardLayouts() {
        let standard = PlanMacroSummaryCardDisplayModel(
            title: "Your plan",
            rows: [
                PlanMetricRowDisplayModel(id: "goal", label: "Goal", value: "Lose fat"),
                PlanMetricRowDisplayModel(id: "calories", label: "Daily calories", value: "2,000 kcal")
            ],
            footerText: "Targets update as you refine your inputs."
        )
        let compact = PlanMacroSummaryCardDisplayModel(
            title: "Preview",
            rows: standard.rows,
            compact: true
        )

        XCTAssertEqual(standard.rows.count, 2)
        XCTAssertTrue(compact.compact)
        XCTAssertEqual(compact.footerText, nil)
    }
}
