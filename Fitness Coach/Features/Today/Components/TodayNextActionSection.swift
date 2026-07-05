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
                        .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .accessibilityAddTraits(.isHeader)

                    if let subtitle = display.subtitle {
                        Text(subtitle)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                    }

                    if display.showsPrimaryButton || display.showsSecondaryButton {
                        actionButtons
                            .padding(.top, TodayLayout.compactSpacing)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(display.accessibilityLabel)
        .onAppear {
            onViewed?()
        }
        .formaThemeReactive()
    }

    @ViewBuilder
    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            buttonRow
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                buttonRow
            }
        }
    }

    private var buttonRow: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            if display.showsPrimaryButton, let buttonTitle = display.primaryButtonTitle {
                FormaQuickActionChip(
                    title: buttonTitle,
                    action: onPrimaryCTA,
                    style: .primary,
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
                    style: .secondary,
                    accessibilityHint: FormaProductCopy.Today.NextAction.primaryButtonHint
                )
                .accessibilityLabel(secondaryTitle)
            }
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
