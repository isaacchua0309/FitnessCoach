//
//  JourneyDashboardHeroSection.swift
//  Fitness Coach
//
//  Forma — Week, chapter, and momentum hero for the Journey dashboard.
//

import SwiftUI

struct JourneyDashboardHeroSection: View {
    let state: JourneyDashboardHeroState

    var body: some View {
        JourneyCard(elevation: .hero) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(state.weekLabel)
                    .font(JourneyTypography.cardSupporting.weight(.semibold))
                    .foregroundStyle(FormaTokens.Theme.primary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .accessibilityHidden(true)

                Text(state.chapterTitle)
                    .font(JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHidden(true)

                Text(state.encouragingSentence)
                    .font(JourneyTypography.cardSupporting)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)

                if !state.compactStats.isEmpty {
                    Text(state.compactStats.map(\.label).joined(separator: " · "))
                        .font(FormaTokens.Typography.caption.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
        .accessibilityIdentifier("journey-dashboard-hero")
        .formaThemeReactive()
    }
}

#if DEBUG
#Preview("Brand new user") {
    let dashboard = JourneyPreviewData.brandNewUser
    JourneyDashboardHeroSection(state: dashboard.dashboardHero)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
#endif
