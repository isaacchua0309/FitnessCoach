//
//  OnboardingSavePlanStepView.swift
//  Fitness Coach
//
//  Forma — Save-plan completion step after plan reveal.
//

import SwiftUI

struct OnboardingSavePlanStepView: View {
    let requiresGoogleSignIn: Bool
    let isBusy: Bool
    var showsSignInSuccess: Bool = false
    let errorMessage: String?
    let planRecap: OnboardingPlanRevealState?
    let onContinue: () -> Void
    let onBack: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var headerVisible = false
    @State private var contentVisible = false
    @State private var footerVisible = false

    private let copy = FormaProductCopy.Onboarding.V2.SavePlan.self

    private var showsSignInError: Bool {
        errorMessage != nil
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = OnboardingSavePlanLayoutMetrics(
                size: geometry.size,
                dynamicTypeSize: dynamicTypeSize
            )

            VStack(spacing: 0) {
                toolbar(metrics: metrics)

                mainContent(metrics: metrics)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                footerSection(metrics: metrics)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .safeAreaPadding(.top, OnboardingLayout.progressHeaderTop)
        .safeAreaPadding(.bottom, OnboardingLayout.savePlanFooterBottomInset)
        .onAppear {
            runEntranceAnimation()
        }
    }

    // MARK: - Layout

    private func toolbar(metrics: OnboardingSavePlanLayoutMetrics) -> some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .frame(width: FormaTokens.Layout.minTouchTarget, height: 32, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(FormaProductCopy.Common.back)

            Spacer(minLength: 0)
        }
        .padding(.bottom, metrics.toolbarBottomSpacing)
    }

    private func mainContent(metrics: OnboardingSavePlanLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
            headerSection(metrics: metrics)

            if let planRecap {
                OnboardingSavePlanSummaryCard(state: planRecap, metrics: metrics)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.28).delay(0.04), value: contentVisible)
            }

            if requiresGoogleSignIn {
                OnboardingSaveBenefitsCard(metrics: metrics)
                    .opacity(contentVisible ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.28).delay(0.08), value: contentVisible)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func headerSection(metrics: OnboardingSavePlanLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.isVeryCompactHeight ? 4 : FormaTokens.Spacing.xs) {
            Text(copy.finalStepLabel.uppercased())
                .font(metrics.completionLabelFont)
                .foregroundStyle(OnboardingTheme.accent)
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule(style: .continuous)
                        .fill(OnboardingTheme.accent.opacity(0.12))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: metrics.isVeryCompactHeight ? 4 : FormaTokens.Spacing.xs) {
                Text(celebrationTitle)
                    .font(metrics.heroTitleFont)
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)

                Text(celebrationSubtitle(metrics: metrics))
                    .font(metrics.heroSubtitleFont)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(metrics.heroSubtitleLineLimit)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }
        }
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: headerVisible)
    }

    private func footerSection(metrics: OnboardingSavePlanLayoutMetrics) -> some View {
        VStack(spacing: metrics.footerSpacing) {
            if requiresGoogleSignIn {
                OnboardingSavePlanPrivacyNote(metrics: metrics)

                if showsSignInError, let errorMessage {
                    OnboardingSavePlanInlineError(message: errorMessage)
                        .transition(.opacity)
                }

                OnboardingSavePlanGoogleCTA(
                    isLoading: isBusy,
                    showsSuccess: showsSignInSuccess,
                    isDisabled: isBusy || showsSignInSuccess,
                    action: onContinue
                )
                .accessibilitySortPriority(100)
            } else {
                signedInContinueButton
            }
        }
        .padding(.top, metrics.footerSpacing)
        .opacity(footerVisible ? 1 : 0)
        .offset(y: footerVisible ? 0 : 8)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.06), value: footerVisible)
    }

    private var signedInContinueButton: some View {
        Button(action: onContinue) {
            Text(copy.signedInContinueCTA)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(OnboardingTheme.primary)
        .disabled(isBusy)
        .accessibilityLabel(copy.signedInContinueCTA)
        .accessibilityHint(copy.signedInContinueAccessibilityHint)
        .accessibilitySortPriority(100)
    }

    // MARK: - Copy

    private var celebrationTitle: String {
        requiresGoogleSignIn ? copy.title : copy.signedInTitle
    }

    private func celebrationSubtitle(metrics: OnboardingSavePlanLayoutMetrics) -> String {
        if requiresGoogleSignIn {
            return metrics.isVeryCompactHeight ? copy.subtitleCompact : copy.subtitle
        }
        return copy.signedInSubtitle
    }

    // MARK: - Entrance

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            contentVisible = true
            footerVisible = true
            return
        }

        headerVisible = false
        contentVisible = false
        footerVisible = false

        withAnimation(.easeOut(duration: 0.28)) {
            headerVisible = true
        }

        withAnimation(.easeOut(duration: 0.28).delay(0.05)) {
            contentVisible = true
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
            footerVisible = true
        }
    }
}

#if DEBUG
private enum OnboardingSavePlanPreviewSupport {
    static func preview(
        requiresGoogleSignIn: Bool = true,
        isBusy: Bool = false,
        showsSignInSuccess: Bool = false,
        errorMessage: String? = nil,
        planRecap: OnboardingPlanRevealState? = OnboardingPreviewData.planRevealState,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        dynamicTypeSize: DynamicTypeSize = .large
    ) -> some View {
        Group {
            if let width, let height {
                OnboardingSavePlanStepView(
                    requiresGoogleSignIn: requiresGoogleSignIn,
                    isBusy: isBusy,
                    showsSignInSuccess: showsSignInSuccess,
                    errorMessage: errorMessage,
                    planRecap: planRecap,
                    onContinue: {},
                    onBack: {}
                )
                .frame(width: width, height: height)
            } else {
                OnboardingSavePlanStepView(
                    requiresGoogleSignIn: requiresGoogleSignIn,
                    isBusy: isBusy,
                    showsSignInSuccess: showsSignInSuccess,
                    errorMessage: errorMessage,
                    planRecap: planRecap,
                    onContinue: {},
                    onBack: {}
                )
            }
        }
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .dynamicTypeSize(dynamicTypeSize)
    }
}

#Preview("iPhone SE") {
    OnboardingSavePlanPreviewSupport.preview(width: 375, height: 667)
}

#Preview("iPhone 13 mini") {
    OnboardingSavePlanPreviewSupport.preview(width: 375, height: 812)
}

#Preview("iPhone 15") {
    OnboardingSavePlanPreviewSupport.preview(width: 393, height: 852)
}

#Preview("iPhone 15 Pro Max") {
    OnboardingSavePlanPreviewSupport.preview(width: 430, height: 932)
}

#Preview("Loading") {
    OnboardingSavePlanPreviewSupport.preview(isBusy: true)
}

#Preview("Error") {
    OnboardingSavePlanPreviewSupport.preview(
        errorMessage: FormaProductCopy.Onboarding.V2.SavePlan.signInRetryHeadline
    )
}

#Preview("Signed-in flow") {
    OnboardingSavePlanPreviewSupport.preview(requiresGoogleSignIn: false)
}

#Preview("Long goal / Large Dynamic Type") {
    OnboardingSavePlanPreviewSupport.preview(
        planRecap: longGoalPlanRevealState(),
        dynamicTypeSize: .accessibility2
    )
}

private func longGoalPlanRevealState() -> OnboardingPlanRevealState? {
    guard var state = OnboardingPreviewData.planRevealState else { return nil }
    return OnboardingPlanRevealState(
        goalDirection: state.goalDirection,
        currentWeightLabel: state.currentWeightLabel,
        goalWeightLabel: state.goalWeightLabel,
        goalProgressLabel: state.goalProgressLabel,
        goalHeroSectionTitle: state.goalHeroSectionTitle,
        goalHeroHeadline: "Reach 60 kg with steady consistency",
        accessibilitySummary: state.accessibilitySummary,
        paceLabel: state.paceLabel,
        estimatedWeeksLabel: state.estimatedWeeksLabel,
        strategyLabel: state.strategyLabel,
        dailyCalorieLabel: state.dailyCalorieLabel,
        calorieExplanationLine: state.calorieExplanationLine,
        proteinLabel: state.proteinLabel,
        waterLabel: state.waterLabel,
        secondaryMacroRows: state.secondaryMacroRows,
        journeyBeliefLine: state.journeyBeliefLine,
        firstWeekMissions: state.firstWeekMissions,
        coachMessage: state.coachMessage,
        planStatus: state.planStatus
    )
}
#endif
