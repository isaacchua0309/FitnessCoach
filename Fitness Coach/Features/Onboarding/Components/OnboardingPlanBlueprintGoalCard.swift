//
//  OnboardingPlanBlueprintGoalCard.swift
//  Fitness Coach
//
//  Forma — Personalization summary for plan-learned milestone.
//

import SwiftUI

struct OnboardingPlanBlueprintPersonalizationSummaryCard: View {
    let summary: String

    var body: some View {
        Text(summary)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(OnboardingTheme.primaryText)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(FormaTokens.Spacing.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                FormaTokens.Color.accentMuted.opacity(0.85),
                                FormaTokens.Color.surfaceSubtle
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                            .stroke(OnboardingTheme.accent.opacity(0.18), lineWidth: 1)
                    }
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Your plan: \(summary)")
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintPersonalizationSummaryCard(
        summary: "Lose 3.5 kg · 70 kg → 66.5 kg · 175 cm, 70 kg · Moderately active"
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
