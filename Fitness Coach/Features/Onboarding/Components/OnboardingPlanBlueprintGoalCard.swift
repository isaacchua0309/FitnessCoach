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
    @State private var launchPulse = false

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.directionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .textCase(.uppercase)
                    .tracking(0.45)

                Text(state.targetWeight)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                visualMetric(caption: state.paceCaption, value: state.paceValue, fill: 0.68)
                visualMetric(caption: state.timelineCaption, value: state.timelineValue, fill: 0.82)
            }
            .frame(maxWidth: 148)
        }
        .padding(.horizontal, FormaTokens.Spacing.md)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .textCase(.uppercase)
                .lineLimit(1)

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
            .frame(height: 4)

            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(2)
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
