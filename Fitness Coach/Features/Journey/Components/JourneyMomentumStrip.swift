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
        JourneyMomentumChip(headline: state.headline, detail: state.detail)
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
