//
//  GoalOptionCard.swift
//  Fitness Coach
//
//  Forma — Selectable goal option card for the Adjust Plan flow.
//

import SwiftUI

private enum GoalOptionCardLayout {
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

struct GoalOptionCard: View {
    let goal: PlanGoalOption
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void

    @Environment(\.formaPlanColors) private var theme

    var body: some View {
        PlanSelectableCard(
            isSelected: isSelected,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: FormaProductCopy.PlanEditAccessibility.selectGoalCardHint,
            contentPadding: GoalOptionCardLayout.contentPadding,
            action: onSelect
        ) {
            HStack(alignment: .top, spacing: GoalOptionCardLayout.contentSpacing) {
                iconColumn

                VStack(alignment: .leading, spacing: GoalOptionCardLayout.textStackSpacing) {
                    Text(goal.title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    if isRecommended {
                        RecommendedChip(text: FormaProductCopy.PlanEditGoal.recommendedBadge)
                    }

                    Text(goal.explanation)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(goal.outcomePreview)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: GoalOptionCardLayout.contentSpacing)

                PlanSelectableCardAccessory.selectionCheckmark(isSelected: isSelected)
            }
        }
        .formaThemeReactive()
    }

    private var iconColumn: some View {
        Image(systemName: goal.iconSystemName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(isSelected ? theme.accent : theme.secondaryText)
            .frame(width: GoalOptionCardLayout.iconColumnWidth, alignment: .center)
            .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        var parts = [goal.title, goal.explanation, goal.outcomePreview]
        if isRecommended {
            parts.append(FormaProductCopy.PlanEditGoal.recommendedBadge)
        }
        return parts.joined(separator: ". ")
    }
}

#if DEBUG
#Preview("Goal Option Cards") {
    ScrollView {
        LazyVStack(spacing: FormaTokens.Spacing.sm) {
            GoalOptionCard(
                goal: PlanGoalSelectionBuilder.options(recommendedGoal: .loseFat)[0],
                isSelected: true,
                isRecommended: true,
                onSelect: {}
            )
            GoalOptionCard(
                goal: PlanGoalSelectionBuilder.options(recommendedGoal: .loseFat)[1],
                isSelected: false,
                isRecommended: false,
                onSelect: {}
            )
            GoalOptionCard(
                goal: PlanGoalSelectionBuilder.options(recommendedGoal: .loseFat)[2],
                isSelected: false,
                isRecommended: false,
                onSelect: {}
            )
        }
        .padding()
    }
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
