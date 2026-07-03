//
//  PlanMetricPill.swift
//  Fitness Coach
//
//  Forma — Accent capsule label for Edit Plan metrics and units.
//

import SwiftUI

struct PlanMetricPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaPlanTokens.Color.planAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(FormaPlanTokens.Color.planAccentSoft)
            }
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    PlanMetricPill(text: "kg")
        .padding()
        .background(FormaPlanTokens.Color.planBackground)
        .formaThemePreview()
}
#endif
