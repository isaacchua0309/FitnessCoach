//
//  PlanRationaleSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanRationaleSection: View {
    let rationale: String

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionLabel(title: "Why this plan?")

            FitPilotPlanCard {
                Text(rationale)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
