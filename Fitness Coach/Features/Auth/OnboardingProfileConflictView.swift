//
//  OnboardingProfileConflictView.swift
//  Fitness Coach
//
//  Forma — Resolve onboarding vs existing cloud profile after sign-in.
//

import SwiftUI

struct OnboardingProfileConflictView: View {
    let summary: OnboardingProfileConflictSummary
    let isResolving: Bool
    let onRestoreExisting: () -> Void
    let onUseNewPlan: () -> Void

    private let copy = FormaProductCopy.Onboarding.V2.ProfileConflict.self

    var body: some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: FormaTokens.Spacing.lg) {
                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.md) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.accent)
                        .accessibilityHidden(true)

                    Text(copy.title)
                        .font(FormaTokens.Typography.screenTitle)
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(copy.body)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)

                if summary.showsComparison {
                    comparisonCard
                        .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                        .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
                }

                Spacer(minLength: 0)

                VStack(spacing: FormaTokens.Spacing.sm) {
                    Button(action: onRestoreExisting) {
                        Group {
                            if isResolving {
                                SwiftUI.ProgressView()
                                    .tint(.white)
                            } else {
                                Text(copy.restoreCTA)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingTheme.accent)
                    .disabled(isResolving)

                    Button(action: onUseNewPlan) {
                        Text(copy.useNewPlanCTA)
                            .font(FormaTokens.Typography.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    }
                    .buttonStyle(.bordered)
                    .tint(OnboardingTheme.secondaryText)
                    .disabled(isResolving)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.bottom, FormaTokens.Spacing.lg)
                .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            }
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
    }

    private var comparisonCard: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            comparisonColumn(
                title: copy.existingPlanLabel,
                dailyTarget: summary.existingDailyTargetLabel,
                goalWeight: summary.existingGoalWeightLabel
            )

            Divider()
                .overlay(OnboardingTheme.border.opacity(0.55))

            comparisonColumn(
                title: copy.newPlanLabel,
                dailyTarget: summary.newDailyTargetLabel,
                goalWeight: summary.newGoalWeightLabel
            )
        }
        .onboardingCompactCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Plan comparison")
    }

    private func comparisonColumn(title: String, dailyTarget: String, goalWeight: String) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .accessibilityAddTraits(.isHeader)

            comparisonRow(label: copy.dailyTargetLabel, value: dailyTarget)
            comparisonRow(label: copy.goalWeightLabel, value: goalWeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func comparisonRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

#Preview {
    OnboardingProfileConflictView(
        summary: OnboardingProfileConflictSummary(
            existingDailyTargetLabel: "1,950 kcal",
            existingGoalWeightLabel: "72 kg",
            newDailyTargetLabel: "2,080 kcal",
            newGoalWeightLabel: "79.5 kg"
        ),
        isResolving: false,
        onRestoreExisting: {},
        onUseNewPlan: {}
    )
}
