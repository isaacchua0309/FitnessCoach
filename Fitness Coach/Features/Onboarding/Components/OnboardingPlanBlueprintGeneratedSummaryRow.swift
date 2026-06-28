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
    @State private var cardPulse = false

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: FormaTokens.Spacing.xs),
        count: 3
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(FormaProductCopy.Onboarding.Flow.Summary.GeneratedSummary.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: FormaTokens.Spacing.xs) {
                ForEach(signals) { signal in
                    factorCard(signal)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
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

    private var accessibilitySummary: String {
        let spokenFactors = signals
            .filter(\.isIncluded)
            .map { "\($0.label): \($0.detail)" }
            .joined(separator: ". ")
        return "\(FormaProductCopy.Onboarding.Flow.Summary.GeneratedSummary.title). \(spokenFactors)"
    }

    private func factorCard(_ signal: OnboardingPlanBlueprintGeneratedSignal) -> some View {
        let accentColor = accent(for: signal.accent)
        let isActive = signal.isIncluded

        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(isActive ? 0.2 : 0.08))
                    .frame(width: 30, height: 30)
                Image(systemName: signal.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isActive ? accentColor : OnboardingTheme.tertiaryText)
            }

            Text(signal.label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isActive ? OnboardingTheme.primaryText : OnboardingTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Text(signal.detail)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(isActive ? OnboardingTheme.secondaryText : OnboardingTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(signal.label), \(signal.detail)")
        .accessibilityHint(isActive ? "Included in your plan" : "Pending")
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
