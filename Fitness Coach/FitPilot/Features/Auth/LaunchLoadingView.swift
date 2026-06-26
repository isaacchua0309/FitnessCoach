//
//  LaunchLoadingView.swift
//  Fitness Coach
//
//  FitPilot — Launch splash while auth session is being determined.
//

import SwiftUI

struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: 14) {
                SwiftUI.ProgressView()
                    .controlSize(.large)
                    .tint(OnboardingTheme.accent)

                Text("Loading...")
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.secondaryText)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    LaunchLoadingView()
}
