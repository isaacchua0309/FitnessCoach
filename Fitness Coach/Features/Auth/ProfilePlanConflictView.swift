//
//  ProfilePlanConflictView.swift
//  Fitness Coach
//
//  Forma — Resolve local vs cloud profile when both exist for a signed-in account.
//

import SwiftUI

struct ProfilePlanConflictView: View {
    let summary: ProfilePlanConflictSummary
    let isResolving: Bool
    let onRestoreExisting: () -> Void
    let onUseDevicePlan: () -> Void

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
                        .foregroundStyle(OnboardingTheme.warning)
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
                                    .tint(OnboardingTheme.ctaText)
                            } else {
                                Text(copy.restoreCTA)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OnboardingTheme.ctaBackground)
                    .disabled(isResolving)

                    Button(action: onUseDevicePlan) {
                        Text(copy.useDevicePlanCTA)
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
    }

    private var comparisonCard: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            comparisonColumn(
                title: copy.existingPlanLabel,
                dailyTarget: summary.existingDailyTargetLabel,
                goalWeight: summary.existingGoalWeightLabel,
                updatedAt: summary.existingUpdatedAtLabel,
                pace: nil
            )

            Divider()
                .overlay(OnboardingTheme.border.opacity(0.55))

            comparisonColumn(
                title: copy.devicePlanLabel,
                dailyTarget: summary.deviceDailyTargetLabel,
                goalWeight: summary.deviceGoalWeightLabel,
                updatedAt: nil,
                pace: summary.devicePaceLabel
            )
        }
        .onboardingCompactCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Plan comparison")
    }

    private func comparisonColumn(
        title: String,
        dailyTarget: String,
        goalWeight: String,
        updatedAt: String?,
        pace: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .accessibilityAddTraits(.isHeader)

            comparisonRow(label: copy.dailyTargetLabel, value: dailyTarget)
            comparisonRow(label: copy.goalWeightLabel, value: goalWeight)
            if let updatedAt {
                comparisonRow(label: copy.updatedLabel, value: updatedAt)
            }
            if let pace {
                comparisonRow(label: copy.paceLabel, value: pace)
            }
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
    ProfilePlanConflictView(
        summary: ProfilePlanConflictSummary(
            existingDailyTargetLabel: "1,950 kcal",
            existingGoalWeightLabel: "72 kg",
            existingUpdatedAtLabel: "Jun 1, 2025",
            deviceDailyTargetLabel: "2,080 kcal",
            deviceGoalWeightLabel: "79.5 kg",
            devicePaceLabel: "Moderate"
        ),
        isResolving: false,
        onRestoreExisting: {},
        onUseDevicePlan: {}
    )
    .formaThemePreview()
}
