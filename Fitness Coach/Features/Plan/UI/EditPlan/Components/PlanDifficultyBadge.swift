//
//  PlanDifficultyBadge.swift
//  Fitness Coach
//
//  Forma — Difficulty label for Edit Plan projection previews.
//

import SwiftUI

struct PlanDifficultyBadge: View {
    let model: PlanDifficultyBadgeDisplayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            PlanMetricPill(text: model.label)

            if let description = model.description {
                Text(description)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
#Preview {
    PlanDifficultyBadge(
        model: PlanDifficultyBadgeDisplayModel(
            label: "Moderate",
            description: "Steady progress with room for life."
        )
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
