//
//  PlanEditFinalPlanSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Final plan summary for Edit Plan review step.
//

import Foundation

struct PlanEditFriendlyChange: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let summary: String
}

struct PlanEditTodayTargetChange: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let value: String
    let previousValue: String?
}

struct PlanEditFinalPlanSummaryState: Equatable, Sendable {
    let headline: String
    let isUpToDate: Bool
    let goal: String
    let currentWeight: String
    let targetWeight: String
    let estimatedFinish: String?
    let calories: String?
    let protein: String?
    let carbs: String?
    let fat: String?
    let water: String?
    let difficultyAdherence: String
    let inputChanges: [PlanEditFriendlyChange]
    let warning: PlanEditReviewWarning?
    let todayChanges: [PlanEditTodayTargetChange]
    let todayNote: String
    let hasTodayChanges: Bool
}

enum PlanEditFinalPlanSummaryBuilder {

    static func build(
        baseline: UserProfile,
        formState: PlanFormState,
        goalType: PlanGoalType,
        projection: PlanProjection,
        review: PlanEditReviewState,
        targetPreview: CalorieTargetResult? = nil,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> PlanEditFinalPlanSummaryState {
        let copy = FormaProductCopy.PlanEditReview.self
        let isUpToDate = !review.hasChanges

        let finish = PlanEditTimelineCopy.monthYearDisplay(
            fromCompletionLabel: projection.estimatedCompletionLabel
        )

        let projectedTargets = resolvedTargets(
            projection: projection,
            formState: formState,
            targetPreview: targetPreview
        )

        let today = todayChanges(
            baselineTargets: baseline.targets,
            projectedTargets: projectedTargets
        )

        return PlanEditFinalPlanSummaryState(
            headline: isUpToDate ? copy.planUpToDateHeadline : copy.planReadyHeadline,
            isUpToDate: isUpToDate,
            goal: projection.goalLabel,
            currentWeight: projection.currentWeightDisplay,
            targetWeight: projection.targetWeightDisplay,
            estimatedFinish: finish,
            calories: formatCalories(projectedTargets.calories),
            protein: formatGrams(projectedTargets.proteinG),
            carbs: formatGrams(projectedTargets.carbsG),
            fat: formatGrams(projectedTargets.fatG),
            water: formatWater(projectedTargets.waterMl),
            difficultyAdherence: "\(projection.difficultyLabel) · \(projection.adherenceEstimate)",
            inputChanges: friendlyChanges(from: review.changes),
            warning: PlanEditWarningCopyMapper.userFacingWarning(
                warningCode: targetPreview?.warning,
                isAggressive: targetPreview?.isAggressive ?? false,
                projection: projection
            ),
            todayChanges: today.changes,
            todayNote: today.hasChanges ? copy.todayChangesNote : copy.todayNoChangeNote,
            hasTodayChanges: today.hasChanges
        )
    }

    private struct ResolvedTargets {
        let calories: Int?
        let proteinG: Double?
        let carbsG: Double?
        let fatG: Double?
        let waterMl: Int?
    }

    private static func resolvedTargets(
        projection: PlanProjection,
        formState: PlanFormState,
        targetPreview: CalorieTargetResult?
    ) -> ResolvedTargets {
        if let preview = targetPreview {
            let targets = preview.targets
            return ResolvedTargets(
                calories: targets.calorieTarget,
                proteinG: targets.proteinTarget,
                carbsG: targets.carbTarget,
                fatG: targets.fatTarget,
                waterMl: targets.waterTargetMl
            )
        }
        return ResolvedTargets(
            calories: projection.targetCalories,
            proteinG: projection.proteinTargetG,
            carbsG: projection.carbTargetG,
            fatG: projection.fatTargetG,
            waterMl: projection.waterTargetMl
        )
    }

    private static func friendlyChanges(
        from changes: [PlanEditChangeRow]
    ) -> [PlanEditFriendlyChange] {
        changes.map { change in
            PlanEditFriendlyChange(
                id: change.id,
                label: change.label,
                summary: FormaProductCopy.PlanEditReview.friendlyChangeSummary(
                    before: change.before,
                    after: change.after
                )
            )
        }
    }

    private struct TodayChanges {
        let changes: [PlanEditTodayTargetChange]
        let hasChanges: Bool
    }

    private static func todayChanges(
        baselineTargets: UserTargets,
        projectedTargets: ResolvedTargets
    ) -> TodayChanges {
        let copy = FormaProductCopy.PlanProjection.self
        var rows: [PlanEditTodayTargetChange] = []

        appendTodayChange(
            to: &rows,
            id: "calories",
            label: copy.targetCaloriesLabel,
            previous: PlanFormatter.kcal(baselineTargets.calorieTarget),
            next: projectedTargets.calories.map(PlanFormatter.kcal)
        )
        appendTodayChange(
            to: &rows,
            id: "protein",
            label: copy.proteinLabel,
            previous: PlanFormatter.grams(baselineTargets.proteinTarget),
            next: projectedTargets.proteinG.map(PlanFormatter.grams)
        )
        appendTodayChange(
            to: &rows,
            id: "carbs",
            label: copy.carbsLabel,
            previous: PlanFormatter.grams(baselineTargets.carbTarget),
            next: projectedTargets.carbsG.map(PlanFormatter.grams)
        )
        appendTodayChange(
            to: &rows,
            id: "fat",
            label: copy.fatLabel,
            previous: PlanFormatter.grams(baselineTargets.fatTarget),
            next: projectedTargets.fatG.map(PlanFormatter.grams)
        )
        appendTodayChange(
            to: &rows,
            id: "water",
            label: copy.waterLabel,
            previous: PlanFormatter.ml(baselineTargets.waterTargetMl),
            next: projectedTargets.waterMl.map(PlanFormatter.ml)
        )

        let hasChanges = rows.contains { $0.previousValue != nil && $0.previousValue != $0.value }
        return TodayChanges(changes: rows, hasChanges: hasChanges)
    }

    private static func appendTodayChange(
        to rows: inout [PlanEditTodayTargetChange],
        id: String,
        label: String,
        previous: String,
        next: String?
    ) {
        guard let next else { return }
        rows.append(
            PlanEditTodayTargetChange(
                id: id,
                label: label,
                value: next,
                previousValue: previous == next ? nil : previous
            )
        )
    }

    private static func formatCalories(_ value: Int?) -> String? {
        value.map(PlanFormatter.kcal)
    }

    private static func formatGrams(_ value: Double?) -> String? {
        value.map(PlanFormatter.grams)
    }

    private static func formatWater(_ value: Int?) -> String? {
        value.map(PlanFormatter.ml)
    }
}
