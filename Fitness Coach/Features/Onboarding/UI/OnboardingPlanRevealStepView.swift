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
            let baseIsCompactHeight = OnboardingPlanRevealLayoutProfile.isCompactHeight(
                geometry.size.height
            )
            let isCompactWidth = OnboardingPlanRevealLayoutProfile.isCompactWidth(geometry.size.width)
            let profile = resolvedLayoutProfile(
                contentHeight: geometry.size.height,
                contentWidth: geometry.size.width
            )
            let stacksActionCards = OnboardingPlanRevealLayoutProfile.shouldStackActionCards(
                width: geometry.size.width,
                height: geometry.size.height,
                dynamicTypeSize: dynamicTypeSize
            )

            ViewThatFits(in: .vertical) {
                planRevealColumn(
                    state,
                    profile: profile,
                    density: .standard,
                    isCompactHeight: baseIsCompactHeight,
                    isCompactWidth: isCompactWidth,
                    stacksActionCards: stacksActionCards
                )
                planRevealColumn(
                    state,
                    profile: profile,
                    density: .compact,
                    isCompactHeight: true,
                    isCompactWidth: isCompactWidth,
                    stacksActionCards: true
                )
                planRevealColumn(
                    state,
                    profile: .compact,
                    density: .tight,
                    isCompactHeight: true,
                    isCompactWidth: true,
                    stacksActionCards: true
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .environment(\.onboardingPlanRevealFixedViewport, true)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(state.accessibilitySummary)
        }
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
    }

    private func planRevealColumn(
        _ state: OnboardingPlanRevealState,
        profile: OnboardingPlanRevealLayoutProfile,
        density: OnboardingPlanRevealContentDensity,
        isCompactHeight: Bool,
        isCompactWidth: Bool,
        stacksActionCards: Bool
    ) -> some View {
        let sectionSpacing = profile.planRevealSectionSpacing(isCompactHeight: isCompactHeight)
        let usesTightCompression = density == .tight

        return VStack(spacing: sectionSpacing) {
            celebrationSection(
                profile: profile,
                isCompactHeight: isCompactHeight,
                usesTightCompression: usesTightCompression
            )
            .layoutPriority(3)

            OnboardingPlanRevealGoalHeroCard(
                badge: state.goalHeroSectionTitle,
                headline: state.goalHeroHeadline,
                strategyLabel: state.strategyLabel,
                direction: state.goalDirection,
                showsSuccessHandoff: showsSuccessHandoff
            )
            .layoutPriority(2)

            OnboardingPlanRevealJourneyCard(
                sectionTitle: cardCopy.journeyTitle,
                progressLabel: state.goalProgressLabel,
                paceLabel: state.paceLabel,
                estimatedWeeksLabel: state.estimatedWeeksLabel,
                beliefLine: state.journeyBeliefLine,
                planStatus: state.planStatus.style == .caution ? state.planStatus : nil
            )
            .layoutPriority(2)

            actionCardsSection(
                state,
                stacksVertically: stacksActionCards,
                spacing: sectionSpacing
            )
            .layoutPriority(1)

            Spacer(minLength: 0)
                .layoutPriority(0)

            OnboardingPlanRevealCoachCard(message: state.coachMessage)
                .layoutPriority(3)
        }
        .environment(\.onboardingPlanRevealLayoutProfile, profile)
        .environment(\.onboardingPlanRevealIsCompactHeight, isCompactHeight)
        .environment(\.onboardingPlanRevealIsCompactWidth, isCompactWidth)
        .environment(\.onboardingPlanRevealActionCardsAreSideBySide, !stacksActionCards)
        .environment(\.onboardingPlanRevealContentDensity, density)
        .environment(\.onboardingPlanRevealVisibleStages, visibleStages)
        .environment(\.onboardingPlanRevealGoalSweepActive, goalSweepActive)
        .environment(\.onboardingPlanRevealUsesSuccessHandoff, showsSuccessHandoff)
        .environment(\.onboardingPlanRevealUsesCompactLayout, profile == .compact || isCompactHeight)
    }

    private func resolvedLayoutProfile(
        contentHeight: CGFloat,
        contentWidth: CGFloat
    ) -> OnboardingPlanRevealLayoutProfile {
        let base = OnboardingPlanRevealLayoutProfile.resolve(
            contentHeight: contentHeight,
            contentWidth: contentWidth,
            dynamicTypeSize: dynamicTypeSize
        )
        switch base {
        case .expansive:
            return .regular
        case .compact, .regular:
            return base
        }
    }

    private func celebrationSection(
        profile: OnboardingPlanRevealLayoutProfile,
        isCompactHeight: Bool,
        usesTightCompression: Bool = false
    ) -> some View {
        VStack(spacing: isCompactHeight ? FormaTokens.Spacing.xs : FormaTokens.Spacing.sm) {
            Text(copy.title)
                .font(profile.celebrationTitleFont)
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(usesTightCompression ? 1 : 2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .onboardingPlanRevealEntrance(.celebrationTitle)

            Text(copy.subtitle)
                .font(profile.celebrationSubtitleFont)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .onboardingPlanRevealEntrance(.celebrationTitle)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func actionCardsSection(
        _ state: OnboardingPlanRevealState,
        stacksVertically: Bool,
        spacing: CGFloat
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

        if stacksVertically {
            VStack(spacing: spacing) {
                firstWeek
                dailyFuel
            }
        } else {
            HStack(alignment: .top, spacing: spacing) {
                firstWeek
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                dailyFuel
                    .frame(maxWidth: .infinity, alignment: .topLeading)
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
        OnboardingPlanRevealProductionPreviewShell(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .frame(width: 375, height: 667)
        .background(OnboardingTheme.background)
        .formaThemePreview()
    }
}

#Preview("iPhone 15 Pro Max class") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealProductionPreviewShell(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .frame(width: 430, height: 932)
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
        OnboardingPlanRevealProductionPreviewShell(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .frame(width: 393, height: 852)
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
