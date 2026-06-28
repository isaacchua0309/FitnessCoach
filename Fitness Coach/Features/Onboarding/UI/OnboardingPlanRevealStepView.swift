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
    var usesCompactLayout: Bool = false

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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Reveal layout

    private func revealContent(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            headerSection

            goalHeroCard(state)
            dailyMissionCard(state)
            focusAndNextCard(state)

            if state.planStatus.style == .caution {
                OnboardingPlanStatusCard(status: state.planStatus)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var headerSection: some View {
        let copy = FormaProductCopy.Onboarding.Flow.PlanReveal.self
        return VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(copy.title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(copy.subtitle)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fallbackContent: some View {
        let copy = FormaProductCopy.Onboarding.Flow.PlanReveal.self
        return VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
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

    private func goalHeroCard(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(state.goalHeroSectionTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .accessibilityAddTraits(.isHeader)

            Text(state.goalHeroHeadline)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let progressLine = state.goalHeroProgressLine {
                Text(progressLine)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(state.goalHeroSupport)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCompactCard(selected: true)
        .accessibilityElement(children: .combine)
    }

    private func dailyMissionCard(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(state.dailyMissionSectionTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .accessibilityAddTraits(.isHeader)

            Text(state.dailyMissionCalorieLine)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            HStack(spacing: FormaTokens.Spacing.sm) {
                missionTargetPill(label: "Protein", value: state.proteinLabel)
                missionTargetPill(label: "Water", value: state.waterLabel)
            }

            if !state.secondaryMacroRows.isEmpty {
                HStack(spacing: FormaTokens.Spacing.sm) {
                    ForEach(state.secondaryMacroRows) { row in
                        missionTargetPill(label: row.label, value: row.value)
                    }
                }
            }
        }
        .onboardingCompactCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(state.dailyMissionSectionTitle), \(state.dailyMissionCalorieLine), protein \(state.proteinLabel), water \(state.waterLabel)"
        )
    }

    private func focusAndNextCard(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(state.focusTitle)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text(state.focusBody)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(state.nextStepLine)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, FormaTokens.Spacing.xs)
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .combine)
    }

    private func missionTargetPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

#Preview("Weight loss plan") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan,
            usesCompactLayout: true
        )
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
    }
}

#Preview("Maintenance plan") {
    OnboardingPlanRevealStepView(
        revealState: maintenanceRevealState(),
        plan: maintenancePlan(),
        usesCompactLayout: true
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Gain plan") {
    OnboardingPlanRevealStepView(
        revealState: gainRevealState(),
        plan: maintenancePlan(),
        usesCompactLayout: true
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Imperial loss") {
    OnboardingPlanRevealStepView(
        revealState: imperialLossRevealState(),
        plan: OnboardingPreviewData.generatedPlan,
        usesCompactLayout: true
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Advanced pace caution") {
    OnboardingPlanRevealStepView(
        revealState: advancedPaceRevealState(),
        plan: aggressivePlan(),
        usesCompactLayout: true
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Missing reveal state") {
    OnboardingPlanRevealStepView(
        revealState: nil,
        plan: nil,
        usesCompactLayout: true
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan,
            usesCompactLayout: true
        )
        .padding()
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
