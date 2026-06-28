//
//  OnboardingSavePlanStepView.swift
//  Fitness Coach
//
//  Forma — Protect-your-progress step after plan reveal.
//

import SwiftUI

struct OnboardingSavePlanStepView: View {
    let requiresGoogleSignIn: Bool
    let isBusy: Bool
    var showsSignInSuccess: Bool = false
    let errorMessage: String?
    let planRecap: OnboardingPlanRevealState?
    let onContinue: () -> Void
    let onSkip: (() -> Void)?
    let onBack: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var visibleStages: Set<OnboardingPlanRevealEntranceStage> = []
    @State private var entranceAnimationToken = UUID()

    private let copy = FormaProductCopy.Onboarding.V2.SavePlan.self
    private let cardCopy = FormaProductCopy.Onboarding.V2.PlanReveal.Cards.self

    private var showsSignInError: Bool {
        errorMessage != nil
    }

    var body: some View {
        Group {
            if let planRecap {
                adaptiveProtectContent(planRecap)
            } else {
                compactFallbackContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            runContinuationEntranceAnimation()
        }
    }

    // MARK: - Plan reveal continuation layout

    private func adaptiveProtectContent(_ state: OnboardingPlanRevealState) -> some View {
        GeometryReader { geometry in
            let profile = OnboardingPlanRevealLayoutProfile.resolve(
                contentHeight: geometry.size.height,
                contentWidth: geometry.size.width,
                dynamicTypeSize: dynamicTypeSize
            )
            let showsJourney = profile.savePlanShowsJourneyCard

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    upperPlanContent(state, profile: profile, showsJourney: showsJourney)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    pinnedProtectFooter(profile: profile)
                }
                .environment(\.onboardingPlanRevealLayoutProfile, profile)
                .environment(\.onboardingPlanRevealVisibleStages, visibleStages)
                .environment(\.onboardingPlanRevealUsesSuccessHandoff, true)
                .environment(\.onboardingPlanRevealUsesCompactLayout, profile == .compact)
                .accessibilityElement(children: .contain)

                backControl
            }
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .safeAreaPadding(.bottom, OnboardingLayout.savePlanFooterBottomInset)
    }

    private func upperPlanContent(
        _ state: OnboardingPlanRevealState,
        profile: OnboardingPlanRevealLayoutProfile,
        showsJourney: Bool
    ) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                celebrationSection(profile: profile)
                    .onboardingPlanRevealZone(.celebration)

                OnboardingPlanRevealGoalHeroCard(
                    badge: state.goalHeroSectionTitle,
                    headline: state.goalHeroHeadline,
                    strategyLabel: state.strategyLabel,
                    direction: state.goalDirection,
                    showsSuccessHandoff: true
                )
                .onboardingPlanRevealZone(.goalHero)

                if showsJourney {
                    OnboardingPlanRevealJourneyCard(
                        sectionTitle: cardCopy.journeyTitle,
                        progressLabel: state.goalProgressLabel,
                        paceLabel: state.paceLabel,
                        estimatedWeeksLabel: state.estimatedWeeksLabel,
                        beliefLine: state.journeyBeliefLine,
                        planStatus: state.planStatus.style == .caution ? state.planStatus : nil
                    )
                    .onboardingPlanRevealZone(.journey)
                }
            }
            .environment(\.onboardingPlanRevealContentHeight, geometry.size.height)
            .environment(
                \.onboardingPlanRevealZoneWeights,
                profile.savePlanUpperZoneWeights(showsJourney: showsJourney)
            )
        }
    }

    private func celebrationSection(profile: OnboardingPlanRevealLayoutProfile) -> some View {
        VStack(spacing: profile == .expansive ? FormaTokens.Spacing.sm : FormaTokens.Spacing.xs) {
            Text(celebrationTitle)
                .font(profile.celebrationTitleFont)
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .onboardingPlanRevealEntrance(.celebrationTitle)

            Text(celebrationSubtitle)
                .font(profile.celebrationSubtitleFont)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(profile == .compact ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .onboardingPlanRevealEntrance(.celebrationTitle)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FormaTokens.Spacing.xs)
        .padding(.horizontal, FormaTokens.Layout.minTouchTarget)
    }

    private func pinnedProtectFooter(profile: OnboardingPlanRevealLayoutProfile) -> some View {
        VStack(spacing: profile.sectionSpacing) {
            OnboardingPlanRevealCoachCard(message: coachMessage)

            if requiresGoogleSignIn {
                signedOutProtectActions(profile: profile)
            } else {
                signedInProtectActions
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private func signedOutProtectActions(profile: OnboardingPlanRevealLayoutProfile) -> some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            OnboardingSavePlanErrorSlot(showsError: showsSignInError)

            premiumGoogleButton
                .onboardingPlanRevealEntrance(.firstWeek)
                .accessibilitySortPriority(100)

            OnboardingProtectProgressSignInTrustRows(
                visibleRowLimit: profile.savePlanTrustRowLimit
            )
            .onboardingPlanRevealEntrance(.firstWeek)
            .accessibilitySortPriority(80)

            if let onSkip {
                Button(action: onSkip) {
                    Text(copy.skipCTA)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel(copy.skipCTA)
                .accessibilityHint(copy.skipAccessibilityHint)
                .onboardingPlanRevealEntrance(.firstWeek)
                .accessibilitySortPriority(60)
            }
        }
    }

    private var signedInProtectActions: some View {
        Button(action: onContinue) {
            Text(copy.signedInContinueCTA)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(OnboardingTheme.accent)
        .disabled(isBusy)
        .accessibilityLabel(copy.signedInContinueCTA)
        .accessibilityHint(copy.signedInContinueAccessibilityHint)
        .onboardingPlanRevealEntrance(.firstWeek)
        .accessibilitySortPriority(100)
    }

    // MARK: - Fallback (no plan recap)

    private var compactFallbackContent: some View {
        GeometryReader { geometry in
            let profile = OnboardingPlanRevealLayoutProfile.resolve(
                contentHeight: geometry.size.height,
                contentWidth: geometry.size.width,
                dynamicTypeSize: dynamicTypeSize
            )

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    celebrationSection(profile: profile)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    pinnedProtectFooter(profile: profile)
                }
                .environment(\.onboardingPlanRevealLayoutProfile, profile)
                .environment(\.onboardingPlanRevealVisibleStages, visibleStages)
                .environment(\.onboardingPlanRevealUsesCompactLayout, profile == .compact)

                backControl
            }
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .safeAreaPadding(.bottom, OnboardingLayout.savePlanFooterBottomInset)
    }

    // MARK: - Controls

    private var backControl: some View {
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
        .accessibilitySortPriority(120)
    }

    private var premiumGoogleButton: some View {
        FormaGoogleSignInButton(
            title: ProfileSignInCopyPolicy.googleButtonTitle(for: .onboardingCompletion),
            loadingTitle: copy.googleSignInLoadingTitle,
            successTitle: copy.googleSignInSuccessTitle,
            successAccessibilityLabel: copy.googleSignInSuccessAccessibilityLabel,
            isLoading: isBusy,
            showsSuccess: showsSignInSuccess,
            isDisabled: isBusy || showsSignInSuccess,
            action: onContinue,
            accessibilityHint: ProfileSignInCopyPolicy.googleButtonAccessibilityHint(
                for: .onboardingCompletion
            )
        )
    }

    // MARK: - Copy

    private var celebrationTitle: String {
        requiresGoogleSignIn ? copy.title : copy.signedInTitle
    }

    private var celebrationSubtitle: String {
        requiresGoogleSignIn ? copy.subtitle : copy.signedInSubtitle
    }

    private var coachMessage: String {
        requiresGoogleSignIn ? copy.trustNote : copy.signedInTrustNote
    }

    // MARK: - Entrance

    private func runContinuationEntranceAnimation() {
        let token = UUID()
        entranceAnimationToken = token

        OnboardingPlanRevealEntranceAnimator.revealSavePlanContinuation(
            reduceMotion: reduceMotion,
            onReveal: { stage in
                guard entranceAnimationToken == token else { return }
                visibleStages.insert(stage)
            },
            onInitialVisible: { stages in
                guard entranceAnimationToken == token else { return }
                visibleStages = stages
            }
        )
    }
}

#Preview("Signed-out flow") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: true,
        isBusy: false,
        errorMessage: nil,
        planRecap: OnboardingPreviewData.planRevealState,
        onContinue: {},
        onSkip: {},
        onBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Signed-out with error") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: true,
        isBusy: false,
        errorMessage: FormaProductCopy.Onboarding.V2.SavePlan.signInRetryHeadline,
        planRecap: OnboardingPreviewData.planRevealState,
        onContinue: {},
        onSkip: {},
        onBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Signed-in flow") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: false,
        isBusy: false,
        errorMessage: nil,
        planRecap: OnboardingPreviewData.planRevealState,
        onContinue: {},
        onSkip: nil,
        onBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("iPhone SE class") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: true,
        isBusy: false,
        errorMessage: nil,
        planRecap: OnboardingPreviewData.planRevealState,
        onContinue: {},
        onSkip: {},
        onBack: {}
    )
    .frame(width: 375, height: 667)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("iPhone Pro Max class") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: true,
        isBusy: false,
        errorMessage: nil,
        planRecap: OnboardingPreviewData.planRevealState,
        onContinue: {},
        onSkip: {},
        onBack: {}
    )
    .frame(width: 430, height: 932)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    OnboardingSavePlanStepView(
        requiresGoogleSignIn: true,
        isBusy: false,
        errorMessage: nil,
        planRecap: OnboardingPreviewData.planRevealState,
        onContinue: {},
        onSkip: {},
        onBack: {}
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility2)
}
