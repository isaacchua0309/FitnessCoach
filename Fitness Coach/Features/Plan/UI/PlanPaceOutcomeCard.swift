//
//  PlanPaceOutcomeCard.swift
//  Fitness Coach
//
//  Forma — Outcome-driven pace selection card for Edit Plan.
//

import SwiftUI

struct PlanPaceOutcomeCard: View {
    let presentation: PlanPaceOutcomePresentation
    let isSelected: Bool
    let action: () -> Void

    private let copy = FormaProductCopy.PlanEditTarget.self

    var body: some View {
        PlanSelectableCard(
            isSelected: isSelected,
            accessibilityLabel: accessibilityLabel,
            action: action
        ) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                headerRow
                outcomeRows
                coachingLine
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
                    Text(presentation.title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    Text("·")
                        .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                    Text(presentation.subtitle)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                }

                Text(presentation.difficultyLabel)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planAccent)
            }

            Spacer(minLength: 0)

            PlanSelectableCardAccessory.selectionCheckmark(isSelected: isSelected)
        }
    }

    @ViewBuilder
    private var outcomeRows: some View {
        if let validationError = presentation.validationError {
            Text(validationError)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planDanger)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if let weekly = presentation.weeklyChangeLabel {
                    PlanMetricRow(label: copy.weeklyChangeLabel, value: weekly, valueWeight: .medium)
                }
                if let monthly = presentation.monthlyChangeLabel {
                    PlanMetricRow(label: copy.monthlyChangeLabel, value: monthly, valueWeight: .medium)
                }
                if let finish = presentation.estimatedFinishLabel {
                    PlanMetricRow(
                        label: FormaProductCopy.PlanEditTarget.estimatedFinishLabel,
                        value: finish,
                        valueWeight: .medium
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var coachingLine: some View {
        if presentation.validationError == nil {
            Text(presentation.coachingDescription)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let warning = presentation.warningMessage {
                Text(warning)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accessibilityLabel: String {
        var parts = [
            "\(presentation.title), \(presentation.subtitle)",
            presentation.difficultyLabel
        ]
        if let weekly = presentation.weeklyChangeLabel {
            parts.append("\(copy.weeklyChangeLabel), \(weekly)")
        }
        if let monthly = presentation.monthlyChangeLabel {
            parts.append("\(copy.monthlyChangeLabel), \(monthly)")
        }
        if let finish = presentation.estimatedFinishLabel {
            parts.append("\(FormaProductCopy.PlanEditTarget.estimatedFinishLabel), \(finish)")
        }
        if let validationError = presentation.validationError {
            parts.append("\(FormaProductCopy.PlanEditAccessibility.errorPrefix). \(validationError)")
        } else {
            parts.append(presentation.coachingDescription)
            if let warning = presentation.warningMessage {
                parts.append("\(FormaProductCopy.PlanEditAccessibility.warningPrefix). \(warning)")
            }
        }
        return parts.joined(separator: ". ")
    }
}

#if DEBUG
#Preview("Pace Outcome Card") {
    let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
    let presentation = PlanPaceOutcomeBuilder.presentation(
        choice: .moderate,
        formState: formState,
        goalType: .loseFat,
        advancedDraft: .default,
        weightKg: 80,
        goalWeightKg: 70
    )

    return PlanPaceOutcomeCard(
        presentation: presentation,
        isSelected: true,
        action: {}
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
