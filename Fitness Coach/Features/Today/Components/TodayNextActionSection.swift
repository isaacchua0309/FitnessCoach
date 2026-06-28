//
//  TodayNextActionSection.swift
//  Fitness Coach
//
//  Forma — Single highest-value next action for Today (Mission Control).
//

import SwiftUI

struct TodayNextActionSection: View {
    let action: NextBestActionState
    let onPrimaryCTA: () -> Void

    private var display: TodayNextActionDisplayModel {
        TodayNextActionFormatting.displayModel(for: action)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: display.sectionTitle)

            TodayActionCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(display.headline)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = display.subtitle {
                        Text(subtitle)
                            .font(FormaTokens.Typography.body)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if display.showsPrimaryButton, let buttonTitle = display.primaryButtonTitle {
                        FormaQuickActionChip(
                            title: buttonTitle,
                            action: onPrimaryCTA,
                            accessibilityHint: FormaProductCopy.Today.NextAction.primaryButtonHint
                        )
                        .padding(.top, FormaTokens.Spacing.xs)
                        .accessibilityLabel(buttonTitle)
                    }
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(display.accessibilityLabel)
    }
}

#Preview("Protein") {
    TodayNextActionSection(
        action: NextBestActionState(
            title: FormaProductCopy.Today.NextAction.eatProteinTitle(grams: 35),
            subtitle: FormaProductCopy.Today.NextAction.eatProteinSubtitle,
            reason: .eatProtein,
            primaryCTA: .logMeal(TodayCoachPrompt.logProtein),
            secondaryCTAs: []
        ),
        onPrimaryCTA: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Log lunch") {
    TodayNextActionSection(
        action: NextBestActionState(
            title: FormaProductCopy.Today.NextAction.logMissedMealTitle(.lunch),
            subtitle: FormaProductCopy.Today.NextAction.logMissedMealSubtitle(.lunch),
            reason: .logMissedMeal(.lunch),
            primaryCTA: .logMeal(TodayCoachPrompt.logMeal(.lunch)),
            secondaryCTAs: []
        ),
        onPrimaryCTA: {}
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
        onPrimaryCTA: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
