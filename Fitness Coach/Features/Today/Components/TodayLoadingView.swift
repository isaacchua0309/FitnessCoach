//
//  TodayLoadingView.swift
//  Fitness Coach
//
//  FitPilot AI — Loading state for Today.
//

import SwiftUI

struct TodayLoadingView: View {
    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            SwiftUI.ProgressView()
                .tint(FormaTokens.Color.accent)
            Text(FormaProductCopy.Loading.today)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    TodayLoadingView()
        .preferredColorScheme(.dark)
}
