//
//  OnboardingAppleHealthHeroIcon.swift
//  Fitness Coach
//
//  Forma — Compact hero visual for Apple Health onboarding.
//

import SwiftUI

struct OnboardingAppleHealthHeroIcon: View {
    let style: OnboardingAppleHealthHeroStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let orbSize: CGFloat = 48
    private let iconSize: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(FormaTokens.Color.accentMuted)
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(style == .heart && pulse && !reduceMotion ? 1.03 : 1)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: pulse
                )

            switch style {
            case .loading:
                SwiftUI.ProgressView()
                    .controlSize(.small)
                    .tint(OnboardingTheme.primary)
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
    VStack(spacing: 24) {
        OnboardingAppleHealthHeroIcon(style: .heart)
        OnboardingAppleHealthHeroIcon(style: .loading)
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
