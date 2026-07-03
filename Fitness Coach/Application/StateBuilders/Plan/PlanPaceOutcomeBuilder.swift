//
//  PlanPaceOutcomeBuilder.swift
//  Fitness Coach
//
//  Forma — Outcome-driven pace card presentations for Edit Plan.
//

import Foundation

struct PlanPaceOutcomePresentation: Equatable, Identifiable, Sendable {
    var id: WeightLossPaceChoice { choice }
    let choice: WeightLossPaceChoice
    let title: String
    let subtitle: String
    let weeklyChangeLabel: String?
    let monthlyChangeLabel: String?
    let estimatedFinishLabel: String?
    let difficultyLabel: String
    let coachingDescription: String
    let energyBalanceLabel: String?
    let validationError: String?
    let warningMessage: String?
    let adherenceEstimate: String?
    let recoveryImpact: String?
    let hungerImpact: String?
    let isSelectable: Bool
}

enum PlanPaceOutcomeBuilder {

    static func options(
        formState: PlanFormState,
        goalType: PlanGoalType,
        advancedDraft: WeightLossAdvancedPaceDraft,
        weightKg: Double,
        goalWeightKg: Double,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlanPaceOutcomePresentation] {
        WeightLossPaceChoice.allCases.map { choice in
            presentation(
                choice: choice,
                formState: formState,
                goalType: goalType,
                advancedDraft: choice == .advanced ? advancedDraft : .default,
                weightKg: weightKg,
                goalWeightKg: goalWeightKg,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }

    static func presentation(
        choice: WeightLossPaceChoice,
        formState: PlanFormState,
        goalType: PlanGoalType,
        advancedDraft: WeightLossAdvancedPaceDraft,
        weightKg: Double,
        goalWeightKg: Double,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> PlanPaceOutcomePresentation {
        let titles = titlePair(for: choice)

        var draft = formState
        draft.weightLossPaceChoice = choice
        draft.advancedPaceDraft = advancedDraft

        let preview = WeightLossPacePreviewBuilder.build(
            choice: choice,
            advancedDraft: advancedDraft,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            referenceDate: referenceDate
        )

        let projection = PlanProjectionBuilder.build(
            formState: draft,
            goalType: goalType,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let finish = projection.estimatedCompletionLabel?
            .replacingOccurrences(of: "Estimated finish: ", with: "")
            .replacingOccurrences(of: ".", with: "")

        return PlanPaceOutcomePresentation(
            choice: choice,
            title: titles.title,
            subtitle: titles.subtitle,
            weeklyChangeLabel: weeklyLabel(from: preview.weeklyLossKg),
            monthlyChangeLabel: monthlyLabel(from: preview.monthlyLossKg),
            estimatedFinishLabel: finish,
            difficultyLabel: projection.difficultyLabel,
            coachingDescription: projection.difficultyDescription,
            energyBalanceLabel: projection.dailyDeficitOrSurplusLabel,
            validationError: preview.validationError,
            warningMessage: preview.warningMessage,
            adherenceEstimate: choice == .advanced ? projection.adherenceEstimate : nil,
            recoveryImpact: choice == .advanced ? projection.recoveryImpact : nil,
            hungerImpact: choice == .advanced ? projection.hungerImpact : nil,
            isSelectable: preview.isSaveable
        )
    }

    private static func titlePair(for choice: WeightLossPaceChoice) -> (title: String, subtitle: String) {
        let copy = FormaProductCopy.PlanEditTarget.self
        switch choice {
        case .gentle:
            return (copy.paceGentleTitle, copy.paceGentleSubtitle)
        case .moderate:
            return (copy.paceModerateTitle, copy.paceModerateSubtitle)
        case .aggressive:
            return (copy.paceAggressiveTitle, copy.paceAggressiveSubtitle)
        case .advanced:
            return (copy.paceAdvancedTitle, copy.paceAdvancedSubtitle)
        }
    }

    private static func weeklyLabel(from value: Double?) -> String? {
        guard let value, value > 0 else { return nil }
        return formatKgRate(value, period: "/week")
    }

    private static func monthlyLabel(from value: Double?) -> String? {
        guard let value, value > 0 else { return nil }
        return formatKgRate(value, period: "/month")
    }

    private static func formatKgRate(_ value: Double, period: String) -> String {
        let amount = value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
        return amount + period
    }
}
