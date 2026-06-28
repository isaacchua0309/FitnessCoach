//
//  OnboardingPlanBlueprintGeneratedSummaryRow.swift
//  Fitness Coach
//
//  Forma — Premium personalization factor grid for plan blueprint screen.
//

import SwiftUI

struct OnboardingPlanBlueprintPersonalizationSignalStrip: View {
    let signals: [OnboardingPlanBlueprintGeneratedSignal]
    var launchReady: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.onboardingVisionLayoutProfile) private var layoutProfile
    @Environment(\.onboardingVisionZoneHeight) private var zoneHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var cardPulse = false

    @ScaledMetric(relativeTo: .caption) private var iconContainerSize: CGFloat = 30
    @ScaledMetric(relativeTo: .caption2) private var cardVerticalPadding: CGFloat = 6

    private var usesLandscapeRow: Bool {
        layoutProfile == .compact && horizontalSizeClass == .regular
    }

    private var gridColumns: [GridItem] {
        let count = usesLandscapeRow ? 6 : 3
        return Array(
            repeating: GridItem(.flexible(), spacing: FormaTokens.Spacing.xs),
            count: count
        )
    }

    private var gridSpacing: CGFloat {
        usesLandscapeRow ? 4 : FormaTokens.Spacing.xs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layoutProfile == .compact ? 4 : 6) {
            Text(FormaProductCopy.Onboarding.Flow.Summary.GeneratedSummary.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.55)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(signals) { signal in
                    factorCard(signal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: zoneHeight > 0 ? zoneHeight : nil, alignment: .top)
        .accessibilityElement(children: .contain)
        .onChange(of: launchReady) { _, ready in
            guard ready, !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: OnboardingPlanBlueprintLaunchTiming.pulseDuration)
                    .repeatForever(autoreverses: true)
            ) {
                cardPulse = true
            }
        }
    }

    private func factorCard(_ signal: OnboardingPlanBlueprintGeneratedSignal) -> some View {
        let accentColor = accent(for: signal.accent)
        let isActive = signal.isIncluded
        let showsDetail = !usesLandscapeRow || !dynamicTypeSize.isAccessibilitySize

        return VStack(spacing: usesLandscapeRow ? 2 : 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(isActive ? 0.2 : 0.08))
                    .frame(width: iconContainerSize, height: iconContainerSize)
                Image(systemName: signal.icon)
                    .font(.system(size: iconContainerSize * 0.42, weight: .semibold))
                    .foregroundStyle(isActive ? accentColor : OnboardingTheme.tertiaryText)
            }
            .accessibilityHidden(true)

            Text(signal.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isActive ? OnboardingTheme.primaryText : OnboardingTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .lineLimit(usesLandscapeRow ? 1 : 2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            if showsDetail {
                Text(signal.detail)
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(isActive ? OnboardingTheme.secondaryText : OnboardingTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(usesLandscapeRow ? 1 : 2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, usesLandscapeRow ? 2 : 4)
        .padding(.vertical, cardVerticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(isActive ? 0.12 : 0.04),
                            FormaTokens.Color.surfaceSubtle.opacity(isActive ? 0.95 : 0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(isActive ? 0.75 : 0.2),
                                    accentColor.opacity(isActive ? 0.25 : 0.08)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                        .stroke(
                            accentColor.opacity(isActive && cardPulse ? 0.38 : (isActive ? 0.22 : 0.12)),
                            lineWidth: 1
                        )
                }
        }
        .scaleEffect(isActive && cardPulse && !reduceMotion ? 1.015 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: signal, isActive: isActive))
        .accessibilityHint(isActive ? "Included in your plan" : "Pending")
    }

    private func accessibilityLabel(
        for signal: OnboardingPlanBlueprintGeneratedSignal,
        isActive: Bool
    ) -> String {
        let status = isActive ? "included" : "pending"
        return "\(signal.label), \(signal.detail), \(status)"
    }

    @MainActor
    private func accent(for accent: OnboardingPlanBlueprintSignalAccent) -> Color {
        switch accent {
        case .activity:
            return OnboardingTheme.chartPrimary
        case .weight:
            return OnboardingTheme.chartSecondary
        case .goal:
            return OnboardingTheme.accent
        case .nutrition:
            return OnboardingTheme.success
        case .lifestyle:
            return OnboardingTheme.warning
        case .training:
            return OnboardingTheme.accent
        }
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintPersonalizationSignalStrip(
        signals: OnboardingPlanBlueprintBuilder.build(
            from: OnboardingPreviewData.formState
        ).generatedSignals,
        launchReady: true
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
