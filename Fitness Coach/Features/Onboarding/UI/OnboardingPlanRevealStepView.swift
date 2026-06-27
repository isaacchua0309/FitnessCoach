//
//  OnboardingPlanRevealStepView.swift
//  Fitness Coach
//
//  Forma — Compact plan-ready screen for onboarding v2/v3.
//

import SwiftUI

struct OnboardingPlanRevealStepView: View {
    let revealState: OnboardingPlanRevealState?
    let plan: CalorieTargetResult?

    @State private var showsSecondaryMacros = false

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if let revealState {
                if let warningMessage = revealState.warningMessage {
                    OnboardingWarningBanner(message: warningMessage)
                }

                dailyTargetHero(revealState)
                compactTargetRows(revealState)
                OnboardingPlanJourneySummary(state: revealState)
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

    private func dailyTargetHero(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(FormaProductCopy.Onboarding.V2.PlanReveal.dailyTargetSectionTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .accessibilityAddTraits(.isHeader)

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
            "\(FormaProductCopy.Onboarding.V2.PlanReveal.dailyTargetSectionTitle), \(state.dailyCalorieLabel). \(state.calorieExplanationLine)"
        )
    }

    private func compactTargetRows(_ state: OnboardingPlanRevealState) -> some View {
        VStack(spacing: 0) {
            targetRow(label: "Protein", value: state.proteinLabel)

            Divider()
                .overlay(OnboardingTheme.border.opacity(0.55))
                .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)

            targetRow(label: "Water", value: state.waterLabel)

            if showsSecondaryMacros, !state.secondaryMacroRows.isEmpty {
                ForEach(state.secondaryMacroRows) { row in
                    Divider()
                        .overlay(OnboardingTheme.border.opacity(0.55))
                        .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)

                    targetRow(label: row.label, value: row.value)
                }
            }

            if !state.secondaryMacroRows.isEmpty {
                Divider()
                    .overlay(OnboardingTheme.border.opacity(0.55))
                    .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)

                macrosDisclosureButton
            }
        }
        .onboardingCompactCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily targets")
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
        plan: OnboardingPreviewData.generatedPlan
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("iPhone SE") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
    }
}

#Preview("Large iPhone") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealStepView(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .padding()
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
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
        plan: OnboardingPreviewData.generatedPlan
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
