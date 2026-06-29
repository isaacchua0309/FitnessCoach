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

    @ScaledMetric(relativeTo: .caption) private var visualHeight: CGFloat = 36

    private var cardPadding: CGFloat {
        layoutProfile == .compact ? FormaTokens.Spacing.md : FormaTokens.Spacing.lg
    }

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
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
        VStack(alignment: .leading, spacing: layoutProfile == .compact ? 6 : 8) {
            featureVisual(feature)
                .frame(height: visualHeight)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(feature.title)
                .font(OnboardingMarketingTypography.blueprintCardTitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(feature.subtitle)
                .font(OnboardingMarketingTypography.blueprintDetail)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onboardingPlanBlueprintSurface(.compact)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.title). \(feature.subtitle)")
    }

    @ViewBuilder
    private func featureVisual(_ feature: OnboardingPlanBlueprintPremiumFeature) -> some View {
        switch feature.visualKind {
        case .nutrition:
            HStack(spacing: 4) {
                miniRing(progress: 0.75, color: OnboardingTheme.chartPrimary)
                miniRing(progress: 0.58, color: OnboardingTheme.chartSecondary)
                miniRing(progress: 0.48, color: OnboardingTheme.success)
            }
        case .activity:
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(activityBarColor(index: index))
                        .frame(
                            width: 6,
                            height: animateBars || reduceMotion
                                ? CGFloat(10 + index * 5)
                                : 8
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

    private func activityBarColor(index: Int) -> Color {
        let colors = [
            OnboardingTheme.chartPrimary,
            OnboardingTheme.chartSecondary,
            OnboardingTheme.chartPrimary,
            OnboardingTheme.success
        ]
        return colors[index % colors.count].opacity(0.55 + Double(index) * 0.1)
    }

    private func miniRing(progress: CGFloat, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 2)
                .frame(width: 22, height: 22)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(-90))
        }
    }

    private var progressSparkline: some View {
        SparklineShape()
            .stroke(
                LinearGradient(
                    colors: [OnboardingTheme.chartPrimary.opacity(0.45), OnboardingTheme.success],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 50, height: min(visualHeight, 22))
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
