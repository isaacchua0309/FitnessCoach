//
//  JourneyNextActionCard.swift
//  Fitness Coach
//
//  Forma — Prominent next-achievement card for early Journey users.
//

import SwiftUI

struct JourneyNextActionCard: View {
    let state: JourneyNextActionCardState
    var onCTA: ((WeeklyProgressCTA) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            JourneySectionLabel(title: state.sectionTitle)

            JourneyCard(elevation: .featured) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(state.title)
                        .font(JourneyTypography.cardHeadline)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(state.progressLabel)
                        .font(JourneyTypography.metricValue)
                        .foregroundStyle(FormaTokens.Theme.primary)

                    Text(state.detail)
                        .font(JourneyTypography.cardSupporting)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let cta = state.cta, let onCTA {
                        WeeklyProgressCTAButton(cta: cta, prominence: .primary) {
                            onCTA(cta)
                        }
                        .padding(.top, JourneyLayout.compactSpacing)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("journey-next-action-card")
        .formaThemeReactive()
    }
}

#if DEBUG
#Preview("Log first meal") {
    let dashboard = JourneyPreviewData.brandNewUser
    if let card = dashboard.screenPresentation.unlockDashboard.nextActionCard {
        JourneyNextActionCard(state: card) { _ in }
            .padding()
            .background(FormaTokens.Color.canvas)
            .formaThemePreview()
    }
}
#endif
