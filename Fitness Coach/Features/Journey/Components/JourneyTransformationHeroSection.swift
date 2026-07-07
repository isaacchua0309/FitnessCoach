//
//  JourneyTransformationHeroSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyTransformationHeroSection: View {
    let state: JourneyTransformationState
    var onCTA: ((JourneyCTA) -> Void)?

    var body: some View {
        JourneyCard(elevation: .hero) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                MainTabHeroText(state.primaryMessage, tier: .narrative)
                    .accessibilityHidden(true)

                if !state.body.isEmpty {
                    Text(state.body)
                        .font(JourneyTypography.cardSupporting)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }

                if state.showsProgressBar {
                    progressBlock
                }

                if state.showsWeightAnchors, let weights = state.weightAnchorsCopy {
                    Text(weights)
                        .font(FormaTokens.Typography.caption2.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .accessibilityHidden(true)
                }

                if let actionTitle = state.nextActionTitle,
                   let cta = state.nextActionCTA,
                   let onCTA {
                    JourneyCTAButton(cta: cta, title: actionTitle) {
                        onCTA(cta)
                    }
                    .padding(.top, JourneyLayout.compactSpacing)
                    .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            JourneyProgressBar(
                progress: state.progressBarFill,
                height: JourneyLayout.heroProgressBarHeight,
                prominent: true
            )
            .accessibilityLabel(FormaProductCopy.Journey.Transformation.progressAccessibilityLabel)
            .accessibilityValue(state.progressBarAccessibilityValue)

            Text(state.progressLabel)
                .font(FormaTokens.Typography.caption2.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.top, JourneyLayout.compactSpacing)
    }
}

// MARK: - Previews

#Preview("New user") {
    JourneyTransformationHeroSection(state: JourneyPreviewData.brandNewUser.transformation)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Active fat loss") {
    JourneyTransformationHeroSection(state: JourneyPreviewData.strongMomentum.transformation)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    JourneyTransformationHeroSection(state: JourneyPreviewData.strongMomentum.transformation)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark mode") {
    JourneyTransformationHeroSection(state: JourneyPreviewData.strongMomentum.transformation)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
        .preferredColorScheme(.dark)
}
