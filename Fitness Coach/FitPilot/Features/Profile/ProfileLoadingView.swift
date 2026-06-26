//
//  ProfileLoadingView.swift
//  Fitness Coach
//
//  FitPilot AI — Loading state for Profile.
//

import SwiftUI

struct ProfileLoadingView: View {
    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            SwiftUI.ProgressView()
                .tint(FormaTokens.Color.accent)
            Text(FormaProductCopy.Loading.plan)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    ProfileLoadingView()
        .preferredColorScheme(.dark)
}
