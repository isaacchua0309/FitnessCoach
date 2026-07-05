//
//  PlanGoalSelectionCard.swift
//  Fitness Coach
//
//  Forma — Theme-aware selectable goal card for the Edit Plan wizard.
//

import SwiftUI

private enum PlanGoalSelectionCardLayout {
    static let iconColumnWidth: CGFloat = 28
    static let contentSpacing: CGFloat = FormaTokens.Spacing.xs
    static let textStackSpacing: CGFloat = FormaTokens.Spacing.xs
    static let contentPadding = EdgeInsets(
        top: FormaTokens.Spacing.sm,
        leading: FormaTokens.Spacing.lg,
        bottom: FormaTokens.Spacing.sm,
        trailing: FormaTokens.Spacing.lg
    )
}

struct PlanGoalSelectionCard: View {
    let presentation: PlanGoalOptionPresentation
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PlanSelectableCard(
            isSelected: isSelected,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: FormaProductCopy.PlanEditAccessibility.selectGoalCardHint,
            contentPadding: PlanGoalSelectionCardLayout.contentPadding,
            action: action
        ) {
            HStack(alignment: .top, spacing: PlanGoalSelectionCardLayout.contentSpacing) {
                iconColumn

                VStack(alignment: .leading, spacing: PlanGoalSelectionCardLayout.textStackSpacing) {
                    Text(presentation.title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    if presentation.isRecommended {
                        PlanMetricPill(
                            text: FormaProductCopy.PlanEditGoal.recommendedBadge,
                            style: .compact
                        )
                    }

                    Text(presentation.explanation)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(presentation.outcomePreview)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: PlanGoalSelectionCardLayout.contentSpacing)

                PlanSelectableCardAccessory.selectionCheckmark(isSelected: isSelected)
            }
        }
    }

    private var iconColumn: some View {
        Image(systemName: presentation.iconSystemName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(
                isSelected
                    ? FormaPlanTokens.Color.planAccent
                    : FormaPlanTokens.Color.planSecondaryText
            )
            .frame(width: PlanGoalSelectionCardLayout.iconColumnWidth, alignment: .center)
            .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        var parts = [presentation.title, presentation.explanation, presentation.outcomePreview]
        if presentation.isRecommended {
            parts.append(FormaProductCopy.PlanEditGoal.recommendedBadge)
        }
        return parts.joined(separator: ". ")
    }
}

#if DEBUG
#Preview("Goal Cards") {
    ScrollView {
        VStack(spacing: FormaTokens.Spacing.sm) {
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
