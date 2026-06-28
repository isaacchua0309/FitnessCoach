//
//  OnboardingIntroProofStepView.swift
//  Fitness Coach
//
//  Forma — intro proof entry with hero trajectory comparison.
//

import SwiftUI

struct OnboardingIntroProofStepView: View {
    private let copy = FormaProductCopy.Onboarding.Flow.IntroProof.self
    private let model = OnboardingWeightTrajectoryComparisonModel.introProofDefault

    @State private var headlineVisible = false
    @State private var chartReveal: CGFloat = 0
    @State private var legendVisible = false
    @State private var takeawayVisible = false

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                headerBlock
                    .opacity(headlineVisible ? 1 : 0)
                    .offset(y: headlineVisible ? 0 : 8)

                OnboardingWeightTrajectoryHeroChart(
                    model: model,
                    revealProgress: chartReveal
                )
                .frame(height: chartHeight(for: geometry.size))

                legendBlock
                    .opacity(legendVisible ? 1 : 0)

                takeawayBlock
                    .opacity(takeawayVisible ? 1 : 0)
                    .offset(y: takeawayVisible ? 0 : 6)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear(perform: runEntranceAnimation)
        .accessibilityElement(children: .contain)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.progressTitleSpacing) {
            Text(copy.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(copy.subtitle)
                .font(.title3)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var legendBlock: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.lg) {
            legendItem(
                color: OnboardingTheme.chartPrimary,
                label: model.formaLabel,
                isDashed: false
            )
            legendItem(
                color: OnboardingTheme.chartSecondary,
                label: model.traditionalLabel,
                isDashed: true
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var takeawayBlock: some View {
        Text(model.takeaway)
            .font(FormaTokens.Typography.bodyMedium)
            .foregroundStyle(OnboardingTheme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(model.takeaway)
    }

    private func legendItem(color: Color, label: String, isDashed: Bool) -> some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Group {
                if isDashed {
                    HStack(spacing: 3) {
                        Capsule().fill(color).frame(width: 8, height: 3)
                        Capsule().fill(color).frame(width: 5, height: 3)
                    }
                } else {
                    Capsule()
                        .fill(color)
                        .frame(width: 22, height: 4)
                }
            }
            .accessibilityHidden(true)

            Text(label)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private func chartHeight(for size: CGSize) -> CGFloat {
        let compact = size.height < 640
        let ratio: CGFloat = compact ? 0.46 : 0.54
        return max(200, min(size.height * ratio, 400))
    }

    private func runEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.22)) {
            headlineVisible = true
        }
        withAnimation(.easeOut(duration: 0.42).delay(0.12)) {
            chartReveal = 1
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.50)) {
            legendVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.66)) {
            takeawayVisible = true
        }
    }
}

#if DEBUG
#Preview("Intro Proof") {
    OnboardingIntroProofStepView()
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
