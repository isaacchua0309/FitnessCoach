//
//  OnboardingPlanBlueprintGoalCard.swift
//  Fitness Coach
//
//  Forma — Goal hero card with optional journey strip and pace/timeline summary.
//

import SwiftUI

struct OnboardingPlanBlueprintGoalHeroCard: View {
    let state: OnboardingPlanBlueprintGoalCardState
    var visualProfile: OnboardingPlanBlueprintVisualProfile?
    var launchReady: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingVisionLayoutProfile) private var layoutProfile
    @Environment(\.onboardingVisionZoneHeight) private var zoneHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var launchPulse = false

    @ScaledMetric(relativeTo: .largeTitle) private var targetWeightFontSize: CGFloat = 36
    @ScaledMetric(relativeTo: .largeTitle) private var compactTargetWeightFontSize: CGFloat = 32

    private var cardPadding: CGFloat {
        layoutProfile == .compact ? FormaTokens.Spacing.md : FormaTokens.Spacing.lg
    }

    private var resolvedTargetFontSize: CGFloat {
        layoutProfile == .compact ? compactTargetWeightFontSize : targetWeightFontSize
    }

    private var metricsMaxWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 168 : (layoutProfile == .compact ? 132 : 148)
    }

    private var showsJourneyStrip: Bool {
        guard let profile = visualProfile else { return false }
        switch profile.style {
        case .loss, .gain:
            return true
        case .maintain, .fallback:
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layoutProfile == .compact ? FormaTokens.Spacing.sm : FormaTokens.Spacing.md) {
            if showsJourneyStrip, let profile = visualProfile {
                OnboardingPlanBlueprintJourneyStrip(profile: profile)
            }

            HStack(alignment: .center, spacing: FormaTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.directionLabel)
                        .font(OnboardingMarketingTypography.blueprintSupporting.weight(.medium))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(state.targetWeight)
                        .font(.system(size: resolvedTargetFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: layoutProfile == .compact ? 6 : 8) {
                    textMetric(caption: state.paceCaption, value: state.paceValue)
                    textMetric(caption: state.timelineCaption, value: state.timelineValue)
                }
                .frame(maxWidth: metricsMaxWidth)
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, maxHeight: zoneHeight > 0 ? zoneHeight : nil, alignment: .center)
        .onboardingPlanBlueprintSurface(.card, launchPulse: launchPulse)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: launchReady) { _, ready in
            guard ready, !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: OnboardingPlanBlueprintLaunchTiming.pulseDuration)
                    .repeatForever(autoreverses: true)
            ) {
                launchPulse = true
            }
        }
    }

    private var accessibilityLabel: String {
        "\(state.directionLabel) \(state.targetWeight). \(state.paceCaption): \(state.paceValue). \(state.timelineCaption): \(state.timelineValue)"
    }

    private func textMetric(caption: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(OnboardingMarketingTypography.blueprintSupporting.weight(.medium))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(value)
                .font(OnboardingMarketingTypography.blueprintCardTitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        }
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintGoalHeroCard(
        state: OnboardingPlanBlueprintBuilder.build(from: OnboardingPreviewData.formState).goalCard,
        visualProfile: OnboardingPlanBlueprintBuilder.build(from: OnboardingPreviewData.formState).visualProfile,
        launchReady: true
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
