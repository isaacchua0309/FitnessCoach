//
//  OnboardingPlanBlueprintAnticipationSection.swift
//  Fitness Coach
//
//  Forma — Personalization pillars for plan-learned milestone.
//

import SwiftUI

struct OnboardingPlanBlueprintPillarsSection: View {
    let pillars: [OnboardingPlanBlueprintPillar]
    let accessibilityLabel: String

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(pillars) { pillar in
                pillarRow(pillar)
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func pillarRow(_ pillar: OnboardingPlanBlueprintPillar) -> some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(FormaTokens.Color.accentMuted)
                    .frame(width: 30, height: 30)

                Image(systemName: pillar.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent.opacity(0.92))
            }
            .accessibilityHidden(true)

            Text(pillar.title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(pillar.title)
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintPillarsSection(
        pillars: OnboardingPlanBlueprintBuilder.build(
            from: OnboardingPreviewData.formState
        ).pillars,
        accessibilityLabel: FormaProductCopy.Onboarding.Flow.Summary.Pillars.accessibilityLabel
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
