//
//  OnboardingAlmostThereHeroView.swift
//  Fitness Coach
//
//  Forma — Hero moment for the almost-there onboarding milestone.
//

import SwiftUI

struct OnboardingAlmostThereHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let orbSize: CGFloat = 56
    private let iconSize: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(FormaTokens.Color.accentMuted)
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(pulse && !reduceMotion ? 1.04 : 1)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: pulse
                )

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
    }
}

#if DEBUG
#Preview {
    OnboardingAlmostThereHeroView()
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
