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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var celebrationVisible = false
    @State private var goalVisible = false
    @State private var journeyVisible = false
    @State private var actionCardsVisible = false
    @State private var coachVisible = false
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.PlanReveal.self
    private let cardCopy = FormaProductCopy.Onboarding.V2.PlanReveal.Cards.self

    private var usesStackedActionCards: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        Group {
            if let revealState {
                revealContent(revealState)
            } else if let plan {
                GeneratedPlanSummaryCard(
                    plan: plan,
                    pacePreview: nil,
                    paceLabel: nil
                )
            } else {
                fallbackContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            runEntranceAnimation()
            playAppearHapticIfNeeded()
        }
    }

    // MARK: - Reveal layout

    private func revealContent(_ state: OnboardingPlanRevealState) -> some View {
        VStack(spacing: sectionSpacing) {
            celebrationSection
                .opacity(celebrationVisible ? 1 : 0)
                .offset(y: celebrationVisible ? 0 : 6)

            OnboardingPlanRevealGoalHeroCard(
                badge: state.goalHeroSectionTitle,
                headline: state.goalHeroHeadline,
                strategyLabel: state.strategyLabel,
                direction: state.goalDirection
            )
            .opacity(goalVisible ? 1 : 0)
            .offset(y: goalVisible ? 0 : 6)
            .scaleEffect(goalVisible ? 1 : 0.98)

            OnboardingPlanRevealJourneyCard(
                sectionTitle: cardCopy.journeyTitle,
                progressLabel: state.goalProgressLabel,
                paceLabel: state.paceLabel,
                estimatedWeeksLabel: state.estimatedWeeksLabel,
                beliefLine: state.journeyBeliefLine,
                planStatus: state.planStatus.style == .caution ? state.planStatus : nil
            )
            .opacity(journeyVisible ? 1 : 0)
            .offset(y: journeyVisible ? 0 : 6)

            actionCardsSection(state)
                .opacity(actionCardsVisible ? 1 : 0)
                .offset(y: actionCardsVisible ? 0 : 6)

            OnboardingPlanRevealCoachCard(message: state.coachMessage)
                .opacity(coachVisible ? 1 : 0)
                .offset(y: coachVisible ? 0 : 6)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var celebrationSection: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            Text(copy.title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            Text(copy.subtitle)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func actionCardsSection(_ state: OnboardingPlanRevealState) -> some View {
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

        if usesStackedActionCards {
            VStack(spacing: sectionSpacing) {
                firstWeek
                dailyFuel
            }
        } else {
            HStack(alignment: .top, spacing: sectionSpacing) {
                firstWeek
                    .frame(maxWidth: .infinity)
                dailyFuel
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var sectionSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? FormaTokens.Spacing.sm
            : FormaTokens.Spacing.xs + 2
    }

    private var fallbackContent: some View {
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
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            celebrationVisible = true
            goalVisible = true
            journeyVisible = true
            actionCardsVisible = true
            coachVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.22)) {
            celebrationVisible = true
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.08)) {
            goalVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.20)) {
            journeyVisible = true
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.32)) {
            actionCardsVisible = true
        }
        withAnimation(.easeOut(duration: 0.22).delay(0.44)) {
            coachVisible = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#Preview("Weight loss plan") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
        .background(OnboardingTheme.background)
        .formaThemePreview()
    }
}

#Preview("Maintenance plan") {
    OnboardingPlanRevealStepView(
        revealState: maintenanceRevealState(),
        plan: maintenancePlan()
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .padding(.top, OnboardingLayout.progressHeaderTop)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Gain plan") {
    OnboardingPlanRevealStepView(
        revealState: gainRevealState(),
        plan: maintenancePlan()
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .padding(.top, OnboardingLayout.progressHeaderTop)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Imperial loss") {
    OnboardingPlanRevealStepView(
        revealState: imperialLossRevealState(),
        plan: OnboardingPreviewData.generatedPlan
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .padding(.top, OnboardingLayout.progressHeaderTop)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Advanced pace caution") {
    OnboardingPlanRevealStepView(
        revealState: advancedPaceRevealState(),
        plan: aggressivePlan()
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .padding(.top, OnboardingLayout.progressHeaderTop)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Missing reveal state") {
    OnboardingPlanRevealStepView(
        revealState: nil,
        plan: nil
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .padding(.top, OnboardingLayout.progressHeaderTop)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .padding(.top, OnboardingLayout.progressHeaderTop)
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

private func gainRevealState() -> OnboardingPlanRevealState? {
    var form = OnboardingPreviewData.formState
    form.goalWeightKgText = "78"
    return OnboardingPlanRevealBuilder.build(
        formState: form,
        plan: maintenancePlan()
    )
}

private func imperialLossRevealState() -> OnboardingPlanRevealState? {
    var form = OnboardingPreviewData.formState
    form.unitSystem = .imperial
    return OnboardingPlanRevealBuilder.build(
        formState: form,
        plan: OnboardingPreviewData.generatedPlan
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
