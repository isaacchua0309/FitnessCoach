//
//  TodayNextActionSection.swift
//  Fitness Coach
//
//  Forma — Single highest-value next action for Today (Mission Control).
//

import SwiftUI

struct TodayNextActionSection: View {
    let action: NextBestActionState
    let onCTA: (NextBestActionCTA) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.NextAction.sectionTitle)

            TodayActionCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(action.title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = action.subtitle {
                        Text(subtitle)
                            .font(FormaTokens.Typography.body)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    actionButtons
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var actionButtons: some View {
        let primaryLabel = FormaProductCopy.Today.NextAction.primaryButtonLabel(for: action.primaryCTA)

        if let primaryLabel {
            HStack(spacing: FormaTokens.Spacing.sm) {
                FormaQuickActionChip(
                    title: primaryLabel,
                    action: { onCTA(action.primaryCTA) },
                    accessibilityHint: FormaProductCopy.Today.nextActionCoachHint
                )

                ForEach(Array(action.secondaryCTAs.enumerated()), id: \.offset) { _, cta in
                    if let label = FormaProductCopy.Today.NextAction.primaryButtonLabel(for: cta) {
                        FormaQuickActionChip(
                            title: label,
                            action: { onCTA(cta) },
                            accessibilityHint: FormaProductCopy.Today.nextActionCoachHint
                        )
                    }
                }
            }
            .padding(.top, FormaTokens.Spacing.xs)
        }
    }
}

#Preview("Log meal") {
    TodayNextActionSection(
        action: NextBestActionState(
            title: FormaProductCopy.Today.NextAction.logFirstMealTitle,
            subtitle: FormaProductCopy.Today.NextAction.logFirstMealSubtitle,
            reason: .logFirstMeal,
            primaryCTA: .logMeal(TodayCoachPrompt.logMeal()),
            secondaryCTAs: [.scanFood]
        ),
        onCTA: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("On track") {
    TodayNextActionSection(
        action: NextBestActionState(
            title: FormaProductCopy.Today.NextAction.onTrackTitle,
            subtitle: FormaProductCopy.Today.NextAction.onTrackSubtitle,
            reason: .onTrack,
            primaryCTA: .none,
            secondaryCTAs: []
        ),
        onCTA: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
