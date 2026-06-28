//
//  OnboardingPlanBlueprintGoalCard.swift
//  Fitness Coach
//
//  Forma — Compact goal card with visual pace/timeline bars.
//

import SwiftUI

struct OnboardingPlanBlueprintGoalHeroCard: View {
    let state: OnboardingPlanBlueprintGoalCardState
    var launchReady: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingVisionLayoutProfile) private var layoutProfile
    @Environment(\.onboardingVisionZoneHeight) private var zoneHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var launchPulse = false

    @ScaledMetric(relativeTo: .largeTitle) private var targetWeightFontSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption2) private var metricBarHeight: CGFloat = 4

    private var verticalPadding: CGFloat {
        layoutProfile == .compact ? 6 : 10
    }

    private var metricsMaxWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 168 : (layoutProfile == .compact ? 132 : 148)
    }

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.directionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .textCase(.uppercase)
                    .tracking(0.45)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(state.targetWeight)
                    .font(.system(size: targetWeightFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: layoutProfile == .compact ? 6 : 8) {
                visualMetric(caption: state.paceCaption, value: state.paceValue, fill: 0.68)
                visualMetric(caption: state.timelineCaption, value: state.timelineValue, fill: 0.82)
            }
            .frame(maxWidth: metricsMaxWidth)
        }
        .padding(.horizontal, FormaTokens.Spacing.md)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: zoneHeight > 0 ? zoneHeight : nil, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FormaTokens.Color.accentMuted.opacity(0.9),
                            FormaTokens.Color.surfaceSubtle
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                        .stroke(
                            OnboardingTheme.accent.opacity(launchPulse ? 0.42 : 0.2),
                            lineWidth: launchPulse ? 1.5 : 1
                        )
                }
        }
        .shadow(
            color: launchPulse ? OnboardingTheme.accent.opacity(0.1) : .clear,
            radius: launchPulse ? 6 : 0
        )
        .scaleEffect(launchPulse && !reduceMotion ? 1.008 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(state.directionLabel) \(state.targetWeight). \(state.paceCaption): \(state.paceValue). \(state.timelineCaption): \(state.timelineValue)"
        )
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

    private func visualMetric(caption: String, value: String, fill: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(caption)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(OnboardingTheme.border.opacity(0.25))
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    OnboardingTheme.accent.opacity(launchPulse ? 0.72 : 0.55),
                                    OnboardingTheme.accent.opacity(launchPulse ? 1 : 0.92)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * (launchPulse ? min(fill + 0.04, 0.96) : fill))
                }
            }
            .frame(height: metricBarHeight)

            Text(value)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintGoalHeroCard(
        state: OnboardingPlanBlueprintBuilder.build(from: OnboardingPreviewData.formState).goalCard,
        launchReady: true
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
