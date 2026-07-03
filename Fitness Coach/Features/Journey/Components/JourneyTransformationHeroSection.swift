//
//  JourneyTransformationHeroSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyTransformationHeroSection: View {
    let state: JourneyTransformationState
    var onCTA: ((JourneyCTA) -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var primarySize: CGFloat = 34

    var body: some View {
        FormaPlanCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(state.title)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .textCase(.uppercase)
                    .accessibilityHidden(true)

                Text(state.primaryMessage)
                    .font(.system(size: primarySize, weight: .bold, design: .rounded))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)

                Text(state.body)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)

                if state.showsProgressBar {
                    progressBlock
                }

                if state.showsWeightAnchors, let weights = state.weightAnchorsCopy {
                    Text(weights)
                        .font(FormaTokens.Typography.caption.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .accessibilityHidden(true)
                }

                if let actionTitle = state.nextActionTitle,
                   let cta = state.nextActionCTA,
                   let onCTA {
                    JourneyCTAButton(cta: cta, title: actionTitle) {
                        onCTA(cta)
                    }
                    .padding(.top, FormaTokens.Spacing.xs)
                    .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            SwiftUI.ProgressView(value: state.progressBarFill)
                .tint(FormaTokens.Color.progress)
                .accessibilityLabel(FormaProductCopy.Journey.Transformation.progressAccessibilityLabel)
                .accessibilityValue(state.progressBarAccessibilityValue)

            Text(state.progressLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.top, FormaTokens.Spacing.xs)
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

#Preview("Near goal") {
    JourneyTransformationHeroSection(state: JourneyPreviewData.nearGoal.transformation)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Gain goal") {
    JourneyTransformationHeroSection(state: JourneyPreviewData.gainGoal.transformation)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Plateau") {
    JourneyTransformationHeroSection(state: JourneyPreviewData.plateau.transformation)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Maintain goal") {
    JourneyTransformationHeroSection(state: JourneyPreviewData.maintainGoal.transformation)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
