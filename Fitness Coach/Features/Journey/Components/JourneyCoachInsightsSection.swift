//
//  JourneyCoachInsightsSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyCoachInsightsSection: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.sectionCoachNote)

            FitPilotPlanCard {
                Text(message)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
