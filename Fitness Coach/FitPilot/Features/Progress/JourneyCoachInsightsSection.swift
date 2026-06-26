//
//  JourneyCoachInsightsSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyCoachInsightsSection: View {
    let insights: [JourneyCoachInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: "Coach insights")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                        Text(insight.message)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if index < insights.count - 1 {
                            FitPilotPlanRowDivider()
                        }
                    }
                }
            }
        }
    }
}
