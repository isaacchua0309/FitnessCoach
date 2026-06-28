//
//  OnboardingFooterMessage.swift
//  Fitness Coach
//
//  Forma — Trust footer copy for onboarding marketing screens.
//

import SwiftUI

struct OnboardingFooterMessage: View {
    let message: String
    var alignment: TextAlignment = .center

    var body: some View {
        Text(message)
            .font(OnboardingMarketingTypography.footer)
            .foregroundStyle(OnboardingTheme.tertiaryText)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .accessibilityLabel(message)
    }

    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }
}

#if DEBUG
#Preview {
    OnboardingFooterMessage(
        message: "Built from your body, goal, and activity level."
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
