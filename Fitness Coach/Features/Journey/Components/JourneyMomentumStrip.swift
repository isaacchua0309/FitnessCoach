//
//  JourneyMomentumStrip.swift
//  Fitness Coach
//
//  Forma — Lightweight momentum line above the transformation hero.
//

import SwiftUI

struct JourneyMomentumStrip: View {
    let state: JourneyMomentumState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(state.headline)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Theme.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = state.detail {
                Text(detail)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    JourneyMomentumStrip(
        state: JourneyMomentumState(
            isVisible: true,
            sectionTitle: FormaProductCopy.Journey.Momentum.sectionTitle,
            headline: FormaProductCopy.Journey.Momentum.activeHeadline(days: 7),
            detail: nil,
            streakDays: 7,
            emptyMessage: nil
        )
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
