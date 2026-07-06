//
//  TodaySmartCoachBanner.swift
//  Fitness Coach
//
//  Forma — Contextual Smart Coach guidance banner for Today.
//

import SwiftUI

struct TodaySmartCoachBanner: View {
    let smartCoach: TodaySmartCoachState
    let onOpenCoach: (CoachLaunchIntent) -> Void
    var onViewed: (() -> Void)?

    @Environment(\.theme) private var theme

    var body: some View {
        if smartCoach.isVisible {
            MainTabCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(smartCoach.message)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let actionTitle = smartCoach.coachActionTitle,
                       let prefill = smartCoach.coachPrefill {
                        FormaQuickActionChip(
                            title: actionTitle,
                            action: {
                                if let prefill = smartCoach.coachPrefill {
                                    onOpenCoach(.prefill(prefill))
                                } else {
                                    onOpenCoach(.normal)
                                }
                            },
                            accessibilityHint: FormaProductCopy.Today.askCoachCTAAccessibilityHint
                        )
                    }
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(smartCoach.accessibilityLabel)
            .onAppear {
                onViewed?()
            }
        }
    }
}

#Preview("Protein behind") {
    TodaySmartCoachBanner(
        smartCoach: TodaySmartCoachState(
            context: .proteinBehind,
            message: FormaProductCopy.Today.SmartCoach.proteinBehind,
            coachPrefill: TodayCoachPrompt.logProtein,
            coachActionTitle: FormaProductCopy.Today.SmartCoach.coachProteinAction
        ),
        onOpenCoach: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Water behind") {
    TodaySmartCoachBanner(
        smartCoach: TodaySmartCoachState(
            context: .waterBehind,
            message: FormaProductCopy.Today.SmartCoach.waterBehind,
            coachPrefill: nil,
            coachActionTitle: nil
        ),
        onOpenCoach: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
