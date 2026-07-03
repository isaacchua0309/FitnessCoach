//
//  JourneyGoalProjectionSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyGoalProjectionSection: View {
    let state: JourneyGoalProjectionState
    var onCTA: ((JourneyCTA) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            JourneySectionLabel(title: state.sectionTitle)

            JourneyCard(elevation: .standard) {
                VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
                    Text(state.title)
                        .font(JourneyTypography.cardHeadline)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHidden(true)

                    Text(state.detail)
                        .font(JourneyTypography.cardSupporting)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    if showsLogWeightCTA, let onCTA {
                        JourneyCTAButton(cta: .logWeight) {
                            onCTA(.logWeight)
                        }
                        .padding(.top, JourneyLayout.compactSpacing)
                        .accessibilityHidden(true)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var showsLogWeightCTA: Bool {
        switch state.status {
        case .insufficientData, .flatTrend, .awayFromGoal:
            return true
        case .hidden, .towardGoal, .goalReached:
            return false
        }
    }
}

// MARK: - Previews

#Preview("Insufficient data") {
    JourneyGoalProjectionSection(state: JourneyPreviewData.brandNewUser.goalProjection)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Toward goal") {
    JourneyGoalProjectionSection(state: JourneyPreviewData.strongMomentum.goalProjection)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
