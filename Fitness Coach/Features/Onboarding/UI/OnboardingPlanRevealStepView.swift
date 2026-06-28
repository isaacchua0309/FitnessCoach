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

    @State private var showsSecondaryMacros = false

    var body: some View {
        Group {
            if let revealState {
                if usesCompactLayout {
                    compactContent(revealState)
                } else {
                    standardContent(revealState)
                }
            } else if let plan {
                GeneratedPlanSummaryCard(
                    plan: plan,
                    pacePreview: nil,
                    paceLabel: nil
                )
            } else {
                OnboardingInfoCard(
                    title: FormaProductCopy.Onboarding.planNotGeneratedTitle,
                    message: FormaProductCopy.Onboarding.planNotGeneratedMessage,
                    icon: "doc.text.magnifyingglass"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Compact layout (fits without scroll)

    private func compactContent(_ state: OnboardingPlanRevealState) -> some View {
        let copy = FormaProductCopy.Onboarding.Flow.PlanReveal.self
        return VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(copy.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(copy.subtitle)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let timelineLine = compactTimelineLine(for: state) {
                    Text(timelineLine)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.accent)
                        .padding(.horizontal, FormaTokens.Spacing.sm)
                        .padding(.vertical, FormaTokens.Spacing.xs)
                        .background(
                            Capsule(style: .continuous)
                                .fill(OnboardingTheme.accent.opacity(0.14))
                        )
                        .accessibilityLabel(timelineLine)
                }
            }

            compactHeroCard(state)
            compactTargetsGrid(state)

            if state.planStatus.style == .caution {
                OnboardingPlanStatusCard(status: state.planStatus)
            }
        }
    }

    private func compactHeroCard(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(state.strategyLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)

            Text(state.dailyCalorieLabel)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(state.calorieExplanationLine)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCompactCard(selected: true)
        .accessibilityElement(children: .combine)
    }

    private func compactTargetsGrid(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(FormaProductCopy.Onboarding.V2.PlanReveal.keyTargetsSectionTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: FormaTokens.Spacing.sm) {
                compactTargetPill(label: "Protein", value: state.proteinLabel)
                compactTargetPill(label: "Water", value: state.waterLabel)
            }

            compactTargetPill(label: "Goal", value: state.goalProgressLabel)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let paceLabel = state.paceLabel {
                compactTargetPill(label: "Pace", value: paceLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !state.secondaryMacroRows.isEmpty {
                if showsSecondaryMacros {
                    HStack(spacing: FormaTokens.Spacing.sm) {
                        ForEach(state.secondaryMacroRows) { row in
                            compactTargetPill(label: row.label, value: row.value)
                        }
                    }
                }
                macrosDisclosureButton
            }
        }
        .onboardingCompactCard()
    }

    private func compactTargetPill(label: String, value: String) -> some View {
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

    private func compactTimelineLine(for state: OnboardingPlanRevealState) -> String? {
        guard let estimatedWeeksLabel = state.estimatedWeeksLabel else { return nil }
        return FormaProductCopy.Onboarding.Flow.PlanReveal.timelineLine(
            estimatedWeeksLabel: estimatedWeeksLabel,
            goalWeightLabel: state.goalWeightLabel
        )
    }

    // MARK: - Standard layout

    private func standardContent(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            planPromiseCard(state)
            keyTargetsCard(state)
            OnboardingPlanStatusCard(status: state.planStatus)
            reassuranceCard
        }
    }

    // MARK: - Plan promise

    private func planPromiseCard(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(state.strategyLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .accessibilityAddTraits(.isHeader)

            Text(FormaProductCopy.Onboarding.V2.PlanReveal.dailyTargetSectionTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)

            Text(state.dailyCalorieLabel)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(state.calorieExplanationLine)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCompactCard(selected: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(state.strategyLabel). \(FormaProductCopy.Onboarding.V2.PlanReveal.dailyTargetSectionTitle), \(state.dailyCalorieLabel). \(state.calorieExplanationLine)"
        )
    }

    // MARK: - Key targets

    private func keyTargetsCard(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(FormaProductCopy.Onboarding.V2.PlanReveal.keyTargetsSectionTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                targetRow(label: "Protein", value: state.proteinLabel)
                targetDivider
                targetRow(label: "Water", value: state.waterLabel)
                targetDivider
                targetRow(label: "Goal", value: state.goalProgressLabel)

                if let paceLabel = state.paceLabel {
                    targetDivider
                    targetRow(label: "Pace", value: paceLabel)
                }

                if showsSecondaryMacros, !state.secondaryMacroRows.isEmpty {
                    ForEach(state.secondaryMacroRows) { row in
                        targetDivider
                        targetRow(label: row.label, value: row.value)
                    }
                }

                if !state.secondaryMacroRows.isEmpty {
                    targetDivider
                    macrosDisclosureButton
                }
            }
        }
        .onboardingCompactCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your daily targets")
    }

    private var targetDivider: some View {
        Divider()
            .overlay(OnboardingTheme.border.opacity(0.55))
            .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
    }

    private var reassuranceCard: some View {
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.Reassurance.self
        return VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(copy.title)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text(copy.body)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                ForEach(copy.bullets, id: \.self) { bullet in
                    Label {
                        Text(bullet)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(OnboardingTheme.accent)
                            .accessibilityHidden(true)
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
        }
        .onboardingCompactCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(copy.title). \(copy.body)")
    }

    private var macrosDisclosureButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showsSecondaryMacros.toggle()
            }
        } label: {
            HStack(spacing: FormaTokens.Spacing.xs) {
                Text(
                    showsSecondaryMacros
                        ? FormaProductCopy.Onboarding.V2.PlanReveal.hideMacrosCTA
                        : FormaProductCopy.Onboarding.V2.PlanReveal.viewMacrosCTA
                )
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)

                Image(systemName: showsSecondaryMacros ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
            .padding(.vertical, OnboardingLayout.compactFieldVerticalPadding)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            showsSecondaryMacros
                ? FormaProductCopy.Onboarding.V2.PlanReveal.hideMacrosCTA
                : FormaProductCopy.Onboarding.V2.PlanReveal.viewMacrosCTA
        )
    }

    private func targetRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(label)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .frame(width: 72, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
        .padding(.vertical, OnboardingLayout.compactFieldVerticalPadding)
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

#Preview("Weight loss plan") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
    }
}

#Preview("Compact") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan,
            usesCompactLayout: true
        )
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
    }
}

#Preview("Maintenance plan") {
    OnboardingPlanRevealStepView(
        revealState: maintenanceRevealState(),
        plan: maintenancePlan()
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Advanced pace plan") {
    OnboardingPlanRevealStepView(
        revealState: advancedPaceRevealState(),
        plan: aggressivePlan()
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}


#Preview("Large Dynamic Type") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
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
