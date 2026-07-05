//
//  PlanHeaderSection.swift
//  Fitness Coach
//
//  Forma — Plan screen header. Preview/test wrapper around PageHeader.
//

import SwiftUI

struct PlanHeaderSection: View {
    let state: PlanHeaderState

    var body: some View {
        PageHeader(
            title: FormaProductCopy.PlanHeader.title,
            subtitle: FormaProductCopy.PlanHeader.subtitle,
            trailingAction: {
                PageActionPill(title: FormaProductCopy.PlanMissionControl.adjustPlanPill)
            }
        )
        .accessibilityLabel(state.accessibilitySummary)
    }
}

#Preview {
    PlanHeaderSection(state: PlanMissionControlFixtures.loseDashboard.header)
        .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
