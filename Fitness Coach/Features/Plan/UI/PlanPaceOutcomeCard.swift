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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let copy = FormaProductCopy.PlanEditTarget.self

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                headerRow
                outcomeRows
                coachingLine
            }
            .padding(FormaTokens.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardBorder)
            .contentShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planAccent)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
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
                    metricRow(label: copy.weeklyChangeLabel, value: weekly)
                }
                if let monthly = presentation.monthlyChangeLabel {
                    metricRow(label: copy.monthlyChangeLabel, value: monthly)
                }
                if let finish = presentation.estimatedFinishLabel {
                    metricRow(
                        label: FormaProductCopy.PlanEditTarget.estimatedFinishLabel,
                        value: finish
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

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            Spacer()
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(PlanEditSelectionChrome.cardBackground(isSelected: isSelected))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .stroke(
                PlanEditSelectionChrome.cardStrokeColor(isSelected: isSelected),
                lineWidth: PlanEditSelectionChrome.cardStrokeWidth(isSelected: isSelected)
            )
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
        parts.append(presentation.coachingDescription)
        if isSelected {
            parts.append("Selected")
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
