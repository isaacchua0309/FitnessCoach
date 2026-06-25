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

            Text(rationale)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
