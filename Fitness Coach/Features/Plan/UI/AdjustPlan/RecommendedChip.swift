//
//  RecommendedChip.swift
//  Fitness Coach
//
//  Forma — Compact recommended-goal badge for Adjust Plan goal cards.
//

import SwiftUI

struct RecommendedChip: View {
    let text: String

    @Environment(\.formaPlanColors) private var theme

    var body: some View {
        Text(text)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, FormaTokens.Spacing.xs)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(theme.accentSoft)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    RecommendedChip(text: FormaProductCopy.PlanEditGoal.recommendedBadge)
        .padding()
        .background(FormaPlanTokens.Color.planBackground)
        .formaThemePreview()
}
#endif
