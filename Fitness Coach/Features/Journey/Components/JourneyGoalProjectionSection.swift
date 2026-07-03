//
//  JourneyGoalProjectionSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyGoalProjectionSection: View {
    let state: JourneyGoalProjectionState
    var onCTA: ((JourneyCTA) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    Text(state.title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHidden(true)

                    Text(state.detail)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    if showsLogWeightCTA, let onCTA {
                        JourneyCTAButton(cta: .logWeight) {
                            onCTA(.logWeight)
                        }
                        .padding(.top, FormaTokens.Spacing.xs)
                        .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview("Near goal") {
    JourneyGoalProjectionSection(state: JourneyPreviewData.nearGoal.goalProjection)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Sparse data") {
    JourneyGoalProjectionSection(state: JourneyPreviewData.sparseData.goalProjection)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
