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

            VStack(alignment: .leading, spacing: 14) {
                ForEach(insights) { insight in
                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
