//
//  OnboardingPrimaryCTA.swift
//  Fitness Coach
//
//  Forma — Shared primary action button for onboarding footers.
//

import SwiftUI

struct OnboardingPrimaryCTA: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var accessibilityHint: String = ""
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 48

    private var resolvedHeight: CGFloat {
        max(buttonHeight, FormaTokens.Layout.minTouchTarget)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: FormaTokens.Spacing.sm) {
                if isLoading {
                    SwiftUI.ProgressView()
                        .tint(OnboardingTheme.ctaText)
                }
                Text(title)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isEnabled && !isLoading ? OnboardingTheme.ctaText : OnboardingTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: resolvedHeight)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading || !isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
    }

  @MainActor
  private var background: some View {
        Group {
            if isEnabled && !isLoading {
                OnboardingTheme.ctaBackground
            } else {
                OnboardingTheme.cardElevated
            }
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        OnboardingPrimaryCTA(title: "See what's next", action: {})
        OnboardingPrimaryCTA(title: "Review my blueprint", isEnabled: false, action: {})
        OnboardingPrimaryCTA(title: "Continue", isLoading: true, action: {})
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
