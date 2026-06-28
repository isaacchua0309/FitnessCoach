//
//  OnboardingPlanBlueprintAnticipationSection.swift
//  Fitness Coach
//
//  Forma — Anticipation bridge before plan generation.
//

import SwiftUI

struct OnboardingPlanBlueprintAnticipationSection: View {
    let title: String
    let bullets: [OnboardingFeatureBullet]
    let accessibilityLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .textCase(.uppercase)
                .tracking(0.4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: FormaTokens.Spacing.xs) {
                ForEach(bullets) { bullet in
                    anticipationChip(bullet)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func anticipationChip(_ bullet: OnboardingFeatureBullet) -> some View {
        HStack(spacing: 5) {
            Image(systemName: bullet.icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .accessibilityHidden(true)

            Text(bullet.title)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.accentMuted.opacity(0.55))
        )
        .accessibilityLabel(bullet.title)
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintAnticipationSection(
        title: FormaProductCopy.Onboarding.Flow.Summary.Anticipation.sectionTitle,
        bullets: OnboardingPlanBlueprintBuilder.build(
            from: OnboardingPreviewData.formState
        ).anticipationBullets,
        accessibilityLabel: FormaProductCopy.Onboarding.Flow.Summary.Anticipation.accessibilityLabel
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
