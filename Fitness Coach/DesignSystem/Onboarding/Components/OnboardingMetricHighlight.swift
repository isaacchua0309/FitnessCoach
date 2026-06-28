//
//  OnboardingMetricHighlight.swift
//  Fitness Coach
//
//  Forma — Large goal metric display for onboarding marketing screens.
//

import SwiftUI

struct OnboardingMetricHighlight: View {
    let value: String
    var showsStabilityBand: Bool = false

    @ScaledMetric(relativeTo: .largeTitle) private var ringReference: CGFloat = 168

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            Text(value)
                .font(OnboardingMarketingTypography.metric)
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText())

            if showsStabilityBand {
                Capsule()
                    .fill(OnboardingTheme.accent.opacity(0.45))
                    .frame(width: ringReference * 0.42, height: 4)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview {
    OnboardingMetricHighlight(value: "70 kg", showsStabilityBand: true)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
