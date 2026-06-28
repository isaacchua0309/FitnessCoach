//
//  OnboardingPlanBlueprintGoalCard.swift
//  Fitness Coach
//
//  Forma — Goal hero for plan blueprint milestone.
//

import SwiftUI

struct OnboardingPlanBlueprintGoalCard: View {
    let badge: String
    let heroMetric: String
    let subtitle: String

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Text(badge.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .tracking(0.6)
                .accessibilityHidden(true)

            Text(heroMetric)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.72)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, FormaTokens.Spacing.lg)
        .padding(.horizontal, FormaTokens.Spacing.md)
        .frame(maxWidth: .infinity)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge). \(heroMetric). \(subtitle)")
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintGoalCard(
        badge: FormaProductCopy.Onboarding.Flow.Summary.goalSectionTitle,
        heroMetric: "Lose 3.5 kg",
        subtitle: "70 kg → 66.5 kg"
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
