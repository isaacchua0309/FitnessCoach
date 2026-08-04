//
//  JourneyProgressDots.swift
//  Fitness Coach
//
//  Forma — Compact progress dots for Journey unlock states.
//

import SwiftUI

struct JourneyProgressDots: View {
    let completedCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            ForEach(0..<max(totalCount, 0), id: \.self) { index in
                Circle()
                    .fill(index < completedCount
                        ? FormaTokens.Theme.primary
                        : FormaTokens.Color.surfaceSubtle)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        FormaProductCopy.Journey.Unlock.progressAccessibility(
            completed: completedCount,
            total: totalCount
        )
    }
}

#if DEBUG
#Preview("Partial progress") {
    JourneyProgressDots(completedCount: 2, totalCount: 5)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
#endif
