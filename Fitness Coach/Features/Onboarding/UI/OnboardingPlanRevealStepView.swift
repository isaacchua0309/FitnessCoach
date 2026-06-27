//
//  OnboardingPlanRevealStepView.swift
//  Fitness Coach
//
//  Forma — Journey-first plan reveal for onboarding v2.
//

import SwiftUI

struct OnboardingPlanRevealStepView: View {
    let revealState: OnboardingPlanRevealState?
    let plan: CalorieTargetResult?

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            if let revealState {
                OnboardingJourneyHeroCard(state: revealState)

                if let warningMessage = revealState.warningMessage {
                    OnboardingWarningBanner(message: warningMessage)
                }

                dailyTargetSection(revealState)
                dailyMacrosSection(revealState)

                if !revealState.firstWeekFocusItems.isEmpty {
                    firstWeekSection(revealState)
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

    private func dailyTargetSection(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            sectionTitle(FormaProductCopy.Onboarding.V2.PlanReveal.dailyTargetSectionTitle)

            Text(state.dailyCalorieLabel)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Text(state.calorieExplanationLine)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onboardingCard()
    }

    private func dailyMacrosSection(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            sectionTitle(FormaProductCopy.Onboarding.V2.PlanReveal.macrosSectionTitle)

            ForEach(state.macroRows) { row in
                FormaMetricRow(label: row.label, value: row.value, style: .snapshot)
            }
        }
        .onboardingCard()
    }

    private func firstWeekSection(_ state: OnboardingPlanRevealState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            sectionTitle(FormaProductCopy.Onboarding.V2.PlanReveal.firstWeekSectionTitle)

            ForEach(state.firstWeekFocusItems, id: \.self) { item in
                firstWeekBulletRow(item)
            }
        }
        .onboardingCard()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
            .foregroundStyle(OnboardingTheme.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }

    private func firstWeekBulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .accessibilityHidden(true)

            Text(text)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

#Preview {
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
