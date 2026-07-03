//
//  TodaySmartCoachBanner.swift
//  Fitness Coach
//
//  Forma — Contextual Smart Coach guidance banner for Today.
//

import SwiftUI

struct TodaySmartCoachBanner: View {
    let smartCoach: TodaySmartCoachState
    let onOpenCoach: (String?) -> Void

    var body: some View {
        if smartCoach.isVisible {
            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(smartCoach.message)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let actionTitle = smartCoach.coachActionTitle,
                       let prefill = smartCoach.coachPrefill {
                        FormaQuickActionChip(
                            title: actionTitle,
                            action: { onOpenCoach(prefill) },
                            accessibilityHint: FormaProductCopy.Today.askCoachCTAAccessibilityHint
                        )
                    }
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(smartCoach.accessibilityLabel)
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
