//
//  OnboardingInfoCard.swift
//  Fitness Coach
//
//  FitPilot AI — Compact informational card.
//

import SwiftUI

struct OnboardingInfoCard: View {
    let title: String
    let message: String
    var icon: String = "info.circle.fill"

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onboardingCard()
        .accessibilityElement(children: .combine)
    }
}
