//
//  PlanGoalSelectionCard.swift
//  Fitness Coach
//
//  Forma — Theme-aware selectable goal card for the Edit Plan wizard.
//

import SwiftUI

struct PlanGoalSelectionCard: View {
    let presentation: PlanGoalOptionPresentation
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                headerRow
                explanationBlock
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
        HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
            Image(systemName: presentation.iconSystemName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(
                    isSelected
                        ? FormaPlanTokens.Color.planAccent
                        : FormaPlanTokens.Color.planSecondaryText
                )
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
                Text(presentation.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                if presentation.isRecommended {
                    recommendedBadge
                }

                Spacer(minLength: 0)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planAccent)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
    }

    private var explanationBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(presentation.explanation)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.outcomePreview)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 30 + FormaTokens.Spacing.md)
    }

    private var recommendedBadge: some View {
        Text(FormaProductCopy.PlanEditGoal.recommendedBadge)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaPlanTokens.Color.planAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(FormaPlanTokens.Color.planAccentSoft)
            }
            .accessibilityHidden(true)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(
                isSelected
                    ? FormaPlanTokens.Color.planSelectedCardBackground
                    : FormaPlanTokens.Color.planUnselectedCardBackground
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .stroke(
                isSelected
                    ? FormaPlanTokens.Color.planAccent
                    : FormaPlanTokens.Color.planCardBorder.opacity(0.45),
                lineWidth: isSelected ? 1.5 : 1
            )
    }

    private var accessibilityLabel: String {
        var parts = [presentation.title, presentation.explanation, presentation.outcomePreview]
        if presentation.isRecommended {
            parts.append(FormaProductCopy.PlanEditGoal.recommendedBadge)
        }
        if isSelected {
            parts.append("Selected")
        }
        return parts.joined(separator: ". ")
    }
}

#if DEBUG
#Preview("Goal Cards") {
    ScrollView {
        VStack(spacing: 12) {
            PlanGoalSelectionCard(
                presentation: PlanGoalSelectionBuilder.options(recommendedGoal: .loseFat)[0],
                isSelected: true,
                action: {}
            )
            PlanGoalSelectionCard(
                presentation: PlanGoalSelectionBuilder.options(recommendedGoal: .loseFat)[1],
                isSelected: false,
                action: {}
            )
            PlanGoalSelectionCard(
                presentation: PlanGoalSelectionBuilder.options(recommendedGoal: .loseFat)[2],
                isSelected: false,
                action: {}
            )
        }
        .padding()
    }
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
