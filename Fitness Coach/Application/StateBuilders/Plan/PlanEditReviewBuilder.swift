//
//  PlanEditReviewBuilder.swift
//  Fitness Coach
//
//  Forma — Before/after summaries for plan edit review and confirmation.
//

import Foundation

struct PlanEditChangeRow: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let before: String
    let after: String
}

struct PlanEditReviewState: Equatable, Sendable {
    let changes: [PlanEditChangeRow]
    let hasChanges: Bool
}

struct PlanEditTargetComparisonRow: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let before: String
    let after: String
}

struct PlanEditTargetComparisonState: Equatable, Sendable {
    let rows: [PlanEditTargetComparisonRow]
    let isAggressive: Bool
    let warning: String?
}

enum PlanEditReviewBuilder {

    static func build(
        baseline: UserProfile,
        formState: PlanFormState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> PlanEditReviewState {
        var rows: [PlanEditChangeRow] = []

        let baselineGoal = PlanStateBuilder.goalType(for: baseline)
        let formSnapshot = profileSnapshot(from: formState, referenceDate: referenceDate)
        let formGoal = PlanStateBuilder.goalType(for: formSnapshot)

        appendChange(
            to: &rows,
            id: "goal",
            label: "Goal",
            before: baselineGoal.rawValue,
            after: formGoal.rawValue
        )

        appendChange(
            to: &rows,
            id: "goalWeight",
            label: FormaProductCopy.ProfileForm.goalWeight,
            before: PlanFormatter.kg(baseline.goalWeightKg),
            after: PlanFormatter.kg(formSnapshot.goalWeightKg)
        )

        if let baselineBirthDate = baseline.birthDate, let formBirthDate = formState.birthDate {
            appendChange(
                to: &rows,
                id: "birthday",
                label: "Birthday",
                before: formattedBirthDate(baselineBirthDate, calendar: calendar),
                after: formattedBirthDate(formBirthDate, calendar: calendar)
            )
        } else if formState.birthDate != baseline.birthDate, let formBirthDate = formState.birthDate {
            appendChange(
                to: &rows,
                id: "birthday",
                label: "Birthday",
                before: "Not set",
                after: formattedBirthDate(formBirthDate, calendar: calendar)
            )
        }

        appendChange(
            to: &rows,
            id: "sex",
            label: FormaProductCopy.ProfileForm.sex,
            before: PlanFormatter.sex(baseline.sex),
            after: PlanFormatter.sex(formState.sex)
        )

        appendChange(
            to: &rows,
            id: "height",
            label: FormaProductCopy.ProfileForm.height,
            before: PlanFormatter.cm(baseline.heightCm),
            after: PlanFormatter.cm(formSnapshot.heightCm)
        )

        appendChange(
            to: &rows,
            id: "weight",
            label: FormaProductCopy.ProfileForm.baselineWeight,
            before: PlanFormatter.kg(baseline.currentWeightKg),
            after: PlanFormatter.kg(formSnapshot.currentWeightKg)
        )

        appendChange(
            to: &rows,
            id: "activity",
            label: FormaProductCopy.ProfileForm.activityLevel,
            before: PlanFormatter.activityLevel(baseline.activityLevel),
            after: PlanFormatter.activityLevel(formState.activityLevel)
        )

        let baselineRhythm = baseline.resolvedTrainingRhythm()
        let formRhythm = formSnapshot.resolvedTrainingRhythm()
        appendChange(
            to: &rows,
            id: "training",
            label: FormaProductCopy.ProfileForm.trainingDays,
            before: "\(baselineRhythm.trainingDaysPerWeek)",
            after: "\(formRhythm.trainingDaysPerWeek)"
        )
        appendChange(
            to: &rows,
            id: "steps",
            label: FormaProductCopy.ProfileForm.averageSteps,
            before: PlanFormatter.steps(baselineRhythm.averageStepsPerDay),
            after: PlanFormatter.steps(formRhythm.averageStepsPerDay)
        )

        if let baselineBodyFat = baseline.estimatedBodyFatPercentage {
            let formBodyFat = formSnapshot.estimatedBodyFatPercentage
            appendChange(
                to: &rows,
                id: "bodyFat",
                label: FormaProductCopy.ProfileForm.bodyFat,
                before: PlanFormatter.percent(baselineBodyFat) ?? "Not set",
                after: PlanFormatter.percent(formBodyFat) ?? "Not set"
            )
        } else if let formBodyFat = formSnapshot.estimatedBodyFatPercentage {
            appendChange(
                to: &rows,
                id: "bodyFat",
                label: FormaProductCopy.ProfileForm.bodyFat,
                before: "Not set",
                after: PlanFormatter.percent(formBodyFat) ?? "Not set"
            )
        }

        return PlanEditReviewState(changes: rows, hasChanges: !rows.isEmpty)
    }

    static func buildTargetComparison(
        before: UserTargets,
        preview: CalorieTargetResult
    ) -> PlanEditTargetComparisonState {
        let after = preview.targets
        let rows: [PlanEditTargetComparisonRow] = [
            comparisonRow("calories", "Calories", PlanFormatter.kcal(before.calorieTarget), PlanFormatter.kcal(after.calorieTarget)),
            comparisonRow("protein", "Protein", PlanFormatter.grams(before.proteinTarget), PlanFormatter.grams(after.proteinTarget)),
            comparisonRow("carbs", "Carbs", PlanFormatter.grams(before.carbTarget), PlanFormatter.grams(after.carbTarget)),
            comparisonRow("fat", "Fat", PlanFormatter.grams(before.fatTarget), PlanFormatter.grams(after.fatTarget)),
            comparisonRow("water", "Water", PlanFormatter.ml(before.waterTargetMl), PlanFormatter.ml(after.waterTargetMl))
        ]

        return PlanEditTargetComparisonState(
            rows: rows,
            isAggressive: preview.isAggressive,
            warning: preview.warning
        )
    }

    private static func appendChange(
        to rows: inout [PlanEditChangeRow],
        id: String,
        label: String,
        before: String,
        after: String
    ) {
        guard before != after else { return }
        rows.append(
            PlanEditChangeRow(id: id, label: label, before: before, after: after)
        )
    }

    private static func comparisonRow(
        _ id: String,
        _ label: String,
        _ before: String,
        _ after: String
    ) -> PlanEditTargetComparisonRow {
        PlanEditTargetComparisonRow(id: id, label: label, before: before, after: after)
    }

    private static func formattedBirthDate(_ date: Date, calendar: Calendar) -> String {
        var format = Date.FormatStyle(date: .long, time: .omitted)
            .locale(.autoupdatingCurrent)
        format.calendar = calendar
        return date.formatted(format)
    }

    private static func profileSnapshot(from formState: PlanFormState, referenceDate: Date) -> UserProfile {
        let now = referenceDate
        let age = (try? formState.resolvedAge(referenceDate: referenceDate)) ?? 24
        return UserProfile(
            id: UUID(),
            name: formState.name.isEmpty ? nil : formState.name,
            birthDate: formState.birthDate,
            age: age,
            sex: formState.sex,
            heightCm: Double(formState.heightCmText) ?? 170,
            currentWeightKg: Double(formState.currentWeightKgText) ?? 70,
            goalWeightKg: Double(formState.goalWeightKgText) ?? 65,
            estimatedBodyFatPercentage: Double(formState.estimatedBodyFatPercentageText),
            activityLevel: formState.activityLevel,
            trainingFrequencyPerWeek: Int(formState.trainingFrequencyPerWeekText) ?? 3,
            averageSteps: Int(formState.averageStepsText) ?? 5000,
            dietPreference: formState.dietPreference.isEmpty ? nil : formState.dietPreference,
            unitSystem: formState.unitSystem,
            targets: UserTargets(
                calorieTarget: Int(formState.calorieTargetText) ?? 2000,
                proteinTarget: Double(formState.proteinTargetText) ?? 140,
                carbTarget: Double(formState.carbTargetText) ?? 200,
                fatTarget: Double(formState.fatTargetText) ?? 56,
                waterTargetMl: Int(formState.waterTargetMlText) ?? 2450,
                expectedWeeklyWeightLossKg: Double(formState.expectedWeeklyWeightLossKgText),
                aggressiveness: formState.aggressiveness
            ),
            createdAt: now,
            updatedAt: now
        )
    }
}
