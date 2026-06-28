//
//  OnboardingPlanRevealStepView.swift
//  Fitness Coach
//
//  Forma — Personal plan payoff screen for onboarding.
//

import SwiftUI

struct OnboardingPlanRevealStepView: View {
    let revealState: OnboardingPlanRevealState?
    let plan: CalorieTargetResult?
    var showsSuccessHandoff: Bool = true
    var defersEntranceForGenerationHandoff: Bool = false
    var revealsEntranceImmediately: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var visibleStages: Set<OnboardingPlanRevealEntranceStage>
    @State private var goalSweepActive = false
    @State private var didPlayAppearHaptic = false
    @State private var entranceAnimationToken = UUID()
    @State private var entranceTask: Task<Void, Never>?

    init(
        revealState: OnboardingPlanRevealState?,
        plan: CalorieTargetResult?,
        showsSuccessHandoff: Bool = true,
        defersEntranceForGenerationHandoff: Bool = false,
        revealsEntranceImmediately: Bool = false
    ) {
        self.revealState = revealState
        self.plan = plan
        self.showsSuccessHandoff = showsSuccessHandoff
        self.defersEntranceForGenerationHandoff = defersEntranceForGenerationHandoff
        self.revealsEntranceImmediately = revealsEntranceImmediately
        _visibleStages = State(
            initialValue: revealsEntranceImmediately
                ? Set(OnboardingPlanRevealEntranceStage.allCases)
                : []
        )
    }

    private let copy = FormaProductCopy.Onboarding.Flow.PlanReveal.self
    private let cardCopy = FormaProductCopy.Onboarding.V2.PlanReveal.Cards.self

    var body: some View {
        Group {
            if let revealState {
                adaptiveRevealContent(revealState)
            } else {
                missingStateFallback
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            scheduleEntranceAnimation()
            playAppearHapticIfNeeded()
        }
        .onDisappear {
            entranceTask?.cancel()
        }
    }

    private func scheduleEntranceAnimation() {
        guard !revealsEntranceImmediately else { return }
        entranceTask?.cancel()
        entranceTask = Task { @MainActor in
            if defersEntranceForGenerationHandoff, !reduceMotion {
                try? await Task.sleep(
                    nanoseconds: UInt64(
                        OnboardingGeneratingPlanTiming.stepTransitionAnimation * 1_000_000_000
                    )
                )
            }
            guard !Task.isCancelled else { return }
            runEntranceAnimation()
        }
    }

    // MARK: - Destination-first layout

    private func adaptiveRevealContent(_ state: OnboardingPlanRevealState) -> some View {
        GeometryReader { geometry in
            let profile = OnboardingPlanRevealLayoutProfile.resolve(
                contentHeight: geometry.size.height,
                contentWidth: geometry.size.width,
                dynamicTypeSize: dynamicTypeSize
            )

            VStack(spacing: 0) {
                celebrationSection(profile: profile)
                    .onboardingPlanRevealZone(.celebration)

                OnboardingPlanRevealGoalHeroCard(
                    badge: state.goalHeroSectionTitle,
                    headline: state.goalHeroHeadline,
                    strategyLabel: state.strategyLabel,
                    direction: state.goalDirection,
                    showsSuccessHandoff: showsSuccessHandoff
                )
                .onboardingPlanRevealZone(.goalHero)

                OnboardingPlanRevealJourneyCard(
                    sectionTitle: cardCopy.journeyTitle,
                    progressLabel: state.goalProgressLabel,
                    paceLabel: state.paceLabel,
                    estimatedWeeksLabel: state.estimatedWeeksLabel,
                    beliefLine: state.journeyBeliefLine,
                    planStatus: state.planStatus.style == .caution ? state.planStatus : nil
                )
                .onboardingPlanRevealZone(.journey)

                actionCardsSection(state, profile: profile)
                    .onboardingPlanRevealZone(.actionCards)

                OnboardingPlanRevealCoachCard(message: state.coachMessage)
                    .onboardingPlanRevealZone(.coach)
            }
            .environment(\.onboardingPlanRevealLayoutProfile, profile)
            .environment(\.onboardingPlanRevealContentHeight, geometry.size.height)
            .environment(\.onboardingPlanRevealZoneWeights, profile.zoneWeights)
            .environment(\.onboardingPlanRevealVisibleStages, visibleStages)
            .environment(\.onboardingPlanRevealGoalSweepActive, goalSweepActive)
            .environment(\.onboardingPlanRevealUsesSuccessHandoff, showsSuccessHandoff)
            .environment(\.onboardingPlanRevealUsesCompactLayout, profile == .compact)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(state.accessibilitySummary)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
    }

    private func celebrationSection(profile: OnboardingPlanRevealLayoutProfile) -> some View {
        VStack(spacing: profile == .expansive ? FormaTokens.Spacing.sm : FormaTokens.Spacing.xs) {
            Text(copy.title)
                .font(profile.celebrationTitleFont)
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .onboardingPlanRevealEntrance(.celebrationTitle)

            Text(copy.subtitle)
                .font(profile.celebrationSubtitleFont)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(profile == .compact ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .onboardingPlanRevealEntrance(.celebrationTitle)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func actionCardsSection(
        _ state: OnboardingPlanRevealState,
        profile: OnboardingPlanRevealLayoutProfile
    ) -> some View {
        let firstWeek = OnboardingPlanRevealFirstWeekCard(
            sectionTitle: cardCopy.firstWeekTitle,
            missions: state.firstWeekMissions
        )
        let dailyFuel = OnboardingPlanRevealNutritionCard(
            sectionTitle: cardCopy.dailyFuelTitle,
            explanationLine: state.calorieExplanationLine,
            calorieLabel: state.dailyCalorieLabel,
            proteinLabel: state.proteinLabel,
            waterLabel: state.waterLabel,
            secondaryMacroRows: state.secondaryMacroRows
        )

        if profile.stacksActionCards {
            VStack(spacing: profile.sectionSpacing) {
                firstWeek
                dailyFuel
            }
        } else {
            HStack(alignment: .top, spacing: profile.sectionSpacing) {
                firstWeek
                    .frame(maxWidth: .infinity)
                dailyFuel
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Fallbacks

    private var missingStateFallback: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(copy.fallbackTitle)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text(copy.fallbackSubtitle)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)

            OnboardingInfoCard(
                title: FormaProductCopy.Onboarding.planNotGeneratedTitle,
                message: FormaProductCopy.Onboarding.planNotGeneratedMessage,
                icon: "doc.text.magnifyingglass"
            )
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
    }

    // MARK: - Entrance

    private func runEntranceAnimation() {
        let token = UUID()
        entranceAnimationToken = token
        visibleStages = []
        goalSweepActive = false

        if reduceMotion {
            visibleStages = Set(OnboardingPlanRevealEntranceStage.allCases)
            return
        }

        OnboardingPlanRevealEntranceAnimator.revealAccumulating(
            stages: Set(OnboardingPlanRevealEntranceStage.allCases),
            reduceMotion: reduceMotion,
            onReveal: { stage in
                guard entranceAnimationToken == token else { return }
                visibleStages.insert(stage)
            },
            onGoalSweep: {
                guard entranceAnimationToken == token else { return }
                goalSweepActive = true
            }
        )
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        if showsSuccessHandoff {
            OnboardingHaptics.selectionChanged()
        }
    }
}

// MARK: - Previews

#Preview("Weight loss plan") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .background(OnboardingTheme.background)
        .formaThemePreview()
    }
}

#Preview("iPhone SE class") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .frame(width: 375, height: 480)
        .background(OnboardingTheme.background)
        .formaThemePreview()
    }
}

#Preview("Pro Max class") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .frame(width: 430, height: 760)
        .background(OnboardingTheme.background)
        .formaThemePreview()
    }
}

#Preview("Maintenance plan") {
    OnboardingPlanRevealStepView(
        revealState: maintenanceRevealState(),
        plan: maintenancePlan()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Advanced pace caution") {
    OnboardingPlanRevealStepView(
        revealState: advancedPaceRevealState(),
        plan: aggressivePlan()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .dynamicTypeSize(.accessibility2)
    }
}

// MARK: - Preview fixtures

private func maintenanceRevealState() -> OnboardingPlanRevealState? {
    var form = OnboardingPreviewData.formState
    form.goalWeightKgText = form.currentWeightKgText
    return OnboardingPlanRevealBuilder.build(
        formState: form,
        plan: maintenancePlan()
    )
}

private func advancedPaceRevealState() -> OnboardingPlanRevealState? {
    var form = OnboardingPreviewData.formState
    form.selectPaceChoice(.advanced)
    form.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.45")
    return OnboardingPlanRevealBuilder.build(
        formState: form,
        plan: aggressivePlan()
    )
}

private func maintenancePlan() -> CalorieTargetResult {
    CalorieTargetResult(
        estimatedBMR: 1480,
        estimatedTDEE: 2290,
        targets: UserTargets(
            calorieTarget: 2290,
            proteinTarget: 130,
            carbTarget: 250,
            fatTarget: 70,
            waterTargetMl: 2520,
            expectedWeeklyWeightLossKg: nil,
            aggressiveness: .moderate
        ),
        estimatedDailyDeficit: 0,
        isAggressive: false,
        warning: nil
    )
}

private func aggressivePlan() -> CalorieTargetResult {
    let plan = OnboardingPreviewData.generatedPlan
    return CalorieTargetResult(
        estimatedBMR: plan.estimatedBMR,
        estimatedTDEE: plan.estimatedTDEE,
        targets: plan.targets,
        estimatedDailyDeficit: plan.estimatedDailyDeficit,
        isAggressive: true,
        warning: "aggressiveDeficit"
    )
}
