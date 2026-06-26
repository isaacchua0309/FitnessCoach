//
//  ProgressLoadingView.swift
//  Fitness Coach
//
//  FitPilot AI — Loading state for Progress.
//

import SwiftUI

struct ProgressLoadingView: View {
    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            SwiftUI.ProgressView()
                .tint(FormaTokens.Color.accent)
            Text(FormaProductCopy.Loading.journey)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    ProgressLoadingView()
        .preferredColorScheme(.dark)
}
