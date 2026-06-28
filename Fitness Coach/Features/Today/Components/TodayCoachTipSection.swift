//
//  TodayCoachTipSection.swift
//  Fitness Coach
//
//  Forma — Deterministic Coach Tip card on Today (no API).
//

import SwiftUI

struct TodayCoachTipSection: View {
    let tip: AICoachTipState
    let onOpenCoach: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.CoachTip.sectionTitle)

            Button {
                onOpenCoach(tip.coachPrefill)
            } label: {
                FitPilotPlanCard {
                    HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.accent)
                            .padding(.top, 2)

                        Text(tip.message)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, FormaTokens.Spacing.xs)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(FormaProductCopy.Today.CoachTip.sectionTitle). \(tip.message)"
            )
            .accessibilityHint(FormaProductCopy.Today.CoachTip.accessibilityHint)
        }
    }
}

#Preview {
    TodayCoachTipSection(
        tip: AICoachTipState(
            message: FormaProductCopy.Today.CoachTip.lunchProteinGap(
                caloriesRemaining: "1,600",
                proteinGrams: 35
            ),
            coachPrefill: TodayCoachPrompt.logMeal(.lunch)
        ),
        onOpenCoach: { _ in }
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
