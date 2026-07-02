//
//  OnboardingTransformationCard.swift
//  Fitness Coach
//
//  Forma — Progressive benefit disclosure card for onboarding marketing screens.
//

import SwiftUI

struct OnboardingTransformationCard: View {
    let benefits: [OnboardingBenefitItem]
    let accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeIndex = 0
    @State private var advanceTask: Task<Void, Never>?

    @ScaledMetric(relativeTo: .title2) private var iconSize = OnboardingVisual.benefitIconHero

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ZStack {
                if let benefit = activeBenefit {
                    benefitPanel(benefit)
                        .id(activeIndex)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(reduceMotion ? nil : OnboardingMotion.transitionEase, value: activeIndex)
            .contentShape(Rectangle())
            .onTapGesture { advanceManually() }

            pageIndicator
        }
        .padding(.horizontal, FormaTokens.Spacing.lg)
        .padding(.vertical, FormaTokens.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: setActiveIndex(activeIndex + 1)
            case .decrement: setActiveIndex(activeIndex - 1)
            @unknown default: break
            }
        }
        .onAppear { startAutoAdvance() }
        .onDisappear {
            advanceTask?.cancel()
            advanceTask = nil
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(OnboardingGradients.cardAccentWash)
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .stroke(OnboardingTheme.accent.opacity(OnboardingVisual.accentCardBorderOpacity), lineWidth: 1)
            )
            .shadow(
                color: OnboardingTheme.accent.opacity(0.1),
                radius: OnboardingVisual.cardShadowRadius,
                y: OnboardingVisual.cardShadowY
            )
    }

    private var activeBenefit: OnboardingBenefitItem? {
        guard !benefits.isEmpty else { return nil }
        let wrapped = ((activeIndex % benefits.count) + benefits.count) % benefits.count
        return benefits[wrapped]
    }

    private func benefitPanel(_ benefit: OnboardingBenefitItem) -> some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(OnboardingTheme.accent.opacity(0.14))
                    .frame(width: iconSize + 28, height: iconSize + 28)

                Image(systemName: benefit.icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)

            Text(benefit.title)
                .font(OnboardingMarketingTypography.benefitTitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }

    private var pageIndicator: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(benefits.indices, id: \.self) { index in
                Capsule()
                    .fill(
                        index == normalizedActiveIndex
                            ? OnboardingTheme.primary
                            : OnboardingTheme.progressTrack.opacity(0.85)
                    )
                    .frame(width: index == normalizedActiveIndex ? 20 : 7, height: 7)
                    .animation(reduceMotion ? nil : OnboardingMotion.indicatorEase, value: activeIndex)
            }
        }
        .accessibilityHidden(true)
    }

    private var normalizedActiveIndex: Int {
        guard !benefits.isEmpty else { return 0 }
        return ((activeIndex % benefits.count) + benefits.count) % benefits.count
    }

    private func startAutoAdvance() {
        guard !reduceMotion, benefits.count > 1 else { return }
        advanceTask?.cancel()
        advanceTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: OnboardingMotion.benefitReelInterval)
                guard !Task.isCancelled else { return }
                setActiveIndex(activeIndex + 1)
            }
        }
    }

    private func advanceManually() {
        setActiveIndex(activeIndex + 1)
        startAutoAdvance()
    }

    private func setActiveIndex(_ index: Int) {
        guard !benefits.isEmpty else { return }
        activeIndex = index
    }
}

#if DEBUG
#Preview {
    OnboardingTransformationCard(
        benefits: OnboardingAlmostThereValues.benefits,
        accessibilityLabel: OnboardingAlmostThereValues.benefitsAccessibilityLabel
    )
    .frame(height: 200)
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
