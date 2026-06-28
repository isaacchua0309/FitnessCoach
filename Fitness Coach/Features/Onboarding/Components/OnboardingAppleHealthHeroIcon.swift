//
//  OnboardingAppleHealthHeroIcon.swift
//  Fitness Coach
//
//  Forma — Hero visual for Apple Health onboarding.
//

import SwiftUI

struct OnboardingAppleHealthHeroIcon: View {
    let style: OnboardingAppleHealthHeroStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let orbSize: CGFloat = 96
    private let iconSize: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(FormaTokens.Color.accentMuted)
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(style == .heart && pulse && !reduceMotion ? 1.04 : 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

            switch style {
            case .loading:
                SwiftUI.ProgressView()
                    .controlSize(.large)
                    .tint(OnboardingTheme.accent)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .transition(.scale.combined(with: .opacity))
            case .heart:
                Image(systemName: "heart.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .onAppear {
            guard style == .heart, !reduceMotion else { return }
            pulse = true
        }
    }
}

#if DEBUG
#Preview("Hero States") {
    VStack(spacing: 32) {
        OnboardingAppleHealthHeroIcon(style: .heart)
        OnboardingAppleHealthHeroIcon(style: .loading)
        OnboardingAppleHealthHeroIcon(style: .success)
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
