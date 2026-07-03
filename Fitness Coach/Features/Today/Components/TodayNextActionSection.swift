//
//  TodayNextActionSection.swift
//  Fitness Coach
//
//  Forma — Next Best Action card for Today (Mission Control item 2).
//

import SwiftUI

struct TodayNextActionSection: View {
    let action: NextBestActionState
    let onPrimaryCTA: () -> Void
    var onSecondaryCTA: ((NextBestActionCTA) -> Void)?
    var onViewed: (() -> Void)?

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
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)

                    if let subtitle = display.subtitle {
                        Text(subtitle)
                            .font(FormaTokens.Typography.body)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }

                    if display.showsPrimaryButton || display.showsSecondaryButton {
                        HStack(spacing: FormaTokens.Spacing.sm) {
                            if display.showsPrimaryButton, let buttonTitle = display.primaryButtonTitle {
                                FormaQuickActionChip(
                                    title: buttonTitle,
                                    action: onPrimaryCTA,
                                    accessibilityHint: FormaProductCopy.Today.NextAction.primaryButtonHint
                                )
                                .accessibilityLabel(buttonTitle)
                            }

                            if display.showsSecondaryButton,
                               let secondaryTitle = display.secondaryButtonTitle,
                               let secondaryCTA = action.secondaryCTAs.first {
                                FormaQuickActionChip(
                                    title: secondaryTitle,
                                    action: { onSecondaryCTA?(secondaryCTA) },
                                    accessibilityHint: FormaProductCopy.Today.NextAction.primaryButtonHint
                                )
                                .accessibilityLabel(secondaryTitle)
                            }
                        }
                        .padding(.top, FormaTokens.Spacing.xs)
                    }
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(display.accessibilityLabel)
        .onAppear {
            onViewed?()
        }
    }
}

#Preview("Protein") {
    TodayNextActionSection(
        action: NextBestActionState(
            title: FormaProductCopy.Today.NextAction.eatProteinTitle,
            subtitle: FormaProductCopy.Today.NextAction.eatProteinSubtitle,
            reason: .eatProtein,
            primaryCTA: .scanFood,
            secondaryCTAs: [.logMeal(TodayCoachPrompt.logMeal())]
        ),
        onPrimaryCTA: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Hydration") {
    TodayNextActionSection(
        action: NextBestActionState(
            title: FormaProductCopy.Today.NextAction.hydrationBehindTitle,
            subtitle: FormaProductCopy.Today.NextAction.hydrationBehindSubtitle,
            reason: .addWater,
            primaryCTA: .addWater(amountMl: 500),
            secondaryCTAs: []
        ),
        onPrimaryCTA: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("All targets met") {
    TodayNextActionSection(
        action: NextBestActionState(
            title: FormaProductCopy.Today.NextAction.allTargetsMetTitle,
            subtitle: FormaProductCopy.Today.NextAction.allTargetsMetSubtitle,
            reason: .allTargetsMet,
            primaryCTA: .none,
            secondaryCTAs: []
        ),
        onPrimaryCTA: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
