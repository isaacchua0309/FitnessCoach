//
//  OnboardingPlanBlueprintAnticipationSection.swift
//  Fitness Coach
//
//  Forma — Visual premium feature tiles for plan blueprint screen.
//

import SwiftUI

struct OnboardingPlanBlueprintPremiumFeatureRow: View {
    let features: [OnboardingPlanBlueprintPremiumFeature]
    let accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingVisionLayoutProfile) private var layoutProfile
    @Environment(\.onboardingVisionZoneHeight) private var zoneHeight
    @State private var animateBars = false

    @ScaledMetric(relativeTo: .caption) private var visualHeight: CGFloat = 28
    @ScaledMetric(relativeTo: .caption2) private var cardVerticalPadding: CGFloat = 7

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            ForEach(features) { feature in
                featureCard(feature)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: zoneHeight > 0 ? zoneHeight : nil, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            animateBars = true
        }
    }

    private func featureCard(_ feature: OnboardingPlanBlueprintPremiumFeature) -> some View {
        VStack(spacing: layoutProfile == .compact ? 3 : 5) {
            featureVisual(feature)
                .frame(height: visualHeight)

            Text(feature.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, layoutProfile == .compact ? 4 : 6)
        .padding(.vertical, cardVerticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FormaTokens.Color.surfaceSubtle,
                            FormaTokens.Color.accentMuted.opacity(0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    OnboardingTheme.accent.opacity(0.6),
                                    OnboardingTheme.accent.opacity(0.15)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                }
        }
        .accessibilityLabel(feature.title)
    }

    @ViewBuilder
    private func featureVisual(_ feature: OnboardingPlanBlueprintPremiumFeature) -> some View {
        switch feature.visualKind {
        case .nutrition:
            HStack(spacing: 3) {
                miniRing(progress: 0.75)
                miniRing(progress: 0.58)
                miniRing(progress: 0.48)
            }
        case .activity:
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(OnboardingTheme.accent.opacity(0.55 + Double(index) * 0.1))
                        .frame(
                            width: 5,
                            height: animateBars || reduceMotion
                                ? CGFloat(8 + index * 4)
                                : 6
                        )
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.8).delay(Double(index) * 0.08),
                            value: animateBars
                        )
                }
            }
        case .progress:
            progressSparkline
        }
    }

    private func miniRing(progress: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(OnboardingTheme.accent.opacity(0.15), lineWidth: 2)
                .frame(width: 18, height: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(OnboardingTheme.accent.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(-90))
        }
    }

    private var progressSparkline: some View {
        SparklineShape()
            .stroke(
                LinearGradient(
                    colors: [OnboardingTheme.accent.opacity(0.45), OnboardingTheme.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 42, height: min(visualHeight, 18))
    }
}

private struct SparklineShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height * 0.75))
            path.addCurve(
                to: CGPoint(x: rect.width * 0.45, y: rect.height * 0.55),
                control1: CGPoint(x: rect.width * 0.15, y: rect.height * 0.9),
                control2: CGPoint(x: rect.width * 0.3, y: rect.height * 0.35)
            )
            path.addCurve(
                to: CGPoint(x: rect.width, y: rect.height * 0.15),
                control1: CGPoint(x: rect.width * 0.62, y: rect.height * 0.72),
                control2: CGPoint(x: rect.width * 0.82, y: rect.height * 0.05)
            )
        }
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintPremiumFeatureRow(
        features: OnboardingPlanBlueprintBuilder.build(
            from: OnboardingPreviewData.formState
        ).premiumFeatures,
        accessibilityLabel: FormaProductCopy.Onboarding.Flow.Summary.PremiumFeatures.accessibilityLabel
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
