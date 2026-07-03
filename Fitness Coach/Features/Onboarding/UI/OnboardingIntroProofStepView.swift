//
//  OnboardingIntroProofStepView.swift
//  Fitness Coach
//
//  Forma — intro proof entry with hero trajectory comparison.
//

import SwiftUI

struct OnboardingIntroProofStepView: View {
    private let model = OnboardingWeightTrajectoryComparisonModel.introProofDefault

    @Environment(\.onboardingStepContentHeight) private var contentHeight
    @Environment(\.onboardingStepLayoutProfile) private var layoutProfile

    @State private var chartReveal: CGFloat = 0
    @State private var legendVisible = false
    @State private var takeawayVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: layoutProfile.sectionSpacing) {
            OnboardingWeightTrajectoryHeroChart(
                model: model,
                revealProgress: chartReveal
            )
            .frame(height: chartHeight)

            legendBlock
                .opacity(legendVisible ? 1 : 0)

            takeawayBlock
                .opacity(takeawayVisible ? 1 : 0)
                .offset(y: takeawayVisible ? 0 : 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: runEntranceAnimation)
        .accessibilityElement(children: .contain)
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

    private var chartHeight: CGFloat {
        OnboardingStepLayoutMetrics.introProofChartHeight(
            contentHeight: contentHeight,
            profile: layoutProfile
        )
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

    private func runEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.42).delay(0.08)) {
            chartReveal = 1
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.42)) {
            legendVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.56)) {
            takeawayVisible = true
        }
    }
}

#if DEBUG
#Preview("Intro Proof") {
    OnboardingStepContainer(
        currentStep: .introProof,
        viewState: .editing,
        validationMessage: nil,
        fieldNavigator: OnboardingFieldNavigator(),
        bottomBar: {
            OnboardingBottomBar(
                currentStep: .introProof,
                isLoading: false,
                canContinue: true,
                onBack: {},
                onContinue: {},
                onComplete: {}
            )
        }
    ) {
        OnboardingIntroProofStepView()
    }
    .formaThemePreview()
}
#endif
