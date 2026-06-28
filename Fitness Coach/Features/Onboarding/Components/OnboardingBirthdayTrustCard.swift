//
//  OnboardingBirthdayTrustCard.swift
//  Fitness Coach
//
//  Forma — Compact trust note for birthday onboarding.
//

import SwiftUI

struct OnboardingBirthdayTrustNote: View {
    let copy: String

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.xs) {
            Image(systemName: "lock.shield")
                .font(.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .accessibilityHidden(true)

            Text(copy)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(copy)
    }
}

/// Legacy name retained for previews and gradual migration.
typealias OnboardingBirthdayTrustCard = OnboardingBirthdayTrustNote

#if DEBUG
#Preview("Birthday Trust") {
    OnboardingBirthdayTrustNote(
        copy: FormaProductCopy.Onboarding.Flow.Birthday.trustNote
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
#endif
