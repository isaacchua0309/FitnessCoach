//
//  CoachHeader.swift
//  Fitness Coach
//
//  FitPilot AI — Coach screen header zone.
//

import SwiftUI

struct CoachHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xs) {
            Text("Coach")
                .font(CoachDesignTokens.Typography.largeTitle)
                .foregroundStyle(CoachDesignTokens.Color.primaryText)

            Text(FormaProductCopy.Coach.headerSubtitle)
                .font(CoachDesignTokens.Typography.subtitle)
                .foregroundStyle(CoachDesignTokens.Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CoachDesignTokens.Layout.horizontalPadding)
        .padding(.top, CoachDesignTokens.Spacing.sm)
        .padding(.bottom, CoachDesignTokens.Spacing.md)
    }
}

#Preview {
    CoachHeader()
        .background(CoachDesignTokens.Color.background)
        .preferredColorScheme(.dark)
}
