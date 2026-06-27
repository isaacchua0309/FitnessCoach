//
//  JourneyDetailedAnalyticsSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyDetailedAnalyticsSection: View {
    let analytics: ProgressAnalyticsDetail
    let weeklySnapshot: JourneyWeeklySnapshot
    let selectedRangeDays: Int
    let onSelectRange: (Int) -> Void

    @State private var isExpanded = false

    var body: some View {
        FitPilotPlanCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    Text(FormaProductCopy.Journey.analyticsBasedOnDays(analytics.nutritionSummary.loggedDays))
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)

                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                        Text("Range")
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                        ProgressRangeSelector(
                            selectedRangeDays: selectedRangeDays,
                            onSelect: onSelectRange
                        )
                    }

                    analyticsBlock(title: "Nutrition") {
                        analyticsRow("Logged days", "\(analytics.nutritionSummary.loggedDays)")
                        analyticsRow("Avg calories", ProgressFormatter.kcal(analytics.nutritionSummary.averageCalories))
                        analyticsRow("Avg protein", ProgressFormatter.grams(analytics.nutritionSummary.averageProtein))
                        analyticsRow("Avg carbs", ProgressFormatter.grams(analytics.nutritionSummary.averageCarbs))
                        analyticsRow("Avg fat", ProgressFormatter.grams(analytics.nutritionSummary.averageFat))
                        if let fiber = analytics.nutritionSummary.averageFiber {
                            analyticsRow("Avg fiber", ProgressFormatter.grams(fiber))
                        }
                    }

                    analyticsBlock(title: "Water") {
                        analyticsRow("Logged days", "\(analytics.waterSummary.loggedDays)")
                        analyticsRow("Avg water", ProgressFormatter.ml(analytics.waterSummary.averageWaterMl))
                        analyticsRow("Avg target", ProgressFormatter.ml(analytics.waterSummary.averageWaterTargetMl))
                        analyticsRow("Consistency", ProgressFormatter.percent(analytics.waterSummary.consistencyPercent))
                    }

                    trainingAnalyticsBlock

                    weeklyAveragesBlock
                }
                .padding(.top, FormaTokens.Spacing.sm)
                .padding(.bottom, JourneyLayout.scrollBottomContentPadding)
            } label: {
                HStack {
                    Text("Detailed analytics")
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                    Spacer()
                }
            }
            .tint(FormaTokens.Color.accent)
        }
    }

    @ViewBuilder
    private var trainingAnalyticsBlock: some View {
        switch weeklySnapshot.training {
        case .hidden, .locked:
            EmptyView()
        case .connectedEmpty:
            analyticsBlock(title: "Training") {
                Text(FormaProductCopy.Journey.noAppleHealthWorkoutsThisWeek)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)
                Text(FormaProductCopy.Journey.trainingDataFromAppleHealth)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        case .connected:
            if let workout = analytics.workoutSummary, workout.isFromAppleHealth {
                analyticsBlock(title: "Training") {
                    Text(FormaProductCopy.Journey.trainingDataFromAppleHealth)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .padding(.bottom, FormaTokens.Spacing.xs)
                    analyticsRow("Workouts", "\(workout.workoutCount)")
                    if let days = workout.workoutDays {
                        analyticsRow("Workout days", "\(days)")
                    }
                    analyticsRow(
                        "Active calories",
                        ProgressFormatter.kcal(workout.totalEstimatedCaloriesBurned)
                    )
                    if let duration = workout.averageDurationMinutes {
                        analyticsRow("Avg duration", "\(duration) min")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weeklyAveragesBlock: some View {
        let training = weeklySnapshot.training
        let hasWeeklyAverages = weeklySnapshot.averageCalorieDeficit != nil
            || (training.averageCaloriesBurned ?? 0) > 0
            || (training.averageTrainingDurationMinutes ?? 0) > 0

        if hasWeeklyAverages {
            analyticsBlock(title: "This week averages") {
                if let deficit = weeklySnapshot.averageCalorieDeficit {
                    let label = deficit > 0
                        ? "\(deficit) kcal under target"
                        : "\(abs(deficit)) kcal above target"
                    analyticsRow("Avg calorie balance", label)
                }
                if case .connected = training,
                   let burned = training.averageCaloriesBurned,
                   burned > 0 {
                    analyticsRow("Avg active calories", "\(burned) kcal per workout")
                }
                if case .connected = training,
                   let duration = training.averageTrainingDurationMinutes,
                   duration > 0 {
                    analyticsRow("Avg training duration", "\(duration) min")
                }
            }
        }
    }

    private func analyticsBlock(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            FormaSectionLabel(title: title)
            content()
        }
    }

    private func analyticsRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
            Spacer(minLength: FormaTokens.Spacing.xs)
            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
