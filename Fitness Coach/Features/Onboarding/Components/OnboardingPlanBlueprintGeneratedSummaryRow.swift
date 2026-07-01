//
//  OnboardingPlanBlueprintGeneratedSummaryRow.swift
//  Fitness Coach
//
//  Forma — Compact personalization inputs for plan blueprint screen.
//

import SwiftUI

struct OnboardingPlanBlueprintPersonalizationSignalStrip: View {
    let signals: [OnboardingPlanBlueprintGeneratedSignal]
    var launchReady: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingVisionLayoutProfile) private var layoutProfile
    @Environment(\.onboardingVisionZoneHeight) private var zoneHeight
    @State private var cardPulse = false

    @ScaledMetric(relativeTo: .caption2) private var iconSize: CGFloat = 24

    private var sectionSpacing: CGFloat {
        layoutProfile == .compact ? FormaTokens.Spacing.xs : FormaTokens.Spacing.sm
    }

    private var cardPadding: CGFloat {
        layoutProfile == .compact ? FormaTokens.Spacing.sm : FormaTokens.Spacing.md
    }

    private var rowVerticalPadding: CGFloat {
        layoutProfile == .compact ? 6 : 8
    }

    private var visibleSignals: [OnboardingPlanBlueprintGeneratedSignal] {
        let priority = signals.contains { $0.id == "pace" }
            ? ["pace", "expectedLoss", "dailyDeficit", "nutrition"]
            : ["activity", "nutrition", "lifestyle", "training"]

        return priority.compactMap { id in
            signals.first { $0.id == id }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            Text(FormaProductCopy.Onboarding.Flow.Summary.GeneratedSummary.title)
                .font(OnboardingMarketingTypography.blueprintSection)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(visibleSignals.enumerated()), id: \.element.id) { index, signal in
                    if index > 0 {
                        rowDivider
                    }
                    signalRow(signal)
                }
            }
            .padding(cardPadding)
            .onboardingPlanBlueprintSurface(.card, launchPulse: cardPulse)
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

    private var rowDivider: some View {
        Rectangle()
            .fill(OnboardingTheme.border.opacity(0.2))
            .frame(height: 0.5)
            .padding(.vertical, rowVerticalPadding)
    }

    private func signalRow(_ signal: OnboardingPlanBlueprintGeneratedSignal) -> some View {
        let accentColor = accent(for: signal.accent)
        let isActive = signal.isIncluded

        return HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            iconOrb(
                systemName: signal.icon,
                accent: accentColor,
                isActive: isActive
            )

            Text(signal.label)
                .font(OnboardingMarketingTypography.blueprintSupporting.weight(.medium))
                .foregroundStyle(isActive ? OnboardingTheme.secondaryText : OnboardingTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: FormaTokens.Spacing.xs)

            Text(signal.detail)
                .font(OnboardingMarketingTypography.blueprintDetail)
                .foregroundStyle(isActive ? OnboardingTheme.primaryText : OnboardingTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, rowVerticalPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: signal, isActive: isActive))
        .accessibilityHint(isActive ? "Included in your plan" : "Pending")
    }

    private func iconOrb(systemName: String, accent: Color, isActive: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accent.opacity(isActive ? 0.14 : 0.06))
                .frame(width: iconSize, height: iconSize)
            Image(systemName: systemName)
                .font(.system(size: iconSize * 0.42, weight: .semibold))
                .foregroundStyle(isActive ? accent : OnboardingTheme.tertiaryText)
        }
        .accessibilityHidden(true)
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
            return OnboardingTheme.chartPrimary
        case .nutrition:
            return OnboardingTheme.success
        case .lifestyle:
            return OnboardingTheme.warning
        case .training, .pace:
            return OnboardingTheme.chartSecondary
        case .deficit:
            return OnboardingTheme.warning
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
