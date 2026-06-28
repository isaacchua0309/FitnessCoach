//
//  OnboardingAlmostThereBenefitReel.swift
//  Fitness Coach
//
//  Forma — Progressive benefit disclosure for the almost-there milestone.
//

import SwiftUI

struct OnboardingAlmostThereBenefitReel: View {
    let benefits: [OnboardingAlmostThereBenefit]
    let accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeIndex = 0
    @State private var advanceTask: Task<Void, Never>?

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title2) private var reelHeight: CGFloat = 88

    private let advanceInterval: Duration = .seconds(3.2)

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            ZStack {
                if let benefit = activeBenefit {
                    benefitPanel(benefit)
                        .id(activeIndex)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                )
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: reelHeight, alignment: .center)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: activeIndex)
            .contentShape(Rectangle())
            .onTapGesture {
                advanceManually()
            }

            pageIndicator
        }
        .padding(.horizontal, FormaTokens.Spacing.lg)
        .padding(.vertical, FormaTokens.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(reelBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setActiveIndex(activeIndex + 1)
            case .decrement:
                setActiveIndex(activeIndex - 1)
            @unknown default:
                break
            }
        }
        .onAppear {
            startAutoAdvance()
        }
        .onDisappear {
            advanceTask?.cancel()
            advanceTask = nil
        }
    }

    private var activeBenefit: OnboardingAlmostThereBenefit? {
        guard !benefits.isEmpty else { return nil }
        let wrapped = ((activeIndex % benefits.count) + benefits.count) % benefits.count
        return benefits[wrapped]
    }

    private func benefitPanel(_ benefit: OnboardingAlmostThereBenefit) -> some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Image(systemName: benefit.icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text(benefit.title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
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
                            ? OnboardingTheme.accent
                            : OnboardingTheme.progressTrack.opacity(0.85)
                    )
                    .frame(width: index == normalizedActiveIndex ? 18 : 6, height: 6)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: activeIndex)
            }
        }
        .accessibilityHidden(true)
    }

    private var normalizedActiveIndex: Int {
        guard !benefits.isEmpty else { return 0 }
        return ((activeIndex % benefits.count) + benefits.count) % benefits.count
    }

    private var reelBackground: some View {
        RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
            .fill(OnboardingTheme.cardElevated)
            .overlay(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                    .stroke(OnboardingTheme.accent.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: OnboardingTheme.accent.opacity(0.08), radius: 16, y: 8)
    }

    private func startAutoAdvance() {
        guard !reduceMotion, benefits.count > 1 else { return }
        advanceTask?.cancel()
        advanceTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: advanceInterval)
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
    OnboardingAlmostThereBenefitReel(
        benefits: OnboardingAlmostThereValues.benefits,
        accessibilityLabel: OnboardingAlmostThereValues.benefitsAccessibilityLabel
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
