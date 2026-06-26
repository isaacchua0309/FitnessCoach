//
//  TrainingLoadingView.swift
//  Fitness Coach
//
//  FitPilot AI — Loading state for Training.
//

import SwiftUI

struct TrainingLoadingView: View {
    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            SwiftUI.ProgressView()
                .tint(FormaTokens.Color.accent)
            Text(FormaProductCopy.Loading.training)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    TrainingLoadingView()
        .preferredColorScheme(.dark)
}
